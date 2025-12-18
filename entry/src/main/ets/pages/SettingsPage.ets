import { router, promptAction } from '@kit.ArkUI';
import { AppSettings, ThemeMode } from '../model/AppSettings';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../common/Constants';

@Entry
@Component
struct SettingsPage {
  @State settings: AppSettings = new AppSettings();
  @State showThemeDialog: boolean = false;
  @State showSpeedDialog: boolean = false;
  @State showKeepEpisodesDialog: boolean = false;
  private settingsService: SettingsService = SettingsService.getInstance();
  private speedOptions: number[] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  private keepEpisodesOptions: number[] = [5, 10, 20, 50, 100];

  aboutToAppear() {
    this.settings = this.settingsService.getSettings();
  }

  build() {
    Column() {
      // 导航栏
      this.buildNavigationBar();

      // 设置列表
      List() {
        // 主题设置
        ListItem() {
          this.buildSettingItem('主题', this.getThemeText(), () => {
            this.showThemeSelector();
          });
        }

        // 网络设置
        ListItemGroup({ header: this.buildGroupHeader('网络设置') }) {
          ListItem() {
            this.buildSwitchItem('仅WiFi下载', this.settings.wifiOnlyDownload, (value: boolean) => {
              this.settingsService.setWifiOnlyDownload(value);
              this.settings.wifiOnlyDownload = value;
            });
          }

          ListItem() {
            this.buildSwitchItem('自动下载新单集', this.settings.autoDownloadNewEpisodes, (value: boolean) => {
              this.settingsService.setAutoDownloadNewEpisodes(value);
              this.settings.autoDownloadNewEpisodes = value;
            });
          }
        }

        // 播放设置
        ListItemGroup({ header: this.buildGroupHeader('播放设置') }) {
          ListItem() {
            this.buildSettingItem('默认播放速度', `${this.settings.playbackSpeed}x`, () => {
              this.showSpeedSelector();
            });
          }

          ListItem() {
            this.buildSwitchItem('跳过静音片段', this.settings.skipSilence, (value: boolean) => {
              this.settingsService.setSkipSilence(value);
              this.settings.skipSilence = value;
            });
          }

          ListItem() {
            this.buildSwitchItem('自动续播', this.settings.continuePlayback, (value: boolean) => {
              this.settings.continuePlayback = value;
              this.settingsService.setContinuePlayback(value);
            });
          }
        }

        // 存储设置
        ListItemGroup({ header: this.buildGroupHeader('存储设置') }) {
          ListItem() {
            this.buildSettingItem('存储位置', this.settings.storagePath || '默认', () => {
              this.showStorageInfo();
            });
          }

          ListItem() {
            this.buildSwitchItem('自动删除已播放', this.settings.autoDeletePlayed, (value: boolean) => {
              this.settings.autoDeletePlayed = value;
              this.settingsService.setAutoDeletePlayed(value);
            });
          }

          ListItem() {
            this.buildSettingItem('保留最近单集数', `${this.settings.keepLastNEpisodes}`, () => {
              this.showKeepEpisodesSelector();
            });
          }
        }

        // 通知设置
        ListItemGroup({ header: this.buildGroupHeader('通知设置') }) {
          ListItem() {
            this.buildSwitchItem('启用通知', this.settings.enableNotifications, (value: boolean) => {
              this.settings.enableNotifications = value;
              this.settingsService.setEnableNotifications(value);
            });
          }

          ListItem() {
            this.buildSwitchItem('新单集通知', this.settings.notifyNewEpisodes, (value: boolean) => {
              this.settings.notifyNewEpisodes = value;
              this.settingsService.setNotifyNewEpisodes(value);
            });
          }
        }

        // 关于
        ListItemGroup({ header: this.buildGroupHeader('关于') }) {
          ListItem() {
            this.buildSettingItem('应用名称', 'AntennaPodHM', () => {
              this.showVersionInfo();
            });
          }

          ListItem() {
            this.buildSettingItem('版本号', '1.0.0', () => {
              this.showVersionInfo();
            });
          }

          ListItem() {
            this.buildSettingItem('开源许可', 'MIT License', () => {
              this.showLicenseInfo();
            });
          }
        }
      }
      .layoutWeight(1)
      .backgroundColor($r('app.color.background_light'))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Button() {
        Text('←')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        router.back();
      })

      Text('设置')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ left: 12 })

      Blank()
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
  }

  @Builder
  buildGroupHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor($r('app.color.text_secondary_light'))
      .padding({ left: 16, top: 16, bottom: 8 })
  }

  @Builder
  buildSettingItem(title: string, value: string, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(16)

      Blank()

      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary_light'))

      Text('›')
        .fontSize(20)
        .margin({ left: 8 })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .onClick(onClick)
  }

  @Builder
  buildSwitchItem(title: string, checked: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(title)
        .fontSize(16)

      Blank()

      Toggle({ type: ToggleType.Switch, isOn: checked })
        .onChange(onChange)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
  }

  getThemeText(): string {
    switch (this.settings.themeMode) {
      case ThemeMode.LIGHT:
        return '浅色';
      case ThemeMode.DARK:
        return '深色';
      case ThemeMode.AUTO:
        return '跟随系统';
      default:
        return '跟随系统';
    }
  }

  /**
   * 显示主题选择器
   */
  showThemeSelector(): void {
    promptAction.showActionMenu({
      title: '选择主题',
      buttons: [
        { text: '跟随系统', color: '#000000' },
        { text: '浅色模式', color: '#000000' },
        { text: '深色模式', color: '#000000' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      let newMode: ThemeMode = ThemeMode.AUTO;
      switch (result.index) {
        case 0:
          newMode = ThemeMode.AUTO;
          break;
        case 1:
          newMode = ThemeMode.LIGHT;
          break;
        case 2:
          newMode = ThemeMode.DARK;
          break;
      }
      this.settings.themeMode = newMode;
      this.settingsService.setThemeMode(newMode);
    }).catch((err: Error) => {
      console.info('Theme selection cancelled');
    });
  }

  /**
   * 显示播放速度选择器
   */
  showSpeedSelector(): void {
    promptAction.showActionMenu({
      title: '选择播放速度',
      buttons: [
        { text: '0.5x', color: '#000000' },
        { text: '0.75x', color: '#000000' },
        { text: '1.0x', color: '#000000' },
        { text: '1.25x', color: '#000000' },
        { text: '1.5x', color: '#000000' },
        { text: '2.0x', color: '#000000' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const speeds: number[] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
      const selectedSpeed = speeds[result.index];
      this.settings.playbackSpeed = selectedSpeed;
      this.settingsService.setPlaybackSpeed(selectedSpeed);
    }).catch((err: Error) => {
      console.info('Speed selection cancelled');
    });
  }

  /**
   * 显示保留单集数选择器
   */
  showKeepEpisodesSelector(): void {
    promptAction.showActionMenu({
      title: '保留最近单集数',
      buttons: [
        { text: '5 集', color: '#000000' },
        { text: '10 集', color: '#000000' },
        { text: '20 集', color: '#000000' },
        { text: '50 集', color: '#000000' },
        { text: '100 集', color: '#000000' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const counts: number[] = [5, 10, 20, 50, 100];
      const selectedCount = counts[result.index];
      this.settings.keepLastNEpisodes = selectedCount;
      this.settingsService.setKeepLastNEpisodes(selectedCount);
    }).catch((err: Error) => {
      console.info('Keep episodes selection cancelled');
    });
  }

  /**
   * 显示存储位置信息
   */
  showStorageInfo(): void {
    promptAction.showDialog({
      title: '存储位置',
      message: '当前使用默认存储位置\n\n下载的单集将保存在应用私有目录中',
      buttons: [
        { text: '确定', color: '#007AFF' }
      ]
    });
  }

  /**
   * 显示版本信息
   */
  showVersionInfo(): void {
    promptAction.showDialog({
      title: 'AntennaPodHM',
      message: '版本: 1.0.0\n\n基于 HarmonyOS ArkTS 开发的播客应用',
      buttons: [
        { text: '确定', color: '#007AFF' }
      ]
    });
  }

  /**
   * 显示开源许可信息
   */
  showLicenseInfo(): void {
    promptAction.showDialog({
      title: 'MIT License',
      message: 'MIT License\n\nCopyright (c) 2024 AntennaPodHM\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.',
      buttons: [
        { text: '确定', color: '#007AFF' }
      ]
    });
  }
}
