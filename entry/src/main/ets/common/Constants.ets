/**
 * 应用常量定义
 */
export class Constants {
  // 数据库常量
  static readonly DB_NAME: string = 'antennapod.db';
  static readonly DB_VERSION: number = 1;
  
  // 表名
  static readonly TABLE_PODCAST: string = 'podcast';
  static readonly TABLE_EPISODE: string = 'episode';
  static readonly TABLE_QUEUE: string = 'queue';
  
  // Preferences键名
  static readonly PREF_SETTINGS: string = 'app_settings';
  static readonly PREF_THEME: string = 'theme_mode';
  static readonly PREF_PLAYBACK_SPEED: string = 'playback_speed';
  
  // 播放速度选项
  static readonly PLAYBACK_SPEEDS: number[] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  
  // 睡眠定时器选项（分钟）
  static readonly SLEEP_TIMER_OPTIONS: number[] = [5, 10, 15, 30, 45, 60, 90, 120];
  
  // 网络超时设置
  static readonly HTTP_TIMEOUT: number = 15000; // 15秒 - RSS获取超时
  static readonly DOWNLOAD_TIMEOUT: number = 300000; // 5分钟
  
  // 分页设置
  static readonly PAGE_SIZE: number = 20;
  
  // 文件路径
  static readonly DOWNLOAD_DIR: string = 'podcasts';
  static readonly CACHE_DIR: string = 'cache';
  
  // 事件名称
  static readonly EVENT_PLAYBACK_STATE_CHANGED: string = 'playback_state_changed';
  static readonly EVENT_DOWNLOAD_PROGRESS: string = 'download_progress';
  static readonly EVENT_PODCAST_UPDATED: string = 'podcast_updated';
}
