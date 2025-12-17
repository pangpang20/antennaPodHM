import { router } from '@kit.ArkUI';
import { Podcast } from '../model/Podcast';
import { PodcastService } from '../service/PodcastService';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct SearchPage {
  @State searchKeyword: string = '';
  @State searchResults: Podcast[] = [];
  @State isSearching: boolean = false;
  @State showAddByUrl: boolean = false;
  @State feedUrl: string = '';
  @State isSubscribing: boolean = false;
  @State subscribingId: string = '';
  @State isAddingByUrl: boolean = false;

  build() {
    Column() {
      // 顶部导航栏
      this.buildNavigationBar();

      // 搜索框
      this.buildSearchBar();

      // 添加方式选择
      this.buildAddOptions();

      // RSS URL 输入区域
      if (this.showAddByUrl) {
        this.buildRssUrlInput();
      }

      // 搜索结果列表
      if (this.isSearching) {
        LoadingProgress()
          .width(50)
          .height(50)
          .margin({ top: 100 })
      } else if (this.searchResults.length > 0) {
        this.buildSearchResults();
      } else if (this.searchKeyword.length > 0) {
        this.buildEmptyView();
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

      Text('搜索播客')
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
  buildSearchBar() {
    Row() {
      TextInput({ placeholder: '搜索播客名称或关键词', text: this.searchKeyword })
        .layoutWeight(1)
        .onChange((value: string) => {
          this.searchKeyword = value;
        })
        .onSubmit(() => {
          this.performSearch();
        })

      Button('搜索')
        .margin({ left: 8 })
        .onClick(() => {
          this.performSearch();
        })
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  buildAddOptions() {
    Column() {
      Button(this.showAddByUrl ? '取消' : '通过 RSS URL 添加')
        .width('100%')
        .type(ButtonType.Normal)
        .onClick(() => {
          this.showAddByUrl = !this.showAddByUrl;
          if (!this.showAddByUrl) {
            this.feedUrl = '';
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
  }

  @Builder
  buildRssUrlInput() {
    Column() {
      TextInput({ placeholder: '输入 RSS Feed URL', text: this.feedUrl })
        .width('100%')
        .onChange((value: string) => {
          this.feedUrl = value;
        })
        .onSubmit(() => {
          this.addByRssUrl();
        })

      Button(this.isAddingByUrl ? '添加中...' : '添加播客')
        .width('100%')
        .margin({ top: 12 })
        .enabled(!this.isAddingByUrl && this.feedUrl.length > 0)
        .onClick(() => {
          this.addByRssUrl();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor(Color.White)
    .borderRadius(8)
  }

  @Builder
  buildSearchResults() {
    List({ space: 12 }) {
      ForEach(this.searchResults, (podcast: Podcast) => {
        ListItem() {
          this.buildPodcastItem(podcast);
        }
      }, (podcast: Podcast) => podcast.id)
    }
    .width('100%')
    .layoutWeight(1)
    .padding(16)
  }

  @Builder
  buildPodcastItem(podcast: Podcast) {
    Row() {
      Image(podcast.imageUrl)
        .width(80)
        .height(80)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)

      Column() {
        Text(podcast.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(podcast.author)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary_light'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      Button(this.subscribingId === podcast.id ? '订阅中...' : '订阅')
        .height(36)
        .enabled(!this.isSubscribing)
        .onClick(() => {
          this.subscribePodcast(podcast);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }

  @Builder
  buildEmptyView() {
    Column() {
      Text('未找到相关播客')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary_light'))
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 执行搜索
   */
  async performSearch() {
    if (this.searchKeyword.trim().length === 0) {
      return;
    }

    this.isSearching = true;
    try {
      this.searchResults = await PodcastService.getInstance().searchPodcasts(this.searchKeyword);
    } catch (error) {
      console.error('Search failed:', error);
    } finally {
      this.isSearching = false;
    }
  }

  /**
   * 通过 RSS URL 添加播客
   */
  async addByRssUrl() {
    if (this.isAddingByUrl || this.feedUrl.trim().length === 0) {
      return;
    }

    // 简单验证 URL 格式
    const url = this.feedUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      promptAction.showToast({
        message: '请输入有效的 URL（以 http:// 或 https:// 开头）',
        duration: 2000
      });
      return;
    }

    this.isAddingByUrl = true;

    try {
      await PodcastService.getInstance().addPodcastByUrl(url);
      promptAction.showToast({
        message: '播客添加成功',
        duration: 2000
      });
      this.feedUrl = '';
      this.showAddByUrl = false;
      router.back();
    } catch (error) {
      console.error('Add by RSS URL failed:', error);
      promptAction.showToast({
        message: '添加失败，请检查 URL 是否正确',
        duration: 2000
      });
    } finally {
      this.isAddingByUrl = false;
    }
  }

  /**
   * 订阅播客
   */
  async subscribePodcast(podcast: Podcast) {
    if (this.isSubscribing) {
      return;
    }

    if (!podcast.feedUrl) {
      promptAction.showToast({
        message: '该播客没有有效的 RSS 地址',
        duration: 2000
      });
      return;
    }

    this.isSubscribing = true;
    this.subscribingId = podcast.id;

    try {
      await PodcastService.getInstance().addPodcastByUrl(podcast.feedUrl);
      promptAction.showToast({
        message: '订阅成功',
        duration: 2000
      });
      router.back();
    } catch (error) {
      console.error('Subscribe failed:', error);
      promptAction.showToast({
        message: '订阅失败，请重试',
        duration: 2000
      });
    } finally {
      this.isSubscribing = false;
      this.subscribingId = '';
    }
  }
}
