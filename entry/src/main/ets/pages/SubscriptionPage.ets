import { UIUtils, ToastOptions, DialogOptions, ButtonOptions, RouteParams } from '../common/UIUtils';
import { Podcast } from '../model/Podcast';
import { PodcastService } from '../service/PodcastService';
import { PlayerService } from '../service/PlayerService';

@Entry
@Component
struct SubscriptionPage {
  @State podcasts: Podcast[] = [];
  @State isLoading: boolean = false;
  @State hasCurrentEpisode: boolean = false;
  private refreshTimer: number = -1;
  private playerService: PlayerService = PlayerService.getInstance();
  private podcastService: PodcastService = PodcastService.getInstance();

  aboutToAppear() {
    this.loadSubscriptions();
    // 检查是否有正在播放的单集
    this.checkCurrentEpisode();
    // 启动定时器，每5秒检查一次是否需要刷新
    this.refreshTimer = setInterval(() => {
      this.smartRefresh();
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

  /**
   * 智能刷新逻辑
   * 新订阅1分钟内每5秒刷新，之后每2小时刷新一次
   * 跳过已标记为获取失败的播客
   */
  async smartRefresh() {
    try {
      // 获取最新的播客列表
      const podcasts = await this.podcastService.getSubscribedPodcasts();
      
      for (const podcast of podcasts) {
        // 跳过已标记为获取失败的播客
        if (podcast.isFetchFailed) {
          continue;
        }
        
        // 检查是否需要刷新
        if (podcast.needsRefresh()) {
          console.info(`[SubscriptionPage] Refreshing podcast: ${podcast.title}`);
          try {
            await this.podcastService.updatePodcastEpisodes(podcast.id);
          } catch (error) {
            console.error(`[SubscriptionPage] Failed to refresh podcast ${podcast.title}:`, error);
            // 失败时不影响其他播客的刷新
          }
        }
      }
      
      // 重新加载订阅列表以显示最新状态
      await this.loadSubscriptions();
    } catch (error) {
      console.error('[SubscriptionPage] Smart refresh failed:', error);
    }
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
      const params = new RouteParams();
      params.episodeId = currentEpisode.id;
      UIUtils.pushUrl('pages/PlayerPage', params);
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
    .backgroundColor($r('app.color.background'))
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
      .backgroundColor($r('app.color.primary'))
      .onClick(() => {
        this.openPlayerPage();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor($r('app.color.background_card'))
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
        console.info('[SubscriptionPage] Back');
        UIUtils.back();
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
    .backgroundColor($r('app.color.background_card'))
  }

  @Builder
  buildEmptyView() {
    Column() {
      Text('暂无订阅')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      Text('在搜索页面订阅感兴趣的播客')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
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
        .fontColor($r('app.color.text_on_primary'))
    }
    .width(80)
    .height('100%')
    .backgroundColor($r('app.color.accent_red'))
    .onClick(async () => {
      console.info(`[SubscriptionPage] Unsubscribe: ${podcast.title}`);
      await this.unsubscribePodcast(podcast);
    })
  }

  async unsubscribePodcast(podcast: Podcast) {
    try {
      await PodcastService.getInstance().unsubscribePodcast(podcast.id);
      UIUtils.showToast(new ToastOptions('已取消订阅', 2000));
      // 刷新列表
      await this.loadSubscriptions();
    } catch (error) {
      console.error('Unsubscribe failed:', error);
      UIUtils.showToast(new ToastOptions('取消订阅失败', 2000));
    }
  }

  /**
   * 显示取消订阅确认对话框
   */
  showUnsubscribeDialog(podcast: Podcast): void {
    const buttons: ButtonOptions[] = [
      new ButtonOptions('取消', '#999999'),
      new ButtonOptions('确定', '#FF3B30')
    ];
    UIUtils.showDialog(new DialogOptions(
      '取消订阅',
      `确定要取消订阅《${podcast.title}》吗？\n\n取消订阅后，该播客的所有单集和下载内容都将被删除。`,
      buttons
    )).then((index: number) => {
      if (index === 1) {
        // 用户点击"确定"，执行取消订阅
        console.info(`[SubscriptionPage] Confirmed unsubscribe: ${podcast.title}`);
        this.unsubscribePodcast(podcast);
      } else {
        // 用户点击"取消"
        console.info(`[SubscriptionPage] Cancelled: ${podcast.title}`);
      }
    });
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
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })

        Row() {
          Text(`${podcast.episodeCount} 集`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          
          // 如果获取失败，显示红色提示
          if (podcast.isFetchFailed) {
            Text('·')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 6, right: 6 })
            Text('无法获取')
              .fontSize(12)
              .fontColor($r('app.color.accent_red'))
              .fontWeight(FontWeight.Medium)
          }
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
    .onClick(() => {
      console.info(`[SubscriptionPage] Podcast: ${podcast.title}`);
      const params = new RouteParams();
      params.podcastId = podcast.id;
      UIUtils.pushUrl('pages/PodcastDetailPage', params);
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          console.info(`[SubscriptionPage] LongPress: ${podcast.title}`);
          this.showUnsubscribeDialog(podcast);
        })
    )
  }
}
