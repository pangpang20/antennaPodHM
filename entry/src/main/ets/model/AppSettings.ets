/**
 * 应用设置
 */
export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark',
  AUTO = 'auto'
}

export class AppSettings {
  // 主题设置
  themeMode: ThemeMode = ThemeMode.AUTO;

  // 网络设置
  wifiOnlyDownload: boolean = true;
  autoDownloadNewEpisodes: boolean = false;

  // 播放设置
  playbackSpeed: number = 1.0;
  skipSilence: boolean = false;
  sleepTimerMinutes: number = 0;
  continuePlayback: boolean = true;

  // 存储设置
  storagePath: string = '';
  autoDeletePlayed: boolean = false;
  keepLastNEpisodes: number = 5;

  // 通知设置
  enableNotifications: boolean = false;
  notifyNewEpisodes: boolean = false;
}
