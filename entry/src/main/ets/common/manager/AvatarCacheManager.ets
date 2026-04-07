import fs from '@ohos.file.fs';
import connection from '@ohos.net.connection';
import common from '@ohos.app.ability.common';
import { ngaApi } from '../../network/api/NgaApi';
import { httpClient } from '../../network/api/HttpClient';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';

export class AvatarCacheManager {
  private static instance: AvatarCacheManager;
  private readonly CACHE_KEY: string = 'user_avatar_cache_map_v1';
  private readonly REMOTE_URL_CACHE_KEY: string = 'user_avatar_remote_url_map_v1';
  private readonly CACHE_DIR_NAME: string = 'avatar-cache';
  private cacheMap: Record<string, string> = {};
  private cacheLoaded: boolean = false;
  private remoteUrlMap: Record<string, string> = {};
  private remoteUrlLoaded: boolean = false;
  private inFlight: Map<string, Promise<string>> = new Map();

  private constructor() {}

  static getInstance(): AvatarCacheManager {
    if (!AvatarCacheManager.instance) {
      AvatarCacheManager.instance = new AvatarCacheManager();
    }
    return AvatarCacheManager.instance;
  }

  async isWifiConnection(): Promise<boolean> {
    try {
      const defaultNet = await connection.getDefaultNet();
      const netCapabilities = await connection.getNetCapabilities(defaultNet);
      const bearerTypes = netCapabilities.bearerTypes || [];
      for (let i = 0; i < bearerTypes.length; i++) {
        if (bearerTypes[i] === connection.NetBearType.BEARER_WIFI) {
          return true;
        }
      }
    } catch (error) {
      console.info('Detect avatar network type failed:', JSON.stringify(error));
    }
    return false;
  }

  async loadAvatar(
    context: common.UIAbilityContext,
    uid: string,
    allowNetwork: boolean,
    forceRefresh: boolean = false,
    knownAvatarUrl: string = '',
    lookupProfileWhenUrlMissing: boolean = true
  ): Promise<string> {
    const normalizedUid = this.normalizeUid(uid);
    if (normalizedUid === '') {
      return '';
    }

    const cachedUri = await this.getCachedAvatarUri(normalizedUid);
    if (!forceRefresh && cachedUri !== '') {
      return cachedUri;
    }
    if (!allowNetwork && !forceRefresh) {
      return cachedUri;
    }

    const existingTask = this.inFlight.get(normalizedUid);
    if (existingTask != null) {
      return await existingTask;
    }

    const task = this.fetchAndCacheAvatar(
      context,
      normalizedUid,
      knownAvatarUrl,
      cachedUri,
      lookupProfileWhenUrlMissing
    );
    this.inFlight.set(normalizedUid, task);
    try {
      return await task;
    } finally {
      this.inFlight.delete(normalizedUid);
    }
  }

  private normalizeUid(uid: string): string {
    const normalized = uid != null ? String(uid).trim() : '';
    if (!/^\d+$/.test(normalized) || normalized === '0') {
      return '';
    }
    return normalized;
  }

  private async ensureCacheMapLoaded(): Promise<void> {
    if (this.cacheLoaded) {
      return;
    }

    try {
      const stored = await PreferencesManager.getInstance().getString(this.CACHE_KEY, '');
      if (stored !== '') {
        this.cacheMap = JSON.parse(stored) as Record<string, string>;
      }
    } catch (error) {
      console.error('Load avatar cache map failed:', error);
      this.cacheMap = {};
    }
    this.cacheLoaded = true;
  }

  private async persistCacheMap(): Promise<void> {
    try {
      await PreferencesManager.getInstance().putString(this.CACHE_KEY, JSON.stringify(this.cacheMap));
    } catch (error) {
      console.error('Persist avatar cache map failed:', error);
    }
  }

  private async ensureRemoteUrlMapLoaded(): Promise<void> {
    if (this.remoteUrlLoaded) {
      return;
    }

    try {
      const stored = await PreferencesManager.getInstance().getString(this.REMOTE_URL_CACHE_KEY, '');
      if (stored !== '') {
        this.remoteUrlMap = JSON.parse(stored) as Record<string, string>;
      }
    } catch (error) {
      console.error('Load avatar remote url map failed:', error);
      this.remoteUrlMap = {};
    }
    this.remoteUrlLoaded = true;
  }

  private async persistRemoteUrlMap(): Promise<void> {
    try {
      await PreferencesManager.getInstance().putString(this.REMOTE_URL_CACHE_KEY, JSON.stringify(this.remoteUrlMap));
    } catch (error) {
      console.error('Persist avatar remote url map failed:', error);
    }
  }

  private async getRememberedAvatarUrl(uid: string): Promise<string> {
    await this.ensureRemoteUrlMapLoaded();
    const remembered = this.remoteUrlMap[uid];
    return remembered != null ? this.normalizeAvatarUrl(remembered) : '';
  }

  private async rememberAvatarUrl(uid: string, avatarUrl: string): Promise<void> {
    const normalizedUid = this.normalizeUid(uid);
    const normalizedUrl = this.normalizeAvatarUrl(avatarUrl);
    if (normalizedUid === '' || normalizedUrl === '') {
      return;
    }

    await this.ensureRemoteUrlMapLoaded();
    if (this.remoteUrlMap[normalizedUid] === normalizedUrl) {
      return;
    }

    this.remoteUrlMap[normalizedUid] = normalizedUrl;
    await this.persistRemoteUrlMap();
  }

  private removeCachedAvatar(uid: string): void {
    const nextCacheMap: Record<string, string> = {};
    const keys = Object.keys(this.cacheMap);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] !== uid) {
        nextCacheMap[keys[i]] = this.cacheMap[keys[i]];
      }
    }
    this.cacheMap = nextCacheMap;
  }

  private avatarDir(context: common.UIAbilityContext): string {
    return context.cacheDir + '/' + this.CACHE_DIR_NAME;
  }

  private ensureAvatarDir(context: common.UIAbilityContext): void {
    const dir = this.avatarDir(context);
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
    } catch (_error) {
      try {
        fs.mkdirSync(dir, true);
      } catch (mkdirError) {
        console.error('Create avatar cache dir failed:', mkdirError);
      }
    }
  }

  private toFileUri(path: string): string {
    if (path.indexOf('file://') === 0) {
      return path;
    }
    return 'file://' + path;
  }

  private toFilePath(uri: string): string {
    if (uri.indexOf('file://') === 0) {
      return uri.substring(7);
    }
    return uri;
  }

  private async getCachedAvatarUri(uid: string): Promise<string> {
    await this.ensureCacheMapLoaded();
    const cachedUri = this.cacheMap[uid];
    if (cachedUri == null || cachedUri === '') {
      return '';
    }

    try {
      if (fs.accessSync(this.toFilePath(cachedUri))) {
        return cachedUri;
      }
    } catch (_error) {
      // ignore and clear invalid cache below
    }

    this.removeCachedAvatar(uid);
    await this.persistCacheMap();
    return '';
  }

  private normalizeAvatarUrl(url: string): string {
    const trimmed = url != null ? String(url).trim() : '';
    if (trimmed === '') {
      return '';
    }
    if (/^https?:\/\//i.test(trimmed)) {
      return trimmed;
    }
    if (trimmed.indexOf('//') === 0) {
      return 'https:' + trimmed;
    }
    if (trimmed.indexOf('/') === 0) {
      return 'https://bbs.nga.cn' + trimmed;
    }
    return 'https://' + trimmed;
  }

  private avatarExt(url: string): string {
    const withoutQuery = url.split('?')[0];
    const dotIdx = withoutQuery.lastIndexOf('.');
    if (dotIdx > withoutQuery.lastIndexOf('/')) {
      const ext = withoutQuery.substring(dotIdx).toLowerCase();
      if (/^\.[a-z0-9]{2,5}$/.test(ext)) {
        return ext;
      }
    }
    return '.jpg';
  }

  private pickAvatarUrlFromProfile(jsonObj: Record<string, Object>): string {
    const data = jsonObj['data'];
    if (data == null || typeof data !== 'object') {
      return '';
    }

    const dataObj = data as Record<string, Object>;
    const first = dataObj['0'];
    if (first != null && typeof first === 'object' && !Array.isArray(first)) {
      const avatar = (first as Record<string, Object>)['avatar'];
      return avatar != null ? String(avatar) : '';
    }

    const keys = Object.keys(dataObj);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (key.indexOf('__') === 0) {
        continue;
      }
      const rec = dataObj[key];
      if (rec != null && typeof rec === 'object' && !Array.isArray(rec)) {
        const avatar = (rec as Record<string, Object>)['avatar'];
        if (avatar != null && String(avatar) !== '') {
          return String(avatar);
        }
      }
    }

    return '';
  }

  private async resolveRemoteAvatarUrl(uid: string, knownAvatarUrl: string): Promise<string> {
    const normalizedKnown = this.normalizeAvatarUrl(knownAvatarUrl);
    if (normalizedKnown !== '') {
      await this.rememberAvatarUrl(uid, normalizedKnown);
      return normalizedKnown;
    }

    const remembered = await this.getRememberedAvatarUrl(uid);
    if (remembered !== '') {
      return remembered;
    }

    const profileResponse = await ngaApi.getUserProfile(uid);
    if (profileResponse.code === 200 && profileResponse.data != null) {
      const profileAvatarUrl = this.normalizeAvatarUrl(this.pickAvatarUrlFromProfile(profileResponse.data));
      if (profileAvatarUrl !== '') {
        await this.rememberAvatarUrl(uid, profileAvatarUrl);
      }
      return profileAvatarUrl;
    }

    return '';
  }

  private async fetchAndCacheAvatar(
    context: common.UIAbilityContext,
    uid: string,
    knownAvatarUrl: string,
    fallbackUri: string,
    lookupProfileWhenUrlMissing: boolean
  ): Promise<string> {
    let remoteAvatarUrl = this.normalizeAvatarUrl(knownAvatarUrl);
    if (remoteAvatarUrl === '') {
      remoteAvatarUrl = await this.getRememberedAvatarUrl(uid);
    }
    if (remoteAvatarUrl === '' && lookupProfileWhenUrlMissing) {
      remoteAvatarUrl = await this.resolveRemoteAvatarUrl(uid, '');
    }
    if (remoteAvatarUrl === '') {
      return fallbackUri;
    }
    await this.rememberAvatarUrl(uid, remoteAvatarUrl);

    const bytes = await httpClient.getBytes(remoteAvatarUrl);
    if (bytes == null) {
      return fallbackUri;
    }

    this.ensureAvatarDir(context);

    const nextPath = this.avatarDir(context) + '/' + uid + this.avatarExt(remoteAvatarUrl);
    const previousUri = this.cacheMap[uid];
    const previousPath = previousUri != null ? this.toFilePath(previousUri) : '';

    try {
      const file = fs.openSync(nextPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, bytes);
      fs.closeSync(file);

      if (previousPath !== '' && previousPath !== nextPath) {
        try {
          if (fs.accessSync(previousPath)) {
            fs.unlinkSync(previousPath);
          }
        } catch (_unlinkErr) {
          console.info('Cleanup previous avatar cache skipped for uid=' + uid);
        }
      }

      const cachedUri = this.toFileUri(nextPath);
      this.cacheMap[uid] = cachedUri;
      await this.persistCacheMap();
      return cachedUri;
    } catch (error) {
      console.error('Cache avatar failed for uid=' + uid + ':', error);
      return fallbackUri;
    }
  }
}

export const avatarCacheManager = AvatarCacheManager.getInstance();
