import relationalStore from '@ohos.data.relationalStore';
import { Podcast } from '../model/Podcast';
import { Episode } from '../model/Episode';
import { QueueItem } from '../model/QueueItem';
import { Constants } from '../common/Constants';

// 搜索结果
export class EpisodeSearchResult {
  episodes: Episode[] = [];
  total: number = 0;

  constructor(episodes: Episode[], total: number) {
    this.episodes = episodes;
    this.total = total;
  }
}

/**
 * 数据库版本历史
 * 每次修改数据库结构时，需要：
 * 1. 在 Constants.DB_VERSION 中增加版本号
 * 2. 在 migrateDatabase() 中添加对应的迁移逻辑
 * 
 * 版本历史:
 * - v1: 初始版本，创建 podcast, episode, queue 表
 * - v2: 添加 podcast 表的 isFetchFailed 和 lastSuccessfulFetch 字段
 */

/**
 * 数据库服务 - 基于 SQLite (relationalStore)
 * 支持版本管理和数据迁移
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
      
      // 检查并执行数据库迁移
      await this.checkAndMigrateDatabase();
      
      console.info(`[DatabaseService] Database initialized, version: ${Constants.DB_VERSION}`);
    } catch (error) {
      console.error('Failed to initialize database:', error);
    }
  }

  /**
   * 检查并执行数据库迁移
   */
  private async checkAndMigrateDatabase(): Promise<void> {
    if (!this.rdbStore) return;

    try {
      // 获取当前数据库版本
      const currentVersion = await this.getDatabaseVersion();
      const targetVersion = Constants.DB_VERSION;

      console.info(`[DatabaseService] Current DB version: ${currentVersion}, Target version: ${targetVersion}`);

      if (currentVersion === 0) {
        // 新安装，创建所有表
        await this.createTables();
        await this.setDatabaseVersion(targetVersion);
        console.info('[DatabaseService] Fresh install, tables created');
      } else if (currentVersion < targetVersion) {
        // 需要升级
        await this.migrateDatabase(currentVersion, targetVersion);
        await this.setDatabaseVersion(targetVersion);
        console.info(`[DatabaseService] Migration completed: v${currentVersion} -> v${targetVersion}`);
      } else {
        console.info('[DatabaseService] Database is up to date');
      }
    } catch (error) {
      console.error('[DatabaseService] Migration failed:', error);
      // 迁移失败时尝试创建表（容错处理）
      await this.createTables();
    }
  }

  /**
   * 获取数据库版本
   */
  private async getDatabaseVersion(): Promise<number> {
    if (!this.rdbStore) return 0;

    try {
      // 使用 PRAGMA user_version 存储版本号
      const resultSet = await this.rdbStore.querySql('PRAGMA user_version');
      let version = 0;
      if (resultSet.goToFirstRow()) {
        version = resultSet.getLong(0);
      }
      resultSet.close();
      return version;
    } catch (error) {
      console.error('[DatabaseService] Failed to get database version:', error);
      return 0;
    }
  }

  /**
   * 设置数据库版本
   */
  private async setDatabaseVersion(version: number): Promise<void> {
    if (!this.rdbStore) return;

    try {
      await this.rdbStore.executeSql(`PRAGMA user_version = ${version}`);
      console.info(`[DatabaseService] Database version set to ${version}`);
    } catch (error) {
      console.error('[DatabaseService] Failed to set database version:', error);
    }
  }

  /**
   * 执行数据库迁移
   * 每次升级版本时，在这里添加对应的迁移逻辑
   */
  private async migrateDatabase(fromVersion: number, toVersion: number): Promise<void> {
    if (!this.rdbStore) return;

    console.info(`[DatabaseService] Migrating from v${fromVersion} to v${toVersion}`);

    // 逐版本升级
    for (let version = fromVersion; version < toVersion; version++) {
      await this.migrateToVersion(version + 1);
    }
  }

  /**
   * 迁移到指定版本
   * 在这里添加每个版本的迁移逻辑
   */
  private async migrateToVersion(version: number): Promise<void> {
    if (!this.rdbStore) return;

    console.info(`[DatabaseService] Migrating to v${version}`);

    switch (version) {
      case 1:
        // v1: 初始版本，创建基础表
        await this.createTables();
        break;

      case 2:
        // v2: 添加 isFetchFailed 和 lastSuccessfulFetch 字段
        try {
          await this.rdbStore.executeSql('ALTER TABLE podcast ADD COLUMN isFetchFailed INTEGER DEFAULT 0');
        } catch (e) {
          // 字段可能已存在，忽略错误
          console.warn('[DatabaseService] Column isFetchFailed may already exist');
        }
        try {
          await this.rdbStore.executeSql('ALTER TABLE podcast ADD COLUMN lastSuccessfulFetch INTEGER DEFAULT 0');
        } catch (e) {
          // 字段可能已存在，忽略错误
          console.warn('[DatabaseService] Column lastSuccessfulFetch may already exist');
        }
        console.info('[DatabaseService] Added isFetchFailed and lastSuccessfulFetch columns to podcast table');
        break;

      default:
        console.warn(`[DatabaseService] Unknown migration version: ${version}`);
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
          isSubscribed INTEGER DEFAULT 1,
          isFetchFailed INTEGER DEFAULT 0,
          lastSuccessfulFetch INTEGER DEFAULT 0
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
        isSubscribed: podcast.isSubscribed ? 1 : 0,
        isFetchFailed: podcast.isFetchFailed ? 1 : 0,
        lastSuccessfulFetch: podcast.lastSuccessfulFetch
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
   * 搜索单集（支持分页）
   */
  async searchEpisodes(keyword: string, offset: number, limit: number): Promise<EpisodeSearchResult> {
    if (!this.rdbStore) return new EpisodeSearchResult([], 0);

    try {
      // 处理关键词：有空格时拆分为多个关键词（AND关系）
      const keywords = keyword.trim().split(/\s+/).filter(k => k.length > 0);
      
      // 转义关键词中的特殊字符
      const escapeKeyword = (kw: string): string => {
        return kw.replace(/'/g, "''").replace(/%/g, '\\%').replace(/_/g, '\\_');
      };
      
      let whereClause = '';
      if (keywords.length === 1) {
        const escaped = escapeKeyword(keywords[0]);
        whereClause = `(title LIKE '%${escaped}%' OR description LIKE '%${escaped}%')`;
      } else {
        const conditions: string[] = [];
        for (const kw of keywords) {
          const escaped = escapeKeyword(kw);
          conditions.push(`(title LIKE '%${escaped}%' OR description LIKE '%${escaped}%')`);
        }
        whereClause = conditions.join(' AND ');
      }
      
      // 先查总数
      const countSql = `SELECT COUNT(*) as cnt FROM ${Constants.TABLE_EPISODE} WHERE ${whereClause}`;
      console.info(`[DatabaseService] countSql: ${countSql}`);
      const countResult = await this.rdbStore.querySql(countSql);
      let total = 0;
      if (countResult.goToFirstRow()) {
        total = countResult.getLong(countResult.getColumnIndex('cnt'));
      }
      countResult.close();

      // 查询分页数据
      const sql = `SELECT * FROM ${Constants.TABLE_EPISODE} WHERE ${whereClause} ORDER BY pubDate DESC LIMIT ${limit} OFFSET ${offset}`;
      console.info(`[DatabaseService] searchSql: ${sql}`);
      const resultSet = await this.rdbStore.querySql(sql);
      const episodes: Episode[] = [];

      while (resultSet.goToNextRow()) {
        episodes.push(this.parseEpisodeFromResultSet(resultSet));
      }

      resultSet.close();
      console.info(`[DatabaseService] searchEpisodes: keywords=${JSON.stringify(keywords)}, total=${total}, returned=${episodes.length}`);
      return new EpisodeSearchResult(episodes, total);
    } catch (error) {
      console.error('[DatabaseService] searchEpisodes failed:', error);
      return new EpisodeSearchResult([], 0);
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
   * 更新播客获取状态（成功/失败）
   */
  async updatePodcastFetchStatus(podcastId: string, isFetchFailed: boolean, lastSuccessfulFetch?: number): Promise<void> {
    if (!this.rdbStore) return;

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        isFetchFailed: isFetchFailed ? 1 : 0
      };
      if (lastSuccessfulFetch !== undefined) {
        valueBucket.lastSuccessfulFetch = lastSuccessfulFetch;
      }
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_PODCAST);
      predicates.equalTo('id', podcastId);
      await this.rdbStore.update(valueBucket, predicates);
      console.info(`[DatabaseService] Updated podcast ${podcastId} fetch status: isFetchFailed=${isFetchFailed}`);
    } catch (error) {
      console.error('Failed to update podcast fetch status:', error);
    }
  }

  /**
   * 更新Episode下载状态
   */
  async updateEpisodeDownloadStatus(episodeId: string, status: number, progress: number, localPath?: string, fileSize?: number): Promise<void> {
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

      if (fileSize !== undefined && fileSize > 0) {
        valueBucket.fileSize = fileSize;
      }

      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_EPISODE);
      predicates.equalTo('id', episodeId);

      const rows = await this.rdbStore.update(valueBucket, predicates);
      console.info(`[DatabaseService] Updated ${rows} rows for episode ${episodeId}, status: ${status}, progress: ${progress}, localPath: ${localPath || 'none'}, fileSize: ${fileSize || 'none'}`);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error('[DatabaseService] Failed to update episode download status:', errMsg);
      throw new Error(`Failed to update episode download status: ${errMsg}`);
    }
  }

  /**
   * 标记单集为已播放
   */
  async markEpisodeAsPlayed(episodeId: string): Promise<void> {
    if (!this.rdbStore) {
      console.error('[DatabaseService] rdbStore is null');
      return;
    }

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        isPlayed: 1
      };

      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_EPISODE);
      predicates.equalTo('id', episodeId);

      const rows = await this.rdbStore.update(valueBucket, predicates);
      console.info(`[DatabaseService] Marked episode ${episodeId} as played, updated ${rows} rows`);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error('[DatabaseService] Failed to mark episode as played:', errMsg);
    }
  }

  private parsePodcastFromResultSet(resultSet: relationalStore.ResultSet): Podcast {
    let podcast = new Podcast();
    try {
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
            // 安全获取新字段（兼容旧版数据库）
            try {
              podcast.isFetchFailed = resultSet.getLong(resultSet.getColumnIndex('isFetchFailed')) === 1;
              podcast.lastSuccessfulFetch = resultSet.getLong(resultSet.getColumnIndex('lastSuccessfulFetch'));
            } catch (e) {
              // 旧版数据库可能没有这些字段
              podcast.isFetchFailed = false;
              podcast.lastSuccessfulFetch = 0;
            }
    } catch (error) {
      console.error('[DatabaseService] Failed to parse podcast from result set:', error);
    }
    return podcast;
  }

  private parseEpisodeFromResultSet(resultSet: relationalStore.ResultSet): Episode {
    let episode = new Episode();
    try {
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
    } catch (error) {
      console.error('[DatabaseService] Failed to parse episode from result set:', error);
    }
    return episode;
  }

  /**
   * 添加到待听队列
   */
  async addToQueue(episodeId: string): Promise<void> {
    if (!this.rdbStore) return;

    try {
      // 检查是否已在队列中
      const checkPredicates = new relationalStore.RdbPredicates(Constants.TABLE_QUEUE);
      checkPredicates.equalTo('episodeId', episodeId);
      const existResult = await this.rdbStore.query(checkPredicates);
      const exists = existResult.rowCount > 0;
      existResult.close();
      
      if (exists) {
        console.info(`[DatabaseService] Episode ${episodeId} already in queue`);
        return;
      }

      // 获取当前最大位置
      const resultSet = await this.rdbStore.querySql(`SELECT MAX(position) as maxPos FROM ${Constants.TABLE_QUEUE}`);
      let nextPosition = 0;
      if (resultSet.goToFirstRow()) {
        nextPosition = (resultSet.getLong(0) || 0) + 1;
      }
      resultSet.close();

      const valueBucket: relationalStore.ValuesBucket = {
        id: `queue_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        episodeId: episodeId,
        position: nextPosition,
        addedDate: Date.now()
      };

      await this.rdbStore.insert(Constants.TABLE_QUEUE, valueBucket);
      console.info(`[DatabaseService] Added episode ${episodeId} to queue at position ${nextPosition}`);
    } catch (error) {
      console.error('[DatabaseService] Failed to add to queue:', error);
    }
  }

  /**
   * 从队列中移除
   */
  async removeFromQueue(episodeId: string): Promise<void> {
    if (!this.rdbStore) return;

    try {
      const predicates = new relationalStore.RdbPredicates(Constants.TABLE_QUEUE);
      predicates.equalTo('episodeId', episodeId);
      await this.rdbStore.delete(predicates);
      console.info(`[DatabaseService] Removed episode ${episodeId} from queue`);
    } catch (error) {
      console.error('[DatabaseService] Failed to remove from queue:', error);
    }
  }

  /**
   * 获取队列中的所有Episode
   */
  async getQueueEpisodes(): Promise<Episode[]> {
    if (!this.rdbStore) return [];

    try {
      // 联合查询获取队列中的Episode
      const sql = `
        SELECT e.* FROM ${Constants.TABLE_EPISODE} e
        INNER JOIN ${Constants.TABLE_QUEUE} q ON e.id = q.episodeId
        ORDER BY q.position ASC
      `;
      const resultSet = await this.rdbStore.querySql(sql);
      const episodes: Episode[] = [];

      while (resultSet.goToNextRow()) {
        episodes.push(this.parseEpisodeFromResultSet(resultSet));
      }

      resultSet.close();
      return episodes;
    } catch (error) {
      console.error('[DatabaseService] Failed to get queue episodes:', error);
      return [];
    }
  }

  /**
   * 清空队列
   */
  async clearQueue(): Promise<void> {
    if (!this.rdbStore) return;

    try {
      await this.rdbStore.executeSql(`DELETE FROM ${Constants.TABLE_QUEUE}`);
      console.info('[DatabaseService] Queue cleared');
    } catch (error) {
      console.error('[DatabaseService] Failed to clear queue:', error);
    }
  }
}
