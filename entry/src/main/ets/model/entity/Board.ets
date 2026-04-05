/**
 * 版块类
 */
export class Board {
  id: string = '';
  stid: string = '0';  // 子版块ID
  name: string = '';
  description: string = '';
  icon: string = '';
  parentId: string = '';
  sortOrder: number = 0;
  topicCount: number = 0;
  postCount: number = 0;
  todayPosts: number = 0;
  lastPost: string = '';
  lastPostTime: string = '';
  isFavorite: boolean = false;
  isVisible: boolean = true;

  constructor() {}

  /**
   * 获取唯一标识
   */
  getKey(): string {
    return this.id + '_' + this.stid;
  }
}

/**
 * 版块分类
 */
export class BoardCategory {
  id: string = '';
  name: string = '';
  boards: Board[] = [];
  subCategories: BoardCategory[] = [];

  constructor() {}
}
