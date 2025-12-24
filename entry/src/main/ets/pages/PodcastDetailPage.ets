import { UIUtils, ToastOptions, DialogOptions, ButtonOptions, RouteParams } from '../common/UIUtils';
import { Podcast } from '../model/Podcast';
import { Episode } from '../model/Episode';
import { DatabaseService } from '../service/DatabaseService';
import { PodcastService } from '../service/PodcastService';
import { DownloadService } from '../service/DownloadService';

@Entry
@Component
struct PodcastDetailPage {
  @State podcast: Podcast | null = null;
  @State episodes: Episode[] = [];
  @State isLoading: boolean = true;
  @State isSelectionMode: boolean = false;
  @State selectedEpisodes: Set<string> = new Set();
  @State currentPage: number = 1;  // 当前页码
  @State pageSize: number = 20;  // 每页数量
  @State hasMore: boolean = false;  // 是否还有更多
  @State isLoadingMore: boolean = false;  // 是否正在加载更多
  private podcastId: string = '';
  private allEpisodes: Episode[] = [];  // 存储所有单集

  aboutToAppear() {
    const params = UIUtils.getParams<Record<string, Object>>();
    if (params && params['podcastId']) {
      this.podcastId = params['podcastId'] as string;
      this.loadPodcastDetail();
    }
  }

  async loadPodcastDetail() {
    this.isLoading = true;
    try {
      const db = DatabaseService.getInstance();
      const service = PodcastService.getInstance();
      // 加载播客基本信息
      this.podcast = await db.getPodcastById(this.podcastId);
      
      try {
        // 如果还没有单集，则尝试从 RSS 更新
        await service.updatePodcastEpisodes(this.podcastId);
      } catch (error) {
        // RSS获取失败，显示友好提示
        const errMsg = error instanceof Error ? error.message : String(error);
        console.error('[PodcastDetailPage] Failed to update episodes:', errMsg);
        
        // 判断是否是网络超时或连接错误
        const isNetworkError = errMsg.includes('timeout') || 
                              errMsg.includes('connect') || 
                              errMsg.includes('network') ||
                              errMsg.includes('Failed to update');
        
        if (isNetworkError) {
          const buttons: ButtonOptions[] = [
            new ButtonOptions('取消', '#999999'),
            new ButtonOptions('重试', '#007AFF')
          ];
          UIUtils.showDialog(new DialogOptions(
            '网络连接失败',
            `无法连接到播客RSS地址，可能原因：

1. 该播客服务器在国外，需要科学上网访问
2. 网络连接不稳定或超时（15秒）
3. RSS地址不可用

建议：
• 开启科学上网工具后点击"重试"
• 检查网络连接
• 稍后再试`,
            buttons
          )).then((index: number) => {
            if (index === 1) {
              console.info('[PodcastDetailPage] User clicked retry, reloading podcast detail');
              this.loadPodcastDetail();
            }
          });
        }
      }
      
      // 加载所有Episodes
      this.allEpisodes = await db.queryEpisodesByPodcastId(this.podcastId);
      // 初始化分页数据
      this.currentPage = 1;
      this.updateDisplayedEpisodes();
    } catch (error) {
      console.error('[PodcastDetailPage] Failed to load podcast detail:', error);
      UIUtils.showToast(new ToastOptions('加载播客详情失败', 2000));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 更新显示的单集列表（分页）
   */
  updateDisplayedEpisodes() {
    const startIndex = 0;
    const endIndex = this.currentPage * this.pageSize;
    this.episodes = this.allEpisodes.slice(startIndex, endIndex);
    this.hasMore = endIndex < this.allEpisodes.length;
    console.info(`[PodcastDetailPage] Displaying ${this.episodes.length}/${this.allEpisodes.length} episodes, hasMore: ${this.hasMore}`);
  }

  /**
   * 加载更多单集
   */
  async loadMore() {
    if (this.isLoadingMore || !this.hasMore) {
      return;
    }

    this.isLoadingMore = true;
    // 模拟网络延迟，提升用户体验
    setTimeout(() => {
      this.currentPage++;
      this.updateDisplayedEpisodes();
      this.isLoadingMore = false;
      console.info(`[PodcastDetailPage] Loaded page ${this.currentPage}`);
    }, 300);
  }

  build() {
    Column() {
      // 导航栏
      this.buildNavigationBar();

      if (this.isLoading) {
        LoadingProgress()
          .width(50)
          .height(50)
          .margin({ top: 100 })
      } else {
        // 播客信息头部
        this.buildPodcastHeader();

        // Episodes列表
        this.buildEpisodesList();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Button() {
        Text(this.isSelectionMode ? '取消' : '←')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        console.info('[PodcastDetailPage] Back/Cancel');
        if (this.isSelectionMode) {
          this.isSelectionMode = false;
          this.selectedEpisodes.clear();
        } else {
          UIUtils.back();
        }
      })

      Text(this.isSelectionMode ? `已选择 ${this.selectedEpisodes.size} 集` : '播客详情')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })

      Blank()

      if (!this.isSelectionMode) {
        Button('多选')
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.primary'))
          .onClick(() => {
            console.info('[PodcastDetailPage] Multi-select mode');
            this.isSelectionMode = true;
          })
      } else {
        Button(`下载(${this.selectedEpisodes.size})`)
          .height(36)
          .enabled(this.selectedEpisodes.size > 0)
          .onClick(() => {
            console.info(`[PodcastDetailPage] Download ${this.selectedEpisodes.size} selected`);
            this.downloadSelectedEpisodes();
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.background_card'))
  }

  @Builder
  buildPodcastHeader() {
    Column() {
      Image(this.podcast?.imageUrl)
        .width(120)
        .height(120)
        .borderRadius(12)
        .objectFit(ImageFit.Cover)

      Text(this.podcast?.title || '')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16 })

      Text(this.podcast?.author || '')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 8 })

      Text(this.podcast?.description || '')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 12 })
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 取消订阅按钮
      Button('取消订阅')
        .width('100%')
        .height(44)
        .fontSize(16)
        .fontColor($r('app.color.accent_red'))
        .backgroundColor($r('app.color.delete_button_bg'))
        .borderRadius(8)
        .margin({ top: 16 })
        .onClick(() => {
          console.info('[PodcastDetailPage] Unsubscribe');
          this.showUnsubscribeDialog();
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.background_card'))
  }

  /**
   * 显示取消订阅确认对话框
   */
  showUnsubscribeDialog(): void {
    if (!this.podcast) return;
    
    const buttons: ButtonOptions[] = [
      new ButtonOptions('取消', '#999999'),
      new ButtonOptions('确定', '#FF3B30')
    ];
    UIUtils.showDialog(new DialogOptions(
      '取消订阅',
      `确定要取消订阅《${this.podcast.title}》吗？\n\n取消订阅后，该播客的所有单集和下载内容都将被删除。`,
      buttons
    )).then((index: number) => {
      if (index === 1) {
        // 用户点击“确定”，执行取消订阅
        this.unsubscribePodcast();
      }
    });
  }

  /**
   * 执行取消订阅
   */
  async unsubscribePodcast(): Promise<void> {
    if (!this.podcast) return;
    
    try {
      await PodcastService.getInstance().unsubscribePodcast(this.podcast.id);
      UIUtils.showToast(new ToastOptions('已取消订阅', 2000));
      // 返回上一页
      UIUtils.back();
    } catch (error) {
      console.error('Unsubscribe failed:', error);
      UIUtils.showToast(new ToastOptions('取消订阅失败', 2000));
    }
  }

  @Builder
  buildEpisodesList() {
    List({ space: 8 }) {
      ForEach(this.episodes, (episode: Episode) => {
        ListItem() {
          this.buildEpisodeItem(episode);
        }
      }, (episode: Episode) => episode.id)

      // 加载更多按钮
      if (this.hasMore) {
        ListItem() {
          Button() {
            if (this.isLoadingMore) {
              Row() {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color($r('app.color.primary'))
                  .margin({ right: 8 })
                Text('加载中...')
                  .fontSize(14)
                  .fontColor($r('app.color.primary'))
              }
            } else {
              Text('加载更多')
                .fontSize(14)
                .fontColor($r('app.color.primary'))
            }
          }
          .width('100%')
          .height(44)
          .backgroundColor($r('app.color.background_card'))
          .borderRadius(8)
          .enabled(!this.isLoadingMore)
          .onClick(() => {
            console.info('[PodcastDetailPage] Load more');
            this.loadMore();
          })
        }
        .margin({ top: 8 })
      }

      // 已加载全部提示
      if (!this.hasMore && this.episodes.length > 0) {
        ListItem() {
          Text(`已加载全部 ${this.allEpisodes.length} 集`)
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .padding(16)
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding(16)
  }

  @Builder
  buildEpisodeItem(episode: Episode) {
    Row() {
      // 多选模式下显示复选框
      if (this.isSelectionMode) {
        Checkbox()
          .select(this.selectedEpisodes.has(episode.id))
          .onChange((isChecked: boolean) => {
            if (isChecked) {
              this.selectedEpisodes.add(episode.id);
            } else {
              this.selectedEpisodes.delete(episode.id);
            }
          })
          .margin({ right: 12 })
      }

      Column() {
        Row() {
          Text(episode.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(episode.isPlayed ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
            .layoutWeight(1)
          
          // 已听过标识
          if (episode.isPlayed) {
            Text('✓ 已听')
              .fontSize(12)
              .fontColor($r('app.color.accent_green'))
              .backgroundColor($r('app.color.badge_green_bg'))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(4)
              .margin({ left: 8 })
          }
        }
        .width('100%')

        Row() {
          Text(episode.getFormattedDuration())
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))

          Text('•')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8, right: 8 })

          Text(new Date(episode.pubDate).toLocaleDateString())
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))

          // 显示下载状态
          if (episode.downloadStatus === 1) {
            Text('•')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 8, right: 8 })
            Text(`${episode.downloadProgress}%`)
              .fontSize(12)
              .fontColor($r('app.color.primary'))
          } else if (episode.downloadStatus === 2) {
            Text('•')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 8, right: 8 })
            Text('已下载')
              .fontSize(12)
              .fontColor($r('app.color.accent_green'))
          }
        }
        .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => {
        // 非选择模式下，点击标题区域跳转到单集详情
        if (!this.isSelectionMode) {
          console.info(`[PodcastDetailPage] Episode: ${episode.title}`);
          const params = new RouteParams();
          params.episodeId = episode.id;
          UIUtils.pushUrl('pages/EpisodeDetailPage', params);
        }
      })

      if (!this.isSelectionMode) {
        // 待听按钮
        Button() {
          Text('➕')
            .fontSize(16)
        }
        .width(40)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          console.info(`[PodcastDetailPage] Add to queue: ${episode.title}`);
          this.addToQueue(episode);
        })
        .margin({ left: 8 })

        // 下载按钮
        Button() {
          if (episode.downloadStatus === 0) {
            Text('⬇️')
              .fontSize(18)
          } else if (episode.downloadStatus === 1) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('app.color.primary'))
          } else {
            Text('✓')
              .fontSize(18)
              .fontColor($r('app.color.accent_green'))
          }
        }
        .width(40)
        .height(36)
        .backgroundColor(Color.Transparent)
        .enabled(episode.downloadStatus === 0)
        .onClick(() => {
          console.info(`[PodcastDetailPage] Download: ${episode.title}`);
          this.downloadEpisode(episode);
        })
        .margin({ left: 8 })

        // 播放按钮
        Button('播放')
          .height(36)
          .onClick(() => {
            console.info(`[PodcastDetailPage] Play: ${episode.title}`);
            const params = new RouteParams();
            params.episodeId = episode.id;
            UIUtils.pushUrl('pages/PlayerPage', params);
          })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
  }

  async downloadEpisode(episode: Episode) {
    try {
      await DownloadService.getInstance().downloadEpisode(episode);
      UIUtils.showToast(new ToastOptions('已加入下载队列', 2000));
    } catch (error) {
      console.error('Download failed:', error);
      UIUtils.showToast(new ToastOptions('下载失败', 2000));
    }
  }

  /**
   * 添加到待听队列
   */
  async addToQueue(episode: Episode) {
    try {
      const db = DatabaseService.getInstance();
      await db.addToQueue(episode.id);
      console.info(`[PodcastDetailPage] Added to queue: ${episode.title}`);
      UIUtils.showToast(new ToastOptions('已添加到待听队列', 2000));
    } catch (error) {
      console.error('[PodcastDetailPage] Failed to add to queue:', error);
      UIUtils.showToast(new ToastOptions('添加失败', 2000));
    }
  }

  async downloadSelectedEpisodes() {
    if (this.selectedEpisodes.size === 0) {
      return;
    }

    const downloadService = DownloadService.getInstance();
    let count = 0;
    let permissionDenied = false;

    for (const episodeId of this.selectedEpisodes) {
      const episode = this.episodes.find(e => e.id === episodeId);
      if (episode && episode.downloadStatus === 0) {
        try {
          await downloadService.downloadEpisode(episode);
          count++;
        } catch (error) {
          console.error('Download failed for episode:', episode.title, error);
          if (error instanceof Error && error.message.includes('权限')) {
            permissionDenied = true;
            break; // 权限被拒绝，停止继续下载
          }
        }
      }
    }

    if (permissionDenied) {
      UIUtils.showToast(new ToastOptions('没有存储权限，无法下载。请在设置中开启存储权限。', 3000));
    } else {
      UIUtils.showToast(new ToastOptions(`已加入 ${count} 个下载任务`, 2000));
    }

    this.isSelectionMode = false;
    this.selectedEpisodes.clear();
  }
}
