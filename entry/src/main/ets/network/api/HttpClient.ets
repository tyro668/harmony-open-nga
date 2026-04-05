import http from '@ohos.net.http';

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
        connectTimeout: 30000,
        readTimeout: 30000
      };

      if (body != '') {
        options.extraData = body;
      }

      const httpResponse = await httpRequest.request(fullUrl, options);

      response.code = httpResponse.responseCode;
      response.message = 'Success';
      if (typeof httpResponse.result === 'string') {
        response.raw = httpResponse.result;
        response.data = httpResponse.result;
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
        connectTimeout: 30000,
        readTimeout: 30000
      };

      const httpResponse = await httpRequest.request(fullUrl, options);
      result.code = httpResponse.responseCode;

      if (typeof httpResponse.result === 'string') {
        result.body = httpResponse.result;
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
