import { Board, BoardCategory } from '../../model/entity/Board';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';

/**
 * JSON数据类型定义
 */
interface BoardData {
  fid: number;
  name: string;
  info?: string;
  infoL?: string;
  stid?: number;
}

interface SubCategoryData {
  name: string;
  content?: BoardData[];
}

interface CategoryData {
  id?: string;
  name: string;
  sub?: SubCategoryData[];
}

/**
 * 版块管理器
 */
export class BoardManager {
  private static instance: BoardManager;
  private categories: BoardCategory[] = [];
  private bookmarkBoards: Board[] = [];
  private readonly KEY_BOOKMARK: string = 'bookmark_boards';

  private constructor() {}

  static getInstance(): BoardManager {
    if (!BoardManager.instance) {
      BoardManager.instance = new BoardManager();
    }
    return BoardManager.instance;
  }

  /**
   * 初始化版块数据
   */
  async init(): Promise<void> {
    // 从JSON文件加载版块数据
    this.categories = await this.loadCategoriesFromJson();
    // 加载收藏
    await this.loadBookmarks();
  }

  /**
   * 从JSON文件加载版块分类
   */
  private async loadCategoriesFromJson(): Promise<BoardCategory[]> {
    try {
      // 读取JSON配置文件
      const context = getContext(this);
      const resMgr = context.resourceManager;
      const jsonData = await resMgr.getRawFileContent('category.json');
      
      // 使用TextDecoder正确解码UTF-8数据
      const textDecoder = util.TextDecoder.create('utf-8');
      const jsonStr = textDecoder.decodeToString(jsonData);
      
      const categoriesData = JSON.parse(jsonStr) as CategoryData[];

      const categories: BoardCategory[] = [];

      // 解析JSON数据
      for (const categoryData of categoriesData) {
        const category = new BoardCategory();
        category.id = categoryData.id || '';
        category.name = categoryData.name || '';
        category.boards = [];
        category.subCategories = [];

        // 解析子分类
        if (categoryData.sub && Array.isArray(categoryData.sub)) {
          for (const subData of categoryData.sub) {
            const subCategory = new BoardCategory();
            subCategory.name = subData.name || '';
            subCategory.boards = [];

            // 解析板块列表
            if (subData.content && Array.isArray(subData.content)) {
              for (const boardData of subData.content) {
                const board = new Board();
                board.id = String(boardData.fid || 0);
                board.stid = String(boardData.stid || 0);
                board.name = boardData.name || '';
                board.description = boardData.info || boardData.infoL || '';
                subCategory.boards.push(board);
              }
            }

            category.subCategories.push(subCategory);
          }
        }

        categories.push(category);
      }

      return categories;
    } catch (error) {
      console.error('Failed to load categories from JSON:', error);
      // 如果加载失败，返回空数组
      return [];
    }
  }

  /**
   * 获取所有版块分类
   */
  getCategories(): BoardCategory[] {
    return this.categories;
  }

  /**
   * 获取收藏版块
   */
  getBookmarks(): Board[] {
    return this.bookmarkBoards;
  }

  /**
   * 判断是否已收藏
   */
  isBookmark(fid: string, stid: string): boolean {
    for (let i = 0; i < this.bookmarkBoards.length; i++) {
      const board = this.bookmarkBoards[i];
      if (board.id === fid && board.stid === stid) {
        return true;
      }
    }
    return false;
  }

  /**
   * 添加收藏
   */
  async addBookmark(board: Board): Promise<void> {
    if (!this.isBookmark(board.id, board.stid)) {
      this.bookmarkBoards.push(board);
      await this.saveBookmarks();
    }
  }

  /**
   * 移除收藏
   */
  async removeBookmark(fid: string, stid: string): Promise<void> {
    for (let i = 0; i < this.bookmarkBoards.length; i++) {
      const board = this.bookmarkBoards[i];
      if (board.id === fid && board.stid === stid) {
        this.bookmarkBoards.splice(i, 1);
        break;
      }
    }
    await this.saveBookmarks();
  }

  /**
   * 加载收藏
   */
  private async loadBookmarks(): Promise<void> {
    try {
      const jsonStr = await PreferencesManager.getInstance().getString(this.KEY_BOOKMARK);
      if (jsonStr != '') {
        const list: Board[] = JSON.parse(jsonStr);
        this.bookmarkBoards = list;
      }
    } catch (err) {
      console.error('Load bookmarks failed:', err);
    }
  }

  /**
   * 保存收藏
   */
  private async saveBookmarks(): Promise<void> {
    try {
      const jsonStr = JSON.stringify(this.bookmarkBoards);
      await PreferencesManager.getInstance().putString(this.KEY_BOOKMARK, jsonStr);
    } catch (err) {
      console.error('Save bookmarks failed:', err);
    }
  }

}

export const boardManager = BoardManager.getInstance();
