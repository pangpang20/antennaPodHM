import { UIUtils, ToastOptions, DialogOptions, ActionMenuOptions, ButtonOptions, RouteParams } from '../common/UIUtils';
import { Episode } from '../model/Episode';
import { PlayerService, PlayerState } from '../service/PlayerService';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../common/Constants';
import { DatabaseService } from '../service/DatabaseService';
import { DownloadService } from '../service/DownloadService';
import { pasteboard } from '@kit.BasicServicesKit';
import { BusinessError } from '@kit.BasicServicesKit';

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
  @State showDescriptionDialog: boolean = false;  // 显示简介弹窗
  
  private playerService: PlayerService = PlayerService.getInstance();
  private updateTimer: number = -1;

  aboutToAppear() {
    const params = UIUtils.getParams<Record<string, Object>>();
    if (params && params['episodeId']) {
      const episodeId = params['episodeId'] as string;
      this.loadEpisode(episodeId);
    }

    // 从 PlayerService 同步当前播放速度，确保一致性
    this.playbackSpeed = this.playerService.getPlaybackSpeed();
    console.info(`[PlayerPage] Synced playback speed from PlayerService: ${this.playbackSpeed}`);

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
      UIUtils.showToast(new ToastOptions('定时播放结束，已暂停', 2000));
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
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Button() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_primary'))
      }
      .width(44)
      .height(44)
      .backgroundColor($r('app.color.background_card'))
      .borderRadius(22)
      .onClick(() => {
        console.info('[PlayerPage] Back');
        UIUtils.back();
      })

      Blank()

      // 更多操作按钮
      Button() {
        Text('⋮')
          .fontSize(22)
          .fontColor($r('app.color.text_primary'))
      }
      .width(44)
      .height(44)
      .backgroundColor($r('app.color.background_card'))
      .borderRadius(22)
      .onClick(() => {
        console.info('[PlayerPage] More options');
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
      Image(this.currentEpisode?.imageUrl || '')
        .width(280)
        .height(280)
        .borderRadius(16)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.app_icon'))
        .margin({ top: 20 })
        .shadow({
          radius: 30,
          color: $r('app.color.shadow_color'),
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
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 20 })
        .allowScale(false)

      // 描述（点击显示完整内容）
      Text(this.currentEpisode?.description || '')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 8 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('85%')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (this.currentEpisode?.description) {
            this.showDescriptionDialog = true;
          }
        })
        .bindSheet($$this.showDescriptionDialog, this.buildDescriptionSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: true
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
  }

  @Builder
  buildDescriptionSheet() {
    Column() {
      Text('单集简介')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 16 })

      Scroll() {
        Text(this.formatDescription(this.currentEpisode?.description || ''))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(24)
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .constraintSize({ maxHeight: 400 })
    }
    .width('100%')
    .padding(20)
  }

  /**
   * 格式化描述，在时间戳前换行
   */
  formatDescription(desc: string): string {
    if (!desc) return '';
    // 匹配时间格式: 02:02, 1:02:02 等，在前面添加换行
    let result = desc.replace(/(\d{1,2}:\d{2}(?::\d{2})?)/g, '\n$1');
    // 去掉开头的换行符
    return result.replace(/^\n/, '').trim();
  }

  @Builder
  buildProgressBar() {
    Column() {
      // 加载状态提示
      if (this.playerState === PlayerState.LOADING) {
        Text('正在连接，请稍候...')
          .fontSize(14)
          .fontColor($r('app.color.primary'))
          .margin({ bottom: 12 })
      }

      // 时间显示
      Row() {
        Text(this.formatTime(this.currentPosition))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.formatTime(this.duration))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
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
        .trackColor($r('app.color.progress_track'))
        .selectedColor($r('app.color.primary'))
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
            .fontColor($r('app.color.primary'))
        }
        .width(56)
        .height(56)
        .backgroundColor($r('app.color.primary_button_bg'))
        .borderRadius(28)
        .onClick(() => {
          console.info('[PlayerPage] Rewind 15s');
          const newPosition = Math.max(0, this.currentPosition - 15);
          this.playerService.seek(newPosition);
          UIUtils.showToast(new ToastOptions('快退 15 秒', 1000));
        })
        
        Text('15秒')
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 4 })
      }
  
      Blank()
  
      // 播放/暂停按钮 - 更大、更突出
      Button() {
        if (this.playerState === PlayerState.LOADING) {
          LoadingProgress()
            .width(38)
            .height(38)
            .color($r('app.color.text_on_primary'))
        } else {
          Text(this.playerState === PlayerState.PLAYING ? '⏸' : '▶')
            .fontSize(38)
            .fontColor($r('app.color.text_on_primary'))
        }
      }
      .width(72)
      .height(72)
      .backgroundColor($r('app.color.primary'))
      .borderRadius(36)
      .shadow({
        radius: 12,
        color: $r('app.color.shadow_color'),
        offsetX: 0,
        offsetY: 4
      })
      .enabled(this.playerState !== PlayerState.LOADING)
      .onClick(() => {
        console.info(`[PlayerPage] Play/Pause, state: ${this.playerState}`);
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
            .fontColor($r('app.color.primary'))
        }
        .width(56)
        .height(56)
        .backgroundColor($r('app.color.primary_button_bg'))
        .borderRadius(28)
        .onClick(() => {
          console.info('[PlayerPage] Forward 30s');
          const newPosition = Math.min(this.duration, this.currentPosition + 30);
          this.playerService.seek(newPosition);
          UIUtils.showToast(new ToastOptions('快进 30 秒', 1000));
        })
        
        Text('30秒')
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
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
            Text('▶')
              .fontSize(14)
              .fontColor($r('app.color.primary'))
              .margin({ right: 4 })
            Text(`${this.playbackSpeed}x`)
              .fontSize(14)
              .fontColor($r('app.color.primary'))
              .fontWeight(FontWeight.Medium)
          }
        }
        .height(40)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.primary_button_bg'))
        .borderRadius(20)
        .border({ width: 1, color: $r('app.color.primary_border'), radius: 20 })
        .onClick(() => {
          console.info('[PlayerPage] Speed selector');
          this.showSpeedSelectorMenu();
        })

        Blank()

        // 睡眠定时器
        Button() {
          Row() {
            Text('⏱')
              .fontSize(14)
              .fontColor(this.sleepTimerRemaining > 0 ? $r('app.color.accent_red') : $r('app.color.text_secondary'))
              .margin({ right: 4 })
            if (this.sleepTimerRemaining > 0) {
              Text(this.formatSleepTimer(this.sleepTimerRemaining))
                .fontSize(14)
                .fontColor($r('app.color.accent_red'))
                .fontWeight(FontWeight.Medium)
            } else {
              Text('定时')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
          }
        }
        .height(40)
        .padding({ left: 16, right: 16 })
        .backgroundColor(this.sleepTimerRemaining > 0 ? $r('app.color.timer_active_bg') : $r('app.color.button_secondary_bg'))
        .borderRadius(20)
        .border({ 
          width: 1, 
          color: this.sleepTimerRemaining > 0 ? $r('app.color.timer_active_border') : $r('app.color.border_color'), 
          radius: 20 
        })
        .onClick(() => {
          console.info('[PlayerPage] Sleep timer');
          this.showSleepTimerMenu();
        })
      }
      .width('100%')
      .margin({ top: 20 })

      // 第二行：添加到队列
      Button() {
        Row() {
          Text('➕')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ right: 4 })
          Text('添加到队列')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
      .height(44)
      .backgroundColor($r('app.color.button_secondary_bg'))
      .borderRadius(22)
      .border({ width: 1, color: $r('app.color.border_color'), radius: 22 })
      .margin({ top: 12 })
      .onClick(() => {
        console.info(`[PlayerPage] Add to queue: ${this.currentEpisode?.title || 'none'}`);
        if (!this.currentEpisode) {
          console.warn('No current episode to add to queue');
          return;
        }
        this.playerService.addToQueue(this.currentEpisode);
        UIUtils.showToast(new ToastOptions('已添加到队列', 2000));
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
    // 符合业界标准的播放速度选项
    // 参考：Apple Podcasts, Spotify, Overcast 等主流播客应用
    const buttons: ButtonOptions[] = [
      new ButtonOptions('0.5x', '#000000'),   // 慢速学习
      new ButtonOptions('0.75x', '#000000'),  // 较慢
      new ButtonOptions('1.0x', '#000000'),   // 正常速度
      new ButtonOptions('1.25x', '#000000'),  // 稍快
      new ButtonOptions('1.5x', '#000000'),   // 较快
      new ButtonOptions('1.75x', '#000000'),  // 很快
      new ButtonOptions('2.0x', '#000000'),   // 2倍速
      new ButtonOptions('2.5x', '#000000'),   // 极快
      new ButtonOptions('3.0x', '#000000')    // 最快
    ];
    UIUtils.showActionMenu(new ActionMenuOptions('选择播放速度', buttons)).then((index: number) => {
      if (index >= 0) {
        const speeds: number[] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];
        const selectedSpeed = speeds[index];
        this.playbackSpeed = selectedSpeed;
        this.playerService.setPlaybackSpeed(selectedSpeed);
        // 保存到设置中，下次启动时记住
        const settingsService = SettingsService.getInstance();
        settingsService.setPlaybackSpeed(selectedSpeed);
        console.info(`[PlayerPage] Playback speed set to ${selectedSpeed}x and saved`);
      }
    });
  }

  showSleepTimerMenu(): void {
    const buttons: ButtonOptions[] = [
      new ButtonOptions('关闭定时', '#000000'),
      new ButtonOptions('5 分钟', '#000000'),
      new ButtonOptions('15 分钟', '#000000'),
      new ButtonOptions('30 分钟', '#000000'),
      new ButtonOptions('45 分钟', '#000000'),
      new ButtonOptions('60 分钟', '#000000')
    ];
    UIUtils.showActionMenu(new ActionMenuOptions('定时关闭', buttons)).then((index: number) => {
      if (index >= 0) {
        const minutesOptions: number[] = [0, 5, 15, 30, 45, 60];
        const minutes = minutesOptions[index];
        this.sleepTimerMinutes = minutes;
        this.playerService.setSleepTimer(minutes);
        const msg = minutes > 0 ? `已设置定时关闭：${minutes} 分钟` : '已关闭定时播放';
        UIUtils.showToast(new ToastOptions(msg, 2000));
      }
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
    
    const buttons: ButtonOptions[] = [
      new ButtonOptions('微信好友', '#000000'),
      new ButtonOptions('微信朋友圈', '#000000'),
      new ButtonOptions('复制链接', '#000000'),
      new ButtonOptions('更多分享方式', '#000000')
    ];
    UIUtils.showActionMenu(new ActionMenuOptions('分享到', buttons)).then((index: number) => {
      if (index >= 0) {
        switch (index) {
          case 0:
            this.shareToWeChatFriend();
            break;
          case 1:
            this.shareToWeChatMoments();
            break;
          case 2:
            this.copyShareLink();
            break;
          case 3:
            this.systemShare();
            break;
        }
      }
    });
  }

  /**
   * 分享到微信好友
   */
  shareToWeChatFriend(): void {
    if (!this.currentEpisode) {
      return;
    }
    
    // HarmonyOS暂不支持直接调用微信SDK，需要通过系统分享或复制链接
    const buttons: ButtonOptions[] = [
      new ButtonOptions('取消', '#999999'),
      new ButtonOptions('复制链接', '#007AFF')
    ];
    UIUtils.showDialog(new DialogOptions(
      '分享到微信',
      '由于系统限制，暂不支持直接分享到微信。\n\n建议操作：\n1. 点击"复制链接"复制分享内容\n2. 手动打开微信发送给好友',
      buttons
    )).then((index: number) => {
      if (index === 1) {
        this.copyShareLink();
      }
    });
    
    console.info('[PlayerPage] Share to WeChat friend:', this.currentEpisode?.title);
  }

  /**
   * 分享到微信朋友圈
   */
  shareToWeChatMoments(): void {
    if (!this.currentEpisode) {
      return;
    }
    
    // HarmonyOS暂不支持直接调用微信SDK，需要通过系统分享或复制链接
    const buttons: ButtonOptions[] = [
      new ButtonOptions('取消', '#999999'),
      new ButtonOptions('复制链接', '#007AFF')
    ];
    UIUtils.showDialog(new DialogOptions(
      '分享到朋友圈',
      '由于系统限制，暂不支持直接分享到朋友圈。\n\n建议操作：\n1. 点击"复制链接"复制分享内容\n2. 手动打开微信发布到朋友圈',
      buttons
    )).then((index: number) => {
      if (index === 1) {
        this.copyShareLink();
      }
    });
    
    console.info('[PlayerPage] Share to WeChat moments:', this.currentEpisode?.title);
  }

  /**
   * 复制分享链接
   */
  async copyShareLink(): Promise<void> {
    if (!this.currentEpisode) {
      return;
    }
    
    try {
      const shareText = `我正在听《${this.currentEpisode.title}》

${this.currentEpisode.description}

分享自 AntennaPodHM`;
      
      // 创建剪贴板数据
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, shareText);
      
      // 获取系统剪贴板实例
      const systemPasteboard = pasteboard.getSystemPasteboard();
      
      // 将数据写入剪贴板
      await systemPasteboard.setData(pasteData);
      
      UIUtils.showToast(new ToastOptions('内容已复制到剪贴板', 2000));
      
      console.info('[PlayerPage] Copy share link success:', shareText);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[PlayerPage] Copy share link failed: ${err.code}, ${err.message}`);
      
      UIUtils.showToast(new ToastOptions('复制失败，请重试', 2000));
    }
  }

  /**
   * 系统分享
   */
  async systemShare(): Promise<void> {
    if (!this.currentEpisode) {
      return;
    }
    
    // HarmonyOS 目前的系统分享API较为复杂，直接使用复制到剪贴板作为替代方案
    const buttons: ButtonOptions[] = [
      new ButtonOptions('取消', '#999999'),
      new ButtonOptions('复制', '#007AFF')
    ];
    UIUtils.showDialog(new DialogOptions(
      '分享',
      '将分享内容复制到剪贴板，然后您可以粘贴到任何应用中分享。',
      buttons
    )).then((index: number) => {
      if (index === 1) {
        this.copyShareLink();
      }
    });
    
    console.info('[PlayerPage] System share initiated');
  }

  /**
   * 显示更多选项菜单
   */
  showMoreOptionsMenu(): void {
    const buttons: ButtonOptions[] = [
      new ButtonOptions('查看单集详情', '#000000'),
      new ButtonOptions('分享这一集', '#000000'),
      new ButtonOptions('下载到本地', '#000000')
    ];
    UIUtils.showActionMenu(new ActionMenuOptions('更多选项', buttons)).then((index: number) => {
      if (index >= 0) {
        switch (index) {
          case 0:
            // 查看单集详情
            if (this.currentEpisode) {
              const params = new RouteParams();
              params.episodeId = this.currentEpisode.id;
              UIUtils.pushUrl('pages/EpisodeDetailPage', params);
            }
            break;
          case 1:
            // 分享
            if (this.currentEpisode) {
              this.shareEpisode();
            } else {
              UIUtils.showToast(new ToastOptions('暂无可分享的内容', 2000));
            }
            break;
          case 2:
            // 下载
            if (this.currentEpisode) {
              DownloadService.getInstance().downloadEpisode(this.currentEpisode)
                .then(() => {
                  UIUtils.showToast(new ToastOptions('已添加到下载队列', 2000));
                })
                .catch((err: Error) => {
                  console.error('Download failed:', err);
                  UIUtils.showToast(new ToastOptions('下载失败', 2000));
                });
            }
            break;
        }
      }
    });
  }
}
