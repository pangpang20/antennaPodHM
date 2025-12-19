import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const TAG = '[TestAbility]';
const DOMAIN = 0x0000;

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'TestAbility onCreate');
    hilog.info(DOMAIN, TAG, 'want param: %{public}s', JSON.stringify(want) ?? '');
    hilog.info(DOMAIN, TAG, 'launchParam: %{public}s', JSON.stringify(launchParam) ?? '');

    const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
    const bundleName = abilityDelegator.getAppContext().applicationInfo.name;
    hilog.info(DOMAIN, TAG, 'start run testcase!!!');
    abilityDelegator.addAbilityMonitor({
      abilityName: 'TestAbility',
      moduleName: 'entry_test',
      onAbilityCreate: () => {
        hilog.info(DOMAIN, TAG, 'onAbilityCreate');
      }
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'TestAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'TestAbility onWindowStageCreate');
    windowStage.loadContent('TestAbility/pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'Succeeded in loading content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'TestAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'TestAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'TestAbility onBackground');
  }
}
