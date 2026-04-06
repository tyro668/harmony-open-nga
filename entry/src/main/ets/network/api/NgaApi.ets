import { HttpClient, HttpResponse, LoginHttpResult } from './HttpClient';
import { User } from '../../model/entity/User';
import { Topic, TopicList } from '../../model/entity/Topic';
import { Article, ArticleList, Attachment, AttachmentType } from '../../model/entity/Article';
import { Board, BoardCategory } from '../../model/entity/Board';
import { Message, MessageList } from '../../model/entity/Message';
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

  /**
   * 清洗昵称中的 HTML 标签与常见实体（接口有时会把 author 带标签返回）
   */
  private sanitizeDisplayName(raw: string): string {
    if (raw == null || raw === '') {
      return '';
    }
    let s = String(raw).replace(/<[^>]*>/g, '');
    s = this.decodeHtmlEntities(s);
    return s.trim();
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

  private findUserRecordForPost(
    userMap: Map<string, Record<string, Object>>,
    userRecords: Record<string, Object>[],
    authorIdStr: string,
    displayAuthor: string
  ): Record<string, Object> | null {
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
        topic.author.username = this.sanitizeDisplayName(topicAuthorRaw);
        const topicAid = item['authorid'] != null ? item['authorid'] : item['userid'];
        topic.author.uid = this.positiveUidString(topicAid);
        topic.postDate = String(item['postdate'] != null ? item['postdate'] : '');
        topic.lastPostDate = String(item['lastpost'] != null ? item['lastpost'] : '');
        topic.replies = item['replies'] != null ? (item['replies'] as number) : 0;
        const lastPoster = item['lastposter'];
        if (lastPoster != null) {
          topic.lastPoster = this.decodeHtmlEntities(String(lastPoster));
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
    const url = this.baseUrl + '/read.php?tid=' + tid + '&page=' + page + '&__output=11&noprefix&v2';
    console.info('getArticleList URL:', url);
    const response = await this.http.get(url);
    const result = new HttpResponse<ArticleList>();
    result.code = response.code;
    result.message = response.message;

    if (response.code === 200 && response.raw != null && response.raw !== '') {
      const parsed = this.parseArticleList(response.raw, page);
      result.data = parsed;
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
    }
    return result;
  }

  /**
   * 解析帖子详情（楼层列表）
   */
  private parseArticleList(jsonStr: string, currentPage: number): ArticleList {
    const list = new ArticleList();
    list.page = currentPage;

    try {
      let js = jsonStr;
      const jsPrefix = 'window.script_muti_get_var_store=';
      if (js.indexOf(jsPrefix) === 0) {
        js = js.substring(jsPrefix.length);
      }
      if (js.indexOf('/*') === 0) {
        const endIdx = js.indexOf('*/');
        if (endIdx > 0) {
          js = js.substring(endIdx + 2);
        }
      }

      let jsonObj: Record<string, Object>;
      try {
        jsonObj = JSON.parse(js) as Record<string, Object>;
      } catch (_parseErr) {
        console.error('JSON.parse failed, attempting truncated JSON recovery...');
        const fixed = this.tryFixTruncatedJson(js);
        if (fixed != null) {
          console.info('Truncated JSON recovered, original=' + js.length + ' fixed=' + fixed.length);
          jsonObj = JSON.parse(fixed) as Record<string, Object>;
        } else {
          list.errorMsg = '数据解析失败';
          return list;
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
        list.errorMsg = '服务器返回数据为空';
        return list;
      }

      const tField: Object | null = data['__T'] as Object;
      const threadMeta = this.extractThreadDetailMeta(tField);
      let threadAuthorId = '';
      let threadAuthorName = '';
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
        if (threadMeta['author'] != null) {
          threadAuthorName = this.sanitizeDisplayName(String(threadMeta['author']));
        }
      }

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
              userRecords.push(rec);
            }
          }
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
            const directAuthorRaw = item['author'] != null ? String(item['author']) : '';
            const directAuthor = this.sanitizeDisplayName(directAuthorRaw);

            const userInfo = this.findUserRecordForPost(userMap, userRecords, authorIdStr, directAuthor);
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
                article.author.username = this.sanitizeDisplayName(String(uname));
              }
              const nickname = userInfo['nickname'];
              if (nickname != null && String(nickname) !== '' && String(nickname) !== 'null') {
                article.author.username = this.sanitizeDisplayName(String(nickname));
              }
            }
            if (authorIdStr !== '') {
              article.author.uid = authorIdStr;
            }
            if (!article.author.username && directAuthor !== '') {
              article.author.username = directAuthor;
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

            // 判断是否为楼主
            if (threadAuthorId !== '' && article.author.uid === threadAuthorId) {
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
            console.error('Parse article item ' + i + ' failed:', itemErr);
          }
        }
      }

      list.hasMore = currentPage < list.totalPages;
    } catch (err) {
      console.error('Parse article list failed:', err);
      console.error('Raw response (first 500 chars):', jsonStr.substring(0, 500));
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
    const result = new HttpResponse<Record<string, Object>>();

    try {
      const uidClean = String(uid).trim();
      if (uidClean === '' || !/^\d+$/.test(uidClean)) {
        result.code = 400;
        result.message = 'UID 无效';
        return result;
      }
      const url = '/nuke.php?__lib=ucp&__act=get&lite=js&noprefix&uid=' + encodeURIComponent(uidClean);
      console.info('getUserProfile URL: ' + url);

      const response = await this.http.getGbk(url);
      result.code = response.code;
      result.message = response.message;

      if (response.code === 200 && response.raw != null && response.raw !== '') {
        let js = response.raw;
        const jsPrefix = 'window.script_muti_get_var_store=';
        if (js.indexOf(jsPrefix) === 0) {
          js = js.substring(jsPrefix.length);
        }
        try {
          const jsonObj: Record<string, Object> = JSON.parse(js);
          result.data = jsonObj;
        } catch (_pe) {
          result.code = 502;
          result.message = '资料内容解析失败';
        }
      } else if (response.code === 200) {
        result.message = '服务器返回空数据';
      }
    } catch (err) {
      console.error('getUserProfile failed:', err);
      result.code = 500;
      result.message = '请求失败';
    }

    return result;
  }
}

export const ngaApi = new NgaApi();
