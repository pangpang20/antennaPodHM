import { router, promptAction } from '@kit.ArkUI';
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
  private podcastId: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
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
      // 如果还没有单集，则尝试从 RSS 更新
      await service.updatePodcastEpisodes(this.podcastId);
      // 加载Episodes
      this.episodes = await db.queryEpisodesByPodcastId(this.podcastId);
    } catch (error) {
      console.error('Failed to load podcast detail:', error);
    } finally {
      this.isLoading = false;
    }
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
    .backgroundColor($r('app.color.background_light'))
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
        console.info('======>>> Click: Back/Cancel button (PodcastDetail)');
        if (this.isSelectionMode) {
          this.isSelectionMode = false;
          this.selectedEpisodes.clear();
        } else {
          router.back();
        }
      })

      Text(this.isSelectionMode ? `已选择 ${this.selectedEpisodes.size} 集` : '播客详情')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ left: 12 })

      Blank()

      if (!this.isSelectionMode) {
        Button('多选')
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.primary'))
          .onClick(() => {
            console.info('======>>> Click: Enable multi-selection mode');
            this.isSelectionMode = true;
          })
      } else {
        Button(`下载(${this.selectedEpisodes.size})`)
          .height(36)
          .enabled(this.selectedEpisodes.size > 0)
          .onClick(() => {
            console.info(`======>>> Click: Download selected episodes - ${this.selectedEpisodes.size} episodes`);
            this.downloadSelectedEpisodes();
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
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
        .margin({ top: 16 })

      Text(this.podcast?.author || '')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary_light'))
        .margin({ top: 8 })

      Text(this.podcast?.description || '')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary_light'))
        .margin({ top: 12 })
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
  }

  @Builder
  buildEpisodesList() {
    List({ space: 8 }) {
      ForEach(this.episodes, (episode: Episode) => {
        ListItem() {
          this.buildEpisodeItem(episode);
        }
      }, (episode: Episode) => episode.id)
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
        Text(episode.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text(episode.getFormattedDuration())
            .fontSize(12)
            .fontColor($r('app.color.text_secondary_light'))

          Text('•')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary_light'))
            .margin({ left: 8, right: 8 })

          Text(new Date(episode.pubDate).toLocaleDateString())
            .fontSize(12)
            .fontColor($r('app.color.text_secondary_light'))

          // 显示下载状态
          if (episode.downloadStatus === 1) {
            Text('•')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary_light'))
              .margin({ left: 8, right: 8 })
            Text(`${episode.downloadProgress}%`)
              .fontSize(12)
              .fontColor($r('app.color.primary'))
          } else if (episode.downloadStatus === 2) {
            Text('•')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary_light'))
              .margin({ left: 8, right: 8 })
            Text('已下载')
              .fontSize(12)
              .fontColor('#4CAF50')
          }
        }
        .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => {
        // 非选择模式下，点击标题区域跳转到单集详情
        if (!this.isSelectionMode) {
          console.info(`======>>> Click: Episode detail - ${episode.title}`);
          router.pushUrl({
            url: 'pages/EpisodeDetailPage',
            params: { episodeId: episode.id }
          }).catch((err: Error) => {
            console.error('Navigation failed:', err);
          });
        }
      })

      if (!this.isSelectionMode) {
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
              .fontColor('#4CAF50')
          }
        }
        .width(40)
        .height(36)
        .backgroundColor(Color.Transparent)
        .enabled(episode.downloadStatus === 0)
        .onClick(() => {
          console.info(`======>>> Click: Download episode - ${episode.title}`);
          this.downloadEpisode(episode);
        })
        .margin({ left: 8 })

        // 播放按钮
        Button('播放')
          .height(36)
          .onClick(() => {
            console.info(`======>>> Click: Play episode - ${episode.title}`);
            router.pushUrl({
              url: 'pages/PlayerPage',
              params: { episodeId: episode.id }
            }).catch((err: Error) => {
              console.error('Navigation failed:', err);
            });
          })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }

  async downloadEpisode(episode: Episode) {
    try {
      await DownloadService.getInstance().downloadEpisode(episode);
      promptAction.showToast({
        message: '已加入下载队列',
        duration: 2000
      });
    } catch (error) {
      console.error('Download failed:', error);
      promptAction.showToast({
        message: '下载失败',
        duration: 2000
      });
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
      promptAction.showToast({
        message: '没有存储权限，无法下载。请在设置中开启存储权限。',
        duration: 3000
      });
    } else {
      promptAction.showToast({
        message: `已加入 ${count} 个下载任务`,
        duration: 2000
      });
    }

    this.isSelectionMode = false;
    this.selectedEpisodes.clear();
  }
}
