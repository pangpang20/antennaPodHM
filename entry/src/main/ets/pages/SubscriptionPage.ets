import router from '@ohos.router';

@Entry
@Component
struct SubscriptionPage {
  build() {
    Column() {
      Text('订阅页面')
        .fontSize(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
