/**
 * 播客实体类
 */
export class Podcast {
  id: string = '';
  title: string = '';
  author: string = '';
  description: string = '';
  imageUrl: string = '';
  feedUrl: string = '';
  link: string = '';
  language: string = '';
  category: string = '';
  subscribeDate: number = 0;
  lastUpdate: number = 0;
  episodeCount: number = 0;
  isSubscribed: boolean = false;
  /** 是否获取失败（无法访问RSS） */
  isFetchFailed: boolean = false;
  /** 最后一次成功刷新的时间戳 */
  lastSuccessfulFetch: number = 0;

  static create(id: string, title: string, feedUrl: string): Podcast {
    let podcast = new Podcast();
    podcast.id = id;
    podcast.title = title;
    podcast.feedUrl = feedUrl;
    return podcast;
  }

  /**
   * 判断是否需要刷新
   * 规则：新订阅1分钟内每5秒刷新，之后每2小时刷新一次
   * 如果已标记为获取失败，则不再刷新
   */
  needsRefresh(): boolean {
    if (this.isFetchFailed) {
      return false;
    }

    const now = Date.now();
    const subscribeAge = now - this.subscribeDate; // 订阅了多久
    const lastFetchAge = now - this.lastSuccessfulFetch; // 距离上次刷新多久

    const ONE_MINUTE = 60 * 1000;
    const FIVE_SECONDS = 5 * 1000;
    const TWO_HOURS = 2 * 60 * 60 * 1000;

    if (subscribeAge < ONE_MINUTE) {
      // 新订阅1分钟内，每5秒刷新一次
      return lastFetchAge >= FIVE_SECONDS;
    } else {
      // 超过1分钟后，每2小时刷新一次
      return lastFetchAge >= TWO_HOURS;
    }
  }
}
