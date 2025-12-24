import preferences from '@ohos.data.preferences';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { AppSettings, ThemeMode } from '../model/AppSettings';
import { Constants } from '../common/Constants';

/**
 * 设置服务
 */
export class SettingsService {
  private static instance: SettingsService;
  private preferences: preferences.Preferences | null = null;
  private settings: AppSettings = new AppSettings();
  private context: Context | null = null;

  private constructor() {}

  static getInstance(): SettingsService {
    if (!SettingsService.instance) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }

  /**
   * 初始化设置
   */
  async init(context: Context): Promise<void> {
    try {
      this.context = context;
      this.preferences = await preferences.getPreferences(context, Constants.PREF_SETTINGS);
      await this.loadSettings();
      // 初始化时应用主题
      this.applyTheme(this.settings.themeMode);
    } catch (error) {
      console.error('[SettingsService] Failed to initialize settings:', error);
    }
  }

  /**
   * 加载设置
   */
  private async loadSettings(): Promise<void> {
    if (!this.preferences) return;

    try {
      // 加载主题设置
      const theme = await this.preferences.get(Constants.PREF_THEME, ThemeMode.AUTO);
      this.settings.themeMode = theme as ThemeMode;

      // 加载播放速度
      const speed = await this.preferences.get(Constants.PREF_PLAYBACK_SPEED, 1.0);
      this.settings.playbackSpeed = speed as number;

      // 加载其他设置...
      const wifiOnly = await this.preferences.get('wifi_only_download', true);
      this.settings.wifiOnlyDownload = wifiOnly as boolean;

      const autoDownload = await this.preferences.get('auto_download', false);
      this.settings.autoDownloadNewEpisodes = autoDownload as boolean;

      const skipSilence = await this.preferences.get('skip_silence', false);
      this.settings.skipSilence = skipSilence as boolean;

      const keepEpisodes = await this.preferences.get('keep_last_n_episodes', 20);
      this.settings.keepLastNEpisodes = keepEpisodes as number;

      const continuePlayback = await this.preferences.get('continue_playback', true);
      this.settings.continuePlayback = continuePlayback as boolean;

      const autoDeletePlayed = await this.preferences.get('auto_delete_played', false);
      this.settings.autoDeletePlayed = autoDeletePlayed as boolean;

      const enableNotifications = await this.preferences.get('enable_notifications', false);
      this.settings.enableNotifications = enableNotifications as boolean;

      const notifyNewEpisodes = await this.preferences.get('notify_new_episodes', false);
      this.settings.notifyNewEpisodes = notifyNewEpisodes as boolean;

    } catch (error) {
      console.error('Failed to load settings:', error);
    }
  }

  /**
   * 保存设置
   */
  private async saveSettings(): Promise<void> {
    if (!this.preferences) return;

    try {
      await this.preferences.put(Constants.PREF_THEME, this.settings.themeMode);
      await this.preferences.put(Constants.PREF_PLAYBACK_SPEED, this.settings.playbackSpeed);
      await this.preferences.put('wifi_only_download', this.settings.wifiOnlyDownload);
      await this.preferences.put('auto_download', this.settings.autoDownloadNewEpisodes);
      await this.preferences.put('skip_silence', this.settings.skipSilence);
      await this.preferences.put('keep_last_n_episodes', this.settings.keepLastNEpisodes);
      await this.preferences.put('continue_playback', this.settings.continuePlayback);
      await this.preferences.put('auto_delete_played', this.settings.autoDeletePlayed);
      await this.preferences.put('enable_notifications', this.settings.enableNotifications);
      await this.preferences.put('notify_new_episodes', this.settings.notifyNewEpisodes);
      
      await this.preferences.flush();
    } catch (error) {
      console.error('Failed to save settings:', error);
    }
  }

  /**
   * 获取当前设置
   */
  getSettings(): AppSettings {
    return this.settings;
  }

  /**
   * 设置主题模式
   */
  async setThemeMode(mode: ThemeMode): Promise<void> {
    this.settings.themeMode = mode;
    await this.saveSettings();
    this.applyTheme(mode);
  }

  /**
   * 应用主题到系统
   */
  private applyTheme(mode: ThemeMode): void {
    if (!this.context) {
      console.error('[SettingsService] Context not initialized');
      return;
    }
    try {
      let colorMode: ConfigurationConstant.ColorMode;
      switch (mode) {
        case ThemeMode.LIGHT:
          colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
          break;
        case ThemeMode.DARK:
          colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
          break;
        case ThemeMode.AUTO:
        default:
          colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
          break;
      }
      this.context.getApplicationContext().setColorMode(colorMode);
      console.info(`[SettingsService] Theme applied: ${mode}`);
    } catch (error) {
      console.error('[SettingsService] Failed to apply theme:', error);
    }
  }

  /**
   * 获取主题模式
   */
  getThemeMode(): ThemeMode {
    return this.settings.themeMode;
  }

  /**
   * 设置播放速度
   */
  async setPlaybackSpeed(speed: number): Promise<void> {
    this.settings.playbackSpeed = speed;
    await this.saveSettings();
  }

  /**
   * 获取播放速度
   */
  getPlaybackSpeed(): number {
    return this.settings.playbackSpeed;
  }

  /**
   * 设置仅WiFi下载
   */
  async setWifiOnlyDownload(enabled: boolean): Promise<void> {
    this.settings.wifiOnlyDownload = enabled;
    await this.saveSettings();
  }

  /**
   * 设置自动下载新Episode
   */
  async setAutoDownloadNewEpisodes(enabled: boolean): Promise<void> {
    this.settings.autoDownloadNewEpisodes = enabled;
    await this.saveSettings();
  }

  /**
   * 设置跳过静音
   */
  async setSkipSilence(enabled: boolean): Promise<void> {
    this.settings.skipSilence = enabled;
    await this.saveSettings();
  }

  /**
   * 设置睡眠定时器
   */
  async setSleepTimer(minutes: number): Promise<void> {
    this.settings.sleepTimerMinutes = minutes;
    await this.saveSettings();
  }

  /**
   * 设置保留最近单集数
   */
  async setKeepLastNEpisodes(count: number): Promise<void> {
    this.settings.keepLastNEpisodes = count;
    await this.saveSettings();
  }

  /**
   * 设置自动续播
   */
  async setContinuePlayback(enabled: boolean): Promise<void> {
    this.settings.continuePlayback = enabled;
    await this.saveSettings();
  }

  /**
   * 获取自动续播设置
   */
  getContinuePlayback(): boolean {
    return this.settings.continuePlayback;
  }

  /**
   * 设置自动删除已播放
   */
  async setAutoDeletePlayed(enabled: boolean): Promise<void> {
    this.settings.autoDeletePlayed = enabled;
    await this.saveSettings();
  }

  /**
   * 获取自动删除已播放设置
   */
  getAutoDeletePlayed(): boolean {
    return this.settings.autoDeletePlayed;
  }

  /**
   * 设置启用通知
   */
  async setEnableNotifications(enabled: boolean): Promise<void> {
    this.settings.enableNotifications = enabled;
    await this.saveSettings();
  }

  /**
   * 设置新单集通知
   */
  async setNotifyNewEpisodes(enabled: boolean): Promise<void> {
    this.settings.notifyNewEpisodes = enabled;
    await this.saveSettings();
  }
}
