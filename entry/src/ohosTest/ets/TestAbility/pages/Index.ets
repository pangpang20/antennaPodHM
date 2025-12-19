@Entry
@Component
struct Index {
  @State message: string = 'AntennaPodHM Tests';

  build() {
    Row() {
      Column() {
        Text(this.message)
          .fontSize(50)
          .fontWeight(FontWeight.Bold)
        Text('Running tests...')
          .fontSize(30)
          .opacity(0.6)
          .margin({ top: 20 })
      }
      .width('100%')
    }
    .height('100%')
  }
}
