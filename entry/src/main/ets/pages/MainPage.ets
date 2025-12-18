import { Podcast } from '../model/Podcast';
import { Episode, DownloadStatus } from '../model/Episode';
import { PodcastService } from '../service/PodcastService';
import { DatabaseService } from '../service/DatabaseService';
import { PlayerService } from '../service/PlayerService';
import { DownloadService } from '../service/DownloadService';
import { router } from '@kit.ArkUI';

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
  @State sleepTimerRemaining: number = 0;  // 睡眠定时器剩余秒数
  @State downloadingEpisodes: Episode[] = [];
  @State downloadedEpisodes: Episode[] = [];
  private playerService: PlayerService = PlayerService.getInstance();
  private downloadUpdateTimer: number = -1;
  private playUpdateTimer: number = -1;

  aboutToAppear() {
    this.loadSubscriptions();
    this.checkCurrentEpisode();
    this.loadDownloads();
    this.startPlayUpdateTimer();
    
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
    // 页面通过路由返回时刷新订阅列表
    this.loadSubscriptions();
    this.checkCurrentEpisode();
    this.loadDownloads();
  }

  /**
   * 加载下载列表
   */
  async loadDownloads() {
    try {
      const db = DatabaseService.getInstance();
      const allEpisodes = await db.getAllEpisodes();
      
      this.downloadingEpisodes = allEpisodes.filter(e => {
        const status = Number(e.downloadStatus);
        return status === DownloadStatus.DOWNLOADING;
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
      router.pushUrl({
        url: 'pages/PlayerPage',
        params: { episodeId: currentEpisode.id }
      }).catch((err: Error) => {
        console.error('Navigation failed:', err);
      });
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
        // 切换到下载 tab 时启动定时刷新
        if (index === 3) {
          this.loadDownloads();
          this.startDownloadUpdateTimer();
        } else {
          this.stopDownloadUpdateTimer();
        }
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_light'))
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
        .fontColor($r('app.color.text_primary_light'))

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
        console.info('======>>> Click: Search button');
        // 跳转到搜索页面
        router.pushUrl({ url: 'pages/SearchPage' }).catch((err: Error) => {
          console.error('Navigation failed:', err);
        });
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
        console.info('======>>> Click: Settings button');
        // 跳转到设置页面
        router.pushUrl({ url: 'pages/SettingsPage' }).catch((err: Error) => {
          console.error('Navigation failed:', err);
        });
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
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

      // 正在播放迷你播放器
      if (this.hasCurrentEpisode && this.currentEpisode) {
        this.buildMiniPlayer();
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
      this.buildEmptyView('暂无单集', '订阅播客后将显示在这里');
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 队列页签
   */
  @Builder
  buildQueueTab() {
    Column() {
      this.buildEmptyView('播放队列为空', '添加单集到队列');
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
          }, (episode: Episode) => episode.id)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }

      // 已下载部分
      if (this.downloadedEpisodes.length > 0) {
        Text('已下载')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .padding({ left: 16, top: 12, bottom: 8 })
        
        List({ space: 8 }) {
          ForEach(this.downloadedEpisodes, (episode: Episode) => {
            ListItem() {
              Row() {
                Column() {
                  Text(episode.title)
                    .fontSize(14)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(episode.getFormattedFileSize())
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary_light'))
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Button('删除')
                  .height(32)
                  .fontSize(12)
                  .onClick(() => {
                    console.info(`======>>> Click: Delete downloaded - ${episode.title}`);
                    DownloadService.getInstance().deleteDownloadedFile(episode);
                    this.loadDownloads();
                  })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Color.White)
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
          .fontColor($r('app.color.text_secondary_light'))
          .margin({ top: 4 })

        Text(`${podcast.episodeCount} 集`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary_light'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .onClick(() => {
      console.info(`======>>> Click: Podcast item - ${podcast.title}`);
      // 跳转到播客详情页
      router.pushUrl({
        url: 'pages/PodcastDetailPage',
        params: { podcastId: podcast.id }
      }).catch((err: Error) => {
        console.error('Navigation failed:', err);
      });
    })
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
          .color('#FF6B9D')
          .backgroundColor('#E0E0E0')
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
            .fill('#1a1a2e')
          
          // 封面图
          Image(this.currentEpisode?.imageUrl || '')
            .width(44)
            .height(44)
            .borderRadius(22)
            .objectFit(ImageFit.Cover)
        }
        .margin({ left: 12 })

        // 标题和描述
        Column() {
          Text(this.currentEpisode?.title || '')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            Text('正在播放')
              .fontSize(11)
              .fontColor('#AAAAAA')
            
            // 睡眠定时器倒计时
            if (this.sleepTimerRemaining > 0) {
              Text(' · ')
                .fontSize(11)
                .fontColor('#AAAAAA')
              Text(`⏰ ${this.formatSleepTimer(this.sleepTimerRemaining)}`)
                .fontSize(11)
                .fontColor('#FF6B9D')
                .fontWeight(FontWeight.Medium)
            }
          }
          .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12, right: 12 })
        .onClick(() => {
          console.info('======>>> Click: Mini player content');
          this.openPlayerPage();
        })

        // 播放/暂停按钮
        Button() {
          Text(this.isPlaying ? '❚❚' : '▶')
            .fontSize(18)
            .fontColor('#FFFFFF')
        }
        .width(40)
        .height(40)
        .backgroundColor('#FF6B9D')
        .borderRadius(20)
        .onClick(() => {
          console.info(`======>>> Click: Mini player play/pause - isPlaying: ${this.isPlaying}`);
          if (this.isPlaying) {
            this.playerService.pause();
          } else {
            this.playerService.resume();
          }
          this.isPlaying = !this.isPlaying;
        })

        // 下一首/列表按钮
        Button() {
          Text('☰')
            .fontSize(18)
            .fontColor('#FFFFFF')
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .margin({ right: 8 })
        .onClick(() => {
          console.info('======>>> Click: Mini player open full player');
          this.openPlayerPage();
        })
      }
      .width('100%')
      .height(64)
      .alignItems(VerticalAlign.Center)
    }
    .width('94%')
    .backgroundColor('#1a1a2e')
    .borderRadius(12)
    .margin({ bottom: 16 })
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.3)',
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
        .fontColor($r('app.color.text_secondary_light'))
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
