import { router, promptAction } from '@kit.ArkUI';
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
            this.buildSwitchItem('自动删除已播放', this.settings.autoDeletePlayed, (value: boolean) => {
              this.settings.autoDeletePlayed = value;
              this.settingsService.setAutoDeletePlayed(value);
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
            this.buildSettingItem('应用详情', 'AntennaPodHM', () => {
              this.showAppDetailInfo();
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
        console.info('======>>> Click: Back button (Settings)');
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

  /**
   * 显示应用详情
   */
  showAppDetailInfo(): void {
    promptAction.showDialog({
      title: 'AntennaPodHM',
      message: 'AntennaPod for HarmonyOS\n\n名称来源：\n• AntennaPod - 知名的开源播客应用\n• HM - HarmonyOS（鸿蒙）的缩写\n\n这是一款基于 HarmonyOS ArkTS 开发的播客应用，致敬经典的 AntennaPod。\n\n作者：陈云亮\n邮箱：676814828@qq.com',
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
