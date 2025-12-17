import request from '@ohos.request';
import { Episode, DownloadStatus } from '../model/Episode';
import { DatabaseService } from './DatabaseService';
import { Constants } from '../common/Constants';
import fs from '@ohos.file.fs';

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
  private dbService: DatabaseService;

  private constructor() {
    this.dbService = DatabaseService.getInstance();
  }

  static getInstance(): DownloadService {
    if (!DownloadService.instance) {
      DownloadService.instance = new DownloadService();
    }
    return DownloadService.instance;
  }

  /**
   * 下载Episode
   */
  async downloadEpisode(episode: Episode, savePath: string): Promise<void> {
    if (this.downloadTasks.has(episode.id)) {
      console.warn('Episode is already downloading');
      return;
    }

    try {
      const downloadConfig: request.DownloadConfig = {
        url: episode.audioUrl,
        filePath: savePath,
        enableMetered: false, // 非计费网络下载
        enableRoaming: false, // 不允许漫游下载
        description: `Downloading ${episode.title}`,
        networkType: request.NETWORK_MOBILE | request.NETWORK_WIFI,
        title: episode.title
      };

      const downloadTask = await request.downloadFile(getContext(), downloadConfig);
      const taskId = Date.now();

      this.downloadTasks.set(episode.id, {
        episode,
        taskId,
        downloadTask
      });

      // 更新数据库状态
      episode.downloadStatus = DownloadStatus.DOWNLOADING;
      await this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.DOWNLOADING, 0);

      // 监听下载进度
      downloadTask.on('progress', (receivedSize: number, totalSize: number) => {
        const progress = Math.floor((receivedSize / totalSize) * 100);
        episode.downloadProgress = progress;
        this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.DOWNLOADING, progress);
      });

      // 监听下载完成
      downloadTask.on('complete', () => {
        episode.downloadStatus = DownloadStatus.DOWNLOADED;
        episode.downloadProgress = 100;
        episode.localPath = savePath;
        this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.DOWNLOADED, 100, savePath);
        this.downloadTasks.delete(episode.id);
      });

      // 监听下载失败
      downloadTask.on('fail', (err: number) => {
        console.error('Download failed:', err);
        episode.downloadStatus = DownloadStatus.FAILED;
        this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.FAILED, episode.downloadProgress);
        this.downloadTasks.delete(episode.id);
      });

    } catch (error) {
      console.error('Failed to start download:', error);
      episode.downloadStatus = DownloadStatus.FAILED;
      await this.dbService.updateEpisodeDownloadStatus(episode.id, DownloadStatus.FAILED, 0);
    }
  }

  /**
   * 暂停下载
   */
  async pauseDownload(episodeId: string): Promise<void> {
    const task = this.downloadTasks.get(episodeId);
    if (task) {
      await task.downloadTask.suspend();
    }
  }

  /**
   * 恢复下载
   */
  async resumeDownload(episodeId: string): Promise<void> {
    const task = this.downloadTasks.get(episodeId);
    if (task) {
      await task.downloadTask.restore();
    }
  }

  /**
   * 取消下载
   */
  async cancelDownload(episodeId: string): Promise<void> {
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
