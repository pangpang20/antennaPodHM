import relationalStore from '@ohos.data.relationalStore';
import { Podcast } from '../model/Podcast';
import { Episode } from '../model/Episode';
import { QueueItem } from '../model/QueueItem';
import { Constants } from '../common/Constants';

/**
 * 数据库服务
 */
export class DatabaseService {
  private static instance: DatabaseService;
  private rdbStore: relationalStore.RdbStore | null = null;

  private constructor() {}

  static getInstance(): DatabaseService {
    if (!DatabaseService.instance) {
      DatabaseService.instance = new DatabaseService();
    }
    return DatabaseService.instance;
  }

  /**
   * 初始化数据库
   */
  async init(context: Context): Promise<void> {
    try {
      const config: relationalStore.StoreConfig = {
        name: Constants.DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      };

      this.rdbStore = await relationalStore.getRdbStore(context, config);
      await this.createTables();
    } catch (error) {
      console.error('Failed to initialize database:', error);
    }
  }

  /**
   * 创建数据库表
   */
  private async createTables(): Promise<void> {
    if (!this.rdbStore) return;

    try {
      // 创建播客表
      const createPodcastTable = `
        CREATE TABLE IF NOT EXISTS ${Constants.TABLE_PODCAST} (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          author TEXT,
          description TEXT,
          imageUrl TEXT,
          feedUrl TEXT NOT NULL,
          link TEXT,
          language TEXT,
          category TEXT,
          subscribeDate INTEGER,
          lastUpdate INTEGER,
          episodeCount INTEGER,
          isSubscribed INTEGER DEFAULT 1
        )
      `;

      // 创建Episode表
      const createEpisodeTable = `
        CREATE TABLE IF NOT EXISTS ${Constants.TABLE_EPISODE} (
          id TEXT PRIMARY KEY,
          podcastId TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          link TEXT,
          audioUrl TEXT NOT NULL,
          imageUrl TEXT,
          duration INTEGER,
          fileSize INTEGER,
          pubDate INTEGER,
          downloadStatus INTEGER DEFAULT 0,
          downloadProgress INTEGER DEFAULT 0,
          localPath TEXT,
          playbackPosition INTEGER DEFAULT 0,
          isPlayed INTEGER DEFAULT 0,
          isFavorite INTEGER DEFAULT 0,
          addedToQueueDate INTEGER DEFAULT 0,
          FOREIGN KEY (podcastId) REFERENCES ${Constants.TABLE_PODCAST}(id)
        )
      `;

      // 创建队列表
      const createQueueTable = `
        CREATE TABLE IF NOT EXISTS ${Constants.TABLE_QUEUE} (
          id TEXT PRIMARY KEY,
          episodeId TEXT NOT NULL,
          position INTEGER NOT NULL,
          addedDate INTEGER,
          FOREIGN KEY (episodeId) REFERENCES ${Constants.TABLE_EPISODE}(id)
        )
      `;

      await this.rdbStore.executeSql(createPodcastTable);
      await this.rdbStore.executeSql(createEpisodeTable);
      await this.rdbStore.executeSql(createQueueTable);
    } catch (error) {
      console.error('Failed to create tables:', error);
    }
  }

  /**
   * 插入播客
   */
  async insertPodcast(podcast: Podcast): Promise<number> {
    if (!this.rdbStore) return -1;

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        id: podcast.id,
        title: podcast.title,
        author: podcast.author,
        description: podcast.description,
        imageUrl: podcast.imageUrl,
        feedUrl: podcast.feedUrl,
        link: podcast.link,
        language: podcast.language,
        category: podcast.category,
        subscribeDate: podcast.subscribeDate,
        lastUpdate: podcast.lastUpdate,
        episodeCount: podcast.episodeCount,
        isSubscribed: podcast.isSubscribed ? 1 : 0
      };

      return await this.rdbStore.insert(Constants.TABLE_PODCAST, valueBucket);
    } catch (error) {
      console.error('Failed to insert podcast:', error);
      return -1;
    }
  }

  /**
   * 查询所有订阅的播客
   */
  async querySubscribedPodcasts(): Promise<Podcast[]> {
    if (!this.rdbStore) return [];

    try {
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_PODCAST);
      predicates.equalTo('isSubscribed', 1);
      predicates.orderByDesc('subscribeDate');

      const resultSet = await this.rdbStore.query(predicates);
      const podcasts: Podcast[] = [];

      while (resultSet.goToNextRow()) {
        podcasts.push(this.parsePodcastFromResultSet(resultSet));
      }

      resultSet.close();
      return podcasts;
    } catch (error) {
      console.error('Failed to query subscribed podcasts:', error);
      return [];
    }
  }

  /**
   * 根据ID查询单个播客
   */
  async getPodcastById(podcastId: string): Promise<Podcast | null> {
    if (!this.rdbStore) return null;

    try {
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_PODCAST);
      predicates.equalTo('id', podcastId);

      const resultSet = await this.rdbStore.query(predicates);
      let podcast: Podcast | null = null;
      if (resultSet.goToNextRow()) {
        podcast = this.parsePodcastFromResultSet(resultSet);
      }
      resultSet.close();
      return podcast;
    } catch (error) {
      console.error('Failed to query podcast by id:', error);
      return null;
    }
  }

  /**
   * 根据ID查询单个Episode
   */
  async getEpisodeById(episodeId: string): Promise<Episode | null> {
    if (!this.rdbStore) return null;

    try {
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_EPISODE);
      predicates.equalTo('id', episodeId);

      const resultSet = await this.rdbStore.query(predicates);
      let episode: Episode | null = null;
      if (resultSet.goToNextRow()) {
        episode = this.parseEpisodeFromResultSet(resultSet);
      }
      resultSet.close();
      return episode;
    } catch (error) {
      console.error('Failed to query episode by id:', error);
      return null;
    }
  }

  /**
   * 插入Episode
   */
  async insertEpisode(episode: Episode): Promise<number> {
    if (!this.rdbStore) return -1;

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        id: episode.id,
        podcastId: episode.podcastId,
        title: episode.title,
        description: episode.description,
        link: episode.link,
        audioUrl: episode.audioUrl,
        imageUrl: episode.imageUrl,
        duration: episode.duration,
        fileSize: episode.fileSize,
        pubDate: episode.pubDate,
        downloadStatus: episode.downloadStatus,
        downloadProgress: episode.downloadProgress,
        localPath: episode.localPath,
        playbackPosition: episode.playbackPosition,
        isPlayed: episode.isPlayed ? 1 : 0,
        isFavorite: episode.isFavorite ? 1 : 0,
        addedToQueueDate: episode.addedToQueueDate
      };

      return await this.rdbStore.insert(Constants.TABLE_EPISODE, valueBucket);
    } catch (error) {
      console.error('Failed to insert episode:', error);
      return -1;
    }
  }

  /**
   * 根据播客ID查询Episodes
   */
  async queryEpisodesByPodcastId(podcastId: string): Promise<Episode[]> {
    if (!this.rdbStore) return [];

    try {
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_EPISODE);
      predicates.equalTo('podcastId', podcastId);
      predicates.orderByDesc('pubDate');

      const resultSet = await this.rdbStore.query(predicates);
      const episodes: Episode[] = [];

      while (resultSet.goToNextRow()) {
        episodes.push(this.parseEpisodeFromResultSet(resultSet));
      }

      resultSet.close();
      return episodes;
    } catch (error) {
      console.error('Failed to query episodes by podcast id:', error);
      return [];
    }
  }

  /**
   * 查询所有Episodes
   */
  async getAllEpisodes(): Promise<Episode[]> {
    if (!this.rdbStore) return [];

    try {
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_EPISODE);
      predicates.orderByDesc('pubDate');

      const resultSet = await this.rdbStore.query(predicates);
      const episodes: Episode[] = [];

      while (resultSet.goToNextRow()) {
        episodes.push(this.parseEpisodeFromResultSet(resultSet));
      }

      resultSet.close();
      return episodes;
    } catch (error) {
      console.error('Failed to query all episodes:', error);
      return [];
    }
  }

  /**
   * 删除指定播客的所有Episodes
   */
  async deleteEpisodesByPodcastId(podcastId: string): Promise<void> {
    if (!this.rdbStore) return;

    try {
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_EPISODE);
      predicates.equalTo('podcastId', podcastId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error('Failed to delete episodes by podcast id:', error);
    }
  }

  /**
   * 删除播客
   */
  async deletePodcast(podcastId: string): Promise<void> {
    if (!this.rdbStore) return;

    try {
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_PODCAST);
      predicates.equalTo('id', podcastId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error('Failed to delete podcast:', error);
    }
  }

  /**
   * 更新播客的Episode数量
   */
  async updatePodcastEpisodeCount(podcastId: string, count: number): Promise<void> {
    if (!this.rdbStore) return;

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        episodeCount: count
      };
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_PODCAST);
      predicates.equalTo('id', podcastId);
      await this.rdbStore.update(valueBucket, predicates);
    } catch (error) {
      console.error('Failed to update podcast episode count:', error);
    }
  }

  /**
   * 更新Episode下载状态
   */
  async updateEpisodeDownloadStatus(episodeId: string, status: number, progress: number, localPath?: string): Promise<void> {
    if (!this.rdbStore) {
      console.error('[DatabaseService] rdbStore is null');
      return;
    }

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        downloadStatus: status,
        downloadProgress: progress
      };

      if (localPath !== undefined) {
        valueBucket.localPath = localPath;
      }

      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_EPISODE);
      predicates.equalTo('id', episodeId);

      const rows = await this.rdbStore.update(valueBucket, predicates);
      console.info(`[DatabaseService] Updated ${rows} rows for episode ${episodeId}, status: ${status}, progress: ${progress}, localPath: ${localPath || 'none'}`);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error('[DatabaseService] Failed to update episode download status:', errMsg);
      throw new Error(`Failed to update episode download status: ${errMsg}`);
    }
  }

  private parsePodcastFromResultSet(resultSet: relationalStore.ResultSet): Podcast {
    let podcast = new Podcast();
    podcast.id = resultSet.getString(resultSet.getColumnIndex('id'));
    podcast.title = resultSet.getString(resultSet.getColumnIndex('title'));
    podcast.author = resultSet.getString(resultSet.getColumnIndex('author'));
    podcast.description = resultSet.getString(resultSet.getColumnIndex('description'));
    podcast.imageUrl = resultSet.getString(resultSet.getColumnIndex('imageUrl'));
    podcast.feedUrl = resultSet.getString(resultSet.getColumnIndex('feedUrl'));
    podcast.link = resultSet.getString(resultSet.getColumnIndex('link'));
    podcast.language = resultSet.getString(resultSet.getColumnIndex('language'));
    podcast.category = resultSet.getString(resultSet.getColumnIndex('category'));
    podcast.subscribeDate = resultSet.getLong(resultSet.getColumnIndex('subscribeDate'));
    podcast.lastUpdate = resultSet.getLong(resultSet.getColumnIndex('lastUpdate'));
    podcast.episodeCount = resultSet.getLong(resultSet.getColumnIndex('episodeCount'));
    podcast.isSubscribed = resultSet.getLong(resultSet.getColumnIndex('isSubscribed')) === 1;
    return podcast;
  }

  private parseEpisodeFromResultSet(resultSet: relationalStore.ResultSet): Episode {
    let episode = new Episode();
    episode.id = resultSet.getString(resultSet.getColumnIndex('id'));
    episode.podcastId = resultSet.getString(resultSet.getColumnIndex('podcastId'));
    episode.title = resultSet.getString(resultSet.getColumnIndex('title'));
    episode.description = resultSet.getString(resultSet.getColumnIndex('description'));
    episode.link = resultSet.getString(resultSet.getColumnIndex('link'));
    episode.audioUrl = resultSet.getString(resultSet.getColumnIndex('audioUrl'));
    episode.imageUrl = resultSet.getString(resultSet.getColumnIndex('imageUrl'));
    episode.duration = resultSet.getLong(resultSet.getColumnIndex('duration'));
    episode.fileSize = resultSet.getLong(resultSet.getColumnIndex('fileSize'));
    episode.pubDate = resultSet.getLong(resultSet.getColumnIndex('pubDate'));
    episode.downloadStatus = resultSet.getLong(resultSet.getColumnIndex('downloadStatus'));
    episode.downloadProgress = resultSet.getLong(resultSet.getColumnIndex('downloadProgress'));
    episode.localPath = resultSet.getString(resultSet.getColumnIndex('localPath'));
    episode.playbackPosition = resultSet.getLong(resultSet.getColumnIndex('playbackPosition'));
    episode.isPlayed = resultSet.getLong(resultSet.getColumnIndex('isPlayed')) === 1;
    episode.isFavorite = resultSet.getLong(resultSet.getColumnIndex('isFavorite')) === 1;
    episode.addedToQueueDate = resultSet.getLong(resultSet.getColumnIndex('addedToQueueDate'));
    return episode;
  }
}
