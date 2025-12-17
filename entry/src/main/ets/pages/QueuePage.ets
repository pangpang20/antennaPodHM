import router from '@ohos.router';
import { Episode } from '../model/Episode';

@Entry
@Component
struct QueuePage {
  @State queueItems: Episode[] = [];

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
    .backgroundColor($r('app.color.background_light'))
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Text('播放队列')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)

      Blank()

      Button('清空')
        .onClick(() => {
          this.queueItems = [];
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
  }

  @Builder
  buildEmptyView() {
    Column() {
      Image($r('app.media.ic_empty'))
        .width(120)
        .height(120)
        .opacity(0.3)

      Text('播放队列为空')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 20 })

      Text('添加单集到队列')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary_light'))
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
        .width(32)

      Column() {
        Text(episode.title)
          .fontSize(16)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(episode.getFormattedDuration())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary_light'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Button('移除')
        .height(36)
        .onClick(() => {
          this.queueItems.splice(index, 1);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }
}
