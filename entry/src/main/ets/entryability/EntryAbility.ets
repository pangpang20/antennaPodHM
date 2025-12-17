import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import { DatabaseService } from '../service/DatabaseService';
import { SettingsService } from '../service/SettingsService';
import { PlayerService } from '../service/PlayerService';

export default class EntryAbility extends UIAbility {
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

    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        console.error(`Failed to load the content. Code: ${err.code}, message: ${err.message}`);
        return;
      }
      console.info('Succeeded in loading the content.');
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
      
      console.info('All services initialized successfully');
    } catch (error) {
      console.error('Failed to initialize services:', error);
    }
  }
}
