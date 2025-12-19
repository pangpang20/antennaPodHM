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
   * 从搜索结果中直接添加播客（不立刻抓取 RSS）
   */
  async addPodcastFromSearchResult(source: Podcast): Promise<Podcast> {
    const podcast = new Podcast();
    podcast.id = source.id || this.generateId();
    podcast.title = source.title;
    podcast.author = source.author;
    podcast.description = source.description;
    podcast.imageUrl = source.imageUrl;
    podcast.feedUrl = source.feedUrl;
    podcast.link = source.link;
    podcast.language = source.language;
    podcast.category = source.category;
    podcast.subscribeDate = Date.now();
    podcast.lastUpdate = Date.now();
    podcast.episodeCount = source.episodeCount;
    podcast.isSubscribed = true;

    await this.dbService.insertPodcast(podcast);
    return podcast;
  }

  /**
   * 搜索播客
   * @param keyword 搜索关键词
   * @param offset 偏移量（iTunes API 不支持，保留为兼容）
   * @param limit 每页数量（默认50，最大200）
   */
  async searchPodcasts(keyword: string, offset: number = 0, limit: number = 50): Promise<Podcast[]> {
    // iTunes Search API 不支持 offset 分页，只支持 limit
    // 如果 offset > 0，返回空数组表示没有更多
    if (offset > 0) {
      return [];
    }
    
    const searchUrl = `https://itunes.apple.com/search?term=${encodeURIComponent(keyword)}&media=podcast&limit=${limit}`;
    
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
    // 删除播客相关的所有单集
    await this.dbService.deleteEpisodesByPodcastId(podcastId);
    // 删除播客
    await this.dbService.deletePodcast(podcastId);
  }

  /**
   * 更新播客的Episodes
   * 成功时更新 lastSuccessfulFetch，失败时标记 isFetchFailed
   */
  async updatePodcastEpisodes(podcastId: string): Promise<void> {
    try {
      console.info(`[PodcastService] Starting to update episodes for podcast: ${podcastId}`);
      
      // 从数据库获取播客信息，拿到 feedUrl
      const podcast = await this.dbService.getPodcastById(podcastId);
      if (!podcast || !podcast.feedUrl) {
        console.warn('[PodcastService] No podcast or feedUrl found for id:', podcastId);
        return;
      }

      // 如果已标记为获取失败，跳过刷新
      if (podcast.isFetchFailed) {
        console.info(`[PodcastService] Podcast ${podcastId} is marked as fetch failed, skipping refresh`);
        return;
      }

      console.info(`[PodcastService] Fetching RSS from: ${podcast.feedUrl}`);
      
      // 拉取 RSS 内容（增加超时时间）
      const rssContent = await this.fetchRssFeed(podcast.feedUrl);
      
      console.info(`[PodcastService] RSS content fetched, length: ${rssContent.length}`);

      // 解析出单集列表
      const episodes = this.parseEpisodesFromRss(rssContent, podcastId);
      console.info(`[PodcastService] Parsed ${episodes.length} episodes`);
      
      if (!episodes.length) {
        console.warn('[PodcastService] No episodes parsed from rss for podcast:', podcastId);
        // 即使没有解析到单集，也不抛异常，只记录日志
        return;
      }

      // 先清空旧的单集，再插入新的
      await this.dbService.deleteEpisodesByPodcastId(podcastId);
      for (let i = 0; i < episodes.length; i++) {
        await this.dbService.insertEpisode(episodes[i]);
      }

      // 更新播客的 episodeCount 和 lastSuccessfulFetch
      await this.dbService.updatePodcastEpisodeCount(podcastId, episodes.length);
      await this.dbService.updatePodcastFetchStatus(podcastId, false, Date.now());
      
      console.info(`[PodcastService] Successfully updated ${episodes.length} episodes for podcast: ${podcastId}`);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error('[PodcastService] Failed to update podcast episodes:', errMsg);
      
      // 标记播客为获取失败
      await this.dbService.updatePodcastFetchStatus(podcastId, true);
      
      // 不抛异常，让调用者决定如何处理
      throw new Error(`Failed to update podcast episodes: ${errMsg}`);
    }
  }

  /**
   * 重置播客获取失败状态（允许重新刷新）
   */
  async resetPodcastFetchStatus(podcastId: string): Promise<void> {
    await this.dbService.updatePodcastFetchStatus(podcastId, false);
    console.info(`[PodcastService] Reset fetch status for podcast: ${podcastId}`);
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
   * 解析RSS中的单集列表
   */
  private parseEpisodesFromRss(rssContent: string, podcastId: string): Episode[] {
    const episodes: Episode[] = [];
    if (!rssContent) {
      return episodes;
    }

    // 粗略匹配 <item> ... </item>
    const itemRegex = /<item[\s\S]*?<\/item>/g;
    const items = rssContent.match(itemRegex);
    if (!items || !Array.isArray(items)) {
      return episodes;
    }

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const episode = new Episode();
      episode.id = this.generateId();
      episode.podcastId = podcastId;

      // 标题
      const titleMatch = item.match(/<title>([\s\S]*?)<\/title>/);
      if (titleMatch) {
        episode.title = this.cleanText(titleMatch[1]);
      }

      // 描述
      const descMatch = item.match(/<description>([\s\S]*?)<\/description>/);
      if (descMatch) {
        episode.description = this.cleanText(descMatch[1]);
      }

      // 链接
      const linkMatch = item.match(/<link>([\s\S]*?)<\/link>/);
      if (linkMatch) {
        episode.link = linkMatch[1].trim();
      }

      // 音频地址（enclosure url）
      const enclosureMatch = item.match(/<enclosure[^>]*url="(.*?)"/);
      if (enclosureMatch) {
        episode.audioUrl = this.decodeHtmlEntities(enclosureMatch[1]);
      } else if (episode.link) {
        episode.audioUrl = episode.link;
      }
      
      // 单集图片
      const imageMatch = item.match(/<itunes:image[^>]*href="(.*?)"/);
      if (imageMatch) {
        episode.imageUrl = this.decodeHtmlEntities(imageMatch[1]);
      }
      
      // 时长 itunes:duration
      const durationMatch = item.match(/<itunes:duration>(.*?)<\/itunes:duration>/);
      if (durationMatch) {
        episode.duration = this.parseDurationToSeconds(durationMatch[1].trim());
      }

      // 发布时间 pubDate
      const pubDateMatch = item.match(/<pubDate>(.*?)<\/pubDate>/);
      if (pubDateMatch) {
        const date = new Date(pubDateMatch[1]);
        const time = date.getTime();
        if (!isNaN(time)) {
          episode.pubDate = time;
        }
      }

      // 其他字段默认值
      episode.fileSize = 0;
      episode.downloadStatus = 0;
      episode.downloadProgress = 0;
      episode.localPath = '';
      episode.playbackPosition = 0;
      episode.isPlayed = false;
      episode.isFavorite = false;
      episode.addedToQueueDate = Date.now();

      episodes.push(episode);
    }

    return episodes;
  }

  /**
   * 将 HH:MM:SS 或 MM:SS 或 秒数字符串 转成秒
   */
  private parseDurationToSeconds(value: string): number {
    if (!value) {
      return 0;
    }

    const parts = value.split(':');
    let seconds = 0;
    if (parts.length === 3) {
      seconds = parseInt(parts[0]) * 3600 + parseInt(parts[1]) * 60 + parseInt(parts[2]);
    } else if (parts.length === 2) {
      seconds = parseInt(parts[0]) * 60 + parseInt(parts[1]);
    } else {
      const num = parseInt(value);
      if (!isNaN(num)) {
        seconds = num;
      }
    }

    if (isNaN(seconds) || seconds < 0) {
      return 0;
    }
    return seconds;
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
      podcast.title = this.cleanText(titleMatch[1]);
    }
    
    // 解析描述
    const descMatch = rssContent.match(/<description>([\s\S]*?)<\/description>/);
    if (descMatch) {
      podcast.description = this.cleanText(descMatch[1]);
    }
    
    // 解析作者
    const authorMatch = rssContent.match(/<itunes:author>([\s\S]*?)<\/itunes:author>/);
    if (authorMatch) {
      podcast.author = this.cleanText(authorMatch[1]);
    }
    
    // 解析图片
    const imageMatch = rssContent.match(/<itunes:image href="(.*?)"/);
    if (imageMatch) {
      podcast.imageUrl = this.decodeHtmlEntities(imageMatch[1]);
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
   * 解码并清洗文本（去掉 CDATA 和 HTML 标签）
   */
  private cleanText(text: string): string {
    if (!text) {
      return '';
    }
    let value = text;
    // 去掉 CDATA 包裹（处理各种情况）
    value = value.replace(/<!\[CDATA\[/g, '');
    value = value.replace(/\]\]>/g, '');
    // 去掉简单 HTML 标签
    value = value.replace(/<[^>]+>/g, '');
    // 解码 HTML 实体
    value = this.decodeHtmlEntities(value);
    return value.trim();
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
