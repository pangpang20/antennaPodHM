import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { AppSettings, ThemeMode } from '../../main/ets/model/AppSettings';

/**
 * AppSettings 模型单元测试
 */
export default function appSettingsTest() {
  describe('AppSettings Model Tests', () => {
    let settings: AppSettings;

    beforeEach(() => {
      settings = new AppSettings();
    });

    /**
     * 测试用例 1: 默认设置值验证
     */
    it('should have correct default values', 0, () => {
      expect(settings.themeMode).assertEqual(ThemeMode.AUTO);
      expect(settings.playbackSpeed).assertEqual(1.0);
      expect(settings.wifiOnlyDownload).assertEqual(true);
      expect(settings.autoDownloadNewEpisodes).assertEqual(false);
      expect(settings.skipSilence).assertEqual(false);
      expect(settings.continuePlayback).assertEqual(true);
      expect(settings.autoDeletePlayed).assertEqual(false);
      expect(settings.keepLastNEpisodes).assertEqual(20);
    });

    /**
     * 测试用例 2: 主题模式设置
     */
    it('should set theme mode correctly', 0, () => {
      settings.themeMode = ThemeMode.LIGHT;
      expect(settings.themeMode).assertEqual(ThemeMode.LIGHT);

      settings.themeMode = ThemeMode.DARK;
      expect(settings.themeMode).assertEqual(ThemeMode.DARK);
    });

    /**
     * 测试用例 3: 播放速度范围验证
     */
    it('should accept valid playback speeds', 0, () => {
      const validSpeeds = [0.75, 1.0, 1.25, 1.5, 2.0, 2.5];

      validSpeeds.forEach(speed => {
        settings.playbackSpeed = speed;
        expect(settings.playbackSpeed).assertEqual(speed);
      });
    });

    /**
     * 测试用例 4: WiFi下载设置
     */
    it('should toggle wifi only download', 0, () => {
      settings.wifiOnlyDownload = true;
      expect(settings.wifiOnlyDownload).assertEqual(true);

      settings.wifiOnlyDownload = false;
      expect(settings.wifiOnlyDownload).assertEqual(false);
    });

    /**
     * 测试用例 5: 自动续播设置
     */
    it('should toggle continue playback', 0, () => {
      settings.continuePlayback = true;
      expect(settings.continuePlayback).assertEqual(true);

      settings.continuePlayback = false;
      expect(settings.continuePlayback).assertEqual(false);
    });

    /**
     * 测试用例 6: 保留单集数量范围
     */
    it('should set keep episodes count in valid range', 0, () => {
      const validCounts = [5, 10, 20, 50, 100];

      validCounts.forEach(count => {
        settings.keepLastNEpisodes = count;
        expect(settings.keepLastNEpisodes).assertEqual(count);
      });
    });

    /**
     * 测试用例 7: 通知设置
     */
    it('should handle notification settings', 0, () => {
      settings.enableNotifications = true;
      settings.notifyNewEpisodes = true;

      expect(settings.enableNotifications).assertEqual(true);
      expect(settings.notifyNewEpisodes).assertEqual(true);
    });

    /**
     * 测试用例 8: 睡眠定时器设置
     */
    it('should set sleep timer minutes', 0, () => {
      settings.sleepTimerMinutes = 30;
      expect(settings.sleepTimerMinutes).assertEqual(30);

      settings.sleepTimerMinutes = 0;
      expect(settings.sleepTimerMinutes).assertEqual(0);
    });
  });
}
