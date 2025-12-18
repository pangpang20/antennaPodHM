import { router } from '@kit.ArkUI';
import { Podcast } from '../model/Podcast';
import { PodcastService } from '../service/PodcastService';
import { promptAction } from '@kit.ArkUI';
import { PlayerService } from '../service/PlayerService';

@Entry
@Component
struct SubscriptionPage {
  @State podcasts: Podcast[] = [];
  @State isLoading: boolean = false;
  @State hasCurrentEpisode: boolean = false;
  private refreshTimer: number = -1;
  private playerService: PlayerService = PlayerService.getInstance();

  aboutToAppear() {
    this.loadSubscriptions();
    // 检查是否有正在播放的单集
    this.checkCurrentEpisode();
    // 启动定时器，每5秒刷新一次（检测后台更新）
    this.refreshTimer = setInterval(() => {
      this.loadSubscriptions();
      this.checkCurrentEpisode();
    }, 5000);
  }

  aboutToDisappear() {
    // 页面销毁时清除定时器
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  onPageShow() {
    // 从其他页面返回时刷新订阅列表
    this.loadSubscriptions();
    this.checkCurrentEpisode();
  }

  async loadSubscriptions() {
    this.isLoading = true;
    try {
      const newPodcasts = await PodcastService.getInstance().getSubscribedPodcasts();
      console.info(`[SubscriptionPage] Loaded ${newPodcasts.length} podcasts`);
      newPodcasts.forEach(p => {
        console.info(`[SubscriptionPage] - ${p.title}: ${p.episodeCount} 集`);
      });
      this.podcasts = newPodcasts;
    } catch (error) {
      console.error('[SubscriptionPage] Failed to load subscriptions:', error);
    } finally {
      this.isLoading = false;
    }
  }

  checkCurrentEpisode() {
    const currentEpisode = this.playerService.getCurrentEpisode();
    this.hasCurrentEpisode = currentEpisode !== null;
  }

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
      // 顶部导航栏
      this.buildNavigationBar();

      if (this.isLoading) {
        LoadingProgress()
          .width(50)
          .height(50)
          .margin({ top: 100 })
      } else if (this.podcasts.length === 0) {
        this.buildEmptyView();
      } else {
        List({ space: 12 }) {
          ForEach(this.podcasts, (podcast: Podcast) => {
            ListItem() {
              this.buildPodcastItem(podcast);
            }
            .swipeAction({ end: this.buildDeleteButton(podcast) })
          }, (podcast: Podcast) => podcast.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
      }

      // 快速打开播放页面按钮
      if (this.hasCurrentEpisode) {
        this.buildPlayerButton();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_light'))
  }

  @Builder
  buildPlayerButton() {
    Row() {
      Button() {
        Row() {
          Text('▶')
            .fontSize(20)
            .margin({ right: 8 })
          Text('正在播放')
            .fontSize(16)
        }
      }
      .width('100%')
      .height(56)
      .type(ButtonType.Normal)
      .borderRadius(28)
      .backgroundColor('#007AFF')
      .onClick(() => {
        this.openPlayerPage();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor(Color.White)
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
        console.info('======>>> Click: Back button (Subscription)');
        router.back();
      })

      Text('我的订阅')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ left: 12 })

      Blank()
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
  }

  @Builder
  buildEmptyView() {
    Column() {
      Text('暂无订阅')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      Text('在搜索页面订阅感兴趣的播客')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary_light'))
        .margin({ top: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildDeleteButton(podcast: Podcast) {
    Button() {
      Text('取消订阅')
        .fontSize(14)
        .fontColor(Color.White)
    }
    .width(80)
    .height('100%')
    .backgroundColor('#FF3B30')
    .onClick(async () => {
      console.info(`======>>> Click: Unsubscribe podcast - ${podcast.title}`);
      await this.unsubscribePodcast(podcast);
    })
  }

  async unsubscribePodcast(podcast: Podcast) {
    try {
      await PodcastService.getInstance().unsubscribePodcast(podcast.id);
      promptAction.showToast({
        message: '已取消订阅',
        duration: 2000
      });
      // 刷新列表
      await this.loadSubscriptions();
    } catch (error) {
      console.error('Unsubscribe failed:', error);
      promptAction.showToast({
        message: '取消订阅失败',
        duration: 2000
      });
    }
  }

  @Builder
  buildPodcastItem(podcast: Podcast) {
    Row() {
      Image(podcast.imageUrl)
        .width(80)
        .height(80)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)

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
      console.info(`======>>> Click: Podcast item (Subscription) - ${podcast.title}`);
      router.pushUrl({
        url: 'pages/PodcastDetailPage',
        params: { podcastId: podcast.id }
      }).catch((err: Error) => {
        console.error('Navigation failed:', err);
      });
    })
  }
}
