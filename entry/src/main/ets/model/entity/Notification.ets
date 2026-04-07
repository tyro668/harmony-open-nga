/**
 * 通知项
 */
export class NotificationItem {
  type: number = 0;
  userId: string = '';
  userName: string = '';
  title: string = '';
  pidStr: string = '';
  tidStr: string = '';
  midStr: string = '';
  timeStamp: string = '';
  timeText: string = '';
  isUnread: boolean = false;
  isMessageNotice: boolean = false;
}

/**
 * 通知列表
 */
export class NotificationList {
  notifications: NotificationItem[] = [];
  unreadCount: number = 0;
  errorMsg: string = '';
}
