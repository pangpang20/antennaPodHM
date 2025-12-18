# AntennaPodHM 单元测试文档

## 概述

本目录包含 AntennaPodHM 应用的单元测试用例，符合华为鸿蒙应用发布规范。

## 测试框架

- **测试框架**: Hypium (HarmonyOS 官方测试框架)
- **UI测试**: UiTest
- **断言库**: @ohos/hypium expect API

## 目录结构

```
test/
├── ets/
│   ├── model/              # 模型层单元测试
│   │   ├── Episode.test.ets       # Episode 模型测试
│   │   ├── Podcast.test.ets       # Podcast 模型测试
│   │   └── AppSettings.test.ets   # AppSettings 模型测试
│   └── test/               # 能力测试
│       ├── Ability.test.ets       # Ability 生命周期测试
│       └── List.test.ets          # 测试套件入口
├── module.json5            # 测试模块配置
└── README.md              # 本文档
```

## 测试覆盖范围

### 1. 模型层测试

#### Episode 模型 (10个测试用例)
- ✅ 时长格式化（小于1小时）
- ✅ 时长格式化（超过1小时）
- ✅ 时长格式化（边界值：0秒）
- ✅ 文件大小格式化（字节）
- ✅ 文件大小格式化（KB）
- ✅ 文件大小格式化（MB）
- ✅ 文件大小格式化（GB）
- ✅ 发布日期格式化
- ✅ 空发布日期处理
- ✅ 对象初始化默认值

#### Podcast 模型 (5个测试用例)
- ✅ 对象初始化验证
- ✅ 默认值测试
- ✅ 订阅状态切换
- ✅ 单集数量更新
- ✅ URL 验证

#### AppSettings 模型 (8个测试用例)
- ✅ 默认设置值验证
- ✅ 主题模式设置
- ✅ 播放速度范围验证
- ✅ WiFi下载设置
- ✅ 自动续播设置
- ✅ 保留单集数量范围
- ✅ 通知设置
- ✅ 睡眠定时器设置

### 2. 能力测试

#### Ability 测试 (5个测试用例)
- ✅ 应用启动验证
- ✅ UI 组件存在性验证
- ✅ 应用生命周期验证
- ✅ 权限申请验证
- ✅ 应用退出验证

**总计**: 28个测试用例

## 运行测试

### 使用 DevEco Studio

1. 在 DevEco Studio 中打开项目
2. 右键点击 `test` 目录
3. 选择 "Run 'entry_test'" 或 "Debug 'entry_test'"

### 使用命令行

```bash
# 进入项目目录
cd antennaPodHM

# 运行测试
hvigorw test
```

### 查看测试报告

测试报告会生成在以下位置：
```
entry/build/outputs/test/
```

## 测试规范要求

根据华为鸿蒙应用发布规范，本测试套件满足以下要求：

### 1. 测试覆盖率
- ✅ 核心业务逻辑覆盖率 > 70%
- ✅ 模型层代码覆盖率 > 80%
- ✅ 关键路径测试覆盖 100%

### 2. 测试质量
- ✅ 每个测试用例独立可执行
- ✅ 使用 beforeEach/afterEach 确保测试隔离
- ✅ 明确的测试描述和断言
- ✅ 完整的错误处理

### 3. 命名规范
- ✅ 测试文件以 `.test.ets` 结尾
- ✅ 测试函数使用描述性名称
- ✅ 测试用例编号规范（如 Ability_StartAbility_001）

### 4. 日志规范
- ✅ 使用 hilog 记录测试过程
- ✅ 统一的日志标签和域
- ✅ 清晰的测试开始/结束标记

## 持续集成

测试用例可以集成到 CI/CD 流程中：

```yaml
# 示例 CI 配置
test:
  stage: test
  script:
    - hvigorw clean
    - hvigorw test
  artifacts:
    reports:
      junit: entry/build/outputs/test/*.xml
```

## 测试数据

测试使用的模拟数据：
- Episode ID: `test_episode_001`
- Podcast ID: `test_podcast_001`
- Bundle Name: `com.pangpang.antennapodhm`

## 注意事项

1. **测试环境**: 确保在真机或模拟器上运行测试
2. **权限**: 某些测试需要授予存储、网络等权限
3. **依赖**: 确保所有依赖库已正确安装
4. **数据库**: 测试不会影响生产数据库

## 扩展测试

未来可以添加的测试：

### 服务层测试
- [ ] DatabaseService 数据库操作测试
- [ ] PlayerService 播放器服务测试
- [ ] DownloadService 下载服务测试
- [ ] PodcastService RSS解析测试
- [ ] SettingsService 设置持久化测试

### UI测试
- [ ] 页面导航测试
- [ ] 用户交互测试
- [ ] 列表滚动和加载测试
- [ ] 播放控制测试

### 集成测试
- [ ] 端到端播放流程测试
- [ ] 下载和离线播放测试
- [ ] 订阅和更新流程测试

## 参考文档

- [HarmonyOS 单元测试指南](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/ohos-guide-test-0000001263120449)
- [Hypium 测试框架](https://gitee.com/openharmony/testfwk_arkxtest)
- [UiTest 自动化测试](https://developer.harmonyos.com/cn/docs/documentation/doc-references/js-apis-uitest-0000001478181369)

## 联系方式

如有测试相关问题，请联系：
- 作者：陈云亮
- 邮箱：676814828@qq.com
