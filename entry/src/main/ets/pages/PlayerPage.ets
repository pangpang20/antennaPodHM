import { router } from '@kit.ArkUI';
import { Episode } from '../model/Episode';
import { PlayerService, PlayerState } from '../service/PlayerService';
import { Constants } from '../common/Constants';

@Entry
@Component
struct PlayerPage {
  @State currentEpisode: Episode | null = null;
  @State playerState: PlayerState = PlayerState.IDLE;
  @State currentPosition: number = 0;
  @State duration: number = 0;
  @State playbackSpeed: number = 1.0;
  @State showSpeedSelector: boolean = false;
  
  private playerService: PlayerService = PlayerService.getInstance();
  private updateTimer: number = -1;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['episodeId']) {
      const episodeId = params['episodeId'] as string;
      this.loadEpisode(episodeId);
    }

    // 监听播放器状态
    this.playerService.addEventListener('stateChange', (state: PlayerState) => {
      this.playerState = state;
    });

    this.playerService.addEventListener('timeUpdate', (time: number) => {
      this.currentPosition = time;
    });

    // 启动定时器更新进度
    this.startUpdateTimer();
  }

  aboutToDisappear() {
    if (this.updateTimer !== -1) {
      clearInterval(this.updateTimer);
    }
  }

  async loadEpisode(episodeId: string) {
    // 加载Episode数据
    // 这里简化处理，实际需要从数据库加载
  }

  startUpdateTimer() {
    this.updateTimer = setInterval(() => {
      if (this.playerState === PlayerState.PLAYING) {
        this.currentPosition = this.playerService.getCurrentPosition();
        this.duration = this.playerService.getDuration();
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
      // 后退15秒
      Button() {
        Text('⏪')
          .fontSize(28)
      }
      .width(60)
      .height(60)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        const newPosition = Math.max(0, this.currentPosition - 15000);
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
        const newPosition = Math.min(this.duration, this.currentPosition + 30000);
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
      }
      .onClick(() => {
        this.showSpeedSelector = true;
      })

      Blank()

      // 睡眠定时器
      Button() {
        Text('⏰')
          .fontSize(20)
      }
      .backgroundColor(Color.Transparent)

      Blank()

      // 添加到队列
      Button() {
        Text('☰')
          .fontSize(20)
      }
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .padding({ left: 40, right: 40, top: 40 })
  }

  formatTime(milliseconds: number): string {
    const seconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);

    if (hours > 0) {
      return `${hours}:${(minutes % 60).toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`;
    } else {
      return `${minutes}:${(seconds % 60).toString().padStart(2, '0')}`;
    }
  }
}
