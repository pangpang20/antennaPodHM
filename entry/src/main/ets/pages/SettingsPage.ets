import { UIUtils, ToastOptions, DialogOptions, ButtonOptions } from '../common/UIUtils';
import { AppSettings, ThemeMode } from '../model/AppSettings';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../common/Constants';
import { bundleManager } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';

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
              if (value) {
                // 打开通知时需要用户确认
                this.confirmEnableNotification();
              } else {
                // 关闭通知直接执行
                this.settings.enableNotifications = false;
                this.settingsService.setEnableNotifications(false);
              }
            });
          }

          ListItem() {
            this.buildSwitchItem('新单集通知', this.settings.notifyNewEpisodes, (value: boolean) => {
              if (value) {
                // 打开新单集通知时需要用户确认
                this.confirmEnableNewEpisodeNotification();
              } else {
                // 关闭通知直接执行
                this.settings.notifyNewEpisodes = false;
                this.settingsService.setNotifyNewEpisodes(false);
              }
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
      .backgroundColor($r('app.color.background'))
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
        console.info('[SettingsPage] Back');
        UIUtils.back();
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
    .backgroundColor($r('app.color.background_card'))
  }

  @Builder
  buildGroupHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor($r('app.color.text_secondary'))
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
        .fontColor($r('app.color.text_secondary'))

      Text('›')
        .fontSize(20)
        .margin({ left: 8 })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.background_card'))
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
    .backgroundColor($r('app.color.background_card'))
  }

  /**
   * 确认启用通知
   */
  confirmEnableNotification(): void {
    const buttons: ButtonOptions[] = [
      new ButtonOptions('取消', '#999999'),
      new ButtonOptions('允许', '#007AFF')
    ];
    UIUtils.showDialog(new DialogOptions(
      '启用通知',
      '开启通知后,应用将会在后台推送播客更新、下载完成等消息。\n\n是否允许启用通知功能?',
      buttons
    )).then((index: number) => {
      if (index === 1) {
        // 用户点击"允许",申请通知权限
        console.info('[SettingsPage] Notifications enabled');
        this.requestNotificationPermission();
      } else {
        // 用户点击"取消",保持关闭状态
        console.info('[SettingsPage] Notifications cancelled');
        this.settings.enableNotifications = false;
      }
    });
  }
  
  /**
   * 申请通知权限
   */
  async requestNotificationPermission(): Promise<void> {
    try {
      // 检查通知是否已启用
      const isEnabled = await notificationManager.isNotificationEnabled();
        
      if (isEnabled) {
        // 已有权限,直接启用
        console.info('[SettingsPage] Notification permission already granted');
        this.settings.enableNotifications = true;
        this.settingsService.setEnableNotifications(true);
        UIUtils.showToast(new ToastOptions('通知已启用', 2000));
        return;
      }
  
      // 请求通知权限
      console.info('[SettingsPage] Requesting notification permission');
      await notificationManager.requestEnableNotification();
        
      // 再次检查是否授权成功
      const enabledAfterRequest = await notificationManager.isNotificationEnabled();
        
      if (enabledAfterRequest) {
        console.info('[SettingsPage] Notification permission granted');
        this.settings.enableNotifications = true;
        this.settingsService.setEnableNotifications(true);
        UIUtils.showToast(new ToastOptions('通知已启用', 2000));
      } else {
        console.warn('[SettingsPage] Notification permission denied by user');
        this.settings.enableNotifications = false;
        UIUtils.showToast(new ToastOptions('用户拒绝了通知权限', 2000));
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[SettingsPage] Failed to request notification permission: ${err.code}, ${err.message}`);
      this.settings.enableNotifications = false;
        
      // 用户取消了权限请求
      if (err.code === 1600004) {
        UIUtils.showToast(new ToastOptions('已取消通知权限申请', 2000));
      } else {
        UIUtils.showToast(new ToastOptions('通知权限申请失败', 2000));
      }
    }
  }

  /**
   * 确认启用新单集通知
   */
  confirmEnableNewEpisodeNotification(): void {
    const buttons: ButtonOptions[] = [
      new ButtonOptions('取消', '#999999'),
      new ButtonOptions('允许', '#007AFF')
    ];
    UIUtils.showDialog(new DialogOptions(
      '新单集通知',
      '开启后,当订阅的播客发布新单集时,将会收到通知提醒。\n\n是否允许新单集通知?',
      buttons
    )).then((index: number) => {
      if (index === 1) {
        // 用户点击"允许",检查并启用新单集通知
        console.info('[SettingsPage] New episode notifications enabled');
        this.checkAndEnableNewEpisodeNotification();
      } else {
        // 用户点击"取消",保持关闭状态
        console.info('[SettingsPage] New episode notifications cancelled');
        this.settings.notifyNewEpisodes = false;
      }
    });
  }

  /**
   * 检查并启用新单集通知
   */
  async checkAndEnableNewEpisodeNotification(): Promise<void> {
    try {
      // 先检查主通知权限是否已启用
      const isEnabled = await notificationManager.isNotificationEnabled();
      
      if (!isEnabled) {
        // 主通知未启用,提示用户需要先启用主通知
        const dialogButtons: ButtonOptions[] = [
          new ButtonOptions('知道了', '#007AFF')
        ];
        UIUtils.showDialog(new DialogOptions(
          '需要启用通知',
          '启用新单集通知需要先开启主通知功能。\n\n请先在"启用通知"选项中开启通知权限。',
          dialogButtons
        )).then(() => {
          this.settings.notifyNewEpisodes = false;
        });
        return;
      }

      // 主通知已启用,可以启用新单集通知
      console.info('[SettingsPage] Enabling new episode notifications');
      this.settings.notifyNewEpisodes = true;
      this.settingsService.setNotifyNewEpisodes(true);
      UIUtils.showToast(new ToastOptions('新单集通知已启用', 2000));
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[SettingsPage] Failed to check notification permission: ${err.code}, ${err.message}`);
      this.settings.notifyNewEpisodes = false;
      UIUtils.showToast(new ToastOptions('检查通知权限失败', 2000));
    }
  }

  /**
   * 显示应用详情
   */
  showAppDetailInfo(): void {
    const buttons: ButtonOptions[] = [
      new ButtonOptions('确定', '#007AFF')
    ];
    UIUtils.showDialog(new DialogOptions(
      'AntennaPodHM',
      'AntennaPod for HarmonyOS\n\n名称来源：\n• AntennaPod - 知名的开源播客应用\n• HM - HarmonyOS（鸿蒙）的缩写\n\n这是一款基于 HarmonyOS ArkTS 开发的播客应用，致敬经典的 AntennaPod。\n\n作者：陈云亮\n邮箱：676814828@qq.com',
      buttons
    ));
  }

  /**
   * 显示开源许可信息
   */
  showLicenseInfo(): void {
    const buttons: ButtonOptions[] = [
      new ButtonOptions('确定', '#007AFF')
    ];
    UIUtils.showDialog(new DialogOptions(
      'MIT License',
      'MIT License\n\nCopyright (c) 2024 AntennaPodHM\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.',
      buttons
    ));
  }
}
