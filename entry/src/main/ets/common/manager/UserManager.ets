import { User } from '../../model/entity/User';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { HttpClient } from '../../network/api/HttpClient';
import { AppConstants } from '../constants/AppConstants';

/**
 * 用户状态
 */
export enum UserState {
  NOT_LOGGED_IN = 'not_logged_in',
  LOGGING_IN = 'logging_in',
  LOGGED_IN = 'logged_in',
  LOGIN_FAILED = 'login_failed'
}

/**
 * 用户管理器
 */
export class UserManager {
  private static instance: UserManager;
  private currentUser: User | null = null;
  private userState: UserState = UserState.NOT_LOGGED_IN;
  private onUserChanged: ((user: User | null) => void) | null = null;
  private initialized: boolean = false;

  private constructor() {}

  static getInstance(): UserManager {
    if (!UserManager.instance) {
      UserManager.instance = new UserManager();
    }
    return UserManager.instance;
  }

  async init(): Promise<void> {
    if (this.initialized) {
      return;
    }

    const uid = await PreferencesManager.getInstance().getString('uid');
    const cid = await PreferencesManager.getInstance().getString('cid');
    const userName = await PreferencesManager.getInstance().getString('userName');

    if (uid != '' && cid != '') {
      this.currentUser = new User();
      this.currentUser.uid = uid;
      this.currentUser.username = userName;
      this.currentUser.nickname = userName;
      this.userState = UserState.LOGGED_IN;

      const cookie = 'ngaPassportUid=' + uid + '; ngaPassportCid=' + cid;
      HttpClient.getInstance().setCookie(cookie);
      console.info('UserManager: restored login for uid=' + uid + ', userName=' + userName);
    }

    this.initialized = true;
  }

  getCurrentUser(): User | null {
    return this.currentUser;
  }

  getUserState(): UserState {
    return this.userState;
  }

  isLoggedIn(): boolean {
    return this.currentUser != null && this.currentUser.isLoggedIn();
  }

  /**
   * 保存登录信息
   */
  async saveLoginInfo(uid: string, cid: string, userName: string): Promise<void> {
    await PreferencesManager.getInstance().putString('uid', uid);
    await PreferencesManager.getInstance().putString('cid', cid);
    await PreferencesManager.getInstance().putString('userName', userName);

    this.currentUser = new User();
    this.currentUser.uid = uid;
    this.currentUser.username = userName;
    this.currentUser.nickname = userName;
    this.userState = UserState.LOGGED_IN;

    // 设置Cookie
    const cookie = 'ngaPassportUid=' + uid + '; ngaPassportCid=' + cid;
    HttpClient.getInstance().setCookie(cookie);

    if (this.onUserChanged != null) {
      this.onUserChanged(this.currentUser);
    }
  }

  async logout(): Promise<boolean> {
    try {
      this.currentUser = null;
      this.userState = UserState.NOT_LOGGED_IN;

      await PreferencesManager.getInstance().remove('uid');
      await PreferencesManager.getInstance().remove('cid');
      await PreferencesManager.getInstance().remove('userName');
      HttpClient.getInstance().setCookie('');

      if (this.onUserChanged != null) {
        this.onUserChanged(null);
      }
      return true;
    } catch (err) {
      return false;
    }
  }

  setOnUserChanged(listener: (user: User | null) => void): void {
    this.onUserChanged = listener;
  }

  setOnStateChanged(listener: (state: UserState) => void): void {
    // 空实现
  }
}

export const userManager = UserManager.getInstance();
