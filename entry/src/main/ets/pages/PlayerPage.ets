import { router, promptAction } from '@kit.ArkUI';
import { Episode } from '../model/Episode';
import { PlayerService, PlayerState } from '../service/PlayerService';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../common/Constants';
import { DatabaseService } from '../service/DatabaseService';

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
        console.info('======>>> Click: Back button (Player)');
        router.back();
      })

      Text('正在播放')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ left: 12 })

      Blank()
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  buildEpisodeInfo() {
    Column() {
      Image(this.currentEpisode?.imageUrl)
        .width(240)
        .height(240)
        .borderRadius(12)
        .objectFit(ImageFit.Cover)
        .margin({ top: 40 })

      Text(this.currentEpisode?.title || '')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 24 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.currentEpisode?.description || '')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary_light'))
        .margin({ top: 12 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
  }

  @Builder
  buildProgressBar() {
    Column() {
      Slider({
        value: this.currentPosition,
        min: 0,
        max: this.duration,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .onChange((value: number) => {
          this.playerService.seek(value);
        })

      Row() {
        Text(this.formatTime(this.currentPosition))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary_light'))

        Blank()

        Text(this.formatTime(this.duration))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary_light'))
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 40 })
  }

  @Builder
  buildPlaybackControls() {
    Row() {
      // 后逘15秒
      Button() {
        Text('⏪')
          .fontSize(28)
      }
      .width(60)
      .height(60)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        console.info('======>>> Click: Rewind 15s');
        const newPosition = Math.max(0, this.currentPosition - 15);
        this.playerService.seek(newPosition);
      })
  
      Blank()
  
      // 播放/暂停按钮
      Button() {
        Text(this.playerState === PlayerState.PLAYING ? '⏸' : '▶')
          .fontSize(36)
          .fontColor(Color.White)
      }
      .width(80)
      .height(80)
      .backgroundColor($r('app.color.primary'))
      .borderRadius(40)
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
      Button() {
        Text('⏩')
          .fontSize(28)
      }
      .width(60)
      .height(60)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        console.info('======>>> Click: Forward 30s');
        const newPosition = Math.min(this.duration, this.currentPosition + 30);
        this.playerService.seek(newPosition);
      })
    }
    .width('100%')
    .padding({ left: 40, right: 40, top: 40 })
  }

  @Builder
  buildFunctionButtons() {
    Row() {
      // 播放速度
      Button() {
        Text(`${this.playbackSpeed}x`)
          .fontSize(14)
          .fontColor('#666666')
      }
      .height(36)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#E8F4FF')
      .borderRadius(18)
      .onClick(() => {
        console.info('======>>> Click: Playback speed selector');
        this.showSpeedSelectorMenu();
      })

      Blank()

      // 睡眠定时器（显示倒计时）
      Column() {
        Button() {
          Row() {
            Text('⏰')
              .fontSize(20)
            if (this.sleepTimerRemaining > 0) {
              Text(this.formatSleepTimer(this.sleepTimerRemaining))
                .fontSize(12)
                .fontColor('#FF6B9D')
                .fontWeight(FontWeight.Medium)
                .margin({ left: 4 })
            }
          }
        }
        .height(36)
        .padding({ left: 12, right: 12 })
        .backgroundColor(this.sleepTimerRemaining > 0 ? '#FFF0F5' : Color.Transparent)
        .borderRadius(18)
        .onClick(() => {
          console.info('======>>> Click: Sleep timer');
          this.showSleepTimerMenu();
        })
      }

      Blank()

      // 添加到队列
      Button() {
        Text('☰')
          .fontSize(20)
      }
      .backgroundColor(Color.Transparent)
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
    .padding({ left: 40, right: 40, top: 40 })
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
        { text: '0.5x', color: '#000000' },
        { text: '0.75x', color: '#000000' },
        { text: '1.0x', color: '#000000' },
        { text: '1.25x', color: '#000000' },
        { text: '1.5x', color: '#000000' },
        { text: '2.0x', color: '#000000' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const speeds: number[] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
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
}
