import http from '@ohos.net.http';
import { util } from '@kit.ArkTS';

/**
 * HTTP响应
 */
export class HttpResponse<T> {
  code: number = 0;
  message: string = '';
  data: T | null = null;
  raw: string = '';
}

/**
 * 登录请求结果（携带响应头中的 Cookie）
 */
export class LoginHttpResult {
  code: number = 0;
  body: string = '';
  cookies: string = '';
  errorMsg: string = '';
}

/**
 * 验证码请求结果（图片数据 + 服务器回传的 Cookie）
 */
export class CaptchaHttpResult {
  imageData: ArrayBuffer | null = null;
  cookies: string = '';
}

/**
 * HTTP客户端
 */
export class HttpClient {
  private static instance: HttpClient;
  private baseUrl: string = '';
  private cookie: string = '';
  private static readonly UA =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36';

  private constructor() {
    this.baseUrl = 'https://bbs.nga.cn';
  }

  static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  setBaseUrl(url: string): void {
    this.baseUrl = url;
  }

  setCookie(cookie: string): void {
    this.cookie = cookie;
  }

  getCookie(): string {
    return this.cookie;
  }

  async get(url: string): Promise<HttpResponse<string>> {
    return this.request(url, http.RequestMethod.GET, '');
  }

  async post(url: string, body: string): Promise<HttpResponse<string>> {
    return this.request(url, http.RequestMethod.POST, body);
  }

  /**
   * 按响应头 charset 将正文解码为字符串；默认 UTF-8。
   * 避免系统把 UTF-8 字节误按本地单字节编码解析导致中文乱码。
   */
  private decodeResponseBody(buffer: ArrayBuffer, contentType: string): string {
    let charset = 'utf-8';
    if (contentType != null && contentType.length > 0) {
      const low = contentType.toLowerCase();
      const idx = low.indexOf('charset=');
      if (idx >= 0) {
        let cs = low.substring(idx + 8).trim();
        const semi = cs.indexOf(';');
        if (semi >= 0) {
          cs = cs.substring(0, semi).trim();
        }
        cs = cs.replace(/"/g, '').toLowerCase();
        if (cs === 'gbk' || cs === 'gb2312' || cs === 'gb18030') {
          charset = 'gbk';
        }
      }
    }
    try {
      const decoder = util.TextDecoder.create(charset);
      return decoder.decodeWithStream(new Uint8Array(buffer));
    } catch (_e) {
      const utf8 = util.TextDecoder.create('utf-8');
      return utf8.decodeWithStream(new Uint8Array(buffer));
    }
  }

  async request(url: string, method: http.RequestMethod, body: string): Promise<HttpResponse<string>> {
    const httpRequest = http.createHttp();
    const response = new HttpResponse<string>();

    try {
      let fullUrl = url;
      if (!url.startsWith('http')) {
        fullUrl = this.baseUrl + url;
      }

      const headerMap: Record<string, string> = {
        'User-Agent': HttpClient.UA,
        'Accept': '*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'X-User-Agent': 'Nga_Official',
        'Cookie': this.cookie
      };

      if (method === http.RequestMethod.POST) {
        headerMap['Content-Type'] = 'application/x-www-form-urlencoded';
      }

      const options: http.HttpRequestOptions = {
        method: method,
        header: headerMap,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        readTimeout: 30000
      };

      if (body != '') {
        options.extraData = body;
      }

      const httpResponse = await httpRequest.request(fullUrl, options);

      response.code = httpResponse.responseCode;
      const hdr = httpResponse.header as Record<string, string> | undefined;
      const contentType = hdr != null ? (hdr['Content-Type'] || hdr['content-type'] || '') : '';

      const rawResult = httpResponse.result;
      if (rawResult instanceof ArrayBuffer) {
        if (rawResult.byteLength === 0) {
          response.message = '服务器返回空响应';
        } else {
          const text = this.decodeResponseBody(rawResult, contentType);
          response.message = 'Success';
          response.raw = text;
          response.data = text;
        }
      } else if (typeof rawResult === 'string') {
        // 部分环境下 expectDataType 未生效，退回字符串（可能仍有乱码，但优于无响应）
        response.message = 'Success';
        response.raw = rawResult;
        response.data = rawResult;
      } else if (rawResult != null) {
        response.message = 'Success';
        const resultStr = String(rawResult);
        response.raw = resultStr;
        response.data = resultStr;
      } else {
        response.message = '服务器返回空响应';
      }
    } catch (err) {
      response.code = -1;
      response.message = String(err);
    } finally {
      httpRequest.destroy();
    }

    return response;
  }

  /**
   * 以 GBK 编码获取响应（用于 nuke.php 等始终返回 GBK 的 API）
   */
  async getGbk(url: string): Promise<HttpResponse<string>> {
    const httpRequest = http.createHttp();
    const response = new HttpResponse<string>();

    try {
      let fullUrl = url;
      if (!url.startsWith('http')) {
        fullUrl = this.baseUrl + url;
      }

      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        header: {
          'User-Agent': HttpClient.UA,
          'Accept': '*/*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'X-User-Agent': 'Nga_Official',
          'Cookie': this.cookie
        } as Record<string, string>,
        connectTimeout: 30000,
        readTimeout: 30000
      };

      const httpResponse = await httpRequest.request(fullUrl, options);
      response.code = httpResponse.responseCode;

      if (httpResponse.result instanceof ArrayBuffer) {
        const decoder = util.TextDecoder.create('gbk');
        const decoded = decoder.decodeWithStream(new Uint8Array(httpResponse.result));
        response.message = 'Success';
        response.raw = decoded;
        response.data = decoded;
      } else if (typeof httpResponse.result === 'string') {
        response.message = 'Success';
        response.raw = httpResponse.result;
        response.data = httpResponse.result;
      } else {
        response.message = '服务器返回空响应';
      }
    } catch (err) {
      response.code = -1;
      response.message = String(err);
    } finally {
      httpRequest.destroy();
    }

    return response;
  }

  /**
   * 下载验证码图片，同时捕获服务器回传的 ngaPassportOid cookie
   */
  async getCaptchaImage(url: string): Promise<CaptchaHttpResult> {
    const httpRequest = http.createHttp();
    const result = new CaptchaHttpResult();

    try {
      const headerMap: Record<string, string> = {
        'User-Agent': HttpClient.UA,
        'Referer': 'https://bbs.nga.cn/nuke/account_copy.html'
      };
      if (this.cookie) {
        headerMap['Cookie'] = this.cookie;
      }

      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        header: headerMap,
        connectTimeout: 15000,
        readTimeout: 15000
      };

      const httpResponse = await httpRequest.request(url, options);
      console.info('Captcha HTTP code: ' + httpResponse.responseCode +
        ', result type: ' + typeof httpResponse.result);

      if (httpResponse.responseCode === 200 && httpResponse.result) {
        if (typeof httpResponse.result === 'string') {
          // expectDataType 未生效，收到文本而非二进制
          console.error('Captcha returned string: ' + (httpResponse.result as string).substring(0, 100));
        } else {
          result.imageData = httpResponse.result as ArrayBuffer;
          console.info('Captcha image size: ' + result.imageData.byteLength);
        }
      } else {
        console.error('Captcha failed, code: ' + httpResponse.responseCode);
      }

      // 优先使用 httpResponse.cookies（直接属性，不依赖 header key 大小写）
      if (httpResponse.cookies) {
        result.cookies = httpResponse.cookies;
      } else {
        const headers = httpResponse.header as Record<string, string>;
        result.cookies = headers['set-cookie'] || headers['Set-Cookie'] || '';
      }
    } catch (err) {
      console.error('getCaptchaImage exception: ' + JSON.stringify(err));
    } finally {
      httpRequest.destroy();
    }

    return result;
  }

  /**
   * 发送登录 POST 请求并提取响应头中的 Set-Cookie
   */
  async postLogin(url: string, body: string, extraCookie: string): Promise<LoginHttpResult> {
    const httpRequest = http.createHttp();
    const result = new LoginHttpResult();

    try {
      const fullUrl = url.startsWith('http') ? url : (this.baseUrl + url);

      let cookieStr = this.cookie;
      if (extraCookie) {
        cookieStr = cookieStr ? (cookieStr + '; ' + extraCookie) : extraCookie;
      }

      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'User-Agent': HttpClient.UA,
          'Accept': '*/*',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://bbs.nga.cn/nuke/p2.htm?login',
          'Cookie': cookieStr
        },
        extraData: body,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        readTimeout: 30000
      };

      const httpResponse = await httpRequest.request(fullUrl, options);
      result.code = httpResponse.responseCode;

      const hdr = httpResponse.header as Record<string, string> | undefined;
      const contentType = hdr != null ? (hdr['Content-Type'] || hdr['content-type'] || '') : '';
      const rawResult = httpResponse.result;
      if (rawResult instanceof ArrayBuffer && rawResult.byteLength > 0) {
        result.body = this.decodeResponseBody(rawResult, contentType);
      } else if (typeof rawResult === 'string') {
        result.body = rawResult;
      }

      if (httpResponse.cookies) {
        result.cookies = httpResponse.cookies;
      } else {
        const headers = httpResponse.header as Record<string, string>;
        result.cookies = headers['set-cookie'] || headers['Set-Cookie'] || '';
      }
    } catch (err) {
      result.code = -1;
      result.errorMsg = String(err);
    } finally {
      httpRequest.destroy();
    }

    return result;
  }
}

export const httpClient = HttpClient.getInstance();
