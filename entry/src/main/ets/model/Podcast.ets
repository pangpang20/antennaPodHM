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

  constructor(data?: Partial<Podcast>) {
    if (data) {
      Object.assign(this, data);
    }
  }
}
