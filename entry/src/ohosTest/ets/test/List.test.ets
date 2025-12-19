import episodeTest from './Episode.test';
import podcastTest from './Podcast.test';
import appSettingsTest from './AppSettings.test';
import abilityTest from './Ability.test';

/**
 * 测试套件入口
 * 符合华为鸿蒙应用发布规范
 */
export default function testsuite() {
  // 模型层单元测试
  episodeTest();
  podcastTest();
  appSettingsTest();

  // 能力测试
  abilityTest();
}
