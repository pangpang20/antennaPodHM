import { UIUtils, ToastOptions, RouteParams } from '../common/UIUtils';
import { Episode, DownloadStatus } from '../model/Episode';
import { PlayerService } from '../service/PlayerService';
import { DownloadService } from '../service/DownloadService';
import { DatabaseService } from '../service/DatabaseService';

@Entry
@Component
struct EpisodeDetailPage {
  @State episode: Episode | null = null;
  @State isDownloading: boolean = false;
  @State downloadProgress: number = 0;
  @State isLoading: boolean = true;
  private episodeId: string = '';
  private playerService: PlayerService = PlayerService.getInstance();
  private downloadService: DownloadService = DownloadService.getInstance();
  private dbService: DatabaseService = DatabaseService.getInstance();

  async aboutToAppear() {
    const params = UIUtils.getParams<Record<string, Object>>();
    if (params && params['episodeId']) {
      this.episodeId = params['episodeId'] as string;
      await this.loadEpisodeDetail();
    } else {
      this.isLoading = false;
    }
  }

  /**
   * 加载单集详情
   */
  async loadEpisodeDetail() {
    this.isLoading = true;
    try {
      // 从数据库加载单集信息
      this.episode = await this.dbService.getEpisodeById(this.episodeId);
      if (this.episode) {
        await this.checkDownloadStatus();
        console.info(`[EpisodeDetailPage] Loaded episode: ${this.episode.title}`);
      } else {
        console.error(`[EpisodeDetailPage] Episode not found: ${this.episodeId}`);
      }
    } catch (error) {
      console.error('[EpisodeDetailPage] Failed to load episode:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 检查下载状态
   */
  async checkDownloadStatus() {
    if (this.episode) {
      const status = this.episode.downloadStatus;
      this.isDownloading = status === DownloadStatus.DOWNLOADING;
      if (this.isDownloading) {
        this.downloadProgress = this.episode.downloadProgress;
      }
    }
  }

  /**
   * 播放单集
   */
  playEpisode() {
    if (this.episode) {
      console.info(`[EpisodeDetailPage] Play: ${this.episode.title}`);
      this.playerService.playEpisode(this.episode);
      
      // 跳转到播放页面
      const params = new RouteParams();
      params.episodeId = this.episode.id;
      UIUtils.pushUrl('pages/PlayerPage', params);
    }
  }

  /**
   * 下载单集
   */
  async downloadEpisode() {
    if (this.episode) {
      console.info(`[EpisodeDetailPage] Download: ${this.episode.title}`);
      try {
        await this.downloadService.downloadEpisode(this.episode);
        UIUtils.showToast(new ToastOptions('已添加到下载队列', 2000));
        this.isDownloading = true;
      } catch (error) {
        console.error('Download failed:', error);
        const errorMsg = error instanceof Error ? error.message : '下载失败';
        UIUtils.showToast(new ToastOptions(errorMsg, 3000));
      }
    }
  }

  /**
   * 添加到待听队列
   */
  async addToQueue() {
    if (this.episode) {
      console.info(`[EpisodeDetailPage] Add to queue: ${this.episode.title}`);
      try {
        await this.dbService.addToQueue(this.episode.id);
        UIUtils.showToast(new ToastOptions('已添加到待听队列', 2000));
      } catch (error) {
        console.error('Add to queue failed:', error);
        UIUtils.showToast(new ToastOptions('添加失败', 2000));
      }
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      this.buildNavigationBar();

      if (this.isLoading) {
        // 加载中
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.episode) {
        Scroll() {
          Column() {
            // 封面图
            this.buildCoverImage();

            // 标题和基本信息
            this.buildEpisodeInfo();

            // 操作按钮
            this.buildActionButtons();

            // 详细描述
            this.buildDescription();
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      } else {
        this.buildEmptyView();
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
        Text('←')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        console.info('[EpisodeDetailPage] Back');
        UIUtils.back();
      })

      Text('单集详情')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })

      Blank()
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.background_card'))
  }

  @Builder
  buildCoverImage() {
    Image(this.episode?.imageUrl || '')
      .width(240)
      .height(240)
      .borderRadius(12)
      .objectFit(ImageFit.Cover)
      .margin({ top: 24 })
      .alt($r('app.media.app_icon'))
  }

  @Builder
  buildEpisodeInfo() {
    Column() {
      // 标题
      Text(this.episode?.title || '')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 20 })

      // 发布日期和时长
      Row() {
        Text(this.episode?.getFormattedPubDate() || '')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        Text('•')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8, right: 8 })

        Text(this.episode?.getFormattedDuration() || '')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        if (this.episode?.fileSize && this.episode.fileSize > 0) {
          Text('•')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8, right: 8 })

          Text(this.episode.getFormattedFileSize())
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .margin({ top: 12 })
      .justifyContent(FlexAlign.Center)

      // 下载状态
      if (this.episode?.downloadStatus === DownloadStatus.DOWNLOADED) {
        Row() {
          Text('✓')
            .fontSize(14)
            .fontColor($r('app.color.accent_green'))
            .margin({ right: 4 })

          Text('已下载')
            .fontSize(14)
            .fontColor($r('app.color.accent_green'))
        }
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
  }

  @Builder
  buildActionButtons() {
    Column() {
      // 播放按钮
      Button() {
        Row() {
          Text('▶')
            .fontSize(18)
            .fontColor($r('app.color.primary'))
            .margin({ right: 8 })

          Text('播放')
            .fontSize(16)
            .fontColor($r('app.color.primary'))
        }
      }
      .width('100%')
      .height(48)
      .backgroundColor(Color.Transparent)
      .border({ width: 2, color: $r('app.color.primary'), radius: 24 })
      .onClick(() => {
        this.playEpisode();
      })

      // 下载和加入队列按钮
      Row() {
        // 下载按钮
        if (this.episode?.downloadStatus !== DownloadStatus.DOWNLOADED) {
          Button() {
            Row() {
              if (this.isDownloading) {
                LoadingProgress()
                  .width(16)
                  .height(16)
                  .color($r('app.color.accent_green'))
                  .margin({ right: 6 })
              } else {
                Text('⬇')
                  .fontSize(16)
                  .fontColor($r('app.color.accent_green'))
                  .margin({ right: 6 })
              }

              Text(this.isDownloading ? `${this.downloadProgress}%` : '下载')
                .fontSize(14)
                .fontColor($r('app.color.accent_green'))
            }
          }
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Color.Transparent)
          .border({ width: 2, color: $r('app.color.accent_green'), radius: 22 })
          .enabled(!this.isDownloading)
          .onClick(() => {
            this.downloadEpisode();
          })
        }

        // 加入待听队列按钮
        Button() {
          Row() {
            Text('+')
              .fontSize(18)
              .fontColor($r('app.color.accent_orange'))
              .margin({ right: 6 })

            Text('待听')
              .fontSize(14)
              .fontColor($r('app.color.accent_orange'))
          }
        }
        .layoutWeight(1)
        .height(44)
        .backgroundColor(Color.Transparent)
        .border({ width: 2, color: $r('app.color.accent_orange'), radius: 22 })
        .margin({ left: this.episode?.downloadStatus !== DownloadStatus.DOWNLOADED ? 12 : 0 })
        .onClick(() => {
          this.addToQueue();
        })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 24 })
  }

  @Builder
  buildDescription() {
    Column() {
      Text('节目简介')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 12 })

      Text(this.formatDescription(this.episode?.description || '暂无简介'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .margin({ top: 16 })
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(12)
  }

  /**
   * 格式化描述，在时间戳前换行
   */
  formatDescription(desc: string): string {
    if (!desc) return '';
    let result = desc.replace(/(\d{1,2}:\d{2}(?::\d{2})?)/g, '\n$1');
    return result.replace(/^\n/, '').trim();
  }

  @Builder
  buildEmptyView() {
    Column() {
      Text('未找到单集信息')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }
}
