import { HttpClient, HttpResponse, LoginHttpResult } from './HttpClient';
import { User } from '../../model/entity/User';
import { Topic, TopicList } from '../../model/entity/Topic';
import { Article, ArticleList, Attachment, AttachmentType } from '../../model/entity/Article';
import { Board, BoardCategory } from '../../model/entity/Board';
import {
  Message,
  MessageList,
  MessageThread,
  MessageThreadList,
  MessageDetail,
  MessageDetailEntry
} from '../../model/entity/Message';
import { NotificationItem, NotificationList } from '../../model/entity/Notification';
import { LogUtils } from '../../common/utils/LogUtils';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util, buffer } from '@kit.ArkTS';

/**
 * 验证码加载结果
 */
export class CaptchaResult {
  rid: string = '';
  imageData: ArrayBuffer | null = null;
  captchaCookie: string = '';
  prid: string = '';
}

/**
 * 登录结果
 */
export class LoginResult {
  success: boolean = false;
  uid: string = '';
  cid: string = '';
  userName: string = '';
  errorMsg: string = '';
}

/**
 * NGA API服务
 */
export class NgaApi {
  private http: HttpClient;
  private baseUrl: string = 'https://bbs.nga.cn';
  private static readonly LOG_TAG: string = 'NgaApi';
  private static readonly ANONYMOUS_NAME_PREFIX: string = '甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥';
  private static readonly ANONYMOUS_NAME_SUFFIX: string =
    '王李张刘陈杨黄吴赵周徐孙马朱胡林郭何高罗郑梁谢宋唐许邓冯韩曹曾彭萧蔡潘田董袁于余叶蒋杜苏魏程吕丁沈任姚卢傅钟姜崔谭廖范汪陆金石戴贾韦夏邱方侯邹熊孟秦白江阎薛尹段雷黎史龙陶贺顾毛郝龚邵万钱严赖覃洪武莫孔汤向常温康施文牛樊葛邢安齐易乔伍庞颜倪庄聂章鲁岳翟殷詹申欧耿关兰焦俞左柳甘祝包宁尚符舒阮柯纪梅童凌毕单季裴霍涂成苗谷盛曲翁冉骆蓝路游辛靳管柴蒙鲍华喻祁蒲房滕屈饶解牟艾尤阳时穆农司卓古吉缪简车项连芦麦褚娄窦戚岑景党宫费卜冷晏席卫米柏宗瞿桂全佟应臧闵苟邬边卞姬师和仇栾隋商刁沙荣巫寇桑郎甄丛仲虞敖巩明佘池查麻苑迟邝';
  private static readonly PROFILE_REQUEST_GAP_MS: number = 350;
  private static readonly PROFILE_HOST_CANDIDATES: string[] = [
    'https://bbs.ngacn.cc',
    'https://ngabbs.com',
    'https://nga.donews.com',
    'https://nga.178.com',
    'https://bbs.nga.cn'
  ];
  private profileRequestQueue: Promise<void> = Promise.resolve();
  private profileRequestInFlight: Map<string, Promise<HttpResponse<Record<string, Object>>>> = new Map();
  private lastProfileRequestAt: number = 0;

  private static readonly NGA_RSA_PUB_KEY: string =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyKzZWDimCN1OCprqWUhF' +
    'UPhcwxDE62/BFVP6LtQHJu+65dm4YNmDvzitmcfaXW9YbhXnd4oP7j+6vpcgJQ+p' +
    '3ucySo1ZnqO0Bb2JKEtxpCmxe7IYXhFEkJqHpFYBTiAxQz2n2mX4JZy/ehBUSMjz' +
    'gzd0NdG6Ai1C42oCzYltUOjNWZUNHn1nqpElSWHnUWqkdN8+5ISP/ZMKiQdFANkE' +
    'qDGw3/34qyF+E/hVgrGF4/CcWNP/LJCdB6DYtx7VPlQZF0tP1s+q/++rC4rQ2wmV' +
    'l2V8zGh1j7ojZbt62hVjy6byK1E/2XYo97ZtL4KDW7F5jJMvSDRFR7901UR8hCdf' +
    '4wIDAQAB';

  constructor() {
    this.http = HttpClient.getInstance();
  }

  /**
   * 从 API JSON 响应中提取错误消息
   */
  private extractErrorMsg(jsonObj: Record<string, Object>): string {
    const errorField = jsonObj['error'];
    if (errorField == null) return '';
    let errMsg = '';
    if (Array.isArray(errorField)) {
      const arr = errorField as string[];
      if (arr.length > 0 && arr[0] != null) errMsg = String(arr[0]);
    } else if (typeof errorField === 'string') {
      errMsg = errorField as string;
    } else if (typeof errorField === 'object') {
      const obj = errorField as Record<string, string>;
      errMsg = obj['0'] || '';
    }
    if (errMsg) {
      const colonIdx = errMsg.indexOf(':');
      if (colonIdx > 0 && colonIdx <= 3) {
        errMsg = errMsg.substring(colonIdx + 1);
      }
    }
    return errMsg;
  }

  /**
   * 尝试修复截断的 JSON 字符串。
   * NGA 服务器有时返回不完整的 JSON（被截断），
   * 此方法通过截取到最后一个完整的 JSON 条目并补全括号来恢复。
   */
  private tryFixTruncatedJson(jsonStr: string): string | null {
    const lastBrace = jsonStr.lastIndexOf('}');
    const lastBracket = jsonStr.lastIndexOf(']');
    if (lastBrace < 0 && lastBracket < 0) return null;

    let cutPos = Math.max(lastBrace, lastBracket) + 1;
    let candidate = jsonStr.substring(0, cutPos);

    let openBraces = 0;
    let openBrackets = 0;
    let inString = false;
    let escape = false;
    for (let i = 0; i < candidate.length; i++) {
      const ch = candidate.charAt(i);
      if (escape) { escape = false; continue; }
      if (ch === '\\') { if (inString) escape = true; continue; }
      if (ch === '"') { inString = !inString; continue; }
      if (inString) continue;
      if (ch === '{') openBraces++;
      else if (ch === '}') openBraces--;
      else if (ch === '[') openBrackets++;
      else if (ch === ']') openBrackets--;
    }

    for (let i = 0; i < openBrackets; i++) candidate += ']';
    for (let i = 0; i < openBraces; i++) candidate += '}';

    try {
      JSON.parse(candidate);
      return candidate;
    } catch (_e) {
      // fallback: aggressive truncation at last complete object
      const lastCompleteObj = jsonStr.lastIndexOf('},');
      const lastCompleteArr = jsonStr.lastIndexOf('],');
      const fallbackPos = Math.max(lastCompleteObj, lastCompleteArr);
      if (fallbackPos > 0) {
        let fallback = jsonStr.substring(0, fallbackPos + 1);
        openBraces = 0;
        openBrackets = 0;
        inString = false;
        escape = false;
        for (let i = 0; i < fallback.length; i++) {
          const ch = fallback.charAt(i);
          if (escape) { escape = false; continue; }
          if (ch === '\\') { if (inString) escape = true; continue; }
          if (ch === '"') { inString = !inString; continue; }
          if (inString) continue;
          if (ch === '{') openBraces++;
          else if (ch === '}') openBraces--;
          else if (ch === '[') openBrackets++;
          else if (ch === ']') openBrackets--;
        }
        for (let i = 0; i < openBrackets; i++) fallback += ']';
        for (let i = 0; i < openBraces; i++) fallback += '}';
        try {
          JSON.parse(fallback);
          return fallback;
        } catch (_e2) {
          return null;
        }
      }
      return null;
    }
  }

  /**
   * 解码纯文本中的 HTML 实体。
   */
  private decodeHtmlEntities(raw: string): string {
    if (raw == null || raw === '') {
      return '';
    }
    let s = String(raw);

    let changed = true;
    let guard = 0;
    while (changed && guard < 5) {
      const before = s;
      s = s.replace(/&nbsp;/g, ' ');
      s = s.replace(/&amp;/g, '&');
      s = s.replace(/&lt;/g, '<');
      s = s.replace(/&gt;/g, '>');
      s = s.replace(/&quot;/g, '"');
      s = s.replace(/&#39;/g, '\'');
      changed = before !== s;
      guard++;
    }

    const reDec = /&#(\d+);/;
    let m = reDec.exec(s);
    guard = 0;
    while (m != null && guard < 50) {
      const code = parseInt(m[1], 10);
      const ch = (!isNaN(code) && code > 0 && code < 0x110000) ? String.fromCharCode(code) : '';
      s = s.replace(m[0], ch);
      m = reDec.exec(s);
      guard++;
    }

    const reHex = /&#x([0-9a-fA-F]+);/;
    m = reHex.exec(s);
    guard = 0;
    while (m != null && guard < 50) {
      const code = parseInt(m[1], 16);
      const ch = (!isNaN(code) && code > 0 && code < 0x110000) ? String.fromCharCode(code) : '';
      s = s.replace(m[0], ch);
      m = reHex.exec(s);
      guard++;
    }

    return s;
  }

  private decodeAnonymousDisplayName(raw: string): string {
    const source = raw != null ? String(raw).trim() : '';
    if (!(source.startsWith('#anony_') || source.startsWith('anony_')) || source.length < 18) {
      return '';
    }

    let result = '';
    let cursor = source.startsWith('#anony_') ? 6 : 5;
    try {
      for (let i = 0; i < 6; i++) {
        let pos = 0;
        if (i === 0 || i === 3) {
          pos = parseInt(source.substring(cursor + 1, cursor + 2), 16);
          if (!isFinite(pos) || isNaN(pos)) {
            return '';
          }
          if (pos < 0) {
            pos = 0;
          } else if (pos >= NgaApi.ANONYMOUS_NAME_PREFIX.length) {
            pos = NgaApi.ANONYMOUS_NAME_PREFIX.length - 1;
          }
          result += NgaApi.ANONYMOUS_NAME_PREFIX.charAt(pos);
        } else {
          pos = parseInt(source.substring(cursor, cursor + 2), 16);
          if (!isFinite(pos) || isNaN(pos)) {
            return '';
          }
          if (pos < 0) {
            pos = 0;
          } else if (pos >= NgaApi.ANONYMOUS_NAME_SUFFIX.length) {
            pos = NgaApi.ANONYMOUS_NAME_SUFFIX.length - 1;
          }
          result += NgaApi.ANONYMOUS_NAME_SUFFIX.charAt(pos);
        }
        cursor += 2;
      }
    } catch (_error) {
      return '';
    }
    return result;
  }

  /**
   * 清洗昵称中的 HTML 标签与常见实体（接口有时会把 author 带标签返回）
   */
  private sanitizeDisplayName(raw: string): string {
    if (raw == null || raw === '') {
      return '';
    }
    let s = String(raw).replace(/<[^>]*>/g, '');
    s = this.decodeHtmlEntities(s);
    const anonymousDecoded = this.decodeAnonymousDisplayName(s);
    if (anonymousDecoded !== '') {
      return anonymousDecoded;
    }
    return s.trim();
  }

  private isGenericAnonymousDisplayName(raw: string): boolean {
    const s = this.sanitizeDisplayName(raw);
    return s === '匿名' || s === '匿名用户' || s === 'Anonymous';
  }

  private isLikelyOpaqueDisplayName(raw: string): boolean {
    const s = this.sanitizeDisplayName(raw);
    if (s === '') {
      return false;
    }
    if (s === '0' || /^-\d+$/.test(s)) {
      return true;
    }
    if (/[\u3400-\u9FFF]/.test(s) || /\s/.test(s) || /[\u00B7\u30FB]/.test(s)) {
      return false;
    }
    if (/^[0-9]{8,}$/.test(s)) {
      return true;
    }
    if (/^[0-9a-f]{12,}$/i.test(s)) {
      return true;
    }
    if (/^[A-Za-z0-9_+=/-]{12,}$/.test(s) && /[A-Za-z]/.test(s) && /\d/.test(s)) {
      return true;
    }
    return false;
  }

  private pickDisplayName(primary: string, secondary: string, tertiary: string): string {
    const candidates = [primary, secondary, tertiary];
    let genericFallback = '';
    let opaqueFallback = '';

    for (let i = 0; i < candidates.length; i++) {
      const name = this.sanitizeDisplayName(candidates[i]);
      if (name === '' || name === 'null' || name === 'undefined') {
        continue;
      }
      if (this.isGenericAnonymousDisplayName(name)) {
        if (genericFallback === '') {
          genericFallback = name;
        }
        continue;
      }
      if (!this.isLikelyOpaqueDisplayName(name)) {
        return name;
      }
      if (opaqueFallback === '') {
        opaqueFallback = name;
      }
    }

    if (genericFallback !== '') {
      return genericFallback;
    }
    return opaqueFallback;
  }

  /**
   * read.php 的 __T 可能是单层主题对象，也可能是以 tid 为键的嵌套对象
   */
  private extractThreadDetailMeta(tField: Object | null): Record<string, Object> | null {
    if (tField == null || typeof tField !== 'object') {
      return null;
    }
    if (Array.isArray(tField)) {
      const arr = tField as Object[];
      if (arr.length > 0 && arr[0] != null && typeof arr[0] === 'object') {
        return arr[0] as Record<string, Object>;
      }
      return null;
    }
    const o = tField as Record<string, Object>;
    if (o['tid'] != null) {
      return o;
    }
    const keys = Object.keys(o);
    for (let k = 0; k < keys.length; k++) {
      const key = keys[k];
      if (key.indexOf('__') === 0) {
        continue;
      }
      const v = o[key];
      if (v != null && typeof v === 'object' && !Array.isArray(v)) {
        const rec = v as Record<string, Object>;
        if (rec['tid'] != null) {
          return rec;
        }
      }
    }
    return o;
  }

  /** 仅接受正整数 UID 字符串，0 或非法视为无 */
  private positiveUidString(raw: Object | null | undefined): string {
    if (raw == null || raw === '') {
      return '';
    }
    const n = Number(raw);
    if (isNaN(n) || n <= 0) {
      return '';
    }
    return String(Math.floor(n));
  }

  private extractAnonymousIdentity(source: Object | null | undefined): string {
    if (source == null || source === '') {
      return '';
    }

    if (typeof source === 'object') {
      const obj = source as Record<string, Object>;
      const candidates: (Object | null | undefined)[] = [obj['author'], obj['username'], obj['nickname']];
      for (let i = 0; i < candidates.length; i++) {
        const identity = this.extractAnonymousIdentity(candidates[i]);
        if (identity !== '') {
          return identity;
        }
      }
      return '';
    }

    let text = String(source).replace(/<[^>]*>/g, '');
    text = this.decodeHtmlEntities(text).trim();
    if (text.startsWith('#anony_')) {
      return text.substring(1);
    }
    if (text.startsWith('anony_')) {
      return text;
    }

    return '';
  }

  private stripScriptPrefix(raw: string): string {
    if (raw == null || raw === '') {
      return '';
    }
    let js = raw.replace(/^\uFEFF/, '').trim();
    js = js.replace(/<script[^>]*>/gi, '');
    js = js.replace(/<\/script>/gi, '');
    js = js.replace(/window\.script_muti_get_var_store=/g, '');
    js = js.replace(/\/\*\$js\$\*\//g, '').trim();
    if (js.endsWith(';')) {
      js = js.substring(0, js.length - 1).trim();
    }
    return js;
  }

  private previewRaw(raw: string, maxLen: number = 600): string {
    if (raw == null || raw === '') {
      return '<empty>';
    }
    let preview = raw.replace(/\r/g, '\\r').replace(/\n/g, '\\n');
    if (preview.length > maxLen) {
      preview = preview.substring(0, maxLen) + '...(truncated)';
    }
    return preview;
  }

  private async sleep(ms: number): Promise<void> {
    if (ms <= 0) {
      return;
    }
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  private async withProfileRequestQueue<T>(task: () => Promise<T>): Promise<T> {
    const previous = this.profileRequestQueue;
    let releaseCurrent: () => void = () => {};
    this.profileRequestQueue = new Promise<void>((resolve: () => void) => {
      releaseCurrent = resolve;
    });

    await previous;
    try {
      const elapsed = Date.now() - this.lastProfileRequestAt;
      const waitMs = NgaApi.PROFILE_REQUEST_GAP_MS - elapsed;
      if (waitMs > 0) {
        await this.sleep(waitMs);
      }
      return await task();
    } finally {
      this.lastProfileRequestAt = Date.now();
      releaseCurrent();
    }
  }

  private normalizeHost(raw: string): string {
    if (raw == null || raw === '') {
      return '';
    }
    let host = String(raw).trim();
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    return host;
  }

  private profileHosts(): string[] {
    const seen: Record<string, boolean> = {};
    const hosts: string[] = [];

    const addHost = (host: string): void => {
      const normalized = this.normalizeHost(host);
      if (normalized === '' || seen[normalized] === true) {
        return;
      }
      seen[normalized] = true;
      hosts.push(normalized);
    };

    for (let i = 0; i < NgaApi.PROFILE_HOST_CANDIDATES.length; i++) {
      addHost(NgaApi.PROFILE_HOST_CANDIDATES[i]);
    }
    addHost(this.baseUrl);
    return hosts;
  }

  private buildProfileUrl(host: string, uid: string): string {
    return host + '/nuke.php?__lib=ucp&__act=get&lite=js&noprefix&uid=' + encodeURIComponent(uid);
  }

  private buildProfileReferer(host: string, uid: string): string {
    return host + '/nuke.php?func=ucp&lite=jsx&uid=' + encodeURIComponent(uid);
  }

  private shouldRetryProfileResponse(response: HttpResponse<string>): boolean {
    if (response.code <= 0 || response.code === 503) {
      return true;
    }
    if (response.code >= 500 && response.code < 600) {
      return true;
    }

    const raw = response.raw != null ? String(response.raw).trim() : '';
    if (raw === '') {
      return true;
    }

    const preview = raw.substring(0, 120).toLowerCase();
    return preview.indexOf('<!doctype') >= 0 || preview.indexOf('<html') >= 0;
  }

  private normalizeTidValue(raw: string): string {
    const text = raw != null ? String(raw).trim() : '';
    if (text === '') {
      return '';
    }
    if (/^\d+$/.test(text)) {
      return text;
    }

    const queryMatch = /(?:[?&#])tid=(\d+)/i.exec(text);
    if (queryMatch != null) {
      return queryMatch[1];
    }

    const looseMatch = /(?:^|[^0-9])(\d{5,})(?:[^0-9]|$)/.exec(text);
    if (looseMatch != null) {
      return looseMatch[1];
    }

    return text;
  }

  private normalizeMessageJson(raw: string): string {
    let js = this.stripScriptPrefix(raw);
    const errorFillPos = js.indexOf('/*error fill content');
    if (errorFillPos > 0) {
      js = js.substring(0, errorFillPos);
    }
    js = js.replace(/"content":\+(\d+),/g, '"content":"+$1",');
    js = js.replace(/"subject":\+(\d+),/g, '"subject":"+$1",');
    js = js.replace(/"content":(0\d+),/g, '"content":"$1",');
    js = js.replace(/"subject":(0\d+),/g, '"subject":"$1",');
    js = js.replace(/"author":(0\d+),/g, '"author":"$1",');
    js = js.replace(/\[img\]\.\/mon_/g, '[img]http://img6.nga.178.com/attachments/mon_');

    const invalidStart = '"__P":{"aid":';
    const invalidEnd = '"this_visit_rows":';
    const invalidStartPos = js.indexOf(invalidStart);
    const invalidEndPos = js.indexOf(invalidEnd);
    if (invalidStartPos >= 0 && invalidEndPos > invalidStartPos) {
      js = js.substring(0, invalidStartPos) + js.substring(invalidEndPos);
    }

    return js;
  }

  private normalizeArticleJson(raw: string): string {
    let js = this.stripScriptPrefix(raw);
    const errorFillPos = js.indexOf('/*error fill content');
    if (errorFillPos > 0) {
      js = js.substring(0, errorFillPos);
    }

    js = js
      .replace(/\/\*\$js\$\*\//g, '')
      .replace(/"content":\+(\d+),/g, '"content":"+$1",')
      .replace(/"subject":\+(\d+),/g, '"subject":"+$1",')
      .replace(/"content":(0\d+),/g, '"content":"$1",')
      .replace(/"subject":(0\d+),/g, '"subject":"$1",')
      .replace(/"author":(0\d+),/g, '"author":"$1",')
      .replace(/"alterinfo":"\[(\w|\s)+\]\s+",/g, '');

    return js;
  }

  private sanitizeJsonControlChars(raw: string): string {
    if (raw == null || raw === '') {
      return '';
    }

    let result = '';
    let inString = false;
    let escape = false;

    for (let i = 0; i < raw.length; i++) {
      const ch = raw.charAt(i);
      const code = raw.charCodeAt(i);

      if (escape) {
        result += ch;
        escape = false;
        continue;
      }

      if (ch === '\\') {
        result += ch;
        if (inString) {
          escape = true;
        }
        continue;
      }

      if (ch === '"') {
        result += ch;
        inString = !inString;
        continue;
      }

      if (inString && (code === 0x2028 || code === 0x2029)) {
        result += code === 0x2028 ? '\\u2028' : '\\u2029';
        continue;
      }

      if (inString && code < 0x20) {
        switch (ch) {
          case '\t':
            result += '\\t';
            break;
          case '\n':
            result += '\\n';
            break;
          case '\r':
            result += '\\r';
            break;
          case '\b':
            result += '\\b';
            break;
          case '\f':
            result += '\\f';
            break;
          default: {
            const hex = code.toString(16).padStart(4, '0');
            result += '\\u' + hex;
            break;
          }
        }
        continue;
      }

      result += ch;
    }

    return result;
  }

  private isHexDigit(ch: string): boolean {
    return /^[0-9a-fA-F]$/.test(ch);
  }

  private normalizeJsonStringEscapes(raw: string): string {
    if (raw == null || raw === '') {
      return '';
    }

    let result = '';
    let inString = false;

    for (let i = 0; i < raw.length; i++) {
      const ch = raw.charAt(i);

      if (ch === '"') {
        let slashCount = 0;
        for (let j = i - 1; j >= 0 && raw.charAt(j) === '\\'; j--) {
          slashCount++;
        }
        if (slashCount % 2 === 0) {
          inString = !inString;
        }
        result += ch;
        continue;
      }

      if (inString && ch === '\\') {
        const next = i + 1 < raw.length ? raw.charAt(i + 1) : '';
        if (next === '') {
          result += '\\\\';
          continue;
        }

        if (next === '\'') {
          result += '\'';
          i++;
          continue;
        }

        if (next === 'x' &&
          i + 3 < raw.length &&
          this.isHexDigit(raw.charAt(i + 2)) &&
          this.isHexDigit(raw.charAt(i + 3))) {
          result += '\\u00' + raw.substring(i + 2, i + 4);
          i += 3;
          continue;
        }

        if (next === 'v') {
          result += '\\u000b';
          i++;
          continue;
        }

        if (next === '0' && (i + 2 >= raw.length || !/[0-9]/.test(raw.charAt(i + 2)))) {
          result += '\\u0000';
          i++;
          continue;
        }

        if (next === 'u' &&
          i + 5 < raw.length &&
          this.isHexDigit(raw.charAt(i + 2)) &&
          this.isHexDigit(raw.charAt(i + 3)) &&
          this.isHexDigit(raw.charAt(i + 4)) &&
          this.isHexDigit(raw.charAt(i + 5))) {
          result += '\\u' + raw.substring(i + 2, i + 6);
          i += 5;
          continue;
        }

        if ('"\\/bfnrt'.indexOf(next) >= 0) {
          result += '\\' + next;
          i++;
          continue;
        }

        // Preserve stray backslashes like "\_" or "\[" as literal content.
        result += '\\\\';
        continue;
      }

      result += ch;
    }

    return result;
  }

  private previewAround(raw: string, center: number, radius: number = 120): string {
    if (raw == null || raw === '') {
      return '<empty>';
    }
    const safeCenter = Math.max(0, Math.min(center, raw.length));
    const start = Math.max(0, safeCenter - radius);
    const end = Math.min(raw.length, safeCenter + radius);
    const prefix = start > 0 ? '...' : '';
    const suffix = end < raw.length ? '...' : '';
    return prefix + raw.substring(start, end) + suffix;
  }

  private describeJsonParseError(error: Object | null | undefined, raw: string): string {
    let message = 'unknown';
    if (error != null && typeof error === 'object') {
      const errorObj = error as Record<string, Object>;
      const name = errorObj['name'] != null ? String(errorObj['name']) : '';
      const detail = errorObj['message'] != null ? String(errorObj['message']) : '';
      message = detail !== '' ? detail : String(error);
      if (name !== '' && message.indexOf(name) !== 0) {
        message = name + ': ' + message;
      }
    } else if (error != null) {
      message = String(error);
    }
    let position = -1;

    const positionMatch = /position\s+(\d+)/i.exec(message);
    if (positionMatch != null) {
      position = Number(positionMatch[1]);
    } else {
      const columnMatch = /column\s+(\d+)/i.exec(message);
      if (columnMatch != null) {
        position = Math.max(0, Number(columnMatch[1]) - 1);
      }
    }

    if (position < 0) {
      return 'error=' + message;
    }

    return 'error=' + message + ', position=' + position + ', near=' + this.previewAround(raw, position);
  }

  private parseJsonObject(raw: string): Record<string, Object> | null {
    const normalized = this.sanitizeJsonControlChars(this.stripScriptPrefix(raw));
    try {
      return JSON.parse(normalized) as Record<string, Object>;
    } catch (_error) {
      LogUtils.w(NgaApi.LOG_TAG, 'parseJsonObject first parse failed, preview=' + this.previewRaw(normalized));
      const repaired = this.tryFixTruncatedJson(normalized);
      if (repaired != null) {
        try {
          LogUtils.i(NgaApi.LOG_TAG, 'parseJsonObject repaired truncated json successfully');
          return JSON.parse(repaired) as Record<string, Object>;
        } catch (_error2) {
          LogUtils.e(NgaApi.LOG_TAG, 'parseJsonObject repaired parse still failed, preview=' + this.previewRaw(repaired));
          return null;
        }
      }
      LogUtils.e(NgaApi.LOG_TAG, 'parseJsonObject unable to repair json, preview=' + this.previewRaw(normalized));
      return null;
    }
  }

  private parseMessageJsonObject(raw: string): Record<string, Object> | null {
    const normalized = this.sanitizeJsonControlChars(this.normalizeMessageJson(raw));
    try {
      return JSON.parse(normalized) as Record<string, Object>;
    } catch (_error) {
      LogUtils.w(NgaApi.LOG_TAG, 'parseMessageJsonObject first parse failed, preview=' + this.previewRaw(normalized));
      const repaired = this.tryFixTruncatedJson(normalized);
      if (repaired != null) {
        try {
          LogUtils.i(NgaApi.LOG_TAG, 'parseMessageJsonObject repaired truncated json successfully');
          return JSON.parse(repaired) as Record<string, Object>;
        } catch (_error2) {
          LogUtils.e(NgaApi.LOG_TAG, 'parseMessageJsonObject repaired parse still failed, preview=' + this.previewRaw(repaired));
          return null;
        }
      }
      LogUtils.e(NgaApi.LOG_TAG, 'parseMessageJsonObject unable to repair json, preview=' + this.previewRaw(normalized));
      return null;
    }
  }

  private intValue(raw: Object | null | undefined): number {
    if (raw == null || raw === '') {
      return 0;
    }
    const value = Number(raw);
    if (!isFinite(value)) {
      return 0;
    }
    return Math.floor(value);
  }

  private indexedValue(source: Object | null | undefined, index: number): Object | null {
    if (source == null) {
      return null;
    }
    if (Array.isArray(source)) {
      const arr = source as Object[];
      return index >= 0 && index < arr.length ? arr[index] : null;
    }
    if (typeof source === 'object') {
      const obj = source as Record<string, Object>;
      const value = obj[String(index)];
      return value != null ? value : null;
    }
    return null;
  }

  private numericObjectKeys(obj: Record<string, Object>): string[] {
    const keys = Object.keys(obj).filter((key: string) => /^\d+$/.test(key));
    keys.sort((a: string, b: string) => Number(a) - Number(b));
    return keys;
  }

  private formatUnixSeconds(raw: Object | null | undefined): string {
    const seconds = this.intValue(raw);
    if (seconds <= 0) {
      return '';
    }
    return this.formatDateTime(seconds * 1000);
  }

  private formatDateTime(timestamp: number): string {
    if (!isFinite(timestamp) || timestamp <= 0) {
      return '';
    }
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hour}:${minute}`;
  }

  private parseMessageParticipantList(raw: string): string {
    if (raw == null || raw === '') {
      return '';
    }
    const normalized = raw.replace(/\t/g, ' ').trim();
    if (normalized === '') {
      return '';
    }
    const parts = normalized.split(/\s+/);
    const names: string[] = [];
    for (let i = 1; i < parts.length; i += 2) {
      const name = this.sanitizeDisplayName(parts[i]);
      if (name !== '') {
        names.push(name);
      }
    }
    return names.join(', ');
  }

  private parseMessageThreadList(raw: string): MessageThreadList | null {
    const jsonObj = this.parseMessageJsonObject(raw);
    if (jsonObj == null) {
      LogUtils.e(NgaApi.LOG_TAG, 'parseMessageThreadList jsonObj is null');
      return null;
    }

    const list = new MessageThreadList();
    const dataField = jsonObj['data'];
    if (dataField == null || typeof dataField !== 'object' || Array.isArray(dataField)) {
      LogUtils.e(NgaApi.LOG_TAG, 'parseMessageThreadList missing data field, topKeys=' + Object.keys(jsonObj).join(','));
      list.errorMsg = this.extractErrorMsg(jsonObj) || '请重新登录';
      return list;
    }

    const pageObj = (dataField as Record<string, Object>)['0'];
    if (pageObj == null || typeof pageObj !== 'object' || Array.isArray(pageObj)) {
      LogUtils.e(
        NgaApi.LOG_TAG,
        'parseMessageThreadList missing data.0, dataKeys=' + Object.keys(dataField as Record<string, Object>).join(',')
      );
      list.errorMsg = '消息列表为空';
      return list;
    }

    const pageData = pageObj as Record<string, Object>;
    list.page = Math.max(1, this.intValue(pageData['currentPage']));
    const nextPage = this.intValue(pageData['nextPage']);
    list.hasMore = nextPage > 0;
    list.totalPages = nextPage > 0 ? Math.max(list.page + 1, nextPage) : list.page;

    const rowKeys = this.numericObjectKeys(pageData);
    LogUtils.i(
      NgaApi.LOG_TAG,
      'parseMessageThreadList page=' + list.page + ', next=' + nextPage +
      ', rows=' + rowKeys.join(',')
    );
    for (let i = 0; i < rowKeys.length; i++) {
      const rowObj = pageData[rowKeys[i]];
      if (rowObj == null || typeof rowObj !== 'object' || Array.isArray(rowObj)) {
        continue;
      }
      const row = rowObj as Record<string, Object>;
      if (row['mid'] == null) {
        continue;
      }

      const thread = new MessageThread();
      thread.mid = String(row['mid']);
      thread.posts = this.intValue(row['posts']);
      thread.subject = this.decodeHtmlEntities(row['subject'] != null ? String(row['subject']) : '');
      thread.fromUserName = this.pickDisplayName(
        row['from_username'] != null ? String(row['from_username']) : '',
        '',
        ''
      );
      thread.lastFromUserName = this.pickDisplayName(
        row['last_from_username'] != null ? String(row['last_from_username']) : '',
        thread.fromUserName,
        ''
      );
      thread.time = this.formatUnixSeconds(row['time']);
      thread.lastTime = this.formatUnixSeconds(row['last_modify']);
      list.threads.push(thread);
    }

    list.totalCount = list.threads.length;
    LogUtils.i(NgaApi.LOG_TAG, 'parseMessageThreadList parsed threads=' + list.totalCount);
    return list;
  }

  private parseMessageDetail(raw: string, mid: string, page: number): MessageDetail | null {
    const jsonObj = this.parseMessageJsonObject(raw);
    if (jsonObj == null) {
      LogUtils.e(NgaApi.LOG_TAG, 'parseMessageDetail jsonObj is null, mid=' + mid + ', page=' + page);
      return null;
    }

    const detail = new MessageDetail();
    detail.mid = mid;

    const dataField = jsonObj['data'];
    if (dataField == null || typeof dataField !== 'object' || Array.isArray(dataField)) {
      LogUtils.e(NgaApi.LOG_TAG, 'parseMessageDetail missing data field, topKeys=' + Object.keys(jsonObj).join(','));
      detail.errorMsg = this.extractErrorMsg(jsonObj) || '请重新登录';
      return detail;
    }

    const pageObj = (dataField as Record<string, Object>)['0'];
    if (pageObj == null || typeof pageObj !== 'object' || Array.isArray(pageObj)) {
      LogUtils.e(
        NgaApi.LOG_TAG,
        'parseMessageDetail missing data.0, dataKeys=' + Object.keys(dataField as Record<string, Object>).join(',')
      );
      detail.errorMsg = '消息详情为空';
      return detail;
    }

    const pageData = pageObj as Record<string, Object>;
    detail.page = Math.max(1, this.intValue(pageData['currentPage']) || page);
    const nextPage = this.intValue(pageData['nextPage']);
    detail.hasMore = nextPage > 0;
    detail.totalPages = nextPage > 0 ? Math.max(detail.page + 1, nextPage) : detail.page;
    detail.allUsers = this.parseMessageParticipantList(pageData['allUsers'] != null ? String(pageData['allUsers']) : '');

    const userInfoMap = pageData['userInfo'] != null && typeof pageData['userInfo'] === 'object' && !Array.isArray(pageData['userInfo'])
      ? pageData['userInfo'] as Record<string, Object>
      : null;

    const allMsgs = pageData['allmsgs'] != null && typeof pageData['allmsgs'] === 'object' && !Array.isArray(pageData['allmsgs'])
      ? pageData['allmsgs'] as Record<string, Object>
      : null;
    if (allMsgs == null) {
      LogUtils.e(NgaApi.LOG_TAG, 'parseMessageDetail missing allmsgs, pageKeys=' + Object.keys(pageData).join(','));
      detail.errorMsg = '消息详情为空';
      return detail;
    }

    const rowKeys = this.numericObjectKeys(allMsgs);
    LogUtils.i(
      NgaApi.LOG_TAG,
      'parseMessageDetail mid=' + mid + ', page=' + detail.page +
      ', next=' + nextPage + ', rows=' + rowKeys.join(',')
    );
    for (let i = 0; i < rowKeys.length; i++) {
      const rowObj = allMsgs[rowKeys[i]];
      if (rowObj == null || typeof rowObj !== 'object' || Array.isArray(rowObj)) {
        continue;
      }
      const row = rowObj as Record<string, Object>;
      const entry = new MessageDetailEntry();
      entry.floor = (detail.page - 1) * 20 + i + 1;
      entry.content = row['content'] != null ? String(row['content']) : '';
      entry.subject = this.decodeHtmlEntities(row['subject'] != null ? String(row['subject']) : '');
      entry.time = this.formatUnixSeconds(row['time']);
      entry.fromUid = this.positiveUidString(row['from']);

      if (userInfoMap != null && entry.fromUid !== '') {
        const userInfo = userInfoMap[entry.fromUid];
        if (userInfo != null && typeof userInfo === 'object' && !Array.isArray(userInfo)) {
          const userObj = userInfo as Record<string, Object>;
          entry.fromUserName = this.pickDisplayName(
            userObj['username'] != null ? String(userObj['username']) : '',
            '',
            ''
          );
          entry.avatarUrl = userObj['avatar'] != null ? String(userObj['avatar']) : '';
          entry.signature = userObj['signature'] != null ? String(userObj['signature']) : '';
        }
      }

      if (entry.fromUserName === '') {
        entry.fromUserName = '用户 ' + (entry.fromUid !== '' ? entry.fromUid : '?');
      }
      detail.entries.push(entry);
    }

    if (detail.entries.length > 0) {
      detail.title = detail.entries[0].subject !== '' ? detail.entries[0].subject : '';
    }
    LogUtils.i(NgaApi.LOG_TAG, 'parseMessageDetail parsed entries=' + detail.entries.length + ', mid=' + mid);
    return detail;
  }

  private parseRecentReplyNotification(itemObj: Object, unread: boolean): NotificationItem {
    const item = new NotificationItem();
    item.type = this.intValue(this.indexedValue(itemObj, 0));
    item.userId = this.positiveUidString(this.indexedValue(itemObj, 1));
    item.userName = this.pickDisplayName(
      this.indexedValue(itemObj, 2) != null ? String(this.indexedValue(itemObj, 2)) : '',
      '',
      ''
    );
    item.title = this.decodeHtmlEntities(this.indexedValue(itemObj, 5) != null ? String(this.indexedValue(itemObj, 5)) : '');
    item.tidStr = this.indexedValue(itemObj, 6) != null ? String(this.indexedValue(itemObj, 6)) : '';
    const pidPrimary = this.indexedValue(itemObj, 7);
    const pidFallback = this.indexedValue(itemObj, 8);
    item.pidStr = pidPrimary != null && String(pidPrimary) !== '' ? String(pidPrimary) : (pidFallback != null ? String(pidFallback) : '');
    item.timeStamp = this.indexedValue(itemObj, 9) != null ? String(this.indexedValue(itemObj, 9)) : '';
    item.timeText = this.formatUnixSeconds(item.timeStamp as Object);
    item.isUnread = unread;
    item.isMessageNotice = false;
    return item;
  }

  private parseMessageNotification(itemObj: Object, unread: boolean): NotificationItem {
    const item = new NotificationItem();
    item.type = this.intValue(this.indexedValue(itemObj, 0));
    item.userId = this.positiveUidString(this.indexedValue(itemObj, 1));
    item.userName = this.pickDisplayName(
      this.indexedValue(itemObj, 2) != null ? String(this.indexedValue(itemObj, 2)) : '',
      '',
      ''
    );
    item.title = this.decodeHtmlEntities(this.indexedValue(itemObj, 5) != null ? String(this.indexedValue(itemObj, 5)) : '');
    item.midStr = this.indexedValue(itemObj, 6) != null ? String(this.indexedValue(itemObj, 6)) : '';
    item.timeStamp = this.indexedValue(itemObj, 9) != null ? String(this.indexedValue(itemObj, 9)) : '';
    item.timeText = this.formatUnixSeconds(item.timeStamp as Object);
    item.isUnread = unread;
    item.isMessageNotice = true;
    return item;
  }

  private parseNotificationList(raw: string): NotificationList | null {
    const jsonObj = this.parseJsonObject(raw);
    if (jsonObj == null) {
      LogUtils.e(NgaApi.LOG_TAG, 'parseNotificationList jsonObj is null');
      return null;
    }

    const list = new NotificationList();
    const dataField = jsonObj['data'];
    if (dataField == null || typeof dataField !== 'object' || Array.isArray(dataField)) {
      LogUtils.e(NgaApi.LOG_TAG, 'parseNotificationList missing data field, topKeys=' + Object.keys(jsonObj).join(','));
      list.errorMsg = this.extractErrorMsg(jsonObj) || '请重新登录';
      return list;
    }

    const root = (dataField as Record<string, Object>)['0'];
    if (root == null || typeof root !== 'object' || Array.isArray(root)) {
      LogUtils.e(
        NgaApi.LOG_TAG,
        'parseNotificationList missing data.0, dataKeys=' + Object.keys(dataField as Record<string, Object>).join(',')
      );
      list.errorMsg = '通知列表为空';
      return list;
    }

    const rootObj = root as Record<string, Object>;
    list.unreadCount = this.intValue(rootObj['unread']);
    const unread = list.unreadCount > 0;

    const recentReplyArray = rootObj['0'];
    if (Array.isArray(recentReplyArray)) {
      const arr = recentReplyArray as Object[];
      for (let i = 0; i < arr.length; i++) {
        list.notifications.push(this.parseRecentReplyNotification(arr[i], unread));
      }
    }

    const messageArray = rootObj['1'];
    if (Array.isArray(messageArray)) {
      const arr = messageArray as Object[];
      for (let i = 0; i < arr.length; i++) {
        list.notifications.push(this.parseMessageNotification(arr[i], unread));
      }
    }

    list.notifications.sort((a: NotificationItem, b: NotificationItem) => {
      return this.intValue(b.timeStamp as Object) - this.intValue(a.timeStamp as Object);
    });
    LogUtils.i(
      NgaApi.LOG_TAG,
      'parseNotificationList parsed notifications=' + list.notifications.length + ', unread=' + list.unreadCount
    );
    return list;
  }

  private findUserRecordForPost(
    userMap: Map<string, Record<string, Object>>,
    userRecords: Record<string, Object>[],
    authorIdStr: string,
    authorLookupKey: string,
    displayAuthor: string
  ): Record<string, Object> | null {
    if (authorLookupKey !== '') {
      const rawKeyRecord = userMap.get(authorLookupKey);
      if (rawKeyRecord != null) {
        return rawKeyRecord;
      }
    }
    if (authorIdStr !== '' && authorIdStr !== '0') {
      const r1 = userMap.get(authorIdStr);
      if (r1 != null) {
        return r1;
      }
    }
    if (authorIdStr !== '' && authorIdStr !== '0') {
      for (let i = 0; i < userRecords.length; i++) {
        const uidVal = userRecords[i]['uid'];
        if (uidVal != null && String(uidVal) === authorIdStr) {
          return userRecords[i];
        }
      }
    }
    const dn = this.sanitizeDisplayName(displayAuthor);
    if (dn !== '') {
      for (let j = 0; j < userRecords.length; j++) {
        const rec = userRecords[j];
        const un = rec['username'];
        const nn = rec['nickname'];
        if (un != null && this.sanitizeDisplayName(String(un)) === dn) {
          return rec;
        }
        if (nn != null && String(nn) !== '' && String(nn) !== 'null' &&
          this.sanitizeDisplayName(String(nn)) === dn) {
          return rec;
        }
      }
    }
    return null;
  }

  /**
   * RSA 加密密码（与 Web 端 JSEncrypt 行为一致）
   */
  private async encryptPassword(password: string): Promise<string> {
    const base64Helper = new util.Base64Helper();
    const pubKeyData = base64Helper.decodeSync(NgaApi.NGA_RSA_PUB_KEY);
    const pubKeyBlob: cryptoFramework.DataBlob = { data: pubKeyData };

    const rsaGenerator = cryptoFramework.createAsyKeyGenerator('RSA2048');
    const keyPair = await rsaGenerator.convertKey(pubKeyBlob, null);

    const cipher = cryptoFramework.createCipher('RSA2048|PKCS1');
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, keyPair.pubKey, null);

    const plainBlob: cryptoFramework.DataBlob = {
      data: new Uint8Array(buffer.from(password, 'utf-8').buffer)
    };
    const encryptedBlob = await cipher.doFinal(plainBlob);

    return base64Helper.encodeToStringSync(encryptedBlob.data);
  }

  /**
   * 加载图形验证码
   */
  async loadCaptcha(): Promise<CaptchaResult> {
    const result = new CaptchaResult();
    result.rid = 'login' + String(Math.random()).substring(2);
    result.prid = 'P' + String(Math.random()).substring(2);
    const url = this.baseUrl + '/login_check_code.php?id=' + result.rid + '&from=login';

    const httpResult = await this.http.getCaptchaImage(url);
    result.imageData = httpResult.imageData;

    // 提取 ngaPassportOid cookie，登录时需要携带
    if (httpResult.cookies) {
      const parts = httpResult.cookies.split(/[;,]/);
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i].trim();
        if (part.indexOf('ngaPassportOid=') >= 0) {
          result.captchaCookie = part;
          break;
        }
      }
    }

    return result;
  }

  async voteArticle(tid: string, pid: string, value: number): Promise<string> {
    const body = 'tid=' + encodeURIComponent(tid) +
      '&pid=' + encodeURIComponent(pid) +
      '&value=' + encodeURIComponent(String(value));
    const response = await this.http.post('/nuke.php?__lib=topic_recommend&__act=add&raw=3&__output=8', body);
    if (response.code !== 200) {
      return response.message !== '' ? response.message : '操作失败';
    }

    const raw = response.raw || '';
    if (raw === '') {
      return '服务器返回空响应';
    }

    try {
      let jsonStr = raw;
      const prefix = 'window.script_muti_get_var_store=';
      if (jsonStr.indexOf(prefix) === 0) {
        jsonStr = jsonStr.substring(prefix.length);
      }

      const jsonObj = JSON.parse(jsonStr) as Record<string, Object>;
      const errMsg = this.extractErrorMsg(jsonObj);
      if (errMsg !== '') {
        return errMsg;
      }

      const data = jsonObj['data'];
      if (data != null && typeof data === 'object' && !Array.isArray(data)) {
        const dataObj = data as Record<string, Object>;
        if (dataObj['0'] != null) {
          return String(dataObj['0']);
        }
      }
      return '操作成功';
    } catch (err) {
      console.error('voteArticle parse failed:', err);
      return response.message !== '' ? response.message : '操作失败';
    }
  }

  /**
   * 原生登录（表单提交）
   * 使用 __output=11 获得 UTF-8 编码的纯 JSON 响应
   */
  async nativeLogin(username: string, password: string, captcha: string,
    rid: string, captchaCookie: string, prid: string): Promise<LoginResult> {
    const loginResult = new LoginResult();

    let encryptedPassword: string;
    try {
      encryptedPassword = await this.encryptPassword(password);
    } catch (e) {
      console.error('RSA encrypt failed, fallback to plaintext: ' + JSON.stringify(e));
      encryptedPassword = password;
    }

    const params: string = [
      'name=' + encodeURIComponent(username),
      'type=name',
      'password=' + encodeURIComponent(encryptedPassword),
      'rid=' + encodeURIComponent(rid),
      'captcha=' + encodeURIComponent(captcha.toUpperCase()),
      'prid=' + encodeURIComponent(prid),
      '__lib=login',
      '__act=login',
      '__output=11',
      '__inchst=UTF-8'
    ].join('&');

    const httpResult: LoginHttpResult =
      await this.http.postLogin(this.baseUrl + '/nuke.php', params, captchaCookie);

    console.info('Login HTTP code: ' + httpResult.code);
    if (httpResult.body) {
      console.info('Login body: ' + httpResult.body.substring(0, 300));
    }

    if (httpResult.code === -1) {
      loginResult.errorMsg = httpResult.errorMsg || '网络请求失败';
      return loginResult;
    }

    // 先从 body 解析登录结果（成功时 uid/token 在 data 字段里，失败时在 error 字段里）
    this.parseLoginBody(httpResult.body, loginResult);

    // 如果 body 没拿到凭证，再尝试从 Set-Cookie 提取（作为备用）
    if (!loginResult.success && httpResult.cookies) {
      this.parseCookies(httpResult.cookies, loginResult);
    }

    console.info('Login result: success=' + loginResult.success +
      ', uid=' + loginResult.uid + ', errorMsg=' + loginResult.errorMsg);

    return loginResult;
  }

  /**
   * 解析登录响应中的 Set-Cookie
   */
  private parseCookies(cookies: string, result: LoginResult): void {
    const TAG_UID = 'ngaPassportUid=';
    const TAG_CID = 'ngaPassportCid=';
    const TAG_UNAME = 'ngaPassportUrlencodedUname=';

    const parts = cookies.split(/[;,]/);
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i].trim();
      const uidIdx = part.indexOf(TAG_UID);
      const cidIdx = part.indexOf(TAG_CID);
      const unameIdx = part.indexOf(TAG_UNAME);

      if (uidIdx >= 0) {
        result.uid = part.substring(uidIdx + TAG_UID.length);
      } else if (cidIdx >= 0) {
        result.cid = part.substring(cidIdx + TAG_CID.length);
      } else if (unameIdx >= 0) {
        let name = part.substring(unameIdx + TAG_UNAME.length);
        try {
          name = decodeURIComponent(name);
        } catch (_e) { /* keep raw */ }
        result.userName = name;
      }
    }

    if (result.uid && result.cid) {
      result.success = true;
    }
  }

  /**
   * 解析登录响应 body
   * 成功: {"data":[..., ..., ..., {"uid":"xxx","token":"yyy"}], "time":...}
   * 失败: {"error":["错误信息"], "time":...}
   */
  private parseLoginBody(body: string, result: LoginResult): void {
    if (!body) {
      return;
    }
    try {
      let json = body;
      const jsPrefix = 'window.script_muti_get_var_store=';
      if (json.indexOf(jsPrefix) === 0) {
        json = json.substring(jsPrefix.length);
      }

      const obj: Record<string, Object> = JSON.parse(json);

      // 1) 检查 error 字段
      const errorField = obj['error'];
      if (errorField != null) {
        if (Array.isArray(errorField)) {
          const arr = errorField as string[];
          if (arr.length > 0) {
            result.errorMsg = String(arr[0]);
          }
        } else if (typeof errorField === 'object') {
          const errorObj = errorField as Record<string, string>;
          result.errorMsg = errorObj['0'] || JSON.stringify(errorObj);
        }
        return;
      }

      // 2) 检查 data 字段（登录成功）
      const dataField = obj['data'];
      if (dataField != null) {
        this.parseLoginData(dataField, result);
      }
    } catch (_e) {
      if (body.length < 500) {
        result.errorMsg = body;
      }
    }
  }

  /**
   * 从 data 字段提取登录凭证
   * Web 端: data[3] 包含 {uid, token}
   */
  private parseLoginData(dataField: Object, result: LoginResult): void {
    let loginInfo: Record<string, Object> | null = null;

    if (Array.isArray(dataField)) {
      // __output=11: data 是数组 [v0, v1, v2, {uid, token}]
      const arr = dataField as Object[];
      if (arr.length > 3 && arr[3] != null && typeof arr[3] === 'object') {
        loginInfo = arr[3] as Record<string, Object>;
      }
    } else if (typeof dataField === 'object') {
      // __output=1/8: data 是对象 {"0":v0, "1":v1, "3":{uid, token}}
      const dataObj = dataField as Record<string, Object>;
      const entry3 = dataObj['3'];
      if (entry3 != null && typeof entry3 === 'object') {
        loginInfo = entry3 as Record<string, Object>;
      }
    }

    if (loginInfo != null) {
      const uid = loginInfo['uid'];
      const token = loginInfo['token'];
      if (uid != null) {
        result.uid = String(uid);
      }
      if (token != null) {
        result.cid = String(token);
      }
      const uname = loginInfo['username'];
      if (uname != null) {
        result.userName = String(uname);
      }
      if (result.uid && result.cid) {
        result.success = true;
      }
    }
  }

  /**
   * 获取帖子列表
   * @param fid 版块ID
   * @param page 页码
   * @param stid 子版块ID（可选）
   */
  async getTopicList(fid: number, page: number, stid: number = 0): Promise<HttpResponse<TopicList>> {
    let url = this.baseUrl + '/thread.php?';
    if (stid != 0) {
      url = url + 'stid=' + stid;
    } else {
      url = url + 'fid=' + fid;
    }
    url = url + '&page=' + page + '&lite=js&noprefix&__output=11';

    const response = await this.http.get(url);
    const result = new HttpResponse<TopicList>();
    result.code = response.code;
    result.message = response.message;

    if (response.code === 200 && response.raw != null && response.raw !== '') {
      const parsed = this.parseTopicList(response.raw, page);
      result.data = parsed;
      if (parsed.errorMsg) {
        result.message = parsed.errorMsg;
      }
    } else {
      const errorList = new TopicList();
      if (response.code !== 200) {
        errorList.errorMsg = '请求失败 (HTTP ' + response.code + ')';
      } else {
        errorList.errorMsg = response.message || '服务器返回空数据';
      }
      result.data = errorList;
    }
    return result;
  }

  /**
   * 获取收藏帖子列表
   */
  async getFavoriteTopics(page: number): Promise<HttpResponse<TopicList>> {
    const url = this.baseUrl + '/thread.php?favor=1&page=' + page + '&lite=js&noprefix&__output=11';
    console.info('getFavoriteTopics URL:', url);
    
    const response = await this.http.get(url);
    const result = new HttpResponse<TopicList>();
    result.code = response.code;
    result.message = response.message;

    if (response.code === 200 && response.raw != null && response.raw !== '') {
      const parsed = this.parseTopicList(response.raw, page);
      result.data = parsed;
      if (parsed.errorMsg) {
        result.message = parsed.errorMsg;
      }
    } else {
      const errorList = new TopicList();
      if (response.code !== 200) {
        errorList.errorMsg = '请求失败 (HTTP ' + response.code + ')';
      } else {
        errorList.errorMsg = response.message || '服务器返回空数据';
      }
      result.data = errorList;
    }
    return result;
  }

  /**
   * 搜索帖子
   * @param keyword 搜索关键词
   * @param fid 板块ID (0表示全站搜索)
   * @param stid 子板块ID
   */
  async searchTopics(keyword: string, fid: number = 0, stid: number = 0): Promise<HttpResponse<TopicList>> {
    let url = this.baseUrl + '/thread.php?';
    if (stid != 0) {
      url = url + 'stid=' + stid;
    } else if (fid != 0) {
      url = url + 'fid=' + fid;
    }
    url = url + '&searchpost=1&key=' + encodeURIComponent(keyword) + '&page=1&lite=js&noprefix&__output=11';
    console.info('searchTopics URL:', url);

    const response = await this.http.get(url);
    const result = new HttpResponse<TopicList>();
    result.code = response.code;
    result.message = response.message;

    if (response.code === 200 && response.raw != null && response.raw !== '') {
      const parsed = this.parseTopicList(response.raw, 1);
      result.data = parsed;
      if (parsed.errorMsg) {
        result.message = parsed.errorMsg;
      }
    } else {
      const errorList = new TopicList();
      if (response.code !== 200) {
        errorList.errorMsg = '请求失败 (HTTP ' + response.code + ')';
      } else {
        errorList.errorMsg = response.message || '服务器返回空数据';
      }
      result.data = errorList;
    }
    return result;
  }

  /**
   * 解析帖子列表
   */
  private parseTopicList(jsonStr: string, currentPage: number): TopicList {
    const list = new TopicList();
    list.page = currentPage;

    try {
      let js = jsonStr;
      const jsPrefix = 'window.script_muti_get_var_store=';
      if (js.indexOf(jsPrefix) === 0) {
        js = js.substring(jsPrefix.length);
      }

      let jsonObj: Record<string, Object>;
      try {
        jsonObj = JSON.parse(js) as Record<string, Object>;
      } catch (_parseErr) {
        console.error('Topic JSON.parse failed, attempting recovery...');
        const fixed = this.tryFixTruncatedJson(js);
        if (fixed != null) {
          console.info('Topic truncated JSON recovered');
          jsonObj = JSON.parse(fixed) as Record<string, Object>;
        } else {
          list.errorMsg = '数据解析失败';
          return list;
        }
      }

      // 检查是否有错误响应（如"未登录"）
      const errMsg = this.extractErrorMsg(jsonObj);
      if (errMsg) {
        list.errorMsg = errMsg;
        console.error('Topic list API error:', errMsg);
        return list;
      }

      const data: Record<string, Object> = jsonObj['data'] as Record<string, Object>;
      if (data == null) {
        list.errorMsg = '服务器返回数据为空';
        return list;
      }

      const tField: Object = data['__T'];
      if (tField == null) {
        list.errorMsg = '帖子列表数据为空';
        return list;
      }

      const tRowsThisPage: number = data['__T__ROWS'] as number;
      const rowsPerPage: number = data['__T__ROWS_PAGE'] as number;
      const totalRowsInBoard: number = data['__ROWS'] as number;

      const tPerPage = (rowsPerPage != null && rowsPerPage > 0) ? rowsPerPage : 35;
      if (totalRowsInBoard != null && totalRowsInBoard > 0) {
        list.totalCount = totalRowsInBoard;
      } else if (tRowsThisPage != null) {
        list.totalCount = tRowsThisPage;
      }
      list.totalPages = list.totalCount > 0 ? Math.ceil(list.totalCount / tPerPage) : 1;

      // __output=11 时 __T 是数组，默认/8 时是对象
      const items: Record<string, Object>[] = [];
      if (Array.isArray(tField)) {
        const arr = tField as Object[];
        for (let i = 0; i < arr.length; i++) {
          if (arr[i] != null && typeof arr[i] === 'object') {
            items.push(arr[i] as Record<string, Object>);
          }
        }
      } else if (typeof tField === 'object') {
        const t = tField as Record<string, Object>;
        const keys: string[] = Object.keys(t);
        for (let i = 0; i < keys.length; i++) {
          if (keys[i].indexOf('__') === 0) {
            continue;
          }
          const val = t[keys[i]];
          if (val != null && typeof val === 'object') {
            items.push(val as Record<string, Object>);
          }
        }
      }

      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const topic = new Topic();
        topic.tid = String(item['tid'] != null ? item['tid'] : '');
        topic.fid = String(item['fid'] != null ? item['fid'] : '');
        topic.subject = item['subject'] != null ? this.decodeHtmlEntities(String(item['subject'])) : '';
        const topicAuthorRaw = item['author'] != null ? String(item['author']) : '';
        const topicAid = item['authorid'] != null ? item['authorid'] : item['userid'];
        topic.author.username = this.pickDisplayName(
          topicAuthorRaw,
          topicAid != null ? String(topicAid) : '',
          ''
        );
        topic.author.uid = this.positiveUidString(topicAid);
        topic.postDate = String(item['postdate'] != null ? item['postdate'] : '');
        topic.lastPostDate = String(item['lastpost'] != null ? item['lastpost'] : '');
        topic.replies = item['replies'] != null ? (item['replies'] as number) : 0;
        const lastPoster = item['lastposter'];
        if (lastPoster != null) {
          topic.lastPoster = this.sanitizeDisplayName(String(lastPoster));
        }

        list.topics.push(topic);
      }

      list.hasMore = items.length > 0;
    } catch (err) {
      console.error('Parse topic list failed:', err);
      console.error('Raw response (first 500 chars):', jsonStr.substring(0, 500));
      list.errorMsg = '列表解析失败';
    }

    return list;
  }

  /**
   * 获取帖子详情
   */
  async getArticleList(tid: string, page: number): Promise<HttpResponse<ArticleList>> {
    const normalizedTid = this.normalizeTidValue(tid);
    if (normalizedTid !== tid) {
      LogUtils.w(NgaApi.LOG_TAG, 'getArticleList normalized tid from ' + tid + ' to ' + normalizedTid);
    }
    const url = this.baseUrl + '/read.php?tid=' + normalizedTid + '&page=' + page + '&__output=11&noprefix&v2';
    LogUtils.i(NgaApi.LOG_TAG, 'getArticleList request tid=' + normalizedTid + ', page=' + page + ', url=' + url);
    const response = await this.http.get(url);
    const result = new HttpResponse<ArticleList>();
    result.code = response.code;
    result.message = response.message;
    LogUtils.i(
      NgaApi.LOG_TAG,
      'getArticleList response tid=' + normalizedTid +
      ', page=' + page +
      ', code=' + response.code +
      ', message=' + response.message +
      ', rawPreview=' + this.previewRaw(response.raw)
    );

    if (response.code === 200 && response.raw != null && response.raw !== '') {
      const parsed = this.parseArticleList(response.raw, page);
      result.data = parsed;
      LogUtils.i(
        NgaApi.LOG_TAG,
        'getArticleList parsed tid=' + normalizedTid +
        ', page=' + page +
        ', subject=' + parsed.subject +
        ', totalCount=' + parsed.totalCount +
        ', totalPages=' + parsed.totalPages +
        ', articles=' + parsed.articles.length +
        ', hasMore=' + parsed.hasMore +
        ', errorMsg=' + parsed.errorMsg
      );
      if (parsed.errorMsg) {
        result.message = parsed.errorMsg;
      }
    } else {
      const errorList = new ArticleList();
      if (response.code !== 200) {
        errorList.errorMsg = '请求失败 (HTTP ' + response.code + ')';
      } else {
        errorList.errorMsg = response.message || '服务器返回空数据';
      }
      result.data = errorList;
      LogUtils.w(
        NgaApi.LOG_TAG,
        'getArticleList request failed tid=' + normalizedTid +
        ', page=' + page +
        ', code=' + response.code +
        ', message=' + errorList.errorMsg
      );
    }
    return result;
  }

  /**
   * 解析帖子详情（楼层列表）
   */
  private parseArticleList(jsonStr: string, currentPage: number): ArticleList {
    const list = new ArticleList();
    list.page = currentPage;
    LogUtils.i(NgaApi.LOG_TAG, 'parseArticleList start page=' + currentPage + ', rawLength=' + jsonStr.length);

    try {
      const js = this.sanitizeJsonControlChars(this.normalizeArticleJson(jsonStr));

      let jsonObj: Record<string, Object>;
      let parseSource = js;
      try {
        jsonObj = JSON.parse(parseSource) as Record<string, Object>;
      } catch (parseErr) {
        LogUtils.w(
          NgaApi.LOG_TAG,
          'parseArticleList first parse failed, page=' + currentPage + ', ' +
          this.describeJsonParseError(parseErr as Object, parseSource)
        );

        const repairedEscapes = this.normalizeJsonStringEscapes(parseSource);
        if (repairedEscapes !== parseSource) {
          try {
            jsonObj = JSON.parse(repairedEscapes) as Record<string, Object>;
            parseSource = repairedEscapes;
            LogUtils.i(NgaApi.LOG_TAG, 'parseArticleList repaired invalid string escape, page=' + currentPage);
          } catch (escapeErr) {
            LogUtils.w(
              NgaApi.LOG_TAG,
              'parseArticleList escape repair failed, page=' + currentPage + ', ' +
              this.describeJsonParseError(escapeErr as Object, repairedEscapes)
            );
            parseSource = repairedEscapes;
            const fixed = this.tryFixTruncatedJson(repairedEscapes);
            if (fixed != null) {
              try {
                jsonObj = JSON.parse(fixed) as Record<string, Object>;
                parseSource = fixed;
                LogUtils.i(NgaApi.LOG_TAG, 'parseArticleList repaired truncated json successfully, page=' + currentPage);
              } catch (fixedErr) {
                LogUtils.e(
                  NgaApi.LOG_TAG,
                  'parseArticleList repaired parse still failed, page=' + currentPage + ', ' +
                  this.describeJsonParseError(fixedErr as Object, fixed)
                );
                list.errorMsg = '数据解析失败';
                return list;
              }
            } else {
              LogUtils.e(NgaApi.LOG_TAG, 'parseArticleList unable to repair json, page=' + currentPage);
              list.errorMsg = '数据解析失败';
              return list;
            }
          }
        } else {
          const fixed = this.tryFixTruncatedJson(parseSource);
          if (fixed != null) {
            try {
              jsonObj = JSON.parse(fixed) as Record<string, Object>;
              parseSource = fixed;
              LogUtils.i(NgaApi.LOG_TAG, 'parseArticleList repaired truncated json successfully, page=' + currentPage);
            } catch (fixedErr) {
              LogUtils.e(
                NgaApi.LOG_TAG,
                'parseArticleList repaired parse still failed, page=' + currentPage + ', ' +
                this.describeJsonParseError(fixedErr as Object, fixed)
              );
              list.errorMsg = '数据解析失败';
              return list;
            }
          } else {
            LogUtils.e(NgaApi.LOG_TAG, 'parseArticleList unable to repair json, page=' + currentPage);
            list.errorMsg = '数据解析失败';
            return list;
          }
        }
      }

      // 检查错误响应
      const errMsg = this.extractErrorMsg(jsonObj);
      if (errMsg) {
        list.errorMsg = errMsg;
        return list;
      }

      const data: Record<string, Object> = jsonObj['data'] as Record<string, Object>;
      if (data == null) {
        LogUtils.e(NgaApi.LOG_TAG, 'parseArticleList missing data field, topKeys=' + Object.keys(jsonObj).join(','));
        list.errorMsg = '服务器返回数据为空';
        return list;
      }
      const dataKeys = Object.keys(data);

      const tField: Object | null = data['__T'] as Object;
      const threadMeta = this.extractThreadDetailMeta(tField);
      let threadAuthorId = '';
      let threadAuthorName = '';
      let threadAuthorAnonymousIdentity = '';
      let threadAuthorLookupKey = '';
      let threadAuthorDisplayRaw = '';
      if (threadMeta != null) {
        if (threadMeta['tid'] != null) {
          list.tid = String(threadMeta['tid']);
        }
        if (threadMeta['subject'] != null) {
          list.subject = this.decodeHtmlEntities(String(threadMeta['subject']));
        }
        const ta = threadMeta['authorid'] != null ? threadMeta['authorid'] :
          (threadMeta['userid'] != null ? threadMeta['userid'] : threadMeta['posterid']);
        threadAuthorId = this.positiveUidString(ta);
        threadAuthorAnonymousIdentity = this.extractAnonymousIdentity(threadMeta);
        threadAuthorLookupKey = threadAuthorAnonymousIdentity !== '' ?
          threadAuthorAnonymousIdentity :
          (ta != null ? String(ta) : '');
        threadAuthorDisplayRaw = threadMeta['author'] != null ? String(threadMeta['author']) : '';
        threadAuthorName = this.pickDisplayName(
          threadAuthorDisplayRaw,
          ta != null ? String(ta) : '',
          ''
        );
      }
      const normalizedThreadAuthorName = this.sanitizeDisplayName(threadAuthorName);
      LogUtils.i(
        NgaApi.LOG_TAG,
        'parseArticleList meta page=' + currentPage +
        ', tid=' + list.tid +
        ', subject=' + list.subject +
        ', threadAuthorId=' + threadAuthorId +
        ', dataKeys=' + dataKeys.join(',')
      );

      const rows: number = data['__ROWS'] as number;
      const rowsPerPage: number = data['__R__ROWS_PAGE'] as number;

      list.totalCount = rows != null ? rows : 0;
      const perPage = (rowsPerPage != null && rowsPerPage > 0) ? rowsPerPage : 20;
      list.totalPages = list.totalCount > 0 ? Math.ceil(list.totalCount / perPage) : 1;

      // 解析用户信息表 __U（键可能是 uid 或用户名，需同时按 uid 建索引）
      const userMap: Map<string, Record<string, Object>> = new Map();
      const userRecords: Record<string, Object>[] = [];
      const uField = data['__U'];
      if (uField != null && typeof uField === 'object') {
        if (Array.isArray(uField)) {
          const uArr = uField as Object[];
          for (let i = 0; i < uArr.length; i++) {
            if (uArr[i] != null && typeof uArr[i] === 'object') {
              const u = uArr[i] as Record<string, Object>;
              const uid = u['uid'];
              if (uid != null) {
                const uidStr = String(uid);
                userMap.set(uidStr, u);
              }
              const anonymousIdentity = this.extractAnonymousIdentity(u);
              if (anonymousIdentity !== '') {
                userMap.set(anonymousIdentity, u);
              }
              userRecords.push(u);
            }
          }
        } else {
          const uObj = uField as Record<string, Object>;
          const uKeys = Object.keys(uObj);
          for (let i = 0; i < uKeys.length; i++) {
            if (uKeys[i].indexOf('__') === 0) continue;
            const u = uObj[uKeys[i]];
            if (u != null && typeof u === 'object') {
              const rec = u as Record<string, Object>;
              userMap.set(uKeys[i], rec);
              const innerUid = rec['uid'];
              if (innerUid != null) {
                userMap.set(String(innerUid), rec);
              }
              const anonymousIdentity = this.extractAnonymousIdentity(rec);
              if (anonymousIdentity !== '') {
                userMap.set(anonymousIdentity, rec);
              }
              userRecords.push(rec);
            }
          }
        }
      }

      const threadUserInfo = this.findUserRecordForPost(
        userMap,
        userRecords,
        threadAuthorId,
        threadAuthorLookupKey,
        threadAuthorDisplayRaw
      );
      if (threadUserInfo != null) {
        const threadUid = this.positiveUidString(threadUserInfo['uid']);
        if (threadAuthorId === '' && threadUid !== '') {
          threadAuthorId = threadUid;
        }
        if (threadAuthorAnonymousIdentity === '') {
          threadAuthorAnonymousIdentity = this.extractAnonymousIdentity(threadUserInfo);
        }
        const threadUserName = threadUserInfo['username'] != null ? String(threadUserInfo['username']) : '';
        const threadNickname = threadUserInfo['nickname'] != null ? String(threadUserInfo['nickname']) : '';
        const resolvedThreadAuthorName = this.pickDisplayName(
          threadAuthorDisplayRaw,
          threadNickname,
          threadUserName !== '' ? threadUserName : (threadAuthorId !== '' ? threadAuthorId : '')
        );
        if (resolvedThreadAuthorName !== '') {
          threadAuthorName = resolvedThreadAuthorName;
        }
      }

      // 遍历回复楼层（__output=11 时 __R 是数组，默认/8 时是对象）
      const rField: Object = data['__R'];
      if (rField != null) {
        const rItems: Record<string, Object>[] = [];
        if (Array.isArray(rField)) {
          const arr = rField as Object[];
          for (let i = 0; i < arr.length; i++) {
            if (arr[i] != null && typeof arr[i] === 'object') {
              rItems.push(arr[i] as Record<string, Object>);
            }
          }
        } else if (typeof rField === 'object') {
          const r = rField as Record<string, Object>;
          const keys: string[] = Object.keys(r);
          for (let i = 0; i < keys.length; i++) {
            if (keys[i].indexOf('__') === 0) {
              continue;
            }
            const val = r[keys[i]];
            if (val != null && typeof val === 'object') {
              rItems.push(val as Record<string, Object>);
            }
          }
        }
        LogUtils.i(
          NgaApi.LOG_TAG,
          'parseArticleList rows page=' + currentPage +
          ', totalRows=' + list.totalCount +
          ', rowsPerPage=' + perPage +
          ', rType=' + (Array.isArray(rField) ? 'array' : typeof rField) +
          ', rItems=' + rItems.length +
          ', userRecords=' + userRecords.length
        );

        for (let i = 0; i < rItems.length; i++) {
          try {
            const item = rItems[i];
            const article = new Article();
            article.pid = String(item['pid'] != null ? item['pid'] : '');
            article.tid = list.tid;
            const louVal = item['lou'];
            article.floor = (louVal != null) ? Number(louVal) : i;
            if (isNaN(article.floor)) article.floor = i;
            article.content = item['content'] != null ? String(item['content']) : '';
            const postdate = item['postdate'];
            if (postdate != null) {
              const pdTimestamp = item['postdatetimestamp'];
              if (pdTimestamp != null) {
                article.postDate = String(pdTimestamp);
              } else {
                article.postDate = String(postdate);
              }
            }

            const idFromPost = item['authorid'] != null ? item['authorid'] :
              (item['uid'] != null ? item['uid'] :
                (item['posterid'] != null ? item['posterid'] : item['userid']));
            let authorIdStr = this.positiveUidString(idFromPost);
            let authorAnonymousIdentity = this.extractAnonymousIdentity(item);
            const authorLookupKey = authorAnonymousIdentity !== '' ?
              authorAnonymousIdentity :
              (idFromPost != null ? String(idFromPost) : '');
            const directAuthorRaw = item['author'] != null ? String(item['author']) : '';
            const directAuthor = this.sanitizeDisplayName(directAuthorRaw);
            const authorIdDisplayCandidate = idFromPost != null ? String(idFromPost) : '';
            let userNameCandidate = '';
            let userNicknameCandidate = '';
            let userAvatarCandidate = '';

            const userInfo = this.findUserRecordForPost(
              userMap,
              userRecords,
              authorIdStr,
              authorLookupKey,
              directAuthor
            );
            if (userInfo != null) {
              const innerUid = userInfo['uid'];
              if (innerUid != null) {
                const uis = this.positiveUidString(innerUid);
                if (uis !== '') {
                  authorIdStr = uis;
                }
              }
              const uname = userInfo['username'];
              if (uname != null) {
                userNameCandidate = String(uname);
              }
              const nickname = userInfo['nickname'];
              if (nickname != null && String(nickname) !== '' && String(nickname) !== 'null') {
                userNicknameCandidate = String(nickname);
              }
              const avatar = userInfo['avatar'];
              if (avatar != null && String(avatar) !== '') {
                userAvatarCandidate = String(avatar);
              }
              if (authorAnonymousIdentity === '') {
                authorAnonymousIdentity = this.extractAnonymousIdentity(userInfo);
              }
            }
            if (authorIdStr !== '') {
              article.author.uid = authorIdStr;
            }
            const resolvedAuthorName = this.pickDisplayName(
              directAuthor,
              userNicknameCandidate,
              userNameCandidate !== '' ? userNameCandidate : authorIdDisplayCandidate
            );
            if (resolvedAuthorName !== '') {
              article.author.username = resolvedAuthorName;
            }
            if (userAvatarCandidate !== '') {
              article.author.avatar = userAvatarCandidate;
            }

            const isFirstPost = (i === 0) || (article.floor === 0);
            if (isFirstPost) {
              if ((article.author.uid === '' || article.author.uid === '0') && threadAuthorId !== '') {
                article.author.uid = threadAuthorId;
              }
              if (!article.author.username && threadAuthorName !== '') {
                article.author.username = threadAuthorName;
              }
            }

            // 判断是否为楼主。匿名楼主没有稳定 UID 时，退化为按解析后的显示名识别。
            const normalizedArticleAuthorName = this.sanitizeDisplayName(article.author.username);
            const sameAuthorByUid = threadAuthorId !== '' && article.author.uid === threadAuthorId;
            const sameAuthorByAnonymousIdentity = threadAuthorAnonymousIdentity !== '' &&
              authorAnonymousIdentity !== '' &&
              authorAnonymousIdentity === threadAuthorAnonymousIdentity;
            const sameAuthorByName = normalizedThreadAuthorName !== '' &&
              normalizedArticleAuthorName !== '' &&
              normalizedArticleAuthorName === normalizedThreadAuthorName &&
              (threadAuthorId === '' || article.author.uid === '' || article.author.uid === '0');
            if (sameAuthorByAnonymousIdentity || sameAuthorByUid || sameAuthorByName) {
              article.isAuthor = true;
            } else if (isFirstPost) {
              // 第一楼肯定是楼主
              article.isAuthor = true;
            }

            const score = item['score'];
            if (score != null) {
              const scoreNum = Number(score);
              article.likes = isNaN(scoreNum) ? 0 : scoreNum;
            }
            const subject = item['subject'];
            if (subject != null && String(subject) !== '') {
              article.noteInfo = this.decodeHtmlEntities(String(subject));
            }

            const attachsField = item['attachs'];
            if (attachsField != null && typeof attachsField === 'object') {
              this.parseAttachments(article, attachsField);
            }

            list.articles.push(article);
          } catch (itemErr) {
            LogUtils.e(
              NgaApi.LOG_TAG,
              'parseArticleList item failed page=' + currentPage +
              ', index=' + i +
              ', itemKeys=' + Object.keys(rItems[i]).join(',') +
              ', err=' + JSON.stringify(itemErr)
            );
          }
        }
      } else {
        LogUtils.w(
          NgaApi.LOG_TAG,
          'parseArticleList missing __R page=' + currentPage +
          ', tid=' + list.tid +
          ', dataKeys=' + dataKeys.join(',')
        );
      }

      list.hasMore = currentPage < list.totalPages;
      if (list.articles.length === 0) {
        LogUtils.w(
          NgaApi.LOG_TAG,
          'parseArticleList empty articles page=' + currentPage +
          ', tid=' + list.tid +
          ', subject=' + list.subject +
          ', totalCount=' + list.totalCount +
          ', totalPages=' + list.totalPages +
          ', dataKeys=' + dataKeys.join(',')
        );
      } else {
        LogUtils.i(
          NgaApi.LOG_TAG,
          'parseArticleList finish page=' + currentPage +
          ', tid=' + list.tid +
          ', articles=' + list.articles.length +
          ', firstPid=' + list.articles[0].pid +
          ', firstFloor=' + list.articles[0].floor
        );
      }
    } catch (err) {
      console.error('Parse article list failed:', err);
      console.error('Raw response (first 500 chars):', jsonStr.substring(0, 500));
      LogUtils.e(NgaApi.LOG_TAG, 'parseArticleList exception page=' + currentPage + ', err=' + JSON.stringify(err));
      list.errorMsg = '内容解析失败';
    }

    return list;
  }

  private parseAttachments(article: Article, attachsObj: Object): void {
    try {
      const attachItems: Record<string, Object>[] = [];
      if (Array.isArray(attachsObj)) {
        const arr = attachsObj as Object[];
        for (let i = 0; i < arr.length; i++) {
          if (arr[i] != null && typeof arr[i] === 'object') {
            attachItems.push(arr[i] as Record<string, Object>);
          }
        }
      } else {
        const obj = attachsObj as Record<string, Object>;
        const keys = Object.keys(obj);
        for (let i = 0; i < keys.length; i++) {
          if (keys[i].indexOf('__') === 0) continue;
          const val = obj[keys[i]];
          if (val != null && typeof val === 'object') {
            attachItems.push(val as Record<string, Object>);
          }
        }
      }

      for (let i = 0; i < attachItems.length; i++) {
        const att = attachItems[i];
        const attachment = new Attachment();
        attachment.id = att['aid'] != null ? String(att['aid']) : '';
        const attachUrl = att['attachurl'] != null ? String(att['attachurl']) : '';
        if (attachUrl) {
          attachment.url = this.normalizeImageUrl(attachUrl);
        }
        const thumbUrl = att['thumb'] != null ? String(att['thumb']) : '';
        if (thumbUrl) {
          attachment.thumbUrl = this.normalizeImageUrl(thumbUrl);
        }
        attachment.name = att['name'] != null ? String(att['name']) : '';
        attachment.size = att['size'] != null ? (att['size'] as number) : 0;
        attachment.width = att['img_width'] != null ? (att['img_width'] as number) : 0;
        attachment.height = att['img_height'] != null ? (att['img_height'] as number) : 0;

        const ext = att['ext'] != null ? String(att['ext']).toLowerCase() : '';
        if (ext === 'jpg' || ext === 'jpeg' || ext === 'png' || ext === 'gif' || ext === 'webp' || ext === 'bmp') {
          attachment.type = AttachmentType.IMAGE;
        }

        article.attachments.push(attachment);
      }
    } catch (err) {
      console.error('Parse attachments failed:', err);
    }
  }

  normalizeImageUrl(url: string): string {
    if (!url) return '';
    if (url.indexOf('http://') === 0 || url.indexOf('https://') === 0) {
      return url;
    }
    if (url.indexOf('./') === 0) {
      return 'https://img.nga.178.com/attachments/' + url.substring(2);
    }
    if (url.indexOf('/') === 0) {
      return 'https://img.nga.178.com' + url;
    }
    return 'https://img.nga.178.com/attachments/' + url;
  }

  async getMessageThreadList(page: number): Promise<HttpResponse<MessageThreadList>> {
    const result = new HttpResponse<MessageThreadList>();
    const url = '/nuke.php?__lib=message&__act=message&act=list&page=' + page + '&lite=js';
    LogUtils.i(NgaApi.LOG_TAG, 'getMessageThreadList request url=' + url);
    const response = await this.http.getGbk(url);
    result.code = response.code;
    result.message = response.message;
    LogUtils.i(
      NgaApi.LOG_TAG,
      'getMessageThreadList response code=' + response.code +
      ', message=' + response.message +
      ', rawPreview=' + this.previewRaw(response.raw)
    );

    if (response.code === 200 && response.raw !== '') {
      const parsed = this.parseMessageThreadList(response.raw);
      if (parsed != null) {
        result.data = parsed;
        result.message = parsed.errorMsg !== '' ? parsed.errorMsg : 'Success';
        LogUtils.i(
          NgaApi.LOG_TAG,
          'getMessageThreadList parsed success, page=' + parsed.page +
          ', totalCount=' + parsed.totalCount + ', errorMsg=' + parsed.errorMsg
        );
      } else {
        result.code = 502;
        result.message = '消息列表解析失败';
        LogUtils.e(NgaApi.LOG_TAG, 'getMessageThreadList parse returned null');
      }
    } else if (response.code === 200) {
      result.message = '服务器返回空数据';
      LogUtils.w(NgaApi.LOG_TAG, 'getMessageThreadList empty body');
    }

    return result;
  }

  async getMessageDetail(mid: string, page: number): Promise<HttpResponse<MessageDetail>> {
    const result = new HttpResponse<MessageDetail>();
    const normalizedMid = String(mid).trim();
    if (!/^\d+$/.test(normalizedMid)) {
      result.code = 400;
      result.message = '消息 ID 无效';
      return result;
    }

    const url = '/nuke.php?__lib=message&__act=message&act=read&page=' + page +
      '&mid=' + encodeURIComponent(normalizedMid) + '&lite=js';
    LogUtils.i(NgaApi.LOG_TAG, 'getMessageDetail request url=' + url);
    const response = await this.http.getGbk(url);
    result.code = response.code;
    result.message = response.message;
    LogUtils.i(
      NgaApi.LOG_TAG,
      'getMessageDetail response code=' + response.code +
      ', message=' + response.message +
      ', mid=' + normalizedMid +
      ', rawPreview=' + this.previewRaw(response.raw)
    );

    if (response.code === 200 && response.raw !== '') {
      const parsed = this.parseMessageDetail(response.raw, normalizedMid, page);
      if (parsed != null) {
        result.data = parsed;
        result.message = parsed.errorMsg !== '' ? parsed.errorMsg : 'Success';
        LogUtils.i(
          NgaApi.LOG_TAG,
          'getMessageDetail parsed success, mid=' + normalizedMid +
          ', page=' + parsed.page + ', entries=' + parsed.entries.length +
          ', errorMsg=' + parsed.errorMsg
        );
      } else {
        result.code = 502;
        result.message = '消息详情解析失败';
        LogUtils.e(NgaApi.LOG_TAG, 'getMessageDetail parse returned null, mid=' + normalizedMid);
      }
    } else if (response.code === 200) {
      result.message = '服务器返回空数据';
      LogUtils.w(NgaApi.LOG_TAG, 'getMessageDetail empty body, mid=' + normalizedMid);
    }

    return result;
  }

  async getNotificationList(): Promise<HttpResponse<NotificationList>> {
    const result = new HttpResponse<NotificationList>();
    const url = '/nuke.php?__lib=noti&__output=8&__act=get_all';
    LogUtils.i(NgaApi.LOG_TAG, 'getNotificationList request url=' + url);
    const response = await this.http.getGbk(url);
    result.code = response.code;
    result.message = response.message;
    LogUtils.i(
      NgaApi.LOG_TAG,
      'getNotificationList response code=' + response.code +
      ', message=' + response.message +
      ', rawPreview=' + this.previewRaw(response.raw)
    );

    if (response.code === 200 && response.raw !== '') {
      const parsed = this.parseNotificationList(response.raw);
      if (parsed != null) {
        result.data = parsed;
        result.message = parsed.errorMsg !== '' ? parsed.errorMsg : 'Success';
        LogUtils.i(
          NgaApi.LOG_TAG,
          'getNotificationList parsed success, count=' + parsed.notifications.length +
          ', unread=' + parsed.unreadCount + ', errorMsg=' + parsed.errorMsg
        );
      } else {
        result.code = 502;
        result.message = '通知列表解析失败';
        LogUtils.e(NgaApi.LOG_TAG, 'getNotificationList parse returned null');
      }
    } else if (response.code === 200) {
      result.message = '服务器返回空数据';
      LogUtils.w(NgaApi.LOG_TAG, 'getNotificationList empty body');
    }

    return result;
  }

  async clearAllNotifications(): Promise<HttpResponse<boolean>> {
    const result = new HttpResponse<boolean>();
    const response = await this.http.post('/nuke.php?__lib=noti&raw=3&__act=del', '');
    result.code = response.code;
    result.message = response.message;
    result.data = response.code === 200;
    if (response.code === 200 && result.message === '') {
      result.message = 'Success';
    }
    return result;
  }

  /**
   * 获取版块列表（从本地JSON）
   */
  async getForumList(): Promise<HttpResponse<BoardCategory[]>> {
    const result = new HttpResponse<BoardCategory[]>();
    result.code = 200;
    result.message = 'Success';
    result.data = this.getDefaultBoards();
    return result;
  }

  private copyBoardForTabs(b: Board): Board {
    const nb = new Board();
    nb.id = b.id;
    nb.stid = b.stid;
    nb.name = b.name;
    return nb;
  }

  private copyCategoryBoardsOnly(src: BoardCategory): BoardCategory {
    const c = new BoardCategory();
    c.id = src.id;
    c.name = src.name;
    for (let i = 0; i < src.boards.length; i++) {
      c.boards.push(this.copyBoardForTabs(src.boards[i]));
    }
    return c;
  }

  /**
   * 首页「版块」顶栏 7 大 Tab 中除「我的收藏」外的 6 段子版块数据（顺序固定）。
   * 「闲事杂谈」为原网事杂谈去掉二次元国家地理；「国家俱乐部」仅含二次元国家地理。
   */
  getMainBoardTabSections(): BoardCategory[] {
    const all = this.getDefaultBoards();
    let other: BoardCategory | null = null;
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === 'other') {
        other = all[i];
        break;
      }
    }
    const out: BoardCategory[] = [];

    if (other != null) {
      const leisure = new BoardCategory();
      leisure.id = 'leisure';
      leisure.name = '\u95f2\u4e8b\u6742\u8c08';
      for (let j = 0; j < other.boards.length; j++) {
        const b = other.boards[j];
        if (b.id !== '-447601') {
          leisure.boards.push(this.copyBoardForTabs(b));
        }
      }
      out.push(leisure);
    }

    const pushById = (catId: string) => {
      for (let k = 0; k < all.length; k++) {
        if (all[k].id === catId) {
          out.push(this.copyCategoryBoardsOnly(all[k]));
          return;
        }
      }
    };
    pushById('riotgame');
    pushById('bliz');
    pushById('wow');
    pushById('games');

    const nat = new BoardCategory();
    nat.id = 'natclub';
    nat.name = '\u56fd\u5bb6\u4ff1\u4e50\u90e8';
    if (other != null) {
      for (let m = 0; m < other.boards.length; m++) {
        const bb = other.boards[m];
        if (bb.id === '-447601') {
          nat.boards.push(this.copyBoardForTabs(bb));
        }
      }
    }
    out.push(nat);
    return out;
  }

  private addBoard(cat: BoardCategory, fid: string, name: string, stid: string = '0'): void {
    const b = new Board();
    b.id = fid;
    b.name = name;
    b.stid = stid;
    cat.boards.push(b);
  }

  private makeCat(id: string, name: string): BoardCategory {
    const c = new BoardCategory();
    c.id = id;
    c.name = name;
    return c;
  }

  /**
   * 获取默认版块列表（数据来自 Android 端 category.json）
   */
  private getDefaultBoards(): BoardCategory[] {
    const categories: BoardCategory[] = [];

    // 网事杂谈
    const cat1 = this.makeCat('other', '网事杂谈');
    this.addBoard(cat1, '-7', '网事杂谈');
    this.addBoard(cat1, '-447601', '二次元国家地理');
    this.addBoard(cat1, '-7955747', '晴风村');
    this.addBoard(cat1, '-343809', '寂寞的车');
    this.addBoard(cat1, '843', '国际新闻');
    this.addBoard(cat1, '485', '篮球');
    this.addBoard(cat1, '-576177', '音乐影视');
    this.addBoard(cat1, '-81981', '生命之杯');
    this.addBoard(cat1, '-1459709', '职场人生');
    this.addBoard(cat1, '-187628', '家居装修');
    this.addBoard(cat1, '-202020', '程序员职业交流');
    categories.push(cat1);

    // IT软硬件
    const catIT = this.makeCat('it', 'IT软硬件');
    this.addBoard(catIT, '436', '消费电子 IT新闻');
    this.addBoard(catIT, '334', '硬件配置');
    this.addBoard(catIT, '498', '二手交易');
    this.addBoard(catIT, '722', '手机研究所');
    categories.push(catIT);

    // 拳头游戏
    const catRiot = this.makeCat('riotgame', '拳头游戏');
    this.addBoard(catRiot, '-152678', '英雄联盟');
    this.addBoard(catRiot, '708', '无畏契约');
    this.addBoard(catRiot, '660', '云顶之弈');
    this.addBoard(catRiot, '681', '英雄联盟手游');
    categories.push(catRiot);

    // 暴雪游戏
    const catBliz = this.makeCat('bliz', '暴雪游戏');
    this.addBoard(catBliz, '459', '守望先锋');
    this.addBoard(catBliz, '422', '炉石传说');
    this.addBoard(catBliz, '318', '暗黑破坏神');
    this.addBoard(catBliz, '685', '暗黑破坏神4');
    this.addBoard(catBliz, '490', '魔兽争霸');
    categories.push(catBliz);

    // 魔兽世界
    const catWow = this.makeCat('wow', '魔兽世界');
    this.addBoard(catWow, '7', '艾泽拉斯议事厅');
    this.addBoard(catWow, '310', '前瞻资讯');
    this.addBoard(catWow, '624', '经典旧世');
    this.addBoard(catWow, '218', '副本专区');
    this.addBoard(catWow, '191', '地精商会');
    categories.push(catWow);

    // 游戏综合
    const catGame = this.makeCat('games', '游戏专版');
    this.addBoard(catGame, '414', '游戏综合讨论区');
    this.addBoard(catGame, '614', 'PS游戏讨论');
    this.addBoard(catGame, '615', 'XBOX游戏综合');
    this.addBoard(catGame, '616', 'Nintendo游戏讨论');
    this.addBoard(catGame, '321', 'Dota2');
    this.addBoard(catGame, '489', '怪物猎人');
    this.addBoard(catGame, '-5080470', '流放之路');
    this.addBoard(catGame, '513', '黑暗之魂');
    this.addBoard(catGame, '-362960', '最终幻想14');
    this.addBoard(catGame, '-7861121', '剑网3');
    this.addBoard(catGame, '481', 'Minecraft');
    this.addBoard(catGame, '-2081117', '游戏王');
    categories.push(catGame);

    // 手机游戏
    const catMobile = this.makeCat('mobile', '手机/页游');
    this.addBoard(catMobile, '428', '手机/页游讨论');
    this.addBoard(catMobile, '650', '原神');
    this.addBoard(catMobile, '-34587507', '明日方舟');
    this.addBoard(catMobile, '538', '阴阳师');
    this.addBoard(catMobile, '516', '王者荣耀');
    this.addBoard(catMobile, '540', 'Fate Grand Order');
    this.addBoard(catMobile, '564', '碧蓝航线');
    this.addBoard(catMobile, '549', '崩坏3');
    this.addBoard(catMobile, '599', '和平精英');
    categories.push(catMobile);

    // 社区管理
    const catClub = this.makeCat('club', '社区');
    this.addBoard(catClub, '10', '银色黎明裁判所');
    this.addBoard(catClub, '335', '论坛开发');
    categories.push(catClub);

    return categories;
  }

  /**
   * 获取用户资料（nuke.php 始终返回 GBK 编码，需用 GBK 解码）
   */
  async getUserProfile(uid: string): Promise<HttpResponse<Record<string, Object>>> {
    const uidClean = String(uid).trim();
    const invalid = new HttpResponse<Record<string, Object>>();
    if (uidClean === '' || !/^\d+$/.test(uidClean)) {
      invalid.code = 400;
      invalid.message = 'UID 无效';
      return invalid;
    }

    const existingTask = this.profileRequestInFlight.get(uidClean);
    if (existingTask != null) {
      LogUtils.i(NgaApi.LOG_TAG, 'getUserProfile reuse in-flight request, uid=' + uidClean);
      return await existingTask;
    }

    const task = this.withProfileRequestQueue(async () => {
      const result = new HttpResponse<Record<string, Object>>();
      try {
        const hosts = this.profileHosts();
        for (let i = 0; i < hosts.length; i++) {
          const host = hosts[i];
          const url = this.buildProfileUrl(host, uidClean);
          const referer = this.buildProfileReferer(host, uidClean);
          LogUtils.i(
            NgaApi.LOG_TAG,
            'getUserProfile request host=' + host +
            ', uid=' + uidClean +
            ', attempt=' + String(i + 1) + '/' + String(hosts.length)
          );

          const response = await this.http.getGbk(url, {
            'Referer': referer,
            'Origin': host
          });
          result.code = response.code;
          result.message = response.message;
          result.raw = response.raw;
          LogUtils.i(
            NgaApi.LOG_TAG,
            'getUserProfile response host=' + host +
            ', code=' + response.code +
            ', message=' + response.message +
            ', uid=' + uidClean +
            ', rawPreview=' + this.previewRaw(response.raw)
          );

          if (response.code === 200 && response.raw != null && response.raw.trim() !== '') {
            const jsonObj = this.parseJsonObject(response.raw);
            if (jsonObj != null) {
              result.data = jsonObj;
              LogUtils.i(NgaApi.LOG_TAG, 'getUserProfile parsed success, uid=' + uidClean + ', host=' + host);
              return result;
            }
            result.code = 502;
            result.message = '资料内容解析失败';
            LogUtils.e(NgaApi.LOG_TAG, 'getUserProfile parse failed, uid=' + uidClean + ', host=' + host);
            return result;
          }

          if (!this.shouldRetryProfileResponse(response) || i >= hosts.length - 1) {
            if (response.code === 200) {
              result.message = response.message !== '' ? response.message : '服务器返回空数据';
            }
            LogUtils.w(
              NgaApi.LOG_TAG,
              'getUserProfile stop retry, uid=' + uidClean +
              ', host=' + host +
              ', code=' + String(response.code)
            );
            return result;
          }

          LogUtils.w(
            NgaApi.LOG_TAG,
            'getUserProfile retry next host, uid=' + uidClean +
            ', failedHost=' + host +
            ', code=' + String(response.code)
          );
        }
      } catch (err) {
        console.error('getUserProfile failed:', err);
        result.code = 500;
        result.message = '请求失败';
        LogUtils.e(NgaApi.LOG_TAG, 'getUserProfile exception, uid=' + uidClean + ', err=' + JSON.stringify(err));
      }
      return result;
    });

    this.profileRequestInFlight.set(uidClean, task);
    try {
      return await task;
    } finally {
      this.profileRequestInFlight.delete(uidClean);
    }
  }
}

export const ngaApi = new NgaApi();
