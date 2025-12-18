/**
 * Episode实体类
 */
export enum DownloadStatus {
  NOT_DOWNLOADED = 0,
  DOWNLOADING = 1,
  DOWNLOADED = 2,
  FAILED = 3
}

export class Episode {
  id: string = '';
  podcastId: string = '';
  title: string = '';
  description: string = '';
  link: string = '';
  audioUrl: string = '';
  imageUrl: string = '';
  duration: number = 0; // 时长（秒）
  fileSize: number = 0; // 文件大小（字节）
  pubDate: number = 0; // 发布时间戳
  downloadStatus: DownloadStatus = DownloadStatus.NOT_DOWNLOADED;
  downloadProgress: number = 0; // 下载进度 0-100
  localPath: string = ''; // 本地文件路径
  playbackPosition: number = 0; // 播放位置（秒）
  isPlayed: boolean = false; // 是否已播放
  isFavorite: boolean = false; // 是否收藏
  addedToQueueDate: number = 0; // 添加到队列的时间

  /**
   * 格式化时长显示
   */
  getFormattedDuration(): string {
    const hours = Math.floor(this.duration / 3600);
    const minutes = Math.floor((this.duration % 3600) / 60);
    const seconds = this.duration % 60;

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    } else {
      return `${minutes}:${seconds.toString().padStart(2, '0')}`;
    }
  }

  /**
   * 格式化文件大小
   */
  getFormattedFileSize(): string {
    if (this.fileSize < 1024) {
      return `${this.fileSize} B`;
    } else if (this.fileSize < 1024 * 1024) {
      return `${(this.fileSize / 1024).toFixed(2)} KB`;
    } else if (this.fileSize < 1024 * 1024 * 1024) {
      return `${(this.fileSize / (1024 * 1024)).toFixed(2)} MB`;
    } else {
      return `${(this.fileSize / (1024 * 1024 * 1024)).toFixed(2)} GB`;
    }
  }

  /**
   * 格式化发布日期
   */
  getFormattedPubDate(): string {
    if (!this.pubDate) {
      return '';
    }
    const date = new Date(this.pubDate);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
