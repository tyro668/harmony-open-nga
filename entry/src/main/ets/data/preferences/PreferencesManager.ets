import preferences from '@ohos.data.preferences';
import { AppConstants } from '../../common/constants/AppConstants';

/**
 * 偏好设置管理器
 */
export class PreferencesManager {
  private static instance: PreferencesManager;
  private preferences: preferences.Preferences | null = null;
  private context: Context | null = null;

  private constructor() {}

  /**
   * 获取单例
   */
  static getInstance(): PreferencesManager {
    if (!PreferencesManager.instance) {
      PreferencesManager.instance = new PreferencesManager();
    }
    return PreferencesManager.instance;
  }

  /**
   * 初始化
   */
  async init(context: Context): Promise<void> {
    this.context = context;
    try {
      this.preferences = await preferences.getPreferences(context, AppConstants.PREF_USER_INFO);
    } catch (error) {
      console.error('Failed to init preferences:', error);
    }
  }

  /**
   * 获取字符串值
   */
  async getString(key: string, defaultValue: string = ''): Promise<string> {
    if (!this.preferences) {
      return defaultValue;
    }
    try {
      return await this.preferences.get(key, defaultValue) as string;
    } catch (error) {
      console.error('Failed to get string:', error);
      return defaultValue;
    }
  }

  /**
   * 获取数字值
   */
  async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    if (!this.preferences) {
      return defaultValue;
    }
    try {
      return await this.preferences.get(key, defaultValue) as number;
    } catch (error) {
      console.error('Failed to get number:', error);
      return defaultValue;
    }
  }

  /**
   * 获取布尔值
   */
  async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
    if (!this.preferences) {
      return defaultValue;
    }
    try {
      return await this.preferences.get(key, defaultValue) as boolean;
    } catch (error) {
      console.error('Failed to get boolean:', error);
      return defaultValue;
    }
  }

  /**
   * 获取对象值
   */
  async getObject<T>(key: string, defaultValue: T | null = null): Promise<T | null> {
    if (!this.preferences) {
      return defaultValue;
    }
    try {
      const str = await this.preferences.get(key, '') as string;
      if (str) {
        return JSON.parse(str) as T;
      }
      return defaultValue;
    } catch (error) {
      console.error('Failed to get object:', error);
      return defaultValue;
    }
  }

  /**
   * 获取字符串数组
   */
  async getStringArray(key: string): Promise<string[]> {
    if (!this.preferences) {
      return [];
    }
    try {
      const str = await this.preferences.get(key, '') as string;
      if (str) {
        return JSON.parse(str) as string[];
      }
      return [];
    } catch (error) {
      console.error('Failed to get string array:', error);
      return [];
    }
  }

  /**
   * 保存字符串值
   */
  async putString(key: string, value: string): Promise<boolean> {
    if (!this.preferences) {
      return false;
    }
    try {
      await this.preferences.put(key, value);
      await this.preferences.flush();
      return true;
    } catch (error) {
      console.error('Failed to put string:', error);
      return false;
    }
  }

  /**
   * 保存数字值
   */
  async putNumber(key: string, value: number): Promise<boolean> {
    if (!this.preferences) {
      return false;
    }
    try {
      await this.preferences.put(key, value);
      await this.preferences.flush();
      return true;
    } catch (error) {
      console.error('Failed to put number:', error);
      return false;
    }
  }

  /**
   * 保存布尔值
   */
  async putBoolean(key: string, value: boolean): Promise<boolean> {
    if (!this.preferences) {
      return false;
    }
    try {
      await this.preferences.put(key, value);
      await this.preferences.flush();
      return true;
    } catch (error) {
      console.error('Failed to put boolean:', error);
      return false;
    }
  }

  /**
   * 保存对象值
   */
  async putObject<T>(key: string, value: T): Promise<boolean> {
    if (!this.preferences) {
      return false;
    }
    try {
      const str = JSON.stringify(value);
      await this.preferences.put(key, str);
      await this.preferences.flush();
      return true;
    } catch (error) {
      console.error('Failed to put object:', error);
      return false;
    }
  }

  /**
   * 保存字符串数组
   */
  async putStringArray(key: string, value: string[]): Promise<boolean> {
    if (!this.preferences) {
      return false;
    }
    try {
      const str = JSON.stringify(value);
      await this.preferences.put(key, str);
      await this.preferences.flush();
      return true;
    } catch (error) {
      console.error('Failed to put string array:', error);
      return false;
    }
  }

  /**
   * 删除值
   */
  async remove(key: string): Promise<boolean> {
    if (!this.preferences) {
      return false;
    }
    try {
      await this.preferences.delete(key);
      await this.preferences.flush();
      return true;
    } catch (error) {
      console.error('Failed to remove:', error);
      return false;
    }
  }

  /**
   * 清空所有数据
   */
  async clear(): Promise<boolean> {
    if (!this.preferences) {
      return false;
    }
    try {
      await this.preferences.clear();
      await this.preferences.flush();
      return true;
    } catch (error) {
      console.error('Failed to clear:', error);
      return false;
    }
  }

  /**
   * 检查是否存在
   */
  async has(key: string): Promise<boolean> {
    if (!this.preferences) {
      return false;
    }
    try {
      return await this.preferences.has(key);
    } catch (error) {
      console.error('Failed to check has:', error);
      return false;
    }
  }
}

// 导出默认实例
export const preferencesManager = PreferencesManager.getInstance();
