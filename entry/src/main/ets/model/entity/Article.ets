import { User } from './User';

/**
 * 附件类型
 */
export enum AttachmentType {
  IMAGE = 'image',
  VIDEO = 'video',
  AUDIO = 'audio',
  FILE = 'file'
}

/**
 * 附件
 */
export class Attachment {
  id: string = '';
  url: string = '';
  name: string = '';
  type: AttachmentType = AttachmentType.FILE;
  size: number = 0;
  width: number = 0;
  height: number = 0;
  thumbUrl: string = '';

  constructor() {}

  isImage(): boolean {
    return this.type === AttachmentType.IMAGE;
  }
}

/**
 * 文章/评论类
 */
export class Article {
  pid: string = '';
  tid: string = '';
  fid: string = '';
  floor: number = 0;
  author: User = new User();
  content: string = '';
  postDate: string = '';
  likes: number = 0;
  isLiked: boolean = false;
  voteValue: number = 0;
  isVoting: boolean = false;
  attachments: Attachment[] = [];
  replyTo: string = '';
  replyToFloor: number = 0;
  isAuthor: boolean = false;
  isDeleted: boolean = false;
  noteInfo: string = '';

  constructor() {}

  getFormattedTime(): string {
    if (!this.postDate) return '';
    const parsed = parseInt(this.postDate);
    // 若 parseInt 结果 < 100000000 则不是有效 unix 时间戳（如解析了 '2026-04-05' 得到 2026）
    if (isNaN(parsed) || parsed < 100000000) {
      // postdate 本身是格式化的日期字符串，直接返回
      return this.postDate;
    }
    const time = parsed * 1000;
    const now = Date.now();
    const diff = now - time;

    if (diff < 60000) return '刚刚';
    if (diff < 3600000) return Math.floor(diff / 60000) + '分钟前';
    if (diff < 86400000) return Math.floor(diff / 3600000) + '小时前';
    if (diff < 604800000) return Math.floor(diff / 86400000) + '天前';

    const date = new Date(time);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hours = date.getHours();
    const minutes = date.getMinutes();
    return month + '-' + day + ' ' + (hours < 10 ? '0' : '') + hours + ':' + (minutes < 10 ? '0' : '') + minutes;
  }

  hasAttachments(): boolean {
    return this.attachments.length > 0;
  }

  getImageAttachments(): Attachment[] {
    const result: Attachment[] = [];
    for (let i = 0; i < this.attachments.length; i++) {
      if (this.attachments[i].isImage()) {
        result.push(this.attachments[i]);
      }
    }
    return result;
  }
}

/**
 * 文章列表
 */
export class ArticleList {
  articles: Article[] = [];
  tid: string = '';
  subject: string = '';
  page: number = 1;
  totalPages: number = 1;
  totalCount: number = 0;
  hasMore: boolean = false;
  errorMsg: string = '';

  constructor() {}
}
