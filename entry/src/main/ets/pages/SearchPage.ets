import { UIUtils, ToastOptions } from '../common/UIUtils';
import { Podcast } from '../model/Podcast';
import { PodcastService } from '../service/PodcastService';

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
  @State subscribedPodcastIds: Set<string> = new Set();
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = false;  // iTunes API 不支持分页，默认无更多
  private currentOffset: number = 0;
  private pageSize: number = 50;  // iTunes API 一次性返回较多结果

  async aboutToAppear() {
    await this.loadSubscribedIds();
  }

  onPageShow() {
    // 每次显示页面时刷新已订阅列表
    this.loadSubscribedIds();
  }

  async loadSubscribedIds() {
    try {
      const podcasts = await PodcastService.getInstance().getSubscribedPodcasts();
      this.subscribedPodcastIds = new Set(podcasts.map(p => p.id));
    } catch (error) {
      console.error('Failed to load subscribed ids:', error);
    }
  }

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
    .backgroundColor($r('app.color.background'))
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
        console.info('[SearchPage] Back');
        UIUtils.back();
      })

      Text('搜索播客')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })

      Blank()
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.background_card'))
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
          console.info(`[SearchPage] Search: ${this.searchKeyword}`);
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
          console.info(`[SearchPage] RSS input toggle: ${this.showAddByUrl ? 'hide' : 'show'}`);
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
          console.info(`[SearchPage] Add RSS: ${this.feedUrl}`);
          this.addByRssUrl();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor($r('app.color.background_card'))
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

      // 加载更多按钮
      if (this.hasMore) {
        ListItem() {
          Row() {
            Button() {
              Row() {
                if (this.isLoadingMore) {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                    .color($r('app.color.text_on_primary'))
                  Text('加载中...')
                    .fontSize(14)
                    .fontColor($r('app.color.text_on_primary'))
                    .margin({ left: 8 })
                } else {
                  Text('点击加载更多')
                    .fontSize(14)
                    .fontColor($r('app.color.text_on_primary'))
                }
              }
            }
            .width('80%')
            .height(40)
            .backgroundColor($r('app.color.primary'))
            .borderRadius(20)
            .enabled(!this.isLoadingMore)
            .onClick(() => {
              console.info('[SearchPage] Load more');
              this.loadMore();
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .padding({ top: 12, bottom: 12 })
      } else if (this.searchResults.length > 0) {
        ListItem() {
          Text('没有更多了')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .height(60)
            .textAlign(TextAlign.Center)
        }
      }
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
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(podcast.author)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      // 判断是否已订阅
      if (this.subscribedPodcastIds.has(podcast.id)) {
        Button('已订阅')
          .height(36)
          .enabled(false)
          .backgroundColor($r('app.color.background_secondary'))
      } else {
        Button(this.subscribingId === podcast.id ? '订阅中...' : '订阅')
          .height(36)
          .enabled(!this.isSubscribing)
          .onClick(() => {
            console.info(`[SearchPage] Subscribe: ${podcast.title}`);
            this.subscribePodcast(podcast);
          })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
  }

  @Builder
  buildEmptyView() {
    Column() {
      Text('未找到相关播客')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
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
    this.currentOffset = 0;
    
    try {
      const results = await PodcastService.getInstance().searchPodcasts(this.searchKeyword, 0, this.pageSize);
      this.searchResults = results;
      console.info(`[SearchPage] Search completed, got ${results.length} results`);
      
      // 如果返回的结果数等于 pageSize，说明可能还有更多
      this.hasMore = results.length >= this.pageSize;
      this.currentOffset = results.length;
    } catch (error) {
      console.error('Search failed:', error);
      this.searchResults = [];
      this.hasMore = false;
    } finally {
      this.isSearching = false;
    }
  }

  /**
   * 加载更多
   */
  async loadMore() {
    if (this.isLoadingMore || !this.hasMore || this.searchKeyword.trim().length === 0) {
      return;
    }

    this.isLoadingMore = true;
    
    try {
      console.info(`[SearchPage] Loading more from offset ${this.currentOffset}`);
      const results = await PodcastService.getInstance().searchPodcasts(
        this.searchKeyword, 
        this.currentOffset, 
        this.pageSize
      );
      
      if (results.length > 0) {
        // 过滤掉已经存在的播客（根据 ID 去重）
        const existingIds = new Set(this.searchResults.map(p => p.id));
        const newResults = results.filter(p => !existingIds.has(p.id));
        
        if (newResults.length > 0) {
          this.searchResults = [...this.searchResults, ...newResults];
          console.info(`[SearchPage] Added ${newResults.length} new results (filtered ${results.length - newResults.length} duplicates), total: ${this.searchResults.length}`);
        }
        
        this.currentOffset += results.length;
        
        // 如果返回结果少于 pageSize，说明没有更多了
        if (results.length < this.pageSize) {
          this.hasMore = false;
        }
      } else {
        this.hasMore = false;
        console.info('[SearchPage] No more results');
      }
    } catch (error) {
      console.error('Load more failed:', error);
      this.hasMore = false;
    } finally {
      this.isLoadingMore = false;
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
      UIUtils.showToast(new ToastOptions('请输入有效的 URL（以 http:// 或 https:// 开头）', 2000));
      return;
    }

    this.isAddingByUrl = true;

    try {
      await PodcastService.getInstance().addPodcastByUrl(url);
      UIUtils.showToast(new ToastOptions('播客添加成功', 2000));
      this.feedUrl = '';
      this.showAddByUrl = false;
      UIUtils.back();
    } catch (error) {
      console.error('Add by RSS URL failed:', error);
      UIUtils.showToast(new ToastOptions('添加失败，请检查 URL 是否正确', 2000));
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

    // 检查是否已订阅
    if (this.subscribedPodcastIds.has(podcast.id)) {
      UIUtils.showToast(new ToastOptions('该播客已订阅', 2000));
      return;
    }

    if (!podcast.feedUrl) {
      UIUtils.showToast(new ToastOptions('该播客没有有效的 RSS 地址', 2000));
      return;
    }

    this.isSubscribing = true;
    this.subscribingId = podcast.id;

    try {
      // 先插入播客基本信息
      await PodcastService.getInstance().addPodcastFromSearchResult(podcast);
      
      // 再拉取单集并更新计数（在后台执行）
      PodcastService.getInstance().updatePodcastEpisodes(podcast.id)
        .catch((err: Error) => {
          console.error('Background update episodes failed:', err.message);
        });
      
      // 添加到已订阅列表
      this.subscribedPodcastIds.add(podcast.id);
      
      UIUtils.showToast(new ToastOptions('订阅成功，正在后台加载单集', 2000));
      
      // 不返回订阅页，留在搜索页继续操作
    } catch (error) {
      console.error('Subscribe failed:', error);
      UIUtils.showToast(new ToastOptions('订阅失败，请重试', 2000));
    } finally {
      this.isSubscribing = false;
      this.subscribingId = '';
    }
  }
}
