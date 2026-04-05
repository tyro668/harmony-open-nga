/**
 * 应用常量配置
 */
export class AppConstants {
  // 应用信息
  static readonly APP_NAME: string = 'OpenNGA';
  static readonly APP_VERSION: string = '1.2.1';
  static readonly APP_VERSION_CODE: number = 1000201;

  // NGA API 配置
  static readonly NGA_BASE_URL: string = 'https://bbs.nga.cn';
  static readonly NGA_API_URL: string = 'https://bbs.nga.cn/api_app';
  static readonly NGA_LOGIN_URL: string = 'https://bbs.nga.cn/nuke.php?__lib=login&__act=account&login';

  // 请求超时配置
  static readonly CONNECT_TIMEOUT: number = 30000;
  static readonly READ_TIMEOUT: number = 30000;
  static readonly WRITE_TIMEOUT: number = 30000;

  // 分页配置
  static readonly PAGE_SIZE: number = 20;
  static readonly ARTICLE_PAGE_SIZE: number = 20;

  // 存储Key
  static readonly PREF_USER_INFO: string = 'pref_user_info';
  static readonly PREF_COOKIE: string = 'pref_cookie';
  static readonly PREF_THEME: string = 'pref_theme';
  static readonly PREF_FONT_SIZE: string = 'pref_font_size';
  static readonly PREF_NIGHT_MODE: string = 'pref_night_mode';
  static readonly PREF_HISTORY: string = 'pref_history';
  static readonly PREF_FAVORITE: string = 'pref_favorite';
  static readonly PREF_BLACKLIST: string = 'pref_blacklist';
  static readonly PREF_FILTER_KEYWORDS: string = 'pref_filter_keywords';
  static readonly PREF_START_PAGE: string = 'pref_start_page';

  // 数据库名称
  static readonly DB_NAME: string = 'open_nga.db';
  static readonly DB_VERSION: number = 1;

  // 文件配置
  static readonly MAX_IMAGE_SIZE: number = 10 * 1024 * 1024; // 10MB
  static readonly MAX_ATTACHMENT_SIZE: number = 20 * 1024 * 1024; // 20MB
  static readonly IMAGE_QUALITY: number = 80;

  // 缓存配置
  static readonly CACHE_MAX_SIZE: number = 50 * 1024 * 1024; // 50MB
  static readonly CACHE_MAX_AGE: number = 7 * 24 * 60 * 60 * 1000; // 7天

  // 主题配置
  static readonly THEME_LIGHT: string = 'light';
  static readonly THEME_DARK: string = 'dark';
  static readonly THEME_SYSTEM: string = 'system';
}

/**
 * API 路径常量
 */
export class ApiPath {
  // 用户相关
  static readonly LOGIN: string = '/nuke.php?__lib=login&__act=login';
  static readonly LOGOUT: string = '/nuke.php?__lib=login&__act=logout';
  static readonly GET_AUTH_CODE: string = '/nuke.php?__lib=login&__act=get_auth_code';
  static readonly GET_PROFILE: string = '/nuke.php?__lib=account&__act=get';

  // 帖子相关
  static readonly GET_TOPIC_LIST: string = '/api_app/thread.php';
  static readonly GET_ARTICLE_LIST: string = '/api_app/thread.php';
  static readonly POST_TOPIC: string = '/nuke.php?__lib=post&__act=new';
  static readonly POST_REPLY: string = '/nuke.php?__lib=post&__act=reply';
  static readonly GET_TOPIC_DETAIL: string = '/api_app/thread.php';

  // 版块相关
  static readonly GET_FORUM_LIST: string = '/api_app/forum.php';
  static readonly GET_SUB_FORUM: string = '/api_app/forum.php';

  // 消息相关
  static readonly GET_MESSAGE_LIST: string = '/nuke.php?__lib=message&__act=list';
  static readonly GET_MESSAGE_DETAIL: string = '/nuke.php?__lib=message&__act=read';
  static readonly SEND_MESSAGE: string = '/nuke.php?__lib=message&__act=send';

  // 搜索相关
  static readonly SEARCH_TOPIC: string = '/api_app/search.php';
  static readonly SEARCH_ARTICLE: string = '/api_app/search.php';

  // 其他功能
  static readonly CHECK_IN: string = '/nuke.php?__lib=check_in&__act=check_in';
  static readonly ADD_BOOKMARK: string = '/nuke.php?__lib=bookmark&__act=add';
  static readonly REMOVE_BOOKMARK: string = '/nuke.php?__lib=bookmark&__act=remove';
  static readonly LIKE: string = '/nuke.php?__lib=recommend&__act=add';
  static readonly REPORT: string = '/nuke.php?__lib=report&__act=report';
  static readonly UPLOAD_FILE: string = '/nuke.php?__lib=upload&__act=upload';
}

/**
 * 请求结果码
 */
export class ResultCode {
  static readonly SUCCESS: number = 0;
  static readonly ERROR: number = -1;
  static readonly TOKEN_EXPIRED: number = 401;
  static readonly FORBIDDEN: number = 403;
  static readonly NOT_FOUND: number = 404;
  static readonly SERVER_ERROR: number = 500;
  static readonly NETWORK_ERROR: number = -100;
  static readonly TIMEOUT: number = -101;
  static readonly CANCEL: number = -102;
}
