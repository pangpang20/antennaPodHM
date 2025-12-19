import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import bundleManager from '@ohos.bundle.bundleManager';
import { BusinessError } from '@ohos.base';
import { DatabaseService } from '../service/DatabaseService';
import { SettingsService } from '../service/SettingsService';
import { PlayerService } from '../service/PlayerService';
import { DownloadService } from '../service/DownloadService';

export default class EntryAbility extends UIAbility {
  private permissionsGranted: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('EntryAbility onCreate');
    
    // 初始化服务
    this.initServices();
  }

  onDestroy(): void {
    console.info('EntryAbility onDestroy');
    
    // 释放播放器资源
    PlayerService.getInstance().release();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('EntryAbility onWindowStageCreate');

    // 先请求权限，再加载页面
    this.requestPermissions().then(() => {
      windowStage.loadContent('pages/MainPage', (err) => {
        if (err.code) {
          console.error(`Failed to load the content. Code: ${err.code}, message: ${err.message}`);
          return;
        }
        console.info('Succeeded in loading the content.');
      });
    }).catch((err: BusinessError) => {
      console.error('Permission request failed:', err);
      // 即使权限被拒绝，也加载页面，但功能可能受限
      windowStage.loadContent('pages/MainPage', (err) => {
        if (err.code) {
          console.error(`Failed to load the content. Code: ${err.code}, message: ${err.message}`);
          return;
        }
        console.info('Succeeded in loading the content.');
      });
    });
  }

  onWindowStageDestroy(): void {
    console.info('EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    console.info('EntryAbility onForeground');
  }

  onBackground(): void {
    console.info('EntryAbility onBackground');
  }

  /**
   * 初始化服务
   */
  private async initServices(): Promise<void> {
    try {
      // 初始化数据库
      await DatabaseService.getInstance().init(this.context);
      
      // 初始化设置
      await SettingsService.getInstance().init(this.context);
      
      // 初始化播放器（设置 Context 以支持后台播放）
      PlayerService.getInstance().setContext(this.context);
      await PlayerService.getInstance().init();
      
      // 初始化下载服务
      DownloadService.getInstance().setContext(this.context);
      
      console.info('All services initialized successfully');
    } catch (error) {
      console.error('Failed to initialize services:', error);
    }
  }

  /**
   * 请求必要权限
   */
  private async requestPermissions(): Promise<void> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenId = bundleInfo.appInfo.accessTokenId;

      // 必要权限：联网
      const requiredPermissions: Permissions[] = [
        'ohos.permission.INTERNET',
        'ohos.permission.GET_NETWORK_INFO'
      ];

      // 可选权限：后台运行（用于后台播放）
      const optionalPermissions: Permissions[] = [
        'ohos.permission.KEEP_BACKGROUND_RUNNING'
      ];

      // 检查并请求必要权限
      const permissionsToRequest: Permissions[] = [];
      
      for (const permission of requiredPermissions) {
        const grantStatus = await atManager.checkAccessToken(tokenId, permission);
        if (grantStatus !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          permissionsToRequest.push(permission);
        }
      }

      // 检查可选权限
      for (const permission of optionalPermissions) {
        const grantStatus = await atManager.checkAccessToken(tokenId, permission);
        if (grantStatus !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          permissionsToRequest.push(permission);
        }
      }

      // 如果有需要请求的权限
      if (permissionsToRequest.length > 0) {
        console.info('Requesting permissions:', permissionsToRequest);
        
        try {
          await atManager.requestPermissionsFromUser(this.context, permissionsToRequest);
          console.info('Permissions granted successfully');
          this.permissionsGranted = true;
        } catch (err) {
          console.error('User denied permissions:', err);
          // 用户拒绝了权限，但应用仍然可以启动（功能可能受限）
          this.permissionsGranted = false;
        }
      } else {
        console.info('All permissions already granted');
        this.permissionsGranted = true;
      }
    } catch (error) {
      console.error('Failed to request permissions:', error);
      // ArkTS 不允许抛出任意类型，这里直接返回，让应用继续启动
      this.permissionsGranted = false;
    }
  }
}
