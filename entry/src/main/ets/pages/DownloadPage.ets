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
    console.info('[DownloadPage] aboutToAppear');
    this.loadDownloads();
    // 每秒更新一次下载进度
    this.updateTimer = setInterval(() => {
      this.loadDownloads();
    }, 1000);
  }

  onPageShow() {
    console.info('[DownloadPage] onPageShow');
    // 页面显示时立即刷新
    this.loadDownloads();
  }

  aboutToDisappear() {
    console.info('[DownloadPage] aboutToDisappear');
    if (this.updateTimer !== -1) {
      clearInterval(this.updateTimer);
      this.updateTimer = -1;
    }
  }

  async loadDownloads() {
    try {
      const db = DatabaseService.getInstance();
      const allEpisodes = await db.getAllEpisodes();
      
      console.info(`[DownloadPage] Total episodes: ${allEpisodes.length}`);
      
      // 使用数字比较，因为数据库返回的是 number 类型
      const downloading = allEpisodes.filter(e => {
        const status = Number(e.downloadStatus);
        console.info(`[DownloadPage] Episode ${e.title}: downloadStatus=${e.downloadStatus}, Number=${status}`);
        return status === DownloadStatus.DOWNLOADING;
      });
      
      const downloaded = allEpisodes.filter(e => {
        const status = Number(e.downloadStatus);
        return status === DownloadStatus.DOWNLOADED;
      });
      
      this.downloadingEpisodes = downloading;
      this.downloadedEpisodes = downloaded;
      
      console.info(`[DownloadPage] Downloading: ${this.downloadingEpisodes.length}, Downloaded: ${this.downloadedEpisodes.length}`);
      
      // 打印前几个单集的下载状态
      if (downloading.length > 0) {
        console.info('[DownloadPage] Downloading episodes:');
        downloading.forEach(e => {
          console.info(`  - ${e.title}: status=${e.downloadStatus}, progress=${e.downloadProgress}%`);
        });
      }
      
      if (downloaded.length > 0) {
        console.info('[DownloadPage] Downloaded episodes:');
        downloaded.forEach(e => {
          console.info(`  - ${e.title}: status=${e.downloadStatus}, localPath=${e.localPath}`);
        });
      }
    } catch (error) {
      console.error('[DownloadPage] Failed to load downloads:', error);
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
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Text('下载管理')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Blank()
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.background_card'))
  }

  @Builder
  buildDownloadingList() {
    if (this.downloadingEpisodes.length === 0) {
      Column() {
        Text('暂无下载任务')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
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
          .fontColor($r('app.color.text_secondary'))
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
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Text(`${episode.downloadProgress}%`)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Progress({ value: episode.downloadProgress, total: 100, type: ProgressType.Linear })
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
  }

  @Builder
  buildDownloadedItem(episode: Episode) {
    Row() {
      Column() {
        Text(episode.title)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)

        Text(episode.getFormattedFileSize())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('删除')
        .height(36)
        .onClick(() => {
          console.info(`[DownloadPage] Delete: ${episode.title}`);
          DownloadService.getInstance().deleteDownloadedFile(episode);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
  }
}
