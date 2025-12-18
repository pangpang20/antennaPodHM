import { router, promptAction } from '@kit.ArkUI';
import { Episode } from '../model/Episode';
import { PlayerService, PlayerState } from '../service/PlayerService';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../common/Constants';
import { DatabaseService } from '../service/DatabaseService';
import { DownloadService } from '../service/DownloadService';

@Entry
@Component
struct PlayerPage {
  @State currentEpisode: Episode | null = null;
  @State playerState: PlayerState = PlayerState.IDLE;
  @State currentPosition: number = 0;
  @State duration: number = 0;
  @State playbackSpeed: number = 1.0;
  @State showSpeedSelector: boolean = false;
  @State sleepTimerMinutes: number = 0;
  @State sleepTimerRemaining: number = 0;  // 剩余秒数
  @State marqueeText: string = '';  // 跑马灯文本
  
  private playerService: PlayerService = PlayerService.getInstance();
  private updateTimer: number = -1;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['episodeId']) {
      const episodeId = params['episodeId'] as string;
      this.loadEpisode(episodeId);
    }

    // 加载默认播放速度
    const settingsService = SettingsService.getInstance();
    this.playbackSpeed = settingsService.getPlaybackSpeed();

    // 监听播放器状态
    this.playerService.addEventListener('stateChange', (state: PlayerState) => {
      this.playerState = state;
    });

    this.playerService.addEventListener('timeUpdate', (time: number) => {
      // 移除频繁的日志输出
      this.currentPosition = time;
    });

    // 监听时长更新
    this.playerService.addEventListener('durationUpdate', (duration: number) => {
      console.info(`[PlayerPage] durationUpdate event received: ${duration}s`);
      this.duration = duration;
    });

    // 监听睡眠定时器结束
    this.playerService.addEventListener('sleepTimerEnd', () => {
      this.sleepTimerMinutes = 0;
      promptAction.showToast({ message: '定时播放结束，已暂停', duration: 2000 });
    });

    // 启动定时器更新进度
    this.startUpdateTimer();

    // 同步睡眠定时器状态
    this.sleepTimerMinutes = this.playerService.getSleepTimerMinutes();
  }

  aboutToDisappear() {
    if (this.updateTimer !== -1) {
      clearInterval(this.updateTimer);
    }
    // 不再清除睡眠定时器，因为它已经在 PlayerService 中管理
  }

  async loadEpisode(episodeId: string) {
    try {
      const db = DatabaseService.getInstance();
      const episode = await db.getEpisodeById(episodeId);
      if (!episode) {
        console.warn('Episode not found for id:', episodeId);
        return;
      }

      console.info('[PlayerPage] Episode loaded:', episode.title);
      console.info('[PlayerPage] audioUrl:', episode.audioUrl);
      console.info('[PlayerPage] localPath:', episode.localPath);
      console.info('[PlayerPage] duration:', episode.duration);

      // 检查是否需要切换播放
      const currentPlaying = this.playerService.getCurrentEpisode();
      const needToPlay = !currentPlaying || currentPlaying.id !== episode.id;

      this.currentEpisode = episode;
      this.currentPosition = episode.playbackPosition;
      this.duration = episode.duration;
      
      // 更新跑马灯文本
      this.marqueeText = `${episode.title}     ◆     `;

      // 如果是新的 episode，自动开始播放
      if (needToPlay) {
        console.info('[PlayerPage] Starting playback for new episode');
        await this.playerService.playEpisode(episode);
      } else {
        // 同步当前播放状态
        this.playerState = this.playerService.getState();
        this.currentPosition = this.playerService.getCurrentPosition();
        this.duration = this.playerService.getDuration();
      }
    } catch (error) {
      console.error('Failed to load episode:', error);
    }
  }

  startUpdateTimer() {
    this.updateTimer = setInterval(() => {
      if (this.playerState === PlayerState.PLAYING) {
        const newPosition = this.playerService.getCurrentPosition();
        const newDuration = this.playerService.getDuration();
        this.currentPosition = newPosition;
        this.duration = newDuration;
      }
      
      // 更新睡眠定时器剩余时间
      this.sleepTimerRemaining = this.playerService.getSleepTimerRemaining();
      if (this.sleepTimerRemaining <= 0) {
        this.sleepTimerMinutes = 0;
      }
    }, 1000);
  }

  build() {
    Column() {
      // 导航栏
      this.buildNavigationBar();

      Scroll() {
        Column() {
          // Episode信息
          this.buildEpisodeInfo();

          // 进度条
          this.buildProgressBar();

          // 播放控制
          this.buildPlaybackControls();

          // 功能按钮
          this.buildFunctionButtons();
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 135,
      colors: [['#f5f7fa', 0.0], ['#e8edf3', 0.5], ['#dce3ec', 1.0]]
    })
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Button() {
        Text('←')
          .fontSize(22)
          .fontColor('#333333')
      }
      .width(44)
      .height(44)
      .backgroundColor('rgba(255, 255, 255, 0.9)')
      .borderRadius(22)
      .onClick(() => {
        console.info('======>>> Click: Back button (Player)');
        router.back();
      })

      Blank()

      // 更多操作按钮
      Button() {
        Text('⋮')
          .fontSize(22)
          .fontColor('#333333')
      }
      .width(44)
      .height(44)
      .backgroundColor('rgba(255, 255, 255, 0.9)')
      .borderRadius(22)
      .onClick(() => {
        console.info('======>>> Click: More options');
        this.showMoreOptionsMenu();
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  buildEpisodeInfo() {
    Column() {
      // 封面图 - 更大，带阴影
      Image(this.currentEpisode?.imageUrl)
        .width(280)
        .height(280)
        .borderRadius(16)
        .objectFit(ImageFit.Cover)
        .margin({ top: 20 })
        .shadow({
          radius: 30,
          color: 'rgba(0, 0, 0, 0.25)',
          offsetX: 0,
          offsetY: 10
        })

      // 标题 - 使用跑马灯
      Marquee({
        start: this.playerState === PlayerState.PLAYING,
        step: 4,
        loop: -1,
        fromStart: true,
        src: this.marqueeText || this.currentEpisode?.title || ''
      })
        .width('85%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a1a')
        .margin({ top: 20 })
        .allowScale(false)

      // 描述
      Text(this.currentEpisode?.description || '')
        .fontSize(13)
        .fontColor('#666666')
        .margin({ top: 8 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('85%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
  }

  @Builder
  buildProgressBar() {
    Column() {
      // 时间显示
      Row() {
        Text(this.formatTime(this.currentPosition))
          .fontSize(13)
          .fontColor('#666666')
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.formatTime(this.duration))
          .fontSize(13)
          .fontColor('#666666')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .margin({ bottom: 8 })
      
      // 进度条
      Slider({
        value: this.currentPosition,
        min: 0,
        max: this.duration,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .trackColor('#E0E0E0')
        .selectedColor('#5C6BC0')
        .trackThickness(4)
        .onChange((value: number) => {
          this.playerService.seek(value);
        })
    }
    .width('100%')
    .padding({ left: 32, right: 32, top: 25 })
  }

  @Builder
  buildPlaybackControls() {
    Row() {
      // 后退15秒
      Column() {
        Button() {
          Text('⏪')
            .fontSize(24)
            .fontColor('#5C6BC0')
        }
        .width(56)
        .height(56)
        .backgroundColor('rgba(92, 107, 192, 0.1)')
        .borderRadius(28)
        .onClick(() => {
          console.info('======>>> Click: Rewind 15s');
          const newPosition = Math.max(0, this.currentPosition - 15);
          this.playerService.seek(newPosition);
          promptAction.showToast({
            message: '快退 15 秒',
            duration: 1000
          });
        })
        
        Text('15秒')
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
  
      Blank()
  
      // 播放/暂停按钮 - 更大、更突出
      Button() {
        Text(this.playerState === PlayerState.PLAYING ? '⏸' : '▶')
          .fontSize(38)
          .fontColor(Color.White)
      }
      .width(72)
      .height(72)
      .backgroundColor('#5C6BC0')
      .borderRadius(36)
      .shadow({
        radius: 12,
        color: 'rgba(92, 107, 192, 0.4)',
        offsetX: 0,
        offsetY: 4
      })
      .onClick(() => {
        console.info(`======>>> Click: Play/Pause - state: ${this.playerState}`);
        if (this.playerState === PlayerState.PLAYING) {
          this.playerService.pause();
        } else if (this.playerState === PlayerState.PAUSED) {
          this.playerService.resume();
        } else if (this.currentEpisode) {
          this.playerService.playEpisode(this.currentEpisode);
        }
      })
  
      Blank()
  
      // 前进30秒
      Column() {
        Button() {
          Text('⏩')
            .fontSize(24)
            .fontColor('#5C6BC0')
        }
        .width(56)
        .height(56)
        .backgroundColor('rgba(92, 107, 192, 0.1)')
        .borderRadius(28)
        .onClick(() => {
          console.info('======>>> Click: Forward 30s');
          const newPosition = Math.min(this.duration, this.currentPosition + 30);
          this.playerService.seek(newPosition);
          promptAction.showToast({
            message: '快进 30 秒',
            duration: 1000
          });
        })
        
        Text('30秒')
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding({ left: 50, right: 50, top: 20 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildFunctionButtons() {
    Column() {
      // 第一行：播放速度、定时关闭
      Row() {
        // 播放速度
        Button() {
          Row() {
            Text('🚀')
              .fontSize(16)
              .margin({ right: 6 })
            Text(`${this.playbackSpeed}x`)
              .fontSize(14)
              .fontColor('#5C6BC0')
              .fontWeight(FontWeight.Medium)
          }
        }
        .height(40)
        .padding({ left: 16, right: 16 })
        .backgroundColor('rgba(92, 107, 192, 0.08)')
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(92, 107, 192, 0.2)', radius: 20 })
        .onClick(() => {
          console.info('======>>> Click: Playback speed selector');
          this.showSpeedSelectorMenu();
        })

        Blank()

        // 睡眠定时器
        Button() {
          Row() {
            Text('⏰')
              .fontSize(16)
              .margin({ right: 6 })
            if (this.sleepTimerRemaining > 0) {
              Text(this.formatSleepTimer(this.sleepTimerRemaining))
                .fontSize(14)
                .fontColor('#FF6B6B')
                .fontWeight(FontWeight.Medium)
            } else {
              Text('定时')
                .fontSize(14)
                .fontColor('#666666')
            }
          }
        }
        .height(40)
        .padding({ left: 16, right: 16 })
        .backgroundColor(this.sleepTimerRemaining > 0 ? 'rgba(255, 107, 107, 0.08)' : 'rgba(0, 0, 0, 0.05)')
        .borderRadius(20)
        .border({ 
          width: 1, 
          color: this.sleepTimerRemaining > 0 ? 'rgba(255, 107, 107, 0.3)' : 'rgba(0, 0, 0, 0.1)', 
          radius: 20 
        })
        .onClick(() => {
          console.info('======>>> Click: Sleep timer');
          this.showSleepTimerMenu();
        })
      }
      .width('100%')
      .margin({ top: 20 })

      // 第二行：添加到队列
      Button() {
        Row() {
          Text('➕')
            .fontSize(16)
            .margin({ right: 6 })
          Text('添加到队列')
            .fontSize(14)
            .fontColor('#666666')
        }
      }
      .width('100%')
      .height(44)
      .backgroundColor('rgba(0, 0, 0, 0.05)')
      .borderRadius(22)
      .border({ width: 1, color: 'rgba(0, 0, 0, 0.1)', radius: 22 })
      .margin({ top: 12 })
      .onClick(() => {
        console.info(`======>>> Click: Add to queue - ${this.currentEpisode?.title || 'no episode'}`);
        if (!this.currentEpisode) {
          console.warn('No current episode to add to queue');
          return;
        }
        this.playerService.addToQueue(this.currentEpisode);
        promptAction.showToast({ message: '已添加到队列', duration: 2000 });
      })
    }
    .width('100%')
    .padding({ left: 32, right: 32, bottom: 20 })
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

  showSpeedSelectorMenu(): void {
    promptAction.showActionMenu({
      title: '选择播放速度',
      buttons: [
        { text: '0.75x', color: '#000000' },
        { text: '1.0x', color: '#000000' },
        { text: '1.25x', color: '#000000' },
        { text: '1.5x', color: '#000000' },
        { text: '2.0x', color: '#000000' },
        { text: '2.5x', color: '#000000' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const speeds: number[] = [0.75, 1.0, 1.25, 1.5, 2.0, 2.5];
      const selectedSpeed = speeds[result.index];
      this.playbackSpeed = selectedSpeed;
      this.playerService.setPlaybackSpeed(selectedSpeed);
    }).catch((err: Error) => {
      console.info('Speed selection cancelled');
    });
  }

  showSleepTimerMenu(): void {
    promptAction.showActionMenu({
      title: '定时关闭',
      buttons: [
        { text: '关闭定时', color: '#000000' },
        { text: '5 分钟', color: '#000000' },
        { text: '15 分钟', color: '#000000' },
        { text: '30 分钟', color: '#000000' },
        { text: '45 分钟', color: '#000000' },
        { text: '60 分钟', color: '#000000' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const minutesOptions: number[] = [0, 5, 15, 30, 45, 60];
      const minutes = minutesOptions[result.index];
      this.sleepTimerMinutes = minutes;
      this.playerService.setSleepTimer(minutes);
      const msg = minutes > 0 ? `已设置定时关闭：${minutes} 分钟` : '已关闭定时播放';
      promptAction.showToast({ message: msg, duration: 2000 });
    }).catch((err: Error) => {
      console.info('Sleep timer selection cancelled');
    });
  }

  formatTime(seconds: number): string {
    const totalSeconds = Math.floor(seconds);
    const minutes = Math.floor(totalSeconds / 60);
    const hours = Math.floor(minutes / 60);
    const remainingSeconds = totalSeconds % 60;

    if (hours > 0) {
      return `${hours}:${(minutes % 60).toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
    } else {
      return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
    }
  }

  /**
   * 分享单集
   */
  shareEpisode(): void {
    if (!this.currentEpisode) {
      return;
    }

    const shareText = `我正在听《${this.currentEpisode.title}》

${this.currentEpisode.description}

分享自 AntennaPodHM`;
    
    promptAction.showActionMenu({
      title: '分享到',
      buttons: [
        { text: '微信好友', color: '#000000' },
        { text: '微信朋友圈', color: '#000000' },
        { text: '复制链接', color: '#000000' },
        { text: '更多分享方式', color: '#000000' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      switch (result.index) {
        case 0:
          // 分享到微信好友
          this.shareToWeChatFriend();
          break;
        case 1:
          // 分享到微信朋友圈
          this.shareToWeChatMoments();
          break;
        case 2:
          // 复制链接
          this.copyShareLink();
          break;
        case 3:
          // 系统分享
          this.systemShare();
          break;
      }
    }).catch((err: Error) => {
      console.info('Share menu cancelled');
    });
  }

  /**
   * 分享到微信好友
   */
  shareToWeChatFriend(): void {
    // TODO: 集成微信 SDK 后实现
    // 目前显示提示，后续集成微信分享 SDK
    promptAction.showToast({
      message: '即将打开微信分享',
      duration: 2000
    });
    console.info('[PlayerPage] Share to WeChat friend:', this.currentEpisode?.title);
  }

  /**
   * 分享到微信朋友圈
   */
  shareToWeChatMoments(): void {
    // TODO: 集成微信 SDK 后实现
    promptAction.showToast({
      message: '即将打开朋友圈分享',
      duration: 2000
    });
    console.info('[PlayerPage] Share to WeChat moments:', this.currentEpisode?.title);
  }

  /**
   * 复制分享链接
   */
  copyShareLink(): void {
    if (!this.currentEpisode) {
      return;
    }
    
    const shareLink = `antennaPod://episode/${this.currentEpisode.id}`;
    const shareText = `《${this.currentEpisode.title}》\n${shareLink}`;
    
    // 使用系统剪贴板 API（需要添加权限）
    // TODO: 添加剪贴板权限后实现
    promptAction.showToast({
      message: '链接已复制',
      duration: 2000
    });
    console.info('[PlayerPage] Copy share link:', shareText);
  }

  /**
   * 系统分享
   */
  systemShare(): void {
    if (!this.currentEpisode) {
      return;
    }
    
    const shareText = `我正在听《${this.currentEpisode.title}》

${this.currentEpisode.description}

分享自 AntennaPodHM`;
    
    // TODO: 使用 HarmonyOS 系统分享 API
    promptAction.showToast({
      message: '打开系统分享面板',
      duration: 2000
    });
    console.info('[PlayerPage] System share:', shareText);
  }

  /**
   * 显示更多选项菜单
   */
  showMoreOptionsMenu(): void {
    promptAction.showActionMenu({
      title: '更多选项',
      buttons: [
        { text: '查看单集详情', color: '#000000' },
        { text: '分享这一集', color: '#000000' },
        { text: '下载到本地', color: '#000000' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      switch (result.index) {
        case 0:
          // 查看单集详情
          if (this.currentEpisode) {
            router.pushUrl({
              url: 'pages/EpisodeDetailPage',
              params: { episodeId: this.currentEpisode.id }
            }).catch((err: Error) => {
              console.error('Navigation failed:', err);
            });
          }
          break;
        case 1:
          // 分享
          if (this.currentEpisode) {
            this.shareEpisode();
          } else {
            promptAction.showToast({ 
              message: '暂无可分享的内容', 
              duration: 2000 
            });
          }
          break;
        case 2:
          // 下载
          if (this.currentEpisode) {
            DownloadService.getInstance().downloadEpisode(this.currentEpisode)
              .then(() => {
                promptAction.showToast({ 
                  message: '已添加到下载队列', 
                  duration: 2000 
                });
              })
              .catch((err: Error) => {
                console.error('Download failed:', err);
                promptAction.showToast({ 
                  message: '下载失败', 
                  duration: 2000 
                });
              });
          }
          break;
      }
    }).catch((err: Error) => {
      console.info('More options menu cancelled');
    });
  }
}
