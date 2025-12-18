import { router } from '@kit.ArkUI';
import { Podcast } from '../model/Podcast';
import { Episode } from '../model/Episode';
import { DatabaseService } from '../service/DatabaseService';
import { PodcastService } from '../service/PodcastService';

@Entry
@Component
struct PodcastDetailPage {
  @State podcast: Podcast | null = null;
  @State episodes: Episode[] = [];
  @State isLoading: boolean = true;
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
        Text('←')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        router.back();
      })

      Text('播客详情')
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
        }
        .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('播放')
        .height(36)
        .onClick(() => {
          // 跳转到播放器页面
          router.pushUrl({
            url: 'pages/PlayerPage',
            params: { episodeId: episode.id }
          }).catch((err: Error) => {
            console.error('Navigation failed:', err);
          });
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }
}
