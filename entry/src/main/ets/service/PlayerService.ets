import media from '@ohos.multimedia.media';
import avSession from '@ohos.multimedia.avsession';
import wantAgent from '@ohos.app.ability.wantAgent';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import { Episode } from '../model/Episode';

/**
 * 播放器状态
 */
export enum PlayerState {
  IDLE = 'idle',
  PLAYING = 'playing',
  PAUSED = 'paused',
  STOPPED = 'stopped',
  ERROR = 'error'
}

/**
 * 播放器服务 - 支持后台播放
 */
export class PlayerService {
  private static instance: PlayerService;
  private avPlayer: media.AVPlayer | null = null;
  private session: avSession.AVSession | null = null;
  private currentEpisode: Episode | null = null;
  private state: PlayerState = PlayerState.IDLE;
  private playbackSpeed: number = 1.0;
  private listeners: Map<string, Function[]> = new Map();
  private context: Context | null = null;
  private isBackgroundRunning: boolean = false;

  private constructor() {}

  static getInstance(): PlayerService {
    if (!PlayerService.instance) {
      PlayerService.instance = new PlayerService();
    }
    return PlayerService.instance;
  }

  /**
   * 设置上下文
   */
  setContext(context: Context): void {
    this.context = context;
  }

  /**
   * 初始化播放器
   */
  async init(): Promise<void> {
    if (this.avPlayer) {
      return;
    }

    try {
      this.avPlayer = await media.createAVPlayer();
      this.setupPlayerCallbacks();
      await this.initAVSession();
    } catch (error) {
      console.error('Failed to initialize player:', error);
    }
  }

  /**
   * 初始化 AVSession 支持后台播放和媒体控制中心
   */
  private async initAVSession(): Promise<void> {
    if (!this.context) {
      console.warn('Context not set, AVSession will not be initialized');
      return;
    }

    try {
      // 创建 AVSession
      this.session = await avSession.createAVSession(this.context, 'AntennaPod', 'audio');
      
      // 设置播放命令回调
      this.session.on('play', () => {
        this.resume();
      });
      
      this.session.on('pause', () => {
        this.pause();
      });
      
      this.session.on('stop', () => {
        this.stop();
      });
      
      this.session.on('seek', (time: number) => {
        this.seek(time);
      });

      // 激活 session
      await this.session.activate();
      console.info('AVSession initialized successfully');
    } catch (error) {
      console.error('Failed to initialize AVSession:', error);
    }
  }

  /**
   * 更新 AVSession 媒体信息
   */
  private async updateSessionMetadata(): Promise<void> {
    if (!this.session || !this.currentEpisode) {
      return;
    }

    try {
      const metadata: avSession.AVMetadata = {
        assetId: this.currentEpisode.id,
        title: this.currentEpisode.title,
        artist: 'Podcast',
        duration: this.currentEpisode.duration
      };
      await this.session.setAVMetadata(metadata);
    } catch (error) {
      console.error('Failed to update session metadata:', error);
    }
  }

  /**
   * 更新 AVSession 播放状态
   */
  private async updateSessionPlaybackState(): Promise<void> {
    if (!this.session) {
      return;
    }

    try {
      let sessionState: avSession.PlaybackState = avSession.PlaybackState.PLAYBACK_STATE_STOP;
      switch (this.state) {
        case PlayerState.PLAYING:
          sessionState = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
          break;
        case PlayerState.PAUSED:
          sessionState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
          break;
        case PlayerState.STOPPED:
          sessionState = avSession.PlaybackState.PLAYBACK_STATE_STOP;
          break;
      }

      const playbackState: avSession.AVPlaybackState = {
        state: sessionState,
        position: {
          elapsedTime: this.currentEpisode?.playbackPosition || 0,
          updateTime: Date.now()
        },
        speed: this.playbackSpeed
      };
      await this.session.setAVPlaybackState(playbackState);
    } catch (error) {
      console.error('Failed to update session playback state:', error);
    }
  }

  /**
   * 开始后台任务
   */
  private async startBackgroundTask(): Promise<void> {
    if (this.isBackgroundRunning || !this.context) {
      return;
    }

    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: 'com.pangpang.antennapod',
            abilityName: 'EntryAbility'
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      const agent = await wantAgent.getWantAgent(wantAgentInfo);

      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        agent
      );

      this.isBackgroundRunning = true;
      console.info('Background task started');
    } catch (error) {
      console.error('Failed to start background task:', error);
    }
  }

  /**
   * 停止后台任务
   */
  private async stopBackgroundTask(): Promise<void> {
    if (!this.isBackgroundRunning || !this.context) {
      return;
    }

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      this.isBackgroundRunning = false;
      console.info('Background task stopped');
    } catch (error) {
      console.error('Failed to stop background task:', error);
    }
  }

  /**
   * 设置播放器回调
   */
  private setupPlayerCallbacks(): void {
    if (!this.avPlayer) return;

    this.avPlayer.on('stateChange', (state: string) => {
      console.info(`AVPlayer state changed to: ${state}`);
      this.updateState(state);
    });

    this.avPlayer.on('error', (err) => {
      console.error('AVPlayer error:', err);
      this.state = PlayerState.ERROR;
      this.notifyListeners('error', err);
    });

    this.avPlayer.on('timeUpdate', (time: number) => {
      if (this.currentEpisode) {
        this.currentEpisode.playbackPosition = time;
        this.notifyListeners('timeUpdate', time);
      }
    });
  }

  /**
   * 播放Episode
   */
  async playEpisode(episode: Episode): Promise<void> {
    try {
      if (!this.avPlayer) {
        await this.init();
      }

      if (!this.avPlayer) {
        throw new Error('Failed to initialize player');
      }

      // 如果正在播放其他Episode,先停止
      if (this.currentEpisode && this.currentEpisode.id !== episode.id) {
        await this.stop();
      }

      this.currentEpisode = episode;

      // 设置音频源
      const audioUrl = episode.localPath || episode.audioUrl;
      this.avPlayer.url = audioUrl;

      // 等待播放器准备就绪
      await this.waitForState('prepared');

      // 如果有保存的播放进度,跳转到该位置
      if (episode.playbackPosition > 0) {
        await this.seek(episode.playbackPosition);
      }

      // 设置播放速度
      if (this.playbackSpeed !== 1.0) {
        await this.setPlaybackSpeed(this.playbackSpeed);
      }

      // 开始后台任务
      await this.startBackgroundTask();

      // 更新媒体信息
      await this.updateSessionMetadata();

      // 开始播放
      await this.avPlayer.play();
    } catch (error) {
      console.error('Failed to play episode:', error);
      this.state = PlayerState.ERROR;
      this.notifyListeners('error', error);
    }
  }

  /**
   * 暂停播放
   */
  async pause(): Promise<void> {
    try {
      if (this.avPlayer && this.state === PlayerState.PLAYING) {
        await this.avPlayer.pause();
      }
    } catch (error) {
      console.error('Failed to pause:', error);
    }
  }

  /**
   * 继续播放
   */
  async resume(): Promise<void> {
    try {
      if (this.avPlayer && this.state === PlayerState.PAUSED) {
        await this.avPlayer.play();
      }
    } catch (error) {
      console.error('Failed to resume:', error);
    }
  }

  /**
   * 停止播放
   */
  async stop(): Promise<void> {
    try {
      if (this.avPlayer) {
        await this.avPlayer.stop();
        this.currentEpisode = null;
      }
      // 停止后台任务
      await this.stopBackgroundTask();
    } catch (error) {
      console.error('Failed to stop:', error);
    }
  }

  /**
   * 跳转到指定位置
   */
  async seek(position: number): Promise<void> {
    if (this.avPlayer) {
      await this.avPlayer.seek(position);
    }
  }

  /**
   * 设置播放速度
   */
  async setPlaybackSpeed(speed: number): Promise<void> {
    if (this.avPlayer) {
      this.playbackSpeed = speed;
      await this.avPlayer.setSpeed(speed);
    }
  }

  /**
   * 获取当前播放位置
   */
  getCurrentPosition(): number {
    return this.currentEpisode?.playbackPosition || 0;
  }

  /**
   * 获取总时长
   */
  getDuration(): number {
    return this.currentEpisode?.duration || 0;
  }

  /**
   * 获取当前播放状态
   */
  getState(): PlayerState {
    return this.state;
  }

  /**
   * 获取当前播放的Episode
   */
  getCurrentEpisode(): Episode | null {
    return this.currentEpisode;
  }

  /**
   * 添加事件监听器
   */
  addEventListener(event: string, callback: Function): void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event)?.push(callback);
  }

  /**
   * 移除事件监听器
   */
  removeEventListener(event: string, callback: Function): void {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  /**
   * 通知监听器
   */
  private notifyListeners(event: string, data?: ESObject): void {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      callbacks.forEach((callback: Function): void => { callback(data); });
    }
  }

  /**
   * 更新播放状态
   */
  private updateState(avState: string): void {
    switch (avState) {
      case 'playing':
        this.state = PlayerState.PLAYING;
        break;
      case 'paused':
        this.state = PlayerState.PAUSED;
        break;
      case 'stopped':
        this.state = PlayerState.STOPPED;
        break;
      case 'error':
        this.state = PlayerState.ERROR;
        break;
      default:
        this.state = PlayerState.IDLE;
    }
    this.notifyListeners('stateChange', this.state);
    // 更新 AVSession 播放状态
    this.updateSessionPlaybackState();
  }

  /**
   * 等待播放器到达指定状态
   */
  private waitForState(targetState: string): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      const checkState = (): void => {
        if (this.avPlayer?.state === targetState) {
          resolve();
        } else {
          setTimeout(checkState, 100);
        }
      };
      checkState();
    });
  }

  /**
   * 释放资源
   */
  async release(): Promise<void> {
    try {
      // 停止后台任务
      await this.stopBackgroundTask();

      // 释放 AVSession
      if (this.session) {
        await this.session.deactivate();
        await this.session.destroy();
        this.session = null;
      }

      // 释放播放器
      if (this.avPlayer) {
        await this.avPlayer.release();
        this.avPlayer = null;
        this.currentEpisode = null;
        this.state = PlayerState.IDLE;
      }
    } catch (error) {
      console.error('Failed to release player:', error);
    }
  }
}
