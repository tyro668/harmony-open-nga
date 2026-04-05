import { User } from './User';

/**
 * 主题类
 */
export class Topic {
  tid: string = '';
  fid: string = '';
  forumName: string = '';
  author: User = new User();
  subject: string = '';
  content: string = '';
  postDate: string = '';
  lastPostDate: string = '';
  replies: number = 0;
  views: number = 0;
  likes: number = 0;
  isTop: boolean = false;
  isDigest: boolean = false;
  isHot: boolean = false;
  isClosed: boolean = false;
  hasAttachment: boolean = false;
  hasImage: boolean = false;
  lastPoster: string = '';
  tags: string[] = [];
  page: number = 1;
  totalPages: number = 1;

  constructor() {}

  getFormattedTime(): string {
    if (!this.postDate) return '';
    const time = parseInt(this.postDate) * 1000;
    const now = Date.now();
    const diff = now - time;

    if (diff < 60000) return '刚刚';
    if (diff < 3600000) return Math.floor(diff / 60000) + '分钟前';
    if (diff < 86400000) return Math.floor(diff / 3600000) + '小时前';
    if (diff < 604800000) return Math.floor(diff / 86400000) + '天前';

    const date = new Date(time);
    return (date.getMonth() + 1) + '-' + date.getDate();
  }
}

/**
 * 主题列表
 */
export class TopicList {
  topics: Topic[] = [];
  page: number = 1;
  totalPages: number = 1;
  totalCount: number = 0;
  hasMore: boolean = false;
  errorMsg: string = '';

  constructor() {}
}
