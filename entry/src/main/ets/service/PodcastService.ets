import http from '@ohos.net.http';
import { Podcast } from '../model/Podcast';
import { Episode } from '../model/Episode';
import { DatabaseService } from './DatabaseService';
import { Constants } from '../common/Constants';
import util from '@ohos.util';

/**
 * 播客服务 - 负责播客订阅和管理
 */
export class PodcastService {
  private static instance: PodcastService;
  private dbService: DatabaseService;

  private constructor() {
    this.dbService = DatabaseService.getInstance();
  }

  static getInstance(): PodcastService {
    if (!PodcastService.instance) {
      PodcastService.instance = new PodcastService();
    }
    return PodcastService.instance;
  }

  /**
   * 通过RSS URL添加播客
   */
  async addPodcastByUrl(feedUrl: string): Promise<Podcast> {
    // 获取RSS内容
    const rssContent = await this.fetchRssFeed(feedUrl);
    
    // 解析RSS
    const podcast = this.parseRssFeed(rssContent, feedUrl);
    
    // 保存到数据库
    podcast.subscribeDate = Date.now();
    podcast.isSubscribed = true;
    await this.dbService.insertPodcast(podcast);
    
    // 获取并保存Episodes
    await this.updatePodcastEpisodes(podcast.id);
    
    return podcast;
  }

  /**
   * 搜索播客
   * @param keyword 搜索关键词
   * @param offset 偏移量，用于分页（默认0）
   * @param limit 每页数量（默认20，最大200）
   */
  async searchPodcasts(keyword: string, offset: number = 0, limit: number = 20): Promise<Podcast[]> {
    // 使用 iTunes Search API
    // offset: 跳过前N条结果，用于分页
    // limit: 返回结果数量，最大200
    const searchUrl = `https://itunes.apple.com/search?term=${encodeURIComponent(keyword)}&media=podcast&limit=${limit}&offset=${offset}`;
    
    try {
      const response = await this.httpRequest(searchUrl);
      return this.parseSearchResults(response);
    } catch (error) {
      console.error('Search podcasts failed:', error);
      return [];
    }
  }

  /**
   * 获取所有订阅的播客
   */
  async getSubscribedPodcasts(): Promise<Podcast[]> {
    return await this.dbService.querySubscribedPodcasts();
  }

  /**
   * 取消订阅播客
   */
  async unsubscribePodcast(podcastId: string): Promise<void> {
    // 实现取消订阅逻辑
    // 可以选择删除或标记为未订阅
  }

  /**
   * 更新播客的Episodes
   */
  async updatePodcastEpisodes(podcastId: string): Promise<void> {
    // 实现更新逻辑
  }

  /**
   * 发送HTTP请求
   */
  private async httpRequest(url: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();
      
      httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: Constants.HTTP_TIMEOUT,
        readTimeout: Constants.HTTP_TIMEOUT
      }, (err, data) => {
        if (!err) {
          resolve(data.result as string);
        } else {
          reject(err);
        }
        httpRequest.destroy();
      });
    });
  }

  /**
   * 获取RSS Feed
   */
  private async fetchRssFeed(feedUrl: string): Promise<string> {
    return await this.httpRequest(feedUrl);
  }

  /**
   * 解析RSS Feed
   */
  private parseRssFeed(rssContent: string, feedUrl: string): Podcast {
    // 简化的RSS解析实现
    // 实际应该使用XML解析器
    const podcast = new Podcast();
    podcast.id = this.generateId();
    podcast.feedUrl = feedUrl;
    
    // 解析标题
    const titleMatch = rssContent.match(/<title>(.*?)<\/title>/);
    if (titleMatch) {
      podcast.title = this.decodeHtmlEntities(titleMatch[1]);
    }
    
    // 解析描述
    const descMatch = rssContent.match(/<description>(.*?)<\/description>/);
    if (descMatch) {
      podcast.description = this.decodeHtmlEntities(descMatch[1]);
    }
    
    // 解析作者
    const authorMatch = rssContent.match(/<itunes:author>(.*?)<\/itunes:author>/);
    if (authorMatch) {
      podcast.author = this.decodeHtmlEntities(authorMatch[1]);
    }
    
    // 解析图片
    const imageMatch = rssContent.match(/<itunes:image href="(.*?)"/);
    if (imageMatch) {
      podcast.imageUrl = imageMatch[1];
    }
    
    podcast.lastUpdate = Date.now();
    
    return podcast;
  }

  /**
   * 解析搜索结果
   */
  private parseSearchResults(response: string): Podcast[] {
    try {
      const data: Record<string, Object> = JSON.parse(response) as Record<string, Object>;
      const podcasts: Podcast[] = [];
      
      const results = data['results'] as Array<Record<string, Object>>;
      if (results && Array.isArray(results)) {
        for (let i = 0; i < results.length; i++) {
          const item = results[i];
          let podcast = new Podcast();
          const collectionId = item['collectionId'];
          podcast.id = collectionId ? String(collectionId) : this.generateId();
          podcast.title = (item['collectionName'] as string) || '';
          podcast.author = (item['artistName'] as string) || '';
          podcast.imageUrl = (item['artworkUrl600'] as string) || (item['artworkUrl100'] as string) || '';
          podcast.feedUrl = (item['feedUrl'] as string) || '';
          podcast.description = (item['description'] as string) || '';
          podcasts.push(podcast);
        }
      }
      
      return podcasts;
    } catch (error) {
      console.error('Parse search results failed:', error);
      return [];
    }
  }

  /**
   * 生成唯一ID
   */
  private generateId(): string {
    return `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 解码HTML实体
   */
  private decodeHtmlEntities(text: string): string {
    return text
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");
  }
}
