import { Podcast } from '../model/Podcast';
import { Episode, DownloadStatus } from '../model/Episode';
import { PodcastService } from '../service/PodcastService';
import { DatabaseService } from '../service/DatabaseService';
import { PlayerService } from '../service/PlayerService';
import { DownloadService } from '../service/DownloadService';
import { UIUtils, ToastOptions, RouteParams } from '../common/UIUtils';

@Entry
@Component
struct MainPage {
  @State currentTabIndex: number = 0;
  @State podcasts: Podcast[] = [];
  @State isLoading: boolean = false;
  @State hasCurrentEpisode: boolean = false;
  @State currentEpisode: Episode | null = null;
  @State isPlaying: boolean = false;
  @State playProgress: number = 0;
  @State currentPlayTime: number = 0;  // 当前播放时间（秒）
  @State totalDuration: number = 0;  // 总时长（秒）
  @State sleepTimerRemaining: number = 0;  // 睡眠定时器剩余秒数
  @State marqueeText: string = '';  // 跑马灯文本
  @State downloadingEpisodes: Episode[] = [];
  @State downloadedEpisodes: Episode[] = [];
  @State allEpisodes: Episode[] = [];  // 所有单集
  @State episodesPage: number = 1;  // 单集当前页
  @State episodesPageSize: number = 20;  // 每页数量
  @State episodesHasMore: boolean = false;  // 是否还有更多
  @State episodeSearchKeyword: string = '';  // 单集搜索关键词
  @State filteredEpisodes: Episode[] = [];  // 过滤/搜索结果
  @State searchTotal: number = 0;  // 搜索结果总数
  @State searchPage: number = 1;  // 搜索结果当前页
  @State isSearching: boolean = false;  // 是否正在搜索（首次）
  @State isLoadingMore: boolean = false;  // 是否正在加载更多
  @State searchHasMore: boolean = false;  // 搜索结果是否还有更多
  @State queueEpisodes: Episode[] = [];  // 待听队列
  @State isDownloadEditMode: boolean = false;  // 下载管理编辑模式
  @State selectedDownloadIds: Set<string> = new Set();  // 已选中的下载项ID
  private playerService: PlayerService = PlayerService.getInstance();
  private dbService: DatabaseService = DatabaseService.getInstance();
  private downloadUpdateTimer: number = -1;
  private playUpdateTimer: number = -1;
  private subscriptionUpdateTimer: number = -1;

  aboutToAppear() {
    this.loadSubscriptions();
    this.loadAllEpisodes();
    this.loadQueue();
    this.checkCurrentEpisode();
    this.loadDownloads();
    this.startPlayUpdateTimer();
    
    // 默认在订阅 Tab，启动订阅刷新定时器
    if (this.currentTabIndex === 0) {
      this.startSubscriptionUpdateTimer();
    }
    
    // 监听播放状态变化
    this.playerService.addEventListener('stateChange', () => {
      this.checkCurrentEpisode();
    });
  }

  aboutToDisappear() {
    if (this.downloadUpdateTimer !== -1) {
      clearInterval(this.downloadUpdateTimer);
      this.downloadUpdateTimer = -1;
    }
    if (this.playUpdateTimer !== -1) {
      clearInterval(this.playUpdateTimer);
      this.playUpdateTimer = -1;
    }
    if (this.subscriptionUpdateTimer !== -1) {
      clearInterval(this.subscriptionUpdateTimer);
      this.subscriptionUpdateTimer = -1;
    }
  }

  /**
   * 启动播放状态更新定时器
   */
  startPlayUpdateTimer() {
    this.playUpdateTimer = setInterval(() => {
      this.checkCurrentEpisode();
    }, 500);
  }

  onPageShow() {
    // 页面通过路由返回时刷新列表
    this.loadSubscriptions();
    this.loadAllEpisodes();
    this.loadQueue();
    this.checkCurrentEpisode();
    this.loadDownloads();
  }

  /**
   * 加载下载列表
   */
  async loadDownloads() {
    try {
      const db = DatabaseService.getInstance();
      const downloadService = DownloadService.getInstance();
      const allEpisodes = await db.getAllEpisodes();
      
      // 获取正在下载的任务（从内存中获取实时进度）
      const activeTasks = downloadService.getAllDownloadTasks();
      const activeTaskMap = new Map(activeTasks.map(t => [t.episode.id, t.episode]));
      
      // 对于正在下载的，优先使用内存中的实时进度
      this.downloadingEpisodes = allEpisodes
        .filter(e => Number(e.downloadStatus) === DownloadStatus.DOWNLOADING)
        .map(e => {
          // 如果在活动下载中，使用内存中的进度
          const activeEpisode = activeTaskMap.get(e.id);
          if (activeEpisode) {
            e.downloadProgress = activeEpisode.downloadProgress;
          }
          return e;
        });
      
      this.downloadedEpisodes = allEpisodes.filter(e => {
        const status = Number(e.downloadStatus);
        return status === DownloadStatus.DOWNLOADED;
      });
      
      console.info(`[MainPage] Downloads - Downloading: ${this.downloadingEpisodes.length}, Downloaded: ${this.downloadedEpisodes.length}`);
    } catch (error) {
      console.error('[MainPage] Failed to load downloads:', error);
    }
  }

  /**
   * 开始下载更新定时器
   */
  startDownloadUpdateTimer() {
    if (this.downloadUpdateTimer === -1) {
      this.downloadUpdateTimer = setInterval(() => {
        this.loadDownloads();
      }, 1000);
    }
  }

  /**
   * 停止下载更新定时器
   */
  stopDownloadUpdateTimer() {
    if (this.downloadUpdateTimer !== -1) {
      clearInterval(this.downloadUpdateTimer);
      this.downloadUpdateTimer = -1;
    }
  }

  /**
   * 开始订阅更新定时器 - 每5秒刷新集数
   */
  startSubscriptionUpdateTimer() {
    if (this.subscriptionUpdateTimer === -1) {
      this.subscriptionUpdateTimer = setInterval(() => {
        this.loadSubscriptions();
        console.info('[MainPage] Subscription list refreshed');
      }, 5000);
    }
  }

  /**
   * 停止订阅更新定时器
   */
  stopSubscriptionUpdateTimer() {
    if (this.subscriptionUpdateTimer !== -1) {
      clearInterval(this.subscriptionUpdateTimer);
      this.subscriptionUpdateTimer = -1;
    }
  }

  /**
   * 加载所有单集（倒序排列，分页）
   */
  async loadAllEpisodes() {
    try {
      const allEps = await this.dbService.getAllEpisodes();
      // 按pubDate倒序排列（最新在前）
      allEps.sort((a, b) => (b.pubDate || 0) - (a.pubDate || 0));
      // 分页显示
      const showCount = this.episodesPage * this.episodesPageSize;
      this.allEpisodes = allEps.slice(0, showCount);
      this.episodesHasMore = allEps.length > showCount;
      
      // 应用搜索过滤
      this.filterEpisodes();
      
      console.info(`[MainPage] Loaded ${this.allEpisodes.length}/${allEps.length} episodes (page ${this.episodesPage})`);
    } catch (error) {
      console.error('[MainPage] Failed to load episodes:', error);
    }
  }

  /**
   * 加载更多单集
   */
  async loadMoreEpisodes() {
    this.episodesPage++;
    await this.loadAllEpisodes();
  }

  /**
   * 过滤单集列表（无搜索关键词时）
   */
  filterEpisodes() {
    // 如果有搜索关键词且有搜索结果，保持搜索结果不变
    if (this.episodeSearchKeyword && this.episodeSearchKeyword.trim() !== '' && this.searchTotal > 0) {
      return;
    }
    this.filteredEpisodes = this.allEpisodes;
  }

  /**
   * 搜索单集（数据库查询）
   */
  async searchEpisodes() {
    if (!this.episodeSearchKeyword || this.episodeSearchKeyword.trim() === '') {
      return;
    }
    
    this.isSearching = true;
    try {
      const result = await this.dbService.searchEpisodes(
        this.episodeSearchKeyword.trim(),
        0,
        this.episodesPageSize
      );
      this.filteredEpisodes = result.episodes;
      this.searchTotal = result.total;
      this.searchPage = 1;
      this.searchHasMore = result.episodes.length < result.total;
      console.info(`[MainPage] Search: ${result.episodes.length}/${result.total}`);
    } catch (error) {
      console.error('[MainPage] Search failed:', error);
    } finally {
      this.isSearching = false;
    }
  }

  /**
   * 加载更多搜索结果
   */
  async loadMoreSearchResults() {
    if (!this.searchHasMore || this.isLoadingMore) return;
    
    this.isLoadingMore = true;
    try {
      const offset = this.searchPage * this.episodesPageSize;
      const result = await this.dbService.searchEpisodes(
        this.episodeSearchKeyword.trim(),
        offset,
        this.episodesPageSize
      );
      this.filteredEpisodes = this.filteredEpisodes.concat(result.episodes);
      this.searchPage++;
      this.searchHasMore = this.filteredEpisodes.length < this.searchTotal;
      console.info(`[MainPage] Load more search: ${this.filteredEpisodes.length}/${this.searchTotal}`);
    } catch (error) {
      console.error('[MainPage] Load more search failed:', error);
    } finally {
      this.isLoadingMore = false;
    }
  }

  /**
   * 处理搜索输入变化
   */
  onEpisodeSearchChange(value: string) {
    this.episodeSearchKeyword = value;
    if (!value || value.trim() === '') {
      // 清空搜索，显示全部单集
      this.searchHasMore = false;
      this.searchTotal = 0;
      this.filterEpisodes();
    }
  }

  /**
   * 执行搜索（用户点击搜索或回车）
   */
  onEpisodeSearchSubmit() {
    if (this.episodeSearchKeyword && this.episodeSearchKeyword.trim() !== '') {
      this.searchEpisodes();
    }
  }

  /**
   * 加载待听队列
   */
  async loadQueue() {
    try {
      this.queueEpisodes = await this.dbService.getQueueEpisodes();
      console.info(`[MainPage] Loaded ${this.queueEpisodes.length} queue items`);
    } catch (error) {
      console.error('[MainPage] Failed to load queue:', error);
    }
  }

  /**
   * 添加到待听队列
   */
  async addToQueue(episode: Episode) {
    try {
      await this.dbService.addToQueue(episode.id);
      await this.loadQueue();
      console.info(`[MainPage] Added to queue: ${episode.title}`);
      UIUtils.showToast(new ToastOptions('已添加到队列', 2000));
    } catch (error) {
      console.error('[MainPage] Failed to add to queue:', error);
      UIUtils.showToast(new ToastOptions('添加失败', 2000));
    }
  }

  /**
   * 从待听队列移除
   */
  async removeFromQueue(episode: Episode) {
    try {
      await this.dbService.removeFromQueue(episode.id);
      await this.loadQueue();
      console.info(`[MainPage] Removed from queue: ${episode.title}`);
    } catch (error) {
      console.error('[MainPage] Failed to remove from queue:', error);
    }
  }

  /**
   * 加载订阅列表
   */
  async loadSubscriptions() {
    this.isLoading = true;
    try {
      this.podcasts = await PodcastService.getInstance().getSubscribedPodcasts();
    } catch (error) {
      console.error('Failed to load subscriptions:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 检查是否有正在播放的单集
   */
  checkCurrentEpisode() {
    this.currentEpisode = this.playerService.getCurrentEpisode();
    this.hasCurrentEpisode = this.currentEpisode !== null;
    this.isPlaying = this.playerService.getState() === 'playing';
    
    if (this.currentEpisode) {
      const position = this.playerService.getCurrentPosition();
      const duration = this.playerService.getDuration();
      this.playProgress = duration > 0 ? (position / duration) * 100 : 0;
      
      // 更新播放时间
      this.currentPlayTime = position;
      this.totalDuration = duration;
      
      // 更新跑马灯文本，使用菱形符号分隔，确保可见性
      this.marqueeText = `${this.currentEpisode.title}     ◆     `;
    }
    
    // 更新睡眠定时器剩余时间
    this.sleepTimerRemaining = this.playerService.getSleepTimerRemaining();
  }

  /**
   * 打开播放页面
   */
  openPlayerPage() {
    const currentEpisode = this.playerService.getCurrentEpisode();
    if (currentEpisode) {
      const params = new RouteParams();
      params.episodeId = currentEpisode.id;
      UIUtils.pushUrl('pages/PlayerPage', params);
    }
  }

  /**
   * 播放下一个单集
   */
  async playNextEpisode() {
    try {
      // 如果队列为空，提示用户
      if (this.queueEpisodes.length === 0) {
        UIUtils.showToast(new ToastOptions('队列为空，请添加单集到队列', 2000));
        return;
      }

      // 获取队列的第一个单集
      const nextEpisode = this.queueEpisodes[0];
      console.info(`[MainPage] Playing next episode: ${nextEpisode.title}`);
      
      // 播放下一个
      await this.playerService.playEpisode(nextEpisode);
      
      // 更新 mini 播放器状态
      this.checkCurrentEpisode();
      
      // 从队列中移除
      await this.removeFromQueue(nextEpisode);
      
      UIUtils.showToast(new ToastOptions(`正在播放：${nextEpisode.title}`, 2000));
    } catch (error) {
      console.error('[MainPage] Failed to play next episode:', error);
      UIUtils.showToast(new ToastOptions('播放失败', 2000));
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      this.buildHeader();

      // Tab页签
      Tabs({ index: this.currentTabIndex }) {
        TabContent() {
          this.buildSubscriptionTab();
        }.tabBar('订阅')

        TabContent() {
          this.buildEpisodesTab();
        }.tabBar('单集')

        TabContent() {
          this.buildQueueTab();
        }.tabBar('队列')

        TabContent() {
          this.buildDownloadsTab();
        }.tabBar('下载')
      }
      .barMode(BarMode.Fixed)
      .barHeight(56)
      .onChange((index: number) => {
        this.currentTabIndex = index;
        // 切换到订阅 tab 时启动订阅刷新定时器
        if (index === 0) {
          this.loadSubscriptions();
          this.startSubscriptionUpdateTimer();
        } else {
          this.stopSubscriptionUpdateTimer();
        }
        // 切换到下载 tab 时启动定时刷新
        if (index === 3) {
          this.loadDownloads();
          this.startDownloadUpdateTimer();
        } else {
          this.stopDownloadUpdateTimer();
        }
      })
      .layoutWeight(1)

      // 迷你播放器（固定在底部）
      if (this.hasCurrentEpisode && this.currentEpisode) {
        this.buildMiniPlayer();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  /**
   * 构建头部
   */
  @Builder
  buildHeader() {
    Row() {
      Text('AntennaPodHM')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Blank()

      // 搜索按钮
      Button() {
        Text('🔍')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        console.info('[MainPage] Search clicked');
        // 跳转到搜索页面
        UIUtils.pushUrl('pages/SearchPage');
      })

      // 设置按钮
      Button() {
        Text('⚙️')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        console.info('[MainPage] Settings clicked');
        // 跳转到设置页面
        UIUtils.pushUrl('pages/SettingsPage');
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.background_card'))
  }

  /**
   * 订阅页签
   */
  @Builder
  buildSubscriptionTab() {
    Column() {
      if (this.isLoading) {
        LoadingProgress()
          .width(50)
          .height(50)
          .margin({ top: 100 })
      } else if (this.podcasts.length === 0) {
        this.buildEmptyView('暂无订阅', '点击右上角添加播客');
      } else {
        List({ space: 12 }) {
          ForEach(this.podcasts, (podcast: Podcast) => {
            ListItem() {
              this.buildPodcastItem(podcast);
            }
          }, (podcast: Podcast) => podcast.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 单集页签
   */
  @Builder
  buildEpisodesTab() {
    Column() {
      // 搜索框
      Row() {
        Search({ placeholder: '搜索单集标题或描述', value: this.episodeSearchKeyword })
          .width('100%')
          .height(40)
          .backgroundColor($r('app.color.background_card'))
          .onChange((value: string) => {
            this.onEpisodeSearchChange(value);
          })
          .onSubmit(() => {
            this.onEpisodeSearchSubmit();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 搜索结果提示
      if (this.episodeSearchKeyword && this.searchTotal > 0) {
        Text(`找到 ${this.searchTotal} 个单集（匹配标题或简介）`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: 16, bottom: 8 })
      }

      if (this.isSearching) {
        LoadingProgress()
          .width(40)
          .height(40)
          .margin({ top: 50 })
      } else if (this.allEpisodes.length === 0 && !this.episodeSearchKeyword) {
        this.buildEmptyView('暂无单集', '订阅播客后将显示在这里');
      } else if (this.filteredEpisodes.length === 0 && this.episodeSearchKeyword) {
        this.buildEmptyView('未找到匹配的单集', '尝试使用其他关键词');
      } else {
        List({ space: 8 }) {
          ForEach(this.filteredEpisodes, (episode: Episode) => {
            ListItem() {
              this.buildEpisodeItemWithDate(episode);
            }
          }, (episode: Episode) => episode.id)

          // 加载更多按钮
          if ((this.episodesHasMore && !this.episodeSearchKeyword) || this.searchHasMore) {
            ListItem() {
              Row() {
                if (this.isLoadingMore) {
                  LoadingProgress()
                    .width(24)
                    .height(24)
                    .margin({ right: 8 })
                  Text('加载中...')
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                } else {
                  Button('加载更多')
                    .width('100%')
                    .height(44)
                    .fontSize(14)
                    .backgroundColor($r('app.color.primary'))
                    .fontColor($r('app.color.text_on_primary'))
                    .onClick(() => {
                      if (this.episodeSearchKeyword) {
                        console.info('[MainPage] Load more search results');
                        this.loadMoreSearchResults();
                      } else {
                        console.info('[MainPage] Load more episodes');
                        this.loadMoreEpisodes();
                      }
                    })
                }
              }
              .width('100%')
              .height(44)
              .justifyContent(FlexAlign.Center)
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 单集项（带日期）
   */
  @Builder
  buildEpisodeItemWithDate(episode: Episode) {
    Row() {
      // 封面图
      Image(episode.imageUrl)
        .width(56)
        .height(56)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.app_icon'))

      // 单集信息
      Column() {
        Text(episode.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text(episode.getFormattedPubDate())
            .fontSize(12)
            .fontColor($r('app.color.primary'))

          Text(` · ${episode.getFormattedDuration()}`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
    .onClick(() => {
      console.info(`[MainPage] Episode: ${episode.title}`);
      const params = new RouteParams();
      params.episodeId = episode.id;
      UIUtils.pushUrl('pages/EpisodeDetailPage', params);
    })
  }

  /**
   * 队列页签
   */
  @Builder
  buildQueueTab() {
    Column() {
      if (this.queueEpisodes.length === 0) {
        this.buildEmptyView('播放队列为空', '添加单集到队列');
      } else {
        // 队列操作栏
        Row() {
          Text(`待听 ${this.queueEpisodes.length} 集`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))

          Blank()

          Button('清空队列')
            .height(32)
            .fontSize(12)
            .backgroundColor($r('app.color.accent_red'))
            .fontColor($r('app.color.text_on_primary'))
            .onClick(async () => {
              console.info('[MainPage] Clear queue');
              await this.dbService.clearQueue();
              await this.loadQueue();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        List({ space: 8 }) {
          ForEach(this.queueEpisodes, (episode: Episode, index: number) => {
            ListItem() {
              this.buildQueueItem(episode, index);
            }
          }, (episode: Episode) => episode.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 下载页签
   */
  @Builder
  buildDownloadsTab() {
    Column() {
      // 下载中部分
      if (this.downloadingEpisodes.length > 0) {
        Text('下载中')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .padding({ left: 16, top: 12, bottom: 8 })
        
        List({ space: 8 }) {
          ForEach(this.downloadingEpisodes, (episode: Episode) => {
            ListItem() {
              Column() {
                Row() {
                  Text(episode.title)
                    .fontSize(14)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(`${episode.downloadProgress}%`)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')

                Progress({ value: episode.downloadProgress, total: 100, type: ProgressType.Linear })
                  .width('100%')
                  .margin({ top: 8 })

                Row() {
                  // 暂停/继续按钮
                  Button(DownloadService.getInstance().isDownloadPaused(episode.id) ? '继续' : '暂停')
                    .height(28)
                    .fontSize(12)
                    .backgroundColor(DownloadService.getInstance().isDownloadPaused(episode.id) ? $r('app.color.accent_green') : $r('app.color.accent_orange'))
                    .fontColor($r('app.color.text_on_primary'))
                    .onClick(async () => {
                      const downloadService = DownloadService.getInstance();
                      if (downloadService.isDownloadPaused(episode.id)) {
                        await downloadService.resumeDownload(episode.id);
                      } else {
                        await downloadService.pauseDownload(episode.id);
                      }
                      this.loadDownloads();
                    })

                  // 取消按钮
                  Button('取消')
                    .height(28)
                    .fontSize(12)
                    .backgroundColor($r('app.color.accent_red'))
                    .fontColor($r('app.color.text_on_primary'))
                    .margin({ left: 8 })
                    .onClick(async () => {
                      await DownloadService.getInstance().cancelDownload(episode.id);
                      this.loadDownloads();
                    })
                }
                .width('100%')
                .margin({ top: 8 })
                .justifyContent(FlexAlign.End)
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.background_card'))
              .borderRadius(8)
            }
          }, (episode: Episode) => `${episode.id}_${episode.downloadProgress}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }

      // 已下载部分
      if (this.downloadedEpisodes.length > 0) {
        Row() {
          Text('已下载')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)

          if (this.isDownloadEditMode) {
            Text(this.selectedDownloadIds.size === this.downloadedEpisodes.length ? '取消全选' : '全选')
              .fontSize(14)
              .fontColor($r('app.color.primary'))
              .onClick(() => {
                if (this.selectedDownloadIds.size === this.downloadedEpisodes.length) {
                  this.selectedDownloadIds = new Set();
                } else {
                  this.selectedDownloadIds = new Set(this.downloadedEpisodes.map(e => e.id));
                }
              })

            Text('完成')
              .fontSize(14)
              .fontColor($r('app.color.primary'))
              .margin({ left: 16 })
              .onClick(() => {
                this.isDownloadEditMode = false;
                this.selectedDownloadIds = new Set();
              })
          } else {
            Text('管理')
              .fontSize(14)
              .fontColor($r('app.color.primary'))
              .onClick(() => {
                this.isDownloadEditMode = true;
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        // 批量操作栏
        if (this.isDownloadEditMode && this.selectedDownloadIds.size > 0) {
          Row() {
            Text(`已选择 ${this.selectedDownloadIds.size} 项`)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)

            Button('+ 待听')
              .height(32)
              .fontSize(12)
              .backgroundColor($r('app.color.accent_green'))
              .fontColor($r('app.color.text_on_primary'))
              .onClick(async () => {
                for (const id of this.selectedDownloadIds) {
                  await this.dbService.addToQueue(id);
                }
                UIUtils.showToast(new ToastOptions(`已添加 ${this.selectedDownloadIds.size} 个单集到待听队列`, 2000));
                this.selectedDownloadIds = new Set();
                this.loadQueue();
              })

            Button('删除')
              .height(32)
              .fontSize(12)
              .backgroundColor($r('app.color.accent_red'))
              .fontColor($r('app.color.text_on_primary'))
              .margin({ left: 8 })
              .onClick(async () => {
                const downloadService = DownloadService.getInstance();
                for (const id of this.selectedDownloadIds) {
                  const episode = this.downloadedEpisodes.find(e => e.id === id);
                  if (episode) {
                    await downloadService.deleteDownloadedFile(episode);
                  }
                }
                UIUtils.showToast(new ToastOptions(`已删除 ${this.selectedDownloadIds.size} 个下载`, 2000));
                this.selectedDownloadIds = new Set();
                this.loadDownloads();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
        }
        
        List({ space: 8 }) {
          ForEach(this.downloadedEpisodes, (episode: Episode) => {
            ListItem() {
              Column() {
                Row() {
                  // 编辑模式下显示选择框
                  if (this.isDownloadEditMode) {
                    Checkbox()
                      .select(this.selectedDownloadIds.has(episode.id))
                      .onChange((checked: boolean) => {
                        if (checked) {
                          this.selectedDownloadIds.add(episode.id);
                        } else {
                          this.selectedDownloadIds.delete(episode.id);
                        }
                        // 触发 UI 更新
                        this.selectedDownloadIds = new Set(this.selectedDownloadIds);
                      })
                      .margin({ right: 12 })
                  }

                  Column() {
                    Text(episode.title)
                      .fontSize(14)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(episode.getFormattedFileSize())
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')

                // 非编辑模式下显示操作按钮
                if (!this.isDownloadEditMode) {
                  Row() {
                    Button('▶ 播放')
                      .height(32)
                      .fontSize(12)
                      .backgroundColor($r('app.color.primary'))
                      .fontColor($r('app.color.text_on_primary'))
                      .onClick(async () => {
                        console.info(`[MainPage] Play: ${episode.title}`);
                        await this.playerService.playEpisode(episode);
                        this.checkCurrentEpisode();
                      })

                    Button('+ 待听')
                      .height(32)
                      .fontSize(12)
                      .margin({ left: 8 })
                      .backgroundColor($r('app.color.accent_green'))
                      .fontColor($r('app.color.text_on_primary'))
                      .onClick(() => {
                        console.info(`[MainPage] Add to queue: ${episode.title}`);
                        this.addToQueue(episode);
                      })

                    Blank()

                    Button('删除')
                      .height(32)
                      .fontSize(12)
                      .backgroundColor($r('app.color.accent_red'))
                      .fontColor($r('app.color.text_on_primary'))
                      .onClick(() => {
                        console.info(`[MainPage] Delete: ${episode.title}`);
                        DownloadService.getInstance().deleteDownloadedFile(episode);
                        this.loadDownloads();
                      })
                  }
                  .width('100%')
                  .margin({ top: 8 })
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.background_card'))
              .borderRadius(8)
            }
          }, (episode: Episode) => episode.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }

      // 空状态
      if (this.downloadingEpisodes.length === 0 && this.downloadedEpisodes.length === 0) {
        this.buildEmptyView('暂无下载', '下载单集以便离线收听');
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 播客项
   */
  @Builder
  buildPodcastItem(podcast: Podcast) {
    Row() {
      // 播客封面
      Image(podcast.imageUrl)
        .width(80)
        .height(80)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.app_icon'))

      // 播客信息
      Column() {
        Text(podcast.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(podcast.author)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })

        Text(`${podcast.episodeCount} 集`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
    .onClick(() => {
      console.info(`[MainPage] Podcast: ${podcast.title}`);
      // 跳转到播客详情页
      const params = new RouteParams();
      params.podcastId = podcast.id;
      UIUtils.pushUrl('pages/PodcastDetailPage', params);
    })
  }

  /**
   * 单集项
   */
  @Builder
  buildEpisodeItem(episode: Episode) {
    Column() {
      Row() {
        // 封面图
        Image(episode.imageUrl)
          .width(60)
          .height(60)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.app_icon'))

        // 单集信息
        Column() {
          Text(episode.title)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            Text(episode.getFormattedDuration())
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))

            if (episode.downloadStatus === 2) {
              Text(' · 已下载')
                .fontSize(12)
                .fontColor($r('app.color.accent_green'))
            }
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .width('100%')

      // 操作按钮
      Row() {
        Button('▶ 播放')
          .height(28)
          .fontSize(11)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.text_on_primary'))
          .onClick(async () => {
            console.info(`[MainPage] Play: ${episode.title}`);
            await this.playerService.playEpisode(episode);
            this.checkCurrentEpisode();
          })

        Button('+ 待听')
          .height(28)
          .fontSize(11)
          .margin({ left: 8 })
          .backgroundColor($r('app.color.accent_green'))
          .fontColor($r('app.color.text_on_primary'))
          .onClick(() => {
            console.info(`[MainPage] Add to queue: ${episode.title}`);
            this.addToQueue(episode);
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
  }

  /**
   * 队列项
   */
  @Builder
  buildQueueItem(episode: Episode, index: number) {
    Row() {
      // 序号
      Text(`${index + 1}`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary'))
        .width(28)
        .textAlign(TextAlign.Center)

      // 封面图
      Image(episode.imageUrl)
        .width(46)
        .height(46)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.app_icon'))
        .margin({ left: 4 })

      // 单集信息
      Column() {
        Text(episode.title)
          .fontSize(13)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(episode.getFormattedDuration())
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 8, right: 8 })

      // 操作按钮
      Row() {
        // 播放按钮
        Button() {
          Text('▶')
            .fontSize(14)
            .fontColor($r('app.color.text_on_primary'))
        }
        .width(36)
        .height(36)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(18)
        .flexShrink(0)
        .onClick(() => {
          console.info(`[MainPage] Queue play: ${episode.title}`);
          this.playerService.playEpisode(episode);
        })

        // 删除按钮
        Button() {
          Text('🗑')
            .fontSize(16)
            .fontColor($r('app.color.delete_button_text'))  // 深红色文字
        }
        .width(36)
        .height(36)
        .backgroundColor($r('app.color.delete_button_bg'))  // 淡红色背景
        .border({ width: 1.5, color: $r('app.color.delete_button_text'), radius: 18 })  // 深红色边框
        .margin({ left: 8 })
        .flexShrink(0)
        .onClick(() => {
          console.info(`[MainPage] Queue remove: ${episode.title}`);
          this.removeFromQueue(episode);
        })
      }
    }
    .width('100%')
    .padding(8)
    .backgroundColor($r('app.color.background_card'))
    .borderRadius(8)
  }

  /**
   * 构建迷你播放器 - QQ音乐风格
   */
  @Builder
  buildMiniPlayer() {
    Column() {
      // 进度条
      Row() {
        Progress({ value: this.playProgress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color($r('app.color.primary'))
          .backgroundColor($r('app.color.progress_track'))
      }
      .width('100%')

      // 播放器内容
      Row() {
        // 封面图（带旋转效果的设计）
        Stack() {
          // 圆形背景
          Circle()
            .width(50)
            .height(50)
            .fill($r('app.color.primary'))
          
          // 封面图
          Image(this.currentEpisode?.imageUrl || '')
            .width(44)
            .height(44)
            .borderRadius(22)
            .objectFit(ImageFit.Cover)
        }
        .margin({ left: 12 })
        .onClick(() => {
          console.info('[MainPage] Mini player cover tapped');
          this.openPlayerPage();
        })

        // 标题和描述
        Column() {
          Marquee({
            start: true,
            step: 4,
            loop: -1,
            fromStart: true,
            src: this.marqueeText || ' '
          })
            .width('100%')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_on_primary'))
            .allowScale(false)

          Row() {
            // 播放时间
            Text(`${this.formatTime(this.currentPlayTime)} / ${this.formatTime(this.totalDuration)}`)
              .fontSize(11)
              .fontColor($r('app.color.text_on_primary_secondary'))
            
            // 睡眠定时器倒计时
            if (this.sleepTimerRemaining > 0) {
              Text(' · ')
                .fontSize(11)
                .fontColor($r('app.color.text_on_primary_secondary'))
              Text(`⏰ ${this.formatSleepTimer(this.sleepTimerRemaining)}`)
                .fontSize(11)
                .fontColor($r('app.color.primary'))
                .fontWeight(FontWeight.Medium)
            }
          }
          .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12, right: 12 })
        .onClick(() => {
          console.info('[MainPage] Mini player tapped');
          this.openPlayerPage();
        })

        // 播放/暂停按钮
        Button() {
          Text(this.isPlaying ? '❚❚' : '▶')
            .fontSize(18)
            .fontColor($r('app.color.text_on_primary'))
        }
        .width(40)
        .height(40)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(20)
        .onClick(() => {
          console.info(`[MainPage] Mini player toggle: ${this.isPlaying}`);
          if (this.isPlaying) {
            this.playerService.pause();
          } else {
            this.playerService.resume();
          }
          this.isPlaying = !this.isPlaying;
        })

        // 下一首按钮
        Button() {
          Text('⏭')
            .fontSize(18)
            .fontColor($r('app.color.text_on_primary'))
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .margin({ right: 8 })
        .onClick(() => {
          console.info('[MainPage] Mini player next');
          this.playNextEpisode();
        })
      }
      .width('100%')
      .height(64)
      .alignItems(VerticalAlign.Center)
    }
    .width('94%')
    .backgroundColor($r('app.color.mini_player_background'))
    .borderRadius(12)
    .margin({ bottom: 16 })
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.2)',
      offsetX: 0,
      offsetY: 4
    })
    .clip(true)
  }

  /**
   * 格式化睡眠定时器剩余时间
   */
  formatSleepTimer(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    if (mins > 0) {
      return `${mins}:${secs.toString().padStart(2, '0')}`;
    } else {
      return `${secs}s`;
    }
  }

  /**
   * 格式化播放时间
   */
  formatTime(seconds: number): string {
    const totalSeconds = Math.floor(seconds);
    const mins = Math.floor(totalSeconds / 60);
    const hours = Math.floor(mins / 60);
    const remainingSeconds = totalSeconds % 60;

    if (hours > 0) {
      return `${hours}:${(mins % 60).toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
    } else {
      return `${mins}:${remainingSeconds.toString().padStart(2, '0')}`;
    }
  }

  /**
   * 空状态视图
   */
  @Builder
  buildEmptyView(title: string, message: string) {
    Column() {
      Text('🎧')
        .fontSize(80)
        .opacity(0.3)

      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 20 })

      Text(message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
