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
  private sleepTimerId: number = -1;
  private sleepTimerMinutes: number = 0;
  private sleepTimerStartTime: number = 0;  // 定时器开始时间戳

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

    this.avPlayer.on('timeUpdate', (timeInMs: number) => {
      if (this.currentEpisode) {
        // AVPlayer 返回的是毫秒，转换为秒
        const timeInSeconds = Math.floor(timeInMs / 1000);
        this.currentEpisode.playbackPosition = timeInSeconds;
        // 移除频繁的日志输出
        this.notifyListeners('timeUpdate', timeInSeconds);
      }
    });

    // 监听时长更新（AVPlayer 加载后会触发）
    this.avPlayer.on('durationUpdate', (durationInMs: number) => {
      if (this.currentEpisode) {
        // AVPlayer 返回的是毫秒，转换为秒
        const durationInSeconds = Math.floor(durationInMs / 1000);
        console.info(`[PlayerService] Duration updated: ${durationInSeconds}s (${durationInMs}ms)`);
        this.currentEpisode.duration = durationInSeconds;
        this.notifyListeners('durationUpdate', durationInSeconds);
      }
    });
  }

  /**
   * 播放Episode
   */
  async playEpisode(episode: Episode): Promise<void> {
    try {
      console.info('[PlayerService] playEpisode start, episode:', episode.title);
      console.info('[PlayerService] audioUrl:', episode.audioUrl);
      console.info('[PlayerService] localPath:', episode.localPath);

      if (!this.avPlayer) {
        console.info('[PlayerService] Initializing player...');
        await this.init();
      }

      if (!this.avPlayer) {
        throw new Error('Failed to initialize player');
      }

      // 如果播放器处于错误状态，先重置
      const currentState = this.avPlayer.state;
      console.info(`[PlayerService] Current AVPlayer state: ${currentState}`);
      
      if (currentState === 'error') {
        console.info('[PlayerService] Player is in error state, resetting...');
        await this.avPlayer.reset();
        await this.waitForState('idle', 3000);
        // 重置后需要重新注册回调
        this.setupPlayerCallbacks();
      }

      // 如果正在播放其他Episode,先停止
      if (this.currentEpisode && this.currentEpisode.id !== episode.id) {
        console.info('[PlayerService] Stopping previous episode...');
        await this.stop();
        // 等待进入 idle 状态
        await this.waitForState('idle', 3000);
      }

      this.currentEpisode = episode;

      // 设置音频源
      const audioUrl = episode.localPath || episode.audioUrl;
      if (!audioUrl || audioUrl.trim().length === 0) {
        throw new Error('No valid audio URL found for episode');
      }

      console.info('[PlayerService] Setting audio URL:', audioUrl);
      this.avPlayer.url = audioUrl;

      // 等待播放器进入 initialized 状态
      console.info('[PlayerService] Waiting for initialized state...');
      await this.waitForState('initialized', 5000);
      console.info('[PlayerService] Player initialized');

      // 调用 prepare 让播放器准备资源
      console.info('[PlayerService] Calling prepare()...');
      await this.avPlayer.prepare();

      // 等待播放器准备就绪
      console.info('[PlayerService] Waiting for prepared state...');
      await this.waitForState('prepared', 10000);
      console.info('[PlayerService] Player prepared successfully');

      // 如果有保存的播放进度,跳转到该位置
      if (episode.playbackPosition > 0) {
        console.info('[PlayerService] Seeking to position:', episode.playbackPosition);
        await this.seek(episode.playbackPosition);
      }

      // 设置播放速度
      if (this.playbackSpeed !== 1.0) {
        console.info('[PlayerService] Setting playback speed:', this.playbackSpeed);
        await this.setPlaybackSpeed(this.playbackSpeed);
      }

      // 开始后台任务
      console.info('[PlayerService] Starting background task...');
      await this.startBackgroundTask();

      // 更新媒体信息
      console.info('[PlayerService] Updating session metadata...');
      await this.updateSessionMetadata();

      // 开始播放
      console.info('[PlayerService] Calling play()...');
      await this.avPlayer.play();
      console.info('[PlayerService] playEpisode completed successfully');
      
      // 打印 AVPlayer 信息
      console.info(`[PlayerService] AVPlayer duration: ${this.avPlayer.duration}ms`);
      console.info(`[PlayerService] AVPlayer currentTime: ${this.avPlayer.currentTime}ms`);
      
      // 测试：1秒后主动获取播放位置
      setTimeout(() => {
        if (this.avPlayer) {
          console.info(`[PlayerService] Manual check - currentTime: ${this.avPlayer.currentTime}ms, duration: ${this.avPlayer.duration}ms`);
        }
      }, 1000);
    } catch (error) {
      console.error('[PlayerService] Failed to play episode:', error);
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
   * 跳转到指定位置（参数为秒，转换为毫秒传给 AVPlayer）
   */
  async seek(positionInSeconds: number): Promise<void> {
    if (this.avPlayer) {
      const positionInMs = Math.floor(positionInSeconds * 1000);
      console.info(`[PlayerService] Seeking to ${positionInSeconds}s (${positionInMs}ms)`);
      await this.avPlayer.seek(positionInMs);
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
    // 优先使用 AVPlayer 的时长，如果没有则使用 Episode 的
    if (this.avPlayer && this.avPlayer.duration > 0) {
      return Math.floor(this.avPlayer.duration / 1000); // 毫秒转秒
    }
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
   * 播放队列相关
   */
  private playQueue: Episode[] = [];

  addToQueue(episode: Episode): void {
    this.playQueue.push(episode);
  }

  getQueue(): Episode[] {
    return this.playQueue.slice();
  }

  clearQueue(): void {
    this.playQueue = [];
  }

  removeFromQueue(index: number): void {
    if (index >= 0 && index < this.playQueue.length) {
      this.playQueue.splice(index, 1);
    }
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
   * 等待播放器到达指定状态（带超时）
   */
  private waitForState(targetState: string, timeoutMs: number = 5000): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (reason: Error) => void) => {
      const startTime = Date.now();
      const checkState = (): void => {
        if (this.avPlayer?.state === targetState) {
          resolve();
        } else if (Date.now() - startTime > timeoutMs) {
          const error = new Error(`Timeout waiting for state: ${targetState}, current state: ${this.avPlayer?.state}`);
          console.error('[PlayerService]', error.message);
          reject(error);
        } else {
          setTimeout(checkState, 100);
        }
      };
      checkState();
    });
  }

  /**
   * 设置睡眠定时器
   */
  setSleepTimer(minutes: number): void {
    console.info(`======>>> Set sleep timer: ${minutes} minutes`);
    
    // 清除之前的定时器
    if (this.sleepTimerId !== -1) {
      clearTimeout(this.sleepTimerId);
      this.sleepTimerId = -1;
    }

    this.sleepTimerMinutes = minutes;
    this.sleepTimerStartTime = minutes > 0 ? Date.now() : 0;

    if (minutes > 0) {
      this.sleepTimerId = setTimeout(() => {
        console.info('======>>> Sleep timer triggered, pausing playback');
        this.pause();
        this.sleepTimerId = -1;
        this.sleepTimerMinutes = 0;
        this.sleepTimerStartTime = 0;
        this.notifyListeners('sleepTimerEnd', null);
      }, minutes * 60 * 1000);
    }
  }

  /**
   * 获取当前睡眠定时器分钟数
   */
  getSleepTimerMinutes(): number {
    return this.sleepTimerMinutes;
  }

  /**
   * 获取睡眠定时器剩余秒数
   */
  getSleepTimerRemaining(): number {
    if (this.sleepTimerMinutes <= 0 || this.sleepTimerStartTime <= 0) {
      return 0;
    }
    
    const elapsed = Date.now() - this.sleepTimerStartTime;
    const totalMs = this.sleepTimerMinutes * 60 * 1000;
    const remaining = Math.max(0, totalMs - elapsed);
    return Math.ceil(remaining / 1000);  // 返回剩余秒数
  }

  /**
   * 清除睡眠定时器
   */
  clearSleepTimer(): void {
    if (this.sleepTimerId !== -1) {
      clearTimeout(this.sleepTimerId);
      this.sleepTimerId = -1;
    }
    this.sleepTimerMinutes = 0;
    this.sleepTimerStartTime = 0;
  }

  /**
   * 释放资源
   */
  async release(): Promise<void> {
    try {
      // 清除睡眠定时器
      this.clearSleepTimer();

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
