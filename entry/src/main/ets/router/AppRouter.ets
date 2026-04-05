import router from '@ohos.router';

/**
 * 路由配置
 */
export class RouterConfig {
  // 页面路径
  static readonly MAIN_PAGE: string = 'pages/main/MainPage';
  static readonly LOGIN_PAGE: string = 'pages/login/LoginPage';
  static readonly TOPIC_LIST_PAGE: string = 'pages/topic/TopicListPage';
  static readonly ARTICLE_LIST_PAGE: string = 'pages/article/ArticleListPage';
  static readonly SETTINGS_PAGE: string = 'pages/settings/SettingsPage';
  // TODO: 以下页面尚未实现
  static readonly PROFILE_PAGE: string = 'pages/main/MainPage';
  static readonly MESSAGE_LIST_PAGE: string = 'pages/main/MainPage';
  static readonly SEARCH_PAGE: string = 'pages/main/MainPage';
  static readonly ABOUT_PAGE: string = 'pages/main/MainPage';
}

/**
 * 路由管理器
 */
export class AppRouter {
  /**
   * 跳转到指定页面
   */
  static push(url: string, params?: Record<string, Object>): void {
    router.pushUrl({
      url: url,
      params: params
    });
  }

  /**
   * 替换当前页面
   */
  static replace(url: string, params?: Record<string, Object>): void {
    router.replaceUrl({
      url: url,
      params: params
    });
  }

  /**
   * 返回上一页
   */
  static back(): void {
    router.back();
  }

  /**
   * 清空页面栈并跳转
   */
  static clearAndPush(url: string, params?: Record<string, Object>): void {
    router.clear();
    this.push(url, params);
  }

  /**
   * 获取当前页面参数
   */
  static getParams(): Record<string, Object> {
    return router.getParams() as Record<string, Object> || {};
  }

  // 便捷方法

  static toMain(): void {
    this.replace(RouterConfig.MAIN_PAGE);
  }

  static toLogin(): void {
    this.push(RouterConfig.LOGIN_PAGE);
  }

  static toTopicList(fid: string): void {
    this.push(RouterConfig.TOPIC_LIST_PAGE, { fid });
  }

  static toArticleList(tid: string): void {
    this.push(RouterConfig.ARTICLE_LIST_PAGE, { tid });
  }

  static toSettings(): void {
    this.push(RouterConfig.SETTINGS_PAGE);
  }

  static toProfile(uid?: string): void {
    if (uid) {
      this.push(RouterConfig.PROFILE_PAGE, { uid });
    } else {
      this.push(RouterConfig.PROFILE_PAGE);
    }
  }

  static toMessageList(): void {
    this.push(RouterConfig.MESSAGE_LIST_PAGE);
  }

  static toSearch(keyword?: string): void {
    if (keyword) {
      this.push(RouterConfig.SEARCH_PAGE, { keyword });
    } else {
      this.push(RouterConfig.SEARCH_PAGE);
    }
  }

  static toAbout(): void {
    this.push(RouterConfig.ABOUT_PAGE);
  }
}
