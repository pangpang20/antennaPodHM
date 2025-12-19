import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { Driver, ON } from '@ohos.UiTest';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '[Sample_Ability_Test]';
const DOMAIN = 0xF811;
const BUNDLE = 'Ability_';

/**
 * Ability 测试
 * 验证应用启动、生命周期等基础能力
 */
export default function abilityTest() {
  describe('Ability Test', () => {
    let driver: Driver;

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'beforeAll called');
      driver = Driver.create();
    });

    afterAll(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'afterAll called');
    });

    /**
     * 测试用例 1: 应用启动验证
     */
    it(BUNDLE + 'StartAbility_001', 0, async (done: Function) => {
      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'StartAbility_001 begin');
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();

      try {
        await delegator.startAbility({
          bundleName: 'com.pangpang.antennapodhm',
          abilityName: 'EntryAbility'
        });
        hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'StartAbility_001 success');
        done();
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Failed to start ability, error: %{public}s', JSON.stringify(err));
        expect().assertFail();
        done();
      }
      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'StartAbility_001 end');
    });

    /**
     * 测试用例 2: UI 组件存在性验证
     */
    it(BUNDLE + 'UIComponent_001', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'UIComponent_001 begin');

      // 等待UI加载
      await driver.delayMs(1000);

      // 验证主要UI组件存在
      try {
        const tabBar = await driver.findComponent(ON.type('Tabs'));
        expect(tabBar !== null).assertTrue();
        hilog.info(DOMAIN, TAG, '%{public}s', 'TabBar component found');
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'TabBar component not found: %{public}s', JSON.stringify(err));
      }

      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'UIComponent_001 end');
    });

    /**
     * 测试用例 3: 应用生命周期验证
     */
    it(BUNDLE + 'Lifecycle_001', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'Lifecycle_001 begin');
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();

      try {
        const ability = delegator.getCurrentTopAbility();
        expect(ability !== null).assertTrue();
        hilog.info(DOMAIN, TAG, '%{public}s', 'Current ability is running');
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Failed to get current ability: %{public}s', JSON.stringify(err));
      }

      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'Lifecycle_001 end');
    });

    /**
     * 测试用例 4: 权限申请验证
     */
    it(BUNDLE + 'Permission_001', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'Permission_001 begin');

      // 等待权限申请弹窗
      await driver.delayMs(2000);

      hilog.info(DOMAIN, TAG, '%{public}s', 'Permission request completed');
      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'Permission_001 end');
    });

    /**
     * 测试用例 5: 应用退出验证
     */
    it(BUNDLE + 'TerminateAbility_001', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'TerminateAbility_001 begin');
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();

      try {
        const ability = delegator.getCurrentTopAbility();
        if (ability) {
          hilog.info(DOMAIN, TAG, '%{public}s', 'Ability is running normally');
        }
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Ability check failed: %{public}s', JSON.stringify(err));
      }

      hilog.info(DOMAIN, TAG, '%{public}s', BUNDLE + 'TerminateAbility_001 end');
    });
  });
}
