import router from '@ohos.router';

@Entry
@Component
struct EpisodeDetailPage {
  build() {
    Column() {
      Text('Episode详情页')
        .fontSize(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
