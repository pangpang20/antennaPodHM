# antennaPodHM
鸿蒙版本的antennaPod
=======
# AntennaPod HarmonyOS

一个使用ArkTS开发的开源播客管理器应用,专为HarmonyOS平台设计。

## 项目概述

AntennaPod HarmonyOS是基于原版AntennaPod的设计理念,使用ArkTS语言和HarmonyOS SDK开发的播客管理应用。本应用提供完整的播客订阅、管理、下载和播放功能。

## 功能特性

### 核心功能

- **播客订阅管理**
  - 通过RSS/Atom URL添加播客
  - 通过关键词搜索播客
  - 播客分类和组织
  - 取消订阅和管理

- **Episode管理**
  - 按时间倒序显示episode列表
  - 下载管理(单集/批量下载)
  - 下载进度显示
  - 离线收听支持

- **播放功能**
  - 基本播放控制(播放/暂停/进度调节)
  - 可变播放速度(0.5x-2.0x)
  - 睡眠定时器
  - 播放历史记录
  - 自动记住播放进度

- **队列管理**
  - 自定义播放顺序
  - 队列编辑和管理

- **设置功能**
  - 主题切换(浅色/深色/跟随系统)
  - 网络设置(WiFi限制等)
  - 存储路径配置
  - 通知设置

## 技术栈

- **开发语言**: ArkTS
- **开发框架**: HarmonyOS SDK API 17+
- **状态管理**: ArkUI组件状态管理
- **本地存储**: Preferences、RelationalStore
- **网络请求**: @ohos.net.http
- **媒体播放**: @ohos.multimedia.media
- **下载管理**: @ohos.request

## 项目结构

```
antennaPodHM/
├── AppScope/                      # 应用全局配置
│   ├── app.json5                 # 应用配置文件
│   └── resources/                # 全局资源
├── entry/                        # 主模块
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── common/          # 公共常量和工具
│   │   │   │   └── Constants.ets
│   │   │   ├── entryability/    # 应用入口
│   │   │   │   └── EntryAbility.ets
│   │   │   ├── model/           # 数据模型
│   │   │   │   ├── Podcast.ets
│   │   │   │   ├── Episode.ets
│   │   │   │   ├── QueueItem.ets
│   │   │   │   └── AppSettings.ets
│   │   │   ├── service/         # 业务逻辑层
│   │   │   │   ├── DatabaseService.ets
│   │   │   │   ├── PodcastService.ets
│   │   │   │   ├── PlayerService.ets
│   │   │   │   ├── DownloadService.ets
│   │   │   │   └── SettingsService.ets
│   │   │   └── pages/           # UI页面
│   │   │       ├── MainPage.ets
│   │   │       ├── SearchPage.ets
│   │   │       ├── PodcastDetailPage.ets
│   │   │       ├── PlayerPage.ets
│   │   │       ├── SettingsPage.ets
│   │   │       ├── DownloadPage.ets
│   │   │       └── QueuePage.ets
│   │   ├── resources/           # 资源文件
│   │   │   └── base/
│   │   │       ├── element/    # 字符串、颜色等
│   │   │       └── profile/    # 配置文件
│   │   └── module.json5        # 模块配置
│   ├── hvigorfile.ts
│   └── oh-package.json5
├── build-profile.json5          # 构建配置
├── hvigorfile.ts               # 构建脚本
└── oh-package.json5            # 依赖配置
```

## 开发要求

### 环境要求

- HarmonyOS SDK 5.0.0(API 17)或更高版本
- DevEco Studio 最新版本
- Node.js 16+

### 权限要求

本应用需要以下权限:

- `ohos.permission.INTERNET` - 用于获取播客内容和更新
- `ohos.permission.GET_NETWORK_INFO` - 用于检测网络状态
- `ohos.permission.WRITE_MEDIA` - 用于下载和保存音频文件
- `ohos.permission.READ_MEDIA` - 用于读取已下载的音频文件

## 开发指南

### 数据模型

#### Podcast (播客)
```typescript
class Podcast {
  id: string;              // 唯一标识
  title: string;           // 标题
  author: string;          // 作者
  description: string;     // 描述
  imageUrl: string;        // 封面图片URL
  feedUrl: string;         // RSS Feed URL
  subscribeDate: number;   // 订阅时间
  episodeCount: number;    // Episode数量
}
```

#### Episode (单集)
```typescript
class Episode {
  id: string;                    // 唯一标识
  podcastId: string;             // 所属播客ID
  title: string;                 // 标题
  audioUrl: string;              // 音频URL
  duration: number;              // 时长(秒)
  downloadStatus: DownloadStatus; // 下载状态
  playbackPosition: number;      // 播放位置
}
```

### 核心服务

#### DatabaseService
负责数据库操作,包括播客和Episode的增删改查。

#### PodcastService
负责播客订阅、搜索和RSS解析。

#### PlayerService
负责音频播放控制,支持播放/暂停、进度调节、速度控制等。

#### DownloadService
负责Episode下载管理,支持断点续传、批量下载等。

#### SettingsService
负责应用设置的保存和读取。

## 性能要求

- 应用启动时间 < 3秒
- 页面切换响应时间 < 500ms
- 播放启动时间 < 1秒
- 内存占用峰值 < 200MB
- 后台播放CPU占用 < 10%

## 安全要求

- 遵循华为应用安全开发规范
- 本地数据加密存储
- 网络请求使用HTTPS
- 不获取无关权限
- 防止敏感信息泄露

## 构建和运行

1. 克隆项目
```bash
git clone <repository-url>
cd antennaPodHM
```

2. 安装依赖
```bash
npm install
```

3. 在DevEco Studio中打开项目

4. 连接HarmonyOS设备或启动模拟器

5. 点击运行按钮或使用命令:
```bash
hvigorw assembleHap
```

## 许可证

本项目采用 GPL-3.0 许可证,详见 [LICENSE](LICENSE) 文件。

## 参考

- [AntennaPod GitHub](https://github.com/AntennaPod/AntennaPod)
- [HarmonyOS开发者文档](https://developer.huawei.com/consumer/cn/doc/development)
- [ArkTS语言参考](https://developer.huawei.com/consumer/cn/doc/development/arkUI-ts/arkts-language-overview-0000001504792369)

## 贡献

欢迎提交Issue和Pull Request!

## 联系方式

如有问题或建议,请通过以下方式联系:

- 提交Issue
- 发送邮件

---

**注意**: 本项目仍在开发中,部分功能可能尚未完全实现。
