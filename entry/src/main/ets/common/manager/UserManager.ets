import { User } from '../../model/entity/User';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { HttpClient } from '../../network/api/HttpClient';
import { AppConstants } from '../constants/AppConstants';

export class SavedAccount {
  uid: string = '';
  cid: string = '';
  userName: string = '';
  lastLoginTime: number = 0;
}

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
  private savedAccounts: SavedAccount[] = [];
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

    await this.loadSavedAccounts();

    const legacyAccount = await this.restoreLegacyAccount();
    if (this.savedAccounts.length === 0 && legacyAccount != null) {
      this.upsertSavedAccount(legacyAccount);
      await this.persistSavedAccounts();
    }

    let activeUid = await PreferencesManager.getInstance().getString(AppConstants.PREF_ACTIVE_ACCOUNT_UID, '');
    if (activeUid === '' && legacyAccount != null) {
      activeUid = legacyAccount.uid;
    }

    if (activeUid !== '') {
      await this.activateSavedAccountByUid(activeUid, false);
    } else {
      await this.clearActiveSession(false);
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

  getSavedAccounts(): SavedAccount[] {
    const result: SavedAccount[] = [];
    for (let i = 0; i < this.savedAccounts.length; i++) {
      const copied = new SavedAccount();
      copied.uid = this.savedAccounts[i].uid;
      copied.cid = this.savedAccounts[i].cid;
      copied.userName = this.savedAccounts[i].userName;
      copied.lastLoginTime = this.savedAccounts[i].lastLoginTime;
      result.push(copied);
    }
    return result;
  }

  /**
   * 保存登录信息
   */
  async saveLoginInfo(uid: string, cid: string, userName: string): Promise<void> {
    const account = new SavedAccount();
    account.uid = uid;
    account.cid = cid;
    account.userName = userName;
    account.lastLoginTime = Date.now();

    this.upsertSavedAccount(account);
    await this.persistSavedAccounts();
    await this.setActiveAccount(account, true);
  }

  async logout(): Promise<boolean> {
    try {
      await this.clearActiveSession(true);
      return true;
    } catch (err) {
      return false;
    }
  }

  async switchAccount(uid: string): Promise<boolean> {
    return this.activateSavedAccountByUid(uid, true);
  }

  private async loadSavedAccounts(): Promise<void> {
    const raw = await PreferencesManager.getInstance().getString(AppConstants.PREF_SAVED_ACCOUNTS, '');
    if (raw === '') {
      this.savedAccounts = [];
      return;
    }
    try {
      const parsed = JSON.parse(raw) as Array<Record<string, Object>>;
      this.savedAccounts = this.restoreAccounts(parsed);
    } catch (err) {
      console.error('UserManager: failed to parse saved accounts', err);
      this.savedAccounts = [];
    }
  }

  private restoreAccounts(parsed: Array<Record<string, Object>>): SavedAccount[] {
    const restored: SavedAccount[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const item = parsed[i];
      if (item == null || typeof item !== 'object') {
        continue;
      }
      const account = new SavedAccount();
      account.uid = item['uid'] != null ? String(item['uid']) : '';
      account.cid = item['cid'] != null ? String(item['cid']) : '';
      account.userName = item['userName'] != null ? String(item['userName']) : '';
      account.lastLoginTime = item['lastLoginTime'] != null ? Number(item['lastLoginTime']) : 0;
      if (account.uid !== '' && account.cid !== '') {
        restored.push(account);
      }
    }
    return restored;
  }

  private async restoreLegacyAccount(): Promise<SavedAccount | null> {
    const uid = await PreferencesManager.getInstance().getString('uid');
    const cid = await PreferencesManager.getInstance().getString('cid');
    const userName = await PreferencesManager.getInstance().getString('userName');
    if (uid === '' || cid === '') {
      return null;
    }

    const account = new SavedAccount();
    account.uid = uid;
    account.cid = cid;
    account.userName = userName;
    account.lastLoginTime = Date.now();
    return account;
  }

  private upsertSavedAccount(account: SavedAccount): void {
    const next: SavedAccount[] = [];
    const copied = new SavedAccount();
    copied.uid = account.uid;
    copied.cid = account.cid;
    copied.userName = account.userName;
    copied.lastLoginTime = account.lastLoginTime;
    next.push(copied);

    for (let i = 0; i < this.savedAccounts.length; i++) {
      if (this.savedAccounts[i].uid !== account.uid) {
        next.push(this.savedAccounts[i]);
      }
    }
    this.savedAccounts = next;
  }

  private async persistSavedAccounts(): Promise<void> {
    await PreferencesManager.getInstance().putString(AppConstants.PREF_SAVED_ACCOUNTS, JSON.stringify(this.savedAccounts));
  }

  private async activateSavedAccountByUid(uid: string, notify: boolean): Promise<boolean> {
    for (let i = 0; i < this.savedAccounts.length; i++) {
      if (this.savedAccounts[i].uid === uid) {
        const account = new SavedAccount();
        account.uid = this.savedAccounts[i].uid;
        account.cid = this.savedAccounts[i].cid;
        account.userName = this.savedAccounts[i].userName;
        account.lastLoginTime = Date.now();
        this.upsertSavedAccount(account);
        await this.persistSavedAccounts();
        await this.setActiveAccount(account, notify);
        return true;
      }
    }
    return false;
  }

  private async setActiveAccount(account: SavedAccount, notify: boolean): Promise<void> {
    await PreferencesManager.getInstance().putString('uid', account.uid);
    await PreferencesManager.getInstance().putString('cid', account.cid);
    await PreferencesManager.getInstance().putString('userName', account.userName);
    await PreferencesManager.getInstance().putString(AppConstants.PREF_ACTIVE_ACCOUNT_UID, account.uid);

    this.currentUser = new User();
    this.currentUser.uid = account.uid;
    this.currentUser.username = account.userName;
    this.currentUser.nickname = account.userName;
    this.userState = UserState.LOGGED_IN;

    const cookie = 'ngaPassportUid=' + account.uid + '; ngaPassportCid=' + account.cid;
    HttpClient.getInstance().setCookie(cookie);

    if (notify && this.onUserChanged != null) {
      this.onUserChanged(this.currentUser);
    }
  }

  private async clearActiveSession(notify: boolean): Promise<void> {
    this.currentUser = null;
    this.userState = UserState.NOT_LOGGED_IN;
    HttpClient.getInstance().setCookie('');

    await PreferencesManager.getInstance().remove('uid');
    await PreferencesManager.getInstance().remove('cid');
    await PreferencesManager.getInstance().remove('userName');
    await PreferencesManager.getInstance().remove(AppConstants.PREF_ACTIVE_ACCOUNT_UID);

    if (notify && this.onUserChanged != null) {
      this.onUserChanged(null);
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
