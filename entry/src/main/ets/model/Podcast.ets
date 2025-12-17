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

  static create(id: string, title: string, feedUrl: string): Podcast {
    let podcast = new Podcast();
    podcast.id = id;
    podcast.title = title;
    podcast.feedUrl = feedUrl;
    return podcast;
  }
}
