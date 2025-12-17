import router from '@ohos.router';
import { AppSettings, ThemeMode } from '../model/AppSettings';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../common/Constants';

@Entry
@Component
struct SettingsPage {
  @State settings: AppSettings = new AppSettings();
  private settingsService: SettingsService = SettingsService.getInstance();

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
            // 显示主题选择对话框
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
              // 显示速度选择对话框
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
            });
          }
        }

        // 存储设置
        ListItemGroup({ header: this.buildGroupHeader('存储设置') }) {
          ListItem() {
            this.buildSettingItem('存储位置', this.settings.storagePath || '默认', () => {
              // 选择存储路径
            });
          }

          ListItem() {
            this.buildSwitchItem('自动删除已播放', this.settings.autoDeletePlayed, (value: boolean) => {
              this.settings.autoDeletePlayed = value;
            });
          }

          ListItem() {
            this.buildSettingItem('保留最近单集数', `${this.settings.keepLastNEpisodes}`, () => {
              // 设置保留数量
            });
          }
        }

        // 通知设置
        ListItemGroup({ header: this.buildGroupHeader('通知设置') }) {
          ListItem() {
            this.buildSwitchItem('启用通知', this.settings.enableNotifications, (value: boolean) => {
              this.settings.enableNotifications = value;
            });
          }

          ListItem() {
            this.buildSwitchItem('新单集通知', this.settings.notifyNewEpisodes, (value: boolean) => {
              this.settings.notifyNewEpisodes = value;
            });
          }
        }

        // 关于
        ListItemGroup({ header: this.buildGroupHeader('关于') }) {
          ListItem() {
            this.buildSettingItem('版本号', '1.0.0', () => {});
          }

          ListItem() {
            this.buildSettingItem('开源许可', 'GPL-3.0', () => {});
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
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
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

      Image($r('app.media.ic_arrow_right'))
        .width(16)
        .height(16)
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
}
