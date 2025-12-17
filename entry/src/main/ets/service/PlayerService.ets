import media from '@ohos.multimedia.media';
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
 * 播放器服务
 */
export class PlayerService {
  private static instance: PlayerService;
  private avPlayer: media.AVPlayer | null = null;
  private currentEpisode: Episode | null = null;
  private state: PlayerState = PlayerState.IDLE;
  private playbackSpeed: number = 1.0;
  private listeners: Map<string, Function[]> = new Map();

  private constructor() {}

  static getInstance(): PlayerService {
    if (!PlayerService.instance) {
      PlayerService.instance = new PlayerService();
    }
    return PlayerService.instance;
  }

  /**
   * 初始化播放器
   */
  async init(): Promise<void> {
    if (this.avPlayer) {
      return;
    }

    this.avPlayer = await media.createAVPlayer();
    this.setupPlayerCallbacks();
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

    // 开始播放
    await this.avPlayer.play();
  }

  /**
   * 暂停播放
   */
  async pause(): Promise<void> {
    if (this.avPlayer && this.state === PlayerState.PLAYING) {
      await this.avPlayer.pause();
    }
  }

  /**
   * 继续播放
   */
  async resume(): Promise<void> {
    if (this.avPlayer && this.state === PlayerState.PAUSED) {
      await this.avPlayer.play();
    }
  }

  /**
   * 停止播放
   */
  async stop(): Promise<void> {
    if (this.avPlayer) {
      await this.avPlayer.stop();
      this.currentEpisode = null;
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
      callbacks.forEach(callback => callback(data));
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
  }

  /**
   * 等待播放器到达指定状态
   */
  private waitForState(targetState: string): Promise<void> {
    return new Promise((resolve) => {
      const checkState = () => {
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
    if (this.avPlayer) {
      await this.avPlayer.release();
      this.avPlayer = null;
      this.currentEpisode = null;
      this.state = PlayerState.IDLE;
    }
  }
}
