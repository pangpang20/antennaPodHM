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
    const config: relationalStore.StoreConfig = {
      name: Constants.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    this.rdbStore = await relationalStore.getRdbStore(context, config);
    await this.createTables();
  }

  /**
   * 创建数据库表
   */
  private async createTables(): Promise<void> {
    if (!this.rdbStore) return;

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
  }

  /**
   * 插入播客
   */
  async insertPodcast(podcast: Podcast): Promise<number> {
    if (!this.rdbStore) return -1;

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
  }

  /**
   * 查询所有订阅的播客
   */
  async querySubscribedPodcasts(): Promise<Podcast[]> {
    if (!this.rdbStore) return [];

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
  }

  /**
   * 插入Episode
   */
  async insertEpisode(episode: Episode): Promise<number> {
    if (!this.rdbStore) return -1;

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
  }

  /**
   * 根据播客ID查询Episodes
   */
  async queryEpisodesByPodcastId(podcastId: string): Promise<Episode[]> {
    if (!this.rdbStore) return [];

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
  }

  /**
   * 更新Episode下载状态
   */
  async updateEpisodeDownloadStatus(episodeId: string, status: number, progress: number, localPath?: string): Promise<void> {
    if (!this.rdbStore) return;

    const valueBucket: relationalStore.ValuesBucket = {
      downloadStatus: status,
      downloadProgress: progress
    };

    if (localPath) {
      valueBucket.localPath = localPath;
    }

    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_EPISODE);
    predicates.equalTo('id', episodeId);

    await this.rdbStore.update(valueBucket, predicates);
  }

  private parsePodcastFromResultSet(resultSet: relationalStore.ResultSet): Podcast {
    return new Podcast({
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      author: resultSet.getString(resultSet.getColumnIndex('author')),
      description: resultSet.getString(resultSet.getColumnIndex('description')),
      imageUrl: resultSet.getString(resultSet.getColumnIndex('imageUrl')),
      feedUrl: resultSet.getString(resultSet.getColumnIndex('feedUrl')),
      link: resultSet.getString(resultSet.getColumnIndex('link')),
      language: resultSet.getString(resultSet.getColumnIndex('language')),
      category: resultSet.getString(resultSet.getColumnIndex('category')),
      subscribeDate: resultSet.getLong(resultSet.getColumnIndex('subscribeDate')),
      lastUpdate: resultSet.getLong(resultSet.getColumnIndex('lastUpdate')),
      episodeCount: resultSet.getLong(resultSet.getColumnIndex('episodeCount')),
      isSubscribed: resultSet.getLong(resultSet.getColumnIndex('isSubscribed')) === 1
    });
  }

  private parseEpisodeFromResultSet(resultSet: relationalStore.ResultSet): Episode {
    return new Episode({
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      podcastId: resultSet.getString(resultSet.getColumnIndex('podcastId')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      description: resultSet.getString(resultSet.getColumnIndex('description')),
      link: resultSet.getString(resultSet.getColumnIndex('link')),
      audioUrl: resultSet.getString(resultSet.getColumnIndex('audioUrl')),
      imageUrl: resultSet.getString(resultSet.getColumnIndex('imageUrl')),
      duration: resultSet.getLong(resultSet.getColumnIndex('duration')),
      fileSize: resultSet.getLong(resultSet.getColumnIndex('fileSize')),
      pubDate: resultSet.getLong(resultSet.getColumnIndex('pubDate')),
      downloadStatus: resultSet.getLong(resultSet.getColumnIndex('downloadStatus')),
      downloadProgress: resultSet.getLong(resultSet.getColumnIndex('downloadProgress')),
      localPath: resultSet.getString(resultSet.getColumnIndex('localPath')),
      playbackPosition: resultSet.getLong(resultSet.getColumnIndex('playbackPosition')),
      isPlayed: resultSet.getLong(resultSet.getColumnIndex('isPlayed')) === 1,
      isFavorite: resultSet.getLong(resultSet.getColumnIndex('isFavorite')) === 1,
      addedToQueueDate: resultSet.getLong(resultSet.getColumnIndex('addedToQueueDate'))
    });
  }
}
