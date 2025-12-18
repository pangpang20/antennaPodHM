import request from '@ohos.request';
import { Episode, DownloadStatus } from '../model/Episode';
import { DatabaseService } from './DatabaseService';
import { Constants } from '../common/Constants';
import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';

/**
 * 下载任务信息
 */
interface DownloadTask {
  episode: Episode;
  taskId: number;
  downloadTask: request.DownloadTask;
}

/**
 * 下载服务
 */
export class DownloadService {
  private static instance: DownloadService;
  private downloadTasks: Map<string, DownloadTask> = new Map();
  private downloadQueue: Episode[] = []; // 下载队列
  private dbService: DatabaseService;
  private readonly MAX_CONCURRENT_DOWNLOADS = 5; // 最大并发下载数
  private activeDownloads = 0;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
    this.dbService = DatabaseService.getInstance();
  }

  static getInstance(): DownloadService {
    if (!DownloadService.instance) {
      DownloadService.instance = new DownloadService();
    }
    return DownloadService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 下载Episode
   */
  async downloadEpisode(episode: Episode): Promise<void> {
    // 如果已经在下载或队列中，直接返回
    if (this.downloadTasks.has(episode.id) || this.downloadQueue.find(e => e.id === episode.id)) {
      console.warn('Episode is already downloading or in queue');
      return;
    }

    // 如果已下载，直接返回
    if (episode.downloadStatus === DownloadStatus.DOWNLOADED) {
      return;
    }

    // 添加到队列
    this.downloadQueue.push(episode);
    console.info(`[DownloadService] Added to queue: ${episode.title}, queue size: ${this.downloadQueue.length}`);

    // 尝试启动下载
    this.processQueue();
  }

  /**
   * 处理下载队列
   */
  private processQueue(): void {
    // 如果正在下载的任务数已达到上限，就不启动新的
    while (this.activeDownloads < this.MAX_CONCURRENT_DOWNLOADS && this.downloadQueue.length > 0) {
      const episode = this.downloadQueue.shift();
      if (episode) {
        this.startDownload(episode);
      }
    }
  }

  /**
   * 开始下载
   */
  private async startDownload(episode: Episode): Promise<void> {
    if (!this.context) {
      console.error('Context not set, cannot start download');
      return;
    }

    try {
      // 生成保存路径
      const fileName = `${episode.id}.m4a`;
      const savePath = `${this.context.filesDir}/${fileName}`;

      const downloadConfig: request.DownloadConfig = {
        url: episode.audioUrl,
        filePath: savePath,
        enableMetered: false,
        enableRoaming: false,
        description: `Downloading ${episode.title}`,
        networkType: request.NETWORK_MOBILE | request.NETWORK_WIFI,
        title: episode.title
      };

      const downloadTask = await request.downloadFile(this.context, downloadConfig);
      const taskId = Date.now();

      this.downloadTasks.set(episode.id, {
        episode,
        taskId,
        downloadTask
      });

      this.activeDownloads++;
      console.info(`[DownloadService] Started download: ${episode.title}, active: ${this.activeDownloads}`);

      // 更新数据库状态
      episode.downloadStatus = DownloadStatus.DOWNLOADING;
      await this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.DOWNLOADING, 0);

      // 监听下载进度
      downloadTask.on('progress', (receivedSize: number, totalSize: number) => {
        const progress = Math.floor((receivedSize / totalSize) * 100);
        episode.downloadProgress = progress;
        episode.fileSize = totalSize;
        this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.DOWNLOADING, progress);
      });

      // 监听下载完成
      downloadTask.on('complete', () => {
        console.info(`[DownloadService] Download completed: ${episode.title}`);
        episode.downloadStatus = DownloadStatus.DOWNLOADED;
        episode.downloadProgress = 100;
        episode.localPath = savePath;
        this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.DOWNLOADED, 100, savePath);
        this.downloadTasks.delete(episode.id);
        this.activeDownloads--;
        // 继续处理队列
        this.processQueue();
      });

      // 监听下载失败
      downloadTask.on('fail', (err: number) => {
        console.error('Download failed:', err);
        episode.downloadStatus = DownloadStatus.FAILED;
        this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.FAILED, episode.downloadProgress);
        this.downloadTasks.delete(episode.id);
        this.activeDownloads--;
        // 继续处理队列
        this.processQueue();
      });

    } catch (error) {
      console.error('Failed to start download:', error);
      episode.downloadStatus = DownloadStatus.FAILED;
      await this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.FAILED, 0);
      this.activeDownloads--;
      // 继续处理队列
      this.processQueue();
    }
  }

  /**
   * 暂停下载
   */
  async pauseDownload(episodeId: string): Promise<void> {
    try {
      const task = this.downloadTasks.get(episodeId);
      if (task) {
        await task.downloadTask.suspend();
      }
    } catch (error) {
      console.error('Failed to pause download:', error);
    }
  }

  /**
   * 恢复下载
   */
  async resumeDownload(episodeId: string): Promise<void> {
    try {
      const task = this.downloadTasks.get(episodeId);
      if (task) {
        await task.downloadTask.restore();
      }
    } catch (error) {
      console.error('Failed to resume download:', error);
    }
  }

  /**
   * 取消下载
   */
  async cancelDownload(episodeId: string): Promise<void> {
    try {
      const task = this.downloadTasks.get(episodeId);
      if (task) {
        await task.downloadTask.delete();
        this.downloadTasks.delete(episodeId);
        
        // 更新数据库状态
        await this.dbService.updateEpisodeDownloadStatus(
          episodeId,
          DownloadStatus.NOT_DOWNLOADED,
          0
        );
      }
    } catch (error) {
      console.error('Failed to cancel download:', error);
    }
  }

  /**
   * 删除已下载文件
   */
  async deleteDownloadedFile(episode: Episode): Promise<void> {
    if (episode.localPath) {
      try {
        // 删除文件
        await fs.unlink(episode.localPath);
        
        // 更新数据库
        episode.downloadStatus = DownloadStatus.NOT_DOWNLOADED;
        episode.localPath = '';
        await this.dbService.updateEpisodeDownloadStatus(
          episode.id,
          DownloadStatus.NOT_DOWNLOADED,
          0,
          ''
        );
      } catch (error) {
        console.error('Failed to delete file:', error);
      }
    }
  }

  /**
   * 获取下载任务状态
   */
  getDownloadTask(episodeId: string): DownloadTask | undefined {
    return this.downloadTasks.get(episodeId);
  }

  /**
   * 获取所有下载任务
   */
  getAllDownloadTasks(): DownloadTask[] {
    return Array.from(this.downloadTasks.values());
  }
}
