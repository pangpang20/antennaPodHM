import router from '@ohos.router';
import { Episode, DownloadStatus } from '../model/Episode';
import { DownloadService } from '../service/DownloadService';
import { DatabaseService } from '../service/DatabaseService';

@Entry
@Component
struct DownloadPage {
  @State downloadedEpisodes: Episode[] = [];
  @State downloadingEpisodes: Episode[] = [];
  private updateTimer: number = -1;

  aboutToAppear() {
    this.loadDownloads();
    // 每秒更新一次下载进度
    this.updateTimer = setInterval(() => {
      this.loadDownloads();
    }, 1000);
  }

  aboutToDisappear() {
    if (this.updateTimer !== -1) {
      clearInterval(this.updateTimer);
    }
  }

  async loadDownloads() {
    try {
      const db = DatabaseService.getInstance();
      const allEpisodes = await db.getAllEpisodes();
      
      this.downloadingEpisodes = allEpisodes.filter(e => e.downloadStatus === 1);
      this.downloadedEpisodes = allEpisodes.filter(e => e.downloadStatus === 2);
    } catch (error) {
      console.error('Failed to load downloads:', error);
    }
  }

  build() {
    Column() {
      // 导航栏
      this.buildNavigationBar();

      Tabs() {
        TabContent() {
          this.buildDownloadingList();
        }.tabBar('下载中')

        TabContent() {
          this.buildDownloadedList();
        }.tabBar('已下载')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_light'))
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Text('下载管理')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)

      Blank()
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
  }

  @Builder
  buildDownloadingList() {
    if (this.downloadingEpisodes.length === 0) {
      Column() {
        Text('暂无下载任务')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary_light'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 8 }) {
        ForEach(this.downloadingEpisodes, (episode: Episode) => {
          ListItem() {
            this.buildDownloadingItem(episode);
          }
        }, (episode: Episode) => episode.id)
      }
      .width('100%')
      .padding(16)
    }
  }

  @Builder
  buildDownloadedList() {
    if (this.downloadedEpisodes.length === 0) {
      Column() {
        Text('暂无已下载内容')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary_light'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 8 }) {
        ForEach(this.downloadedEpisodes, (episode: Episode) => {
          ListItem() {
            this.buildDownloadedItem(episode);
          }
        }, (episode: Episode) => episode.id)
      }
      .width('100%')
      .padding(16)
    }
  }

  @Builder
  buildDownloadingItem(episode: Episode) {
    Column() {
      Row() {
        Text(episode.title)
          .fontSize(16)
          .layoutWeight(1)

        Text(`${episode.downloadProgress}%`)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary_light'))
      }
      .width('100%')

      Progress({ value: episode.downloadProgress, total: 100, type: ProgressType.Linear })
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }

  @Builder
  buildDownloadedItem(episode: Episode) {
    Row() {
      Column() {
        Text(episode.title)
          .fontSize(16)
          .maxLines(2)

        Text(episode.getFormattedFileSize())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary_light'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('删除')
        .height(36)
        .onClick(() => {
          DownloadService.getInstance().deleteDownloadedFile(episode);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }
}
