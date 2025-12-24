import router from '@ohos.router';
import { Episode } from '../model/Episode';
import { PlayerService } from '../service/PlayerService';

@Entry
@Component
struct QueuePage {
  @State queueItems: Episode[] = [];
  private playerService: PlayerService = PlayerService.getInstance();

  aboutToAppear() {
    this.loadQueue();
  }

  loadQueue() {
    this.queueItems = this.playerService.getQueue();
  }

  build() {
    Column() {
      // 导航栏
      this.buildNavigationBar();

      if (this.queueItems.length === 0) {
        this.buildEmptyView();
      } else {
        this.buildQueueList();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Text('播放队列')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Blank()

      Button('清空')
        .onClick(() => {
          console.info('[QueuePage] Clear queue');
          this.playerService.clearQueue();
          this.queueItems = [];
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.background_card'))
  }

  @Builder
  buildEmptyView() {
    Column() {
      Text('🎧')
        .fontSize(80)
        .opacity(0.3)

      Text('播放队列为空')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 20 })

      Text('添加单集到队列')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildQueueList() {
    List({ space: 8 }) {
      ForEach(this.queueItems, (episode: Episode, index: number) => {
        ListItem() {
          this.buildQueueItem(episode, index);
        }
      }, (episode: Episode) => episode.id)
    }
    .width('100%')
    .layoutWeight(1)
    .padding(16)
  }

  @Builder
  buildQueueItem(episode: Episode, index: number) {
    Row() {
      Text(`${index + 1}`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width(32)

      Column() {
        Text(episode.title)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(episode.getFormattedDuration())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Button('移除')
        .height(36)
        .onClick(() => {
          console.info(`[QueuePage] Remove: ${episode.title}`);
          this.playerService.removeFromQueue(index);
          this.queueItems = this.playerService.getQueue();
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
  }
}
