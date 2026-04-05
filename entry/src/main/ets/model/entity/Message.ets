import { User } from './User';

/**
 * 消息类型
 */
export enum MessageType {
  SYSTEM = 'system',
  PRIVATE = 'private',
  REPLY = 'reply',
  AT = 'at'
}

/**
 * 消息类
 */
export class Message {
  mid: string = '';
  type: MessageType = MessageType.PRIVATE;
  title: string = '';
  content: string = '';
  sender: User = new User();
  receiver: User = new User();
  sendTime: string = '';
  readTime: string = '';
  isRead: boolean = false;
  tid: string = '';
  pid: string = '';

  constructor() {}

  getFormattedTime(): string {
    if (!this.sendTime) return '';
    const time = parseInt(this.sendTime) * 1000;
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
 * 消息列表
 */
export class MessageList {
  messages: Message[] = [];
  page: number = 1;
  totalPages: number = 1;
  totalCount: number = 0;
  unreadCount: number = 0;
  hasMore: boolean = false;

  constructor() {}
}
