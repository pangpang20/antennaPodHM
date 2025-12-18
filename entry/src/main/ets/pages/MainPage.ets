import { Podcast } from '../model/Podcast';
import { Episode } from '../model/Episode';
import { PodcastService } from '../service/PodcastService';
import { DatabaseService } from '../service/DatabaseService';
import { PlayerService } from '../service/PlayerService';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct MainPage {
  @State currentTabIndex: number = 0;
  @State podcasts: Podcast[] = [];
  @State isLoading: boolean = false;
  @State hasCurrentEpisode: boolean = false;
  private playerService: PlayerService = PlayerService.getInstance();

  aboutToAppear() {
    this.loadSubscriptions();
    this.checkCurrentEpisode();
  }

  onPageShow() {
    // 页面通过路由返回时刷新订阅列表
    this.loadSubscriptions();
    this.checkCurrentEpisode();
  }

  /**
   * 加载订阅列表
   */
  async loadSubscriptions() {
    this.isLoading = true;
    try {
      this.podcasts = await PodcastService.getInstance().getSubscribedPodcasts();
    } catch (error) {
      console.error('Failed to load subscriptions:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 检查是否有正在播放的单集
   */
  checkCurrentEpisode() {
    const currentEpisode = this.playerService.getCurrentEpisode();
    this.hasCurrentEpisode = currentEpisode !== null;
  }

  /**
   * 打开播放页面
   */
  openPlayerPage() {
    const currentEpisode = this.playerService.getCurrentEpisode();
    if (currentEpisode) {
      router.pushUrl({
        url: 'pages/PlayerPage',
        params: { episodeId: currentEpisode.id }
      }).catch((err: Error) => {
        console.error('Navigation failed:', err);
      });
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      this.buildHeader();

      // Tab页签
      Tabs({ index: this.currentTabIndex }) {
        TabContent() {
          this.buildSubscriptionTab();
        }.tabBar('订阅')

        TabContent() {
          this.buildEpisodesTab();
        }.tabBar('单集')

        TabContent() {
          this.buildQueueTab();
        }.tabBar('队列')

        TabContent() {
          this.buildDownloadsTab();
        }.tabBar('下载')
      }
      .barMode(BarMode.Fixed)
      .barHeight(56)
      .onChange((index: number) => {
        this.currentTabIndex = index;
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_light'))
  }

  /**
   * 构建头部
   */
  @Builder
  buildHeader() {
    Row() {
      Text('AntennaPodHM')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary_light'))

      Blank()

      // 搜索按钮
      Button() {
        Text('🔍')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        console.info('======>>> Click: Search button');
        // 跳转到搜索页面
        router.pushUrl({ url: 'pages/SearchPage' }).catch((err: Error) => {
          console.error('Navigation failed:', err);
        });
      })

      // 设置按钮
      Button() {
        Text('⚙️')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        console.info('======>>> Click: Settings button');
        // 跳转到设置页面
        router.pushUrl({ url: 'pages/SettingsPage' }).catch((err: Error) => {
          console.error('Navigation failed:', err);
        });
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
  }

  /**
   * 订阅页签
   */
  @Builder
  buildSubscriptionTab() {
    Column() {
      if (this.isLoading) {
        LoadingProgress()
          .width(50)
          .height(50)
          .margin({ top: 100 })
      } else if (this.podcasts.length === 0) {
        this.buildEmptyView('暂无订阅', '点击右上角添加播客');
      } else {
        List({ space: 12 }) {
          ForEach(this.podcasts, (podcast: Podcast) => {
            ListItem() {
              this.buildPodcastItem(podcast);
            }
          }, (podcast: Podcast) => podcast.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
      }

      // 正在播放按钮
      if (this.hasCurrentEpisode) {
        Button() {
          Row() {
            Text('▶')
              .fontSize(20)
              .margin({ right: 8 })
            Text('正在播放')
              .fontSize(16)
          }
        }
        .width('90%')
        .height(48)
        .type(ButtonType.Normal)
        .borderRadius(24)
        .backgroundColor('#007AFF')
        .margin({ bottom: 20 })
        .onClick(() => {
          console.info('======>>> Click: Now playing button (Main)');
          this.openPlayerPage();
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 单集页签
   */
  @Builder
  buildEpisodesTab() {
    Column() {
      this.buildEmptyView('暂无单集', '订阅播客后将显示在这里');
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 队列页签
   */
  @Builder
  buildQueueTab() {
    Column() {
      this.buildEmptyView('播放队列为空', '添加单集到队列');
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 下载页签
   */
  @Builder
  buildDownloadsTab() {
    Column() {
      this.buildEmptyView('暂无下载', '下载单集以便离线收听');
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 播客项
   */
  @Builder
  buildPodcastItem(podcast: Podcast) {
    Row() {
      // 播客封面
      Image(podcast.imageUrl)
        .width(80)
        .height(80)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.app_icon'))

      // 播客信息
      Column() {
        Text(podcast.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(podcast.author)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary_light'))
          .margin({ top: 4 })

        Text(`${podcast.episodeCount} 集`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary_light'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .onClick(() => {
      console.info(`======>>> Click: Podcast item - ${podcast.title}`);
      // 跳转到播客详情页
      router.pushUrl({
        url: 'pages/PodcastDetailPage',
        params: { podcastId: podcast.id }
      }).catch((err: Error) => {
        console.error('Navigation failed:', err);
      });
    })
  }

  /**
   * 空状态视图
   */
  @Builder
  buildEmptyView(title: string, message: string) {
    Column() {
      Text('🎧')
        .fontSize(80)
        .opacity(0.3)

      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 20 })

      Text(message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary_light'))
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
