import { TestRunner, abilityDelegatorRegistry } from '@kit.TestKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UIAbility, Want } from '@kit.AbilityKit';

const TAG = '[OpenHarmonyTestRunner]';
const DOMAIN = 0x0000;

let abilityDelegator: abilityDelegatorRegistry.AbilityDelegator;
let abilityDelegatorArguments: abilityDelegatorRegistry.AbilityDelegatorArgs;

async function onAbilityCreateCallback(data: UIAbility): Promise<void> {
  hilog.info(DOMAIN, TAG, 'onAbilityCreateCallback, data: %{public}s', JSON.stringify(data) ?? '');
}

async function addAbilityMonitorCallback(err: Error): Promise<void> {
  hilog.info(DOMAIN, TAG, 'addAbilityMonitorCallback: %{public}s', JSON.stringify(err) ?? '');
}

export default class OpenHarmonyTestRunner implements TestRunner {
  constructor() {
  }

  onPrepare(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'OpenHarmonyTestRunner OnPrepare');
  }

  async onRun(): Promise<void> {
    hilog.info(DOMAIN, TAG, '%{public}s', 'OpenHarmonyTestRunner onRun run');
    abilityDelegatorArguments = abilityDelegatorRegistry.getArguments();
    abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();

    const bundleName = abilityDelegatorArguments.bundleName;
    const testAbilityName = 'TestAbility';

    const monitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: testAbilityName,
      onAbilityCreate: onAbilityCreateCallback
    };

    abilityDelegator.addAbilityMonitor(monitor, addAbilityMonitorCallback);

    const want: Want = {
      bundleName: bundleName,
      abilityName: testAbilityName,
      moduleName: 'entry_test'
    };

    abilityDelegator.startAbility(want, (err) => {
      hilog.info(DOMAIN, TAG, 'startAbility callback, err: %{public}s', JSON.stringify(err) ?? '');
    });

    hilog.info(DOMAIN, TAG, '%{public}s', 'OpenHarmonyTestRunner onRun end');
  }
}
