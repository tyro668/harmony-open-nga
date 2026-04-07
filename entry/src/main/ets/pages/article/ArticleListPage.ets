import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';
import { AppConstants } from '../../common/constants/AppConstants';
import { Article, Attachment } from '../../model/entity/Article';
import { Topic } from '../../model/entity/Topic';
import { User } from '../../model/entity/User';
import { ngaApi } from '../../network/api/NgaApi';
import { NgaApi } from '../../network/api/NgaApi';
import { HttpClient } from '../../network/api/HttpClient';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { userManager } from '../../common/manager/UserManager';
import { AvatarView } from '../../ui/components/CommonComponents';
import { avatarCacheManager } from '../../common/manager/AvatarCacheManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import connection from '@ohos.net.connection';
import common from '@ohos.app.ability.common';

class ContentSegment {
  type: string = 'text';
  text: string = '';
  linkUrl: string = '';
  userUid: string = '';
  imageUrl: string = '';
  originalImageUrl: string = '';
  isQuote: boolean = false;

  static makeText(text: string, isQuote: boolean = false): ContentSegment {
    const seg = new ContentSegment();
    seg.type = 'text';
    seg.text = text;
    seg.isQuote = isQuote;
    return seg;
  }

  static makeImage(previewUrl: string, originalUrl: string = ''): ContentSegment {
    const seg = new ContentSegment();
    seg.type = 'image';
    seg.imageUrl = previewUrl;
    seg.originalImageUrl = originalUrl !== '' ? originalUrl : previewUrl;
    return seg;
  }

  static makeLink(text: string, url: string, isQuote: boolean = false): ContentSegment {
    const seg = new ContentSegment();
    seg.type = 'link';
    seg.text = text;
    seg.linkUrl = url;
    seg.isQuote = isQuote;
    return seg;
  }

  static makeUser(text: string, uid: string, isQuote: boolean = false): ContentSegment {
    const seg = new ContentSegment();
    seg.type = 'user';
    seg.text = text;
    seg.userUid = uid;
    seg.isQuote = isQuote;
    return seg;
  }
}

class ContentBlock {
  type: string = 'inline';
  segments: ContentSegment[] = [];
  isQuote: boolean = false;

  static makeInline(segments: ContentSegment[], isQuote: boolean = false): ContentBlock {
    const block = new ContentBlock();
    block.type = 'inline';
    block.segments = segments;
    block.isQuote = isQuote;
    return block;
  }

  static makeImage(segment: ContentSegment, isQuote: boolean = false): ContentBlock {
    const block = new ContentBlock();
    block.type = 'image';
    block.segments = [segment];
    block.isQuote = isQuote;
    return block;
  }
}

@Entry
@Component
struct ArticleListPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State tid: string = '';
  @State subject: string = '帖子详情';
  @State articles: Article[] = [];
  @State page: number = 1;
  @State totalPages: number = 1;
  @State totalCount: number = 0;
  @State isLoading: boolean = true;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = false;
  @State loadError: string = '';
  @State showPageJumper: boolean = false;
  @State jumpPageText: string = '';
  @State showReplyBar: boolean = false;
  @State replyContent: string = '';
  @State replyToPid: string = '';
  @State replyToFloor: number = -1;
  @State replyToUser: string = '';
  @State isReplying: boolean = false;
  @State useOriginalImagesInPost: boolean = false;
  @State avatarUrls: Record<string, string> = {};
  private apiHelper: NgaApi = new NgaApi();

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params != null) {
      const tidParam = params['tid'];
      if (tidParam != null) {
        this.tid = String(tidParam);
      }
      const titleParam = params['title'];
      if (titleParam != null) {
        this.subject = String(titleParam);
      }
    }
    this.updateInlineImageNetworkMode();
    if (this.tid != '') {
      this.loadArticles();
    }
  }

  onPageShow() {
    this.updateInlineImageNetworkMode();
  }

  /** 头像首字：兼容中文与代理对（emoji 等） */
  private authorInitial(name: string): string {
    const s = name != null ? name.trim() : '';
    if (s.length === 0) {
      return '?';
    }
    const c0 = s.charCodeAt(0);
    if (c0 >= 0xD800 && c0 <= 0xDBFF && s.length >= 2) {
      return s.substring(0, 2);
    }
    return s.substring(0, 1);
  }

  goToUserProfile(uid: string, username: string) {
    const id = uid != null ? String(uid).trim() : '';
    // 资料接口只接受数字 UID；勿把中文昵称当作 uid（会导致加载失败）
    if (id === '' || id === '0' || !/^\d+$/.test(id)) {
      promptAction.showToast({ message: '暂无法打开资料：缺少该用户的数字 UID' });
      return;
    }
    const params: Record<string, Object> = { 'uid': id, 'name': username != null ? username : '' };
    router.pushUrl({ url: 'pages/profile/ProfilePage', params: params });
  }

  private avatarUrlForUid(uid: string): string {
    const normalizedUid = uid != null ? String(uid).trim() : '';
    if (normalizedUid === '') {
      return '';
    }
    const cached = this.avatarUrls[normalizedUid];
    return cached != null ? cached : '';
  }

  private updateAvatarUrl(uid: string, avatarUrl: string) {
    const normalizedUid = uid != null ? String(uid).trim() : '';
    if (normalizedUid === '' || avatarUrl === '') {
      return;
    }
    if (this.avatarUrls[normalizedUid] === avatarUrl) {
      return;
    }
    const nextState: Record<string, string> = {};
    const keys = Object.keys(this.avatarUrls);
    for (let i = 0; i < keys.length; i++) {
      nextState[keys[i]] = this.avatarUrls[keys[i]];
    }
    nextState[normalizedUid] = avatarUrl;
    this.avatarUrls = nextState;
  }

  private async warmArticleAvatars(articlesToWarm: Article[]) {
    if (articlesToWarm.length === 0) {
      return;
    }

    const context = getContext(this) as common.UIAbilityContext;
    const allowNetwork = await avatarCacheManager.isWifiConnection();
    const seen: Set<string> = new Set<string>();

    for (let i = 0; i < articlesToWarm.length; i++) {
      const uid = articlesToWarm[i].author.uid != null ? String(articlesToWarm[i].author.uid).trim() : '';
      if (!/^\d+$/.test(uid) || uid === '0' || seen.has(uid)) {
        continue;
      }
      seen.add(uid);
      const avatarUrl = await avatarCacheManager.loadAvatar(context, uid, allowNetwork);
      if (avatarUrl !== '') {
        this.updateAvatarUrl(uid, avatarUrl);
      }
    }
  }

  private refreshArticleList() {
    this.articles = this.articles;
  }

  async updateInlineImageNetworkMode() {
    try {
      const defaultNet = await connection.getDefaultNet();
      const netCapabilities = await connection.getNetCapabilities(defaultNet);
      const bearerTypes = netCapabilities.bearerTypes || [];
      let isWifiNetwork = false;
      for (let i = 0; i < bearerTypes.length; i++) {
        if (bearerTypes[i] === connection.NetBearType.BEARER_WIFI) {
          isWifiNetwork = true;
          break;
        }
      }
      this.useOriginalImagesInPost = isWifiNetwork;
    } catch (error) {
      console.info('Detect network type failed:', JSON.stringify(error));
      this.useOriginalImagesInPost = false;
    }
  }

  async voteArticle(article: Article, value: number) {
    if (!userManager.isLoggedIn()) {
      promptAction.showToast({ message: '请先登录后再进行操作', duration: 1500 });
      return;
    }
    if (article.isVoting) {
      return;
    }

    article.isVoting = true;
    this.refreshArticleList();

    try {
      const result = await ngaApi.voteArticle(article.tid || this.tid, article.pid, value);
      const lowerResult = result.toLowerCase();
      if (lowerResult.indexOf('成功') >= 0 || lowerResult.indexOf('ok') >= 0 || lowerResult.indexOf('支持') >= 0 || lowerResult.indexOf('反对') >= 0) {
        if (article.voteValue !== 0) {
          article.likes -= article.voteValue;
        }
        article.voteValue = value;
        article.likes += value;
      }
      promptAction.showToast({ message: result, duration: 1500 });
    } catch (err) {
      console.error('vote article failed:', err);
      promptAction.showToast({ message: '操作失败', duration: 1500 });
    } finally {
      article.isVoting = false;
      this.refreshArticleList();
    }
  }

  async saveBrowseHistory(tid: string, subject: string) {
    if (tid === '' || subject === '') return;
    
    try {
      const KEY_HISTORY = 'topic_history';
      const MAX_HISTORY = 100;
      
      // 加载现有历史
      const jsonStr = await PreferencesManager.getInstance().getString(KEY_HISTORY);
      let topics: Topic[] = [];
      if (jsonStr !== '') {
        topics = JSON.parse(jsonStr) as Topic[];
      }
      
      // 检查是否已存在相同帖子
      let existingIndex = -1;
      for (let i = 0; i < topics.length; i++) {
        if (topics[i].tid === tid) {
          existingIndex = i;
          break;
        }
      }
      
      // 创建历史记录项
      const historyTopic = new Topic();
      historyTopic.tid = tid;
      historyTopic.subject = subject;
      historyTopic.author = new User();
      historyTopic.author.username = '';
      historyTopic.postDate = String(Math.floor(Date.now() / 1000));
      historyTopic.replies = 0;
      
      // 如果已存在，移除旧的
      if (existingIndex >= 0) {
        topics.splice(existingIndex, 1);
      }
      
      // 添加到开头
      topics.unshift(historyTopic);
      
      // 限制最大数量
      if (topics.length > MAX_HISTORY) {
        topics = topics.slice(0, MAX_HISTORY);
      }
      
      // 保存
      await PreferencesManager.getInstance().putString(KEY_HISTORY, JSON.stringify(topics));
      console.info('Saved browse history: tid=' + tid + ', subject=' + subject);
    } catch (err) {
      console.error('Save browse history failed:', err);
    }
  }

  async loadArticles(loadMore: boolean = false) {
    if (loadMore) {
      this.isLoadingMore = true;
    } else {
      this.isLoading = true;
      this.loadError = '';
    }

    try {
      const response = await ngaApi.getArticleList(this.tid, this.page);
      if (response.code === 200 && response.data != null) {
        const data = response.data;
        if (data.errorMsg) {
          this.loadError = data.errorMsg;
          return;
        }
        if (data.subject != '') {
          this.subject = data.subject;
          // 首次加载时保存浏览历史
          if (!loadMore && this.page === 1) {
            this.saveBrowseHistory(this.tid, this.subject);
          }
        }
        this.totalPages = data.totalPages;
        this.totalCount = data.totalCount;
        this.hasMore = data.hasMore;

        if (loadMore) {
          for (let i = 0; i < data.articles.length; i++) {
            this.articles.push(data.articles[i]);
          }
        } else {
          this.articles = data.articles;
        }
        this.warmArticleAvatars(this.articles);

        if (this.articles.length === 0 && !loadMore) {
          this.loadError = '该帖子暂无可显示的内容';
        }
      } else {
        this.loadError = response.message || '加载失败';
      }
    } catch (err) {
      this.loadError = '网络错误';
      console.error('Load articles failed:', err);
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  loadNextPage() {
    if (this.hasMore && !this.isLoadingMore) {
      this.page++;
      this.loadArticles(true);
    }
  }

  goToPage(targetPage: number) {
    if (targetPage < 1) targetPage = 1;
    if (targetPage > this.totalPages) targetPage = this.totalPages;
    if (targetPage === this.page && this.articles.length > 0) return;
    this.page = targetPage;
    this.loadArticles(false);
    this.showPageJumper = false;
    this.jumpPageText = '';
  }

  getVisiblePages(): number[] {
    const pages: number[] = [];
    const total = this.totalPages;
    const current = this.page;

    if (total <= 7) {
      for (let i = 1; i <= total; i++) pages.push(i);
      return pages;
    }

    pages.push(1);

    if (current > 3) {
      pages.push(-1);
    }

    let start = Math.max(2, current - 1);
    let end = Math.min(total - 1, current + 1);

    if (current <= 3) {
      start = 2;
      end = Math.min(4, total - 1);
    }
    if (current >= total - 2) {
      start = Math.max(total - 3, 2);
      end = total - 1;
    }

    for (let i = start; i <= end; i++) pages.push(i);

    if (current < total - 2) {
      pages.push(-1);
    }

    pages.push(total);
    return pages;
  }

  openReplyTo(article: Article) {
    this.replyToPid = article.pid;
    this.replyToFloor = article.floor;
    this.replyToUser = article.author.username || '\u533F\u540D';
    this.replyContent = '';
    this.showReplyBar = true;
  }

  openReplyToThread() {
    this.replyToPid = '';
    this.replyToFloor = -1;
    this.replyToUser = '';
    this.replyContent = '';
    this.showReplyBar = true;
  }

  closeReplyBar() {
    this.showReplyBar = false;
    this.replyContent = '';
    this.replyToPid = '';
    this.replyToFloor = -1;
    this.replyToUser = '';
  }

  buildQuotePrefix(article: Article): string {
    if (!this.replyToPid || this.replyToFloor < 0) return '';

    const pid = this.replyToPid;
    const tid = this.tid;
    const page = this.page;
    const uid = article.author.uid || '0';
    const name = this.replyToUser;
    const floor = this.replyToFloor;
    const postTime = article.getFormattedTime();

    let prefix = '[quote][pid=' + pid + ',' + tid + ',' + page + ']Reply[/pid] [b]Post by [uid=' +
      uid + ']' + name + '[/uid] (' + postTime + '):[/b]\n[/quote]\n';
    return prefix;
  }

  async submitReply() {
    if (this.replyContent.trim() === '' || this.isReplying) return;
    this.isReplying = true;

    try {
      const httpClient = HttpClient.getInstance();

      let fullContent = '';
      if (this.replyToPid && this.replyToFloor >= 0) {
        let replyArticle: Article | null = null;
        for (let i = 0; i < this.articles.length; i++) {
          if (this.articles[i].pid === this.replyToPid) {
            replyArticle = this.articles[i];
            break;
          }
        }
        if (replyArticle != null) {
          fullContent = this.buildQuotePrefix(replyArticle) + this.replyContent;
        } else {
          fullContent = this.replyContent;
        }
      } else {
        fullContent = this.replyContent;
      }

      const bodyParts: string[] = [];
      bodyParts.push('step=2');
      bodyParts.push('action=reply');
      bodyParts.push('tid=' + this.tid);
      bodyParts.push('post_content=' + encodeURIComponent(fullContent));
      const postBody = bodyParts.join('&');

      console.info('Reply POST to /post.php?__output=11');
      console.info('Reply POST body: ' + postBody);
      const response = await httpClient.post('/post.php?__output=11', postBody);
      console.info('Reply response code: ' + response.code);
      console.info('Reply response body: ' + (response.raw || '').substring(0, 500));

      if (response.code !== 200) {
        try {
          promptAction.showToast({ message: '\u56DE\u590D\u5931\u8D25\uFF0CHTTP ' + response.code, duration: 2000 });
        } catch (e) {
          console.info('Reply HTTP error');
        }
        return;
      }

      const body = response.raw || '';
      let hasError = false;
      let errMsg = '';

      try {
        let jsonStr = body;
        const prefixTag = 'window.script_muti_get_var_store=';
        const prefixIdx = jsonStr.indexOf(prefixTag);
        if (prefixIdx >= 0) {
          jsonStr = jsonStr.substring(prefixIdx + prefixTag.length);
        }
        const jsonObj = JSON.parse(jsonStr) as Record<string, Object>;
        const errorField = jsonObj['error'];
        if (errorField != null) {
          if (Array.isArray(errorField)) {
            const errArr = errorField as Object[];
            if (errArr.length > 0 && errArr[0] != null && String(errArr[0]) !== '') {
              hasError = true;
              errMsg = String(errArr[0]);
              const colonIdx = errMsg.indexOf(':');
              if (colonIdx >= 0) {
                errMsg = errMsg.substring(colonIdx + 1);
              }
            }
          } else if (typeof errorField === 'object') {
            const errObj = errorField as Record<string, Object>;
            const e0 = errObj['0'];
            if (e0 != null && String(e0) !== '') {
              hasError = true;
              errMsg = String(e0);
              const colonIdx = errMsg.indexOf(':');
              if (colonIdx >= 0) {
                errMsg = errMsg.substring(colonIdx + 1);
              }
            }
          }
        }
      } catch (parseErr) {
        console.error('Parse reply response failed:', parseErr);
        if (body.indexOf('\u53D1\u8D34\u5B8C\u6BD5') >= 0) {
          hasError = false;
        } else {
          hasError = true;
          errMsg = '\u54CD\u5E94\u89E3\u6790\u5931\u8D25';
        }
      }

      if (!hasError) {
        this.closeReplyBar();
        const lastPage = this.totalPages;
        this.page = lastPage;
        this.loadArticles(false);
        try {
          promptAction.showToast({ message: '\u56DE\u590D\u6210\u529F', duration: 1500 });
        } catch (e) {
          console.info('Reply success');
        }
      } else {
        try {
          promptAction.showToast({ message: errMsg || '\u56DE\u590D\u5931\u8D25', duration: 2500 });
        } catch (e) {
          console.info('Reply failed: ' + errMsg);
        }
      }
    } catch (err) {
      console.error('Reply error:', err);
      try {
        promptAction.showToast({ message: '\u7F51\u7EDC\u9519\u8BEF', duration: 1500 });
      } catch (e) {
        console.info('Reply network error');
      }
    } finally {
      this.isReplying = false;
    }
  }

  private findMatchingQuoteEnd(lowerContent: string, quoteStart: number): number {
    const openTagEnd = lowerContent.indexOf(']', quoteStart);
    if (openTagEnd < 0) {
      return -1;
    }

    let depth = 1;
    let searchPos = openTagEnd + 1;
    while (searchPos < lowerContent.length) {
      const nextQuoteOpen = lowerContent.indexOf('[quote', searchPos);
      const nextQuoteClose = lowerContent.indexOf('[/quote]', searchPos);
      if (nextQuoteClose < 0) {
        return -1;
      }

      if (nextQuoteOpen >= 0 && nextQuoteOpen < nextQuoteClose) {
        const nestedOpenEnd = lowerContent.indexOf(']', nextQuoteOpen);
        if (nestedOpenEnd < 0) {
          return -1;
        }
        depth++;
        searchPos = nestedOpenEnd + 1;
        continue;
      }

      depth--;
      if (depth === 0) {
        return nextQuoteClose;
      }
      searchPos = nextQuoteClose + 8;
    }

    return -1;
  }

  parseContentSegments(content: string, attachments: Attachment[], appendDetachedAttachments: boolean = true): ContentSegment[] {
    if (!content) return [];

    const segments: ContentSegment[] = [];
    let processed = content;

    // 先处理 HTML 换行
    processed = processed.replace(/<br\s*\/?>/g, '\n');
    processed = processed.replace(/<a\b[^>]*href=(['"])(.*?)\1[^>]*>(.*?)<\/a>/gi, '[url=$2]$3[/url]');
    // 去掉 HTML 标签（img 除外）
    processed = processed.replace(/<(?!\/?img)[^>]+>/g, '');
    // HTML 实体
    processed = this.decodeHtmlEntities(processed);
    const lowerProcessed = processed.toLowerCase();

    // 收集附件图片 URL 映射（按 attachs key / aid）
    const thumbToOriginalMap: Map<string, string> = new Map();
    for (let i = 0; i < attachments.length; i++) {
      const att = attachments[i];
      if (att.url) {
        thumbToOriginalMap.set(att.url, att.url);
      }
      if (att.thumbUrl) {
        thumbToOriginalMap.set(att.thumbUrl, att.url || att.thumbUrl);
      }
    }

    // 用正则拆分内容：匹配 [img]...[/img]、[quote]...[/quote]、[collapse=...]...[/collapse]
    // 使用手动扫描实现分段
    let pos = 0;
    let textBuf = '';

    const flushText = (): void => {
      const cleaned = this.cleanBBCode(textBuf);
      if (cleaned.trim()) {
        segments.push(ContentSegment.makeText(cleaned));
      }
      textBuf = '';
    };

    while (pos < processed.length) {
      // 查找下一个 [img] 标签
      const imgStart = lowerProcessed.indexOf('[img]', pos);
      const imgStart2 = lowerProcessed.indexOf('[img=', pos);
      const urlStart = lowerProcessed.indexOf('[url]', pos);
      const urlStart2 = lowerProcessed.indexOf('[url=', pos);
      const uidStart = lowerProcessed.indexOf('[uid=', pos);
      const quoteStart = lowerProcessed.indexOf('[quote', pos);

      // 找最近的图片标签位置
      let nextImgPos = -1;
      let isImgWithParams = false;
      let nextUrlPos = -1;
      let isUrlWithParams = false;
      let nextUidPos = -1;
      let nextQuotePos = -1;

      if (imgStart >= 0 && imgStart2 >= 0) {
        if (imgStart <= imgStart2) { nextImgPos = imgStart; isImgWithParams = false; }
        else { nextImgPos = imgStart2; isImgWithParams = true; }
      } else if (imgStart >= 0) { nextImgPos = imgStart; isImgWithParams = false; }
      else if (imgStart2 >= 0) { nextImgPos = imgStart2; isImgWithParams = true; }

      if (urlStart >= 0 && urlStart2 >= 0) {
        if (urlStart <= urlStart2) { nextUrlPos = urlStart; isUrlWithParams = false; }
        else { nextUrlPos = urlStart2; isUrlWithParams = true; }
      } else if (urlStart >= 0) { nextUrlPos = urlStart; isUrlWithParams = false; }
      else if (urlStart2 >= 0) { nextUrlPos = urlStart2; isUrlWithParams = true; }

      if (uidStart >= 0) {
        nextUidPos = uidStart;
      }

      if (quoteStart >= 0) {
        nextQuotePos = quoteStart;
      }

      let nextTagPos = -1;
      let nextTagType = '';
      if (nextImgPos >= 0) {
        nextTagPos = nextImgPos;
        nextTagType = 'image';
      }
      if (nextUrlPos >= 0 && (nextTagPos < 0 || nextUrlPos < nextTagPos)) {
        nextTagPos = nextUrlPos;
        nextTagType = 'link';
      }
      if (nextUidPos >= 0 && (nextTagPos < 0 || nextUidPos < nextTagPos)) {
        nextTagPos = nextUidPos;
        nextTagType = 'user';
      }
      if (nextQuotePos >= 0 && (nextTagPos < 0 || nextQuotePos < nextTagPos)) {
        nextTagPos = nextQuotePos;
        nextTagType = 'quote';
      }

      if (nextTagPos < 0) {
        textBuf += processed.substring(pos);
        break;
      }

      textBuf += processed.substring(pos, nextTagPos);

      if (nextTagType === 'quote') {
        const quoteOpenEnd = processed.indexOf(']', nextTagPos);
        const quoteEndPos = this.findMatchingQuoteEnd(lowerProcessed, nextTagPos);
        if (quoteOpenEnd < 0 || quoteEndPos < 0) {
          textBuf += processed.substring(nextTagPos);
          break;
        }

        flushText();
        const quoteInner = processed.substring(quoteOpenEnd + 1, quoteEndPos);
        const quoteSegments = this.parseContentSegments(quoteInner, attachments, false);
        for (let i = 0; i < quoteSegments.length; i++) {
          quoteSegments[i].isQuote = true;
          segments.push(quoteSegments[i]);
        }

        pos = quoteEndPos + 8;
        continue;
      }

      if (nextTagType === 'image') {
        const imgEndTag = '[/img]';
        const imgEndPos = lowerProcessed.indexOf(imgEndTag, nextTagPos);
        if (imgEndPos < 0) {
          textBuf += processed.substring(nextTagPos);
          break;
        }

        let imgUrl = '';
        if (isImgWithParams) {
          const closeBracket = processed.indexOf(']', nextTagPos);
          if (closeBracket >= 0 && closeBracket < imgEndPos) {
            imgUrl = processed.substring(closeBracket + 1, imgEndPos).trim();
          }
        } else {
          imgUrl = processed.substring(nextTagPos + 5, imgEndPos).trim();
        }

        if (imgUrl) {
          flushText();
          const normalizedUrl = this.apiHelper.normalizeImageUrl(imgUrl);
          const originalUrl = thumbToOriginalMap.get(normalizedUrl) || normalizedUrl;
          segments.push(ContentSegment.makeImage(normalizedUrl, originalUrl));
        }

        pos = imgEndPos + imgEndTag.length;
        continue;
      }

      const closeBracket = processed.indexOf(']', nextTagPos);
      if (closeBracket < 0) {
        textBuf += processed.substring(nextTagPos);
        break;
      }

      if (nextTagType === 'user') {
        const uidEndTag = '[/uid]';
        const uidEndPos = lowerProcessed.indexOf(uidEndTag, closeBracket);
        if (uidEndPos < 0) {
          textBuf += processed.substring(nextTagPos);
          break;
        }

        const uidValue = processed.substring(nextTagPos + 5, closeBracket).trim();
        const rawUserText = processed.substring(closeBracket + 1, uidEndPos);
        const cleanedUserText = this.cleanBBCode(rawUserText).trim();
        if (/^\d+$/.test(uidValue) && cleanedUserText !== '') {
          flushText();
          segments.push(ContentSegment.makeUser(cleanedUserText, uidValue));
        } else {
          textBuf += rawUserText;
        }

        pos = uidEndPos + uidEndTag.length;
        continue;
      }

      const urlEndTag = '[/url]';
      const urlEndPos = lowerProcessed.indexOf(urlEndTag, closeBracket);
      if (urlEndPos < 0) {
        textBuf += processed.substring(nextTagPos);
        break;
      }

      let linkUrl = '';
      if (isUrlWithParams) {
        linkUrl = processed.substring(nextTagPos + 5, closeBracket).trim();
      } else {
        linkUrl = processed.substring(closeBracket + 1, urlEndPos).trim();
      }
      const rawLinkText = processed.substring(closeBracket + 1, urlEndPos);
      const cleanedLinkText = this.cleanBBCode(rawLinkText);
      const normalizedLinkUrl = this.normalizeLinkUrl(linkUrl);
      const displayText = cleanedLinkText.trim() !== '' ? cleanedLinkText : normalizedLinkUrl;

      if (normalizedLinkUrl !== '' && displayText.trim() !== '') {
        flushText();
        segments.push(ContentSegment.makeLink(displayText, normalizedLinkUrl));
      } else {
        textBuf += rawLinkText;
      }

      pos = urlEndPos + urlEndTag.length;
    }

    flushText();

    // 如果内容中没有 [img] 但有附件图片，在末尾追加
    if (appendDetachedAttachments && attachments.length > 0) {
      let hasImgInContent = false;
      for (let i = 0; i < segments.length; i++) {
        if (segments[i].type === 'image') {
          hasImgInContent = true;
          break;
        }
      }
      if (!hasImgInContent) {
        for (let i = 0; i < attachments.length; i++) {
          if (attachments[i].url && attachments[i].type.toString() === 'image') {
            segments.push(ContentSegment.makeImage(
              attachments[i].thumbUrl !== '' ? attachments[i].thumbUrl : attachments[i].url,
              attachments[i].url
            ));
          }
        }
      }
    }

    return segments;
  }

  buildContentBlocks(segments: ContentSegment[]): ContentBlock[] {
    const blocks: ContentBlock[] = [];
    let inlineSegments: ContentSegment[] = [];

    const flushInline = (): void => {
      if (inlineSegments.length > 0) {
        blocks.push(ContentBlock.makeInline(inlineSegments, inlineSegments[0].isQuote));
        inlineSegments = [];
      }
    };

    for (let i = 0; i < segments.length; i++) {
      const segment = segments[i];
      if (segment.type === 'image') {
        flushInline();
        blocks.push(ContentBlock.makeImage(segment, segment.isQuote));
      } else {
        if (inlineSegments.length > 0 && inlineSegments[0].isQuote !== segment.isQuote) {
          flushInline();
        }
        inlineSegments.push(segment);
      }
    }

    flushInline();
    return blocks;
  }

  cleanBBCode(text: string): string {
    let result = text;
    result = result.replace(/\[quote\]/g, '\u300C');
    result = result.replace(/\[\/quote\]/g, '\u300D\n');
    result = result.replace(/\[b\]/g, '');
    result = result.replace(/\[\/b\]/g, '');
    result = result.replace(/\[i\]/g, '');
    result = result.replace(/\[\/i\]/g, '');
    result = result.replace(/\[u\]/g, '');
    result = result.replace(/\[\/u\]/g, '');
    result = result.replace(/\[url\]([^\[]*)\[\/url\]/g, '$1');
    result = result.replace(/\[url=[^\]]*\]([^\[]*)\[\/url\]/g, '$1');
    result = result.replace(/\[collapse=[^\]]*\]/g, '');
    result = result.replace(/\[\/collapse\]/g, '');
    result = result.replace(/\[size=[^\]]*\]/g, '');
    result = result.replace(/\[\/size\]/g, '');
    result = result.replace(/\[color=[^\]]*\]/g, '');
    result = result.replace(/\[\/color\]/g, '');
    result = result.replace(/\[font=[^\]]*\]/g, '');
    result = result.replace(/\[\/font\]/g, '');
    result = result.replace(/\[align=[^\]]*\]/g, '');
    result = result.replace(/\[\/align\]/g, '');
    result = result.replace(/\[del\]/g, '');
    result = result.replace(/\[\/del\]/g, '');
    result = result.replace(/\[list\]/g, '');
    result = result.replace(/\[\/list\]/g, '');
    result = result.replace(/\[\*\]/g, '\u2022 ');
    result = result.replace(/\[tid=[^\]]*\]/g, '');
    result = result.replace(/\[\/tid\]/g, '');
    result = result.replace(/\[pid=[^\]]*\]/g, '');
    result = result.replace(/\[\/pid\]/g, '');
    result = result.replace(/\[flash\][^\[]*\[\/flash\]/g, '[\u89C6\u9891]');
    result = result.replace(/\[\/?[a-zA-Z]+[^\]]*\]/g, '');
    result = result.replace(/\n{3,}/g, '\n\n');
    return this.decodeHtmlEntities(result);
  }

  private normalizeLinkUrl(url: string): string {
    const cleaned = this.decodeHtmlEntities(url).trim();
    if (!cleaned) {
      return '';
    }

    if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(cleaned)) {
      return cleaned;
    }
    if (cleaned.indexOf('//') === 0) {
      return 'https:' + cleaned;
    }
    if (cleaned.indexOf('/') === 0) {
      return AppConstants.NGA_BASE_URL + cleaned;
    }
    if (cleaned.indexOf('./') === 0) {
      return AppConstants.NGA_BASE_URL + '/' + cleaned.substring(2);
    }
    if (/^(read|thread|post|nuke)\.php/i.test(cleaned) || cleaned.indexOf('.php?') >= 0 || cleaned.indexOf('.php#') >= 0) {
      return AppConstants.NGA_BASE_URL + '/' + cleaned;
    }
    if (/^[^\/\s]+\.[^\s]+/.test(cleaned)) {
      return 'https://' + cleaned;
    }
    return '';
  }

  private decodeHtmlEntities(text: string): string {
    if (!text) {
      return '';
    }

    let result = text;
    let changed = true;
    let guard = 0;
    while (changed && guard < 5) {
      const before = result;
      result = result.replace(/&nbsp;/g, ' ');
      result = result.replace(/&amp;/g, '&');
      result = result.replace(/&lt;/g, '<');
      result = result.replace(/&gt;/g, '>');
      result = result.replace(/&quot;/g, '"');
      result = result.replace(/&#39;/g, '\'');
      changed = before !== result;
      guard++;
    }

    const reDec = /&#(\d+);/;
    let decMatch = reDec.exec(result);
    guard = 0;
    while (decMatch != null && guard < 50) {
      const code = parseInt(decMatch[1], 10);
      const char = (!isNaN(code) && code > 0 && code < 0x110000) ? String.fromCharCode(code) : '';
      result = result.replace(decMatch[0], char);
      decMatch = reDec.exec(result);
      guard++;
    }

    const reHex = /&#x([0-9a-fA-F]+);/;
    let hexMatch = reHex.exec(result);
    guard = 0;
    while (hexMatch != null && guard < 50) {
      const code = parseInt(hexMatch[1], 16);
      const char = (!isNaN(code) && code > 0 && code < 0x110000) ? String.fromCharCode(code) : '';
      result = result.replace(hexMatch[0], char);
      hexMatch = reHex.exec(result);
      guard++;
    }

    return result;
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('\u{276E}')
          .fontSize(22)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(40)
          .height(48)
          .textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })

        Column() {
          Text(this.subject)
            .fontSize(FontSize.MEDIUM)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.totalCount + ' \u697C  \u00B7  \u5171 ' + this.totalPages + ' \u9875')
            .fontSize(FontSize.EXTRA_SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .width('100%')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .margin({ left: 4 })

        Stack() {
          Circle()
            .width(36)
            .height(36)
            .fill(this.isLoading ? ThemeColors.PRIMARY_LIGHT : ThemeColors.SEARCH_BG)

          if (this.isLoading) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(ThemeColors.PRIMARY)
          } else {
            Text('\u27F3')
              .fontSize(17)
              .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
              .fontWeight(FontWeight.Medium)
              .fontFamily(ThemeColors.FONT_FAMILY_UI)
          }
        }
          .width(40)
          .height(48)
          .onClick(() => {
            this.page = 1;
            this.loadArticles();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 8, right: 8 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      // 分页导航栏
      if (this.totalPages > 1) {
        Row() {
          // 上一页
          Text('\u{276E}')
            .fontSize(14)
            .fontColor(this.page > 1 ? ThemeColors.PRIMARY : ThemeColors.TEXT_HINT_LIGHT)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .borderRadius(BorderRadius.SMALL)
            .backgroundColor(this.page > 1 ? ThemeColors.PRIMARY_LIGHT : ThemeColors.BACKGROUND_LIGHT)
            .onClick(() => { if (this.page > 1) this.goToPage(this.page - 1); })

          // 页码按钮
          Row() {
            ForEach(this.getVisiblePages(), (p: number) => {
              if (p === -1) {
                Text('\u22EF')
                  .fontSize(FontSize.SMALL)
                  .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                  .width(28)
                  .height(28)
                  .textAlign(TextAlign.Center)
              } else {
                Text('' + p)
                  .fontSize(FontSize.SMALL)
                  .fontWeight(p === this.page ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(p === this.page ? '#FFFFFF' : ThemeColors.TEXT_PRIMARY_LIGHT)
                  .backgroundColor(p === this.page ? ThemeColors.PRIMARY : Color.Transparent)
                  .width(28)
                  .height(28)
                  .textAlign(TextAlign.Center)
                  .borderRadius(BorderRadius.SMALL)
                  .onClick(() => { this.goToPage(p); })
              }
            }, (p: number, index: number) => 'page_' + p + '_' + index)
          }
          .margin({ left: 4, right: 4 })

          // 下一页
          Text('\u{276F}')
            .fontSize(14)
            .fontColor(this.page < this.totalPages ? ThemeColors.PRIMARY : ThemeColors.TEXT_HINT_LIGHT)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .borderRadius(BorderRadius.SMALL)
            .backgroundColor(this.page < this.totalPages ? ThemeColors.PRIMARY_LIGHT : ThemeColors.BACKGROUND_LIGHT)
            .onClick(() => { if (this.page < this.totalPages) this.goToPage(this.page + 1); })

          Blank()

          // 跳转按钮
          Text('\u{1F4C4} ' + this.page + '/' + this.totalPages)
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.PRIMARY)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .backgroundColor(ThemeColors.PRIMARY_LIGHT)
            .onClick(() => { this.showPageJumper = !this.showPageJumper; })
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .backgroundColor(ThemeColors.SURFACE_LIGHT)
        .alignItems(VerticalAlign.Center)
        .shadow({ radius: 2, color: '#00000008', offsetX: 0, offsetY: 1 })
      }

      // 页码跳转输入栏
      if (this.showPageJumper) {
        Row() {
          Text('\u8DF3\u8F6C\u5230')
            .fontSize(FontSize.NORMAL)
            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)

          TextInput({ placeholder: '\u9875\u7801', text: this.jumpPageText })
            .width(60)
            .height(36)
            .fontSize(FontSize.NORMAL)
            .textAlign(TextAlign.Center)
            .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
            .borderRadius(BorderRadius.NORMAL)
            .margin({ left: 8, right: 8 })
            .type(InputType.Number)
            .onChange((value: string) => { this.jumpPageText = value; })
            .onSubmit(() => {
              const p = parseInt(this.jumpPageText);
              if (!isNaN(p)) this.goToPage(p);
            })

          Text('\u9875')
            .fontSize(FontSize.NORMAL)
            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)

          Button('\u786E\u5B9A')
            .fontSize(FontSize.SMALL)
            .fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .height(32)
            .padding({ left: 16, right: 16 })
            .margin({ left: 12 })
            .onClick(() => {
              const p = parseInt(this.jumpPageText);
              if (!isNaN(p)) this.goToPage(p);
            })

          Blank()

          Text('\u2715')
            .fontSize(16)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.showPageJumper = false; })
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 12 })
        .backgroundColor(ThemeColors.CARD_BG)
        .alignItems(VerticalAlign.Center)
        .shadow({ radius: 2, color: '#00000008', offsetX: 0, offsetY: 1 })
      }

      // 内容区域
      if (this.isLoading && this.articles.length === 0) {
        Column() {
          LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
          Text('\u6B63\u5728\u52A0\u8F7D...').fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadError && this.articles.length === 0) {
        Column() {
          Text('Oops!')
            .fontSize(FontSize.EXTRA_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          Text(this.loadError)
            .fontSize(FontSize.NORMAL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 8 })
          Button('\u91CD\u65B0\u52A0\u8F7D')
            .fontSize(FontSize.NORMAL)
            .fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .height(40)
            .padding({ left: 24, right: 24 })
            .margin({ top: 20 })
            .onClick(() => {
              this.page = 1;
              this.loadArticles();
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.articles.length > 0) {
        List() {
          ForEach(this.articles, (article: Article, index: number) => {
            ListItem() {
              this.ArticleCard(article, index);
            }
          })

          if (this.hasMore) {
            ListItem() {
              Row() {
                if (this.isLoadingMore) {
                  LoadingProgress().width(20).height(20).color(ThemeColors.PRIMARY)
                  Text('\u52A0\u8F7D\u4E2D...').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                    .margin({ left: 8 })
                } else {
                  Text('\u4E0A\u62C9\u52A0\u8F7D\u66F4\u591A').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                }
              }
              .width('100%')
              .height(50)
              .justifyContent(FlexAlign.Center)
            }
          } else if (this.articles.length > 0) {
            ListItem() {
              Text('\u2014 \u5DF2\u7ECF\u5230\u5E95\u4E86 \u2014')
                .fontSize(FontSize.SMALL)
                .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(20)
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
        .edgeEffect(EdgeEffect.Spring)
        .divider({ strokeWidth: 0 })
        .onReachEnd(() => { this.loadNextPage(); })
      } else {
        Column() {
          Text('\u{1F4AD}')
            .fontSize(48)
          Text('暂无内容')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 12 })
          Text('该帖子可能需要登录或特定权限才能查看')
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 6 })
          Button('重新加载')
            .fontSize(FontSize.NORMAL)
            .fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .height(40)
            .padding({ left: 24, right: 24 })
            .margin({ top: 20 })
            .onClick(() => {
              this.page = 1;
              this.loadArticles();
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      // 底部回复入口栏
      if (!this.showReplyBar && this.articles.length > 0) {
        Row() {
          Row() {
            Text('\u{270D}\uFE0F')
              .fontSize(14)
              .margin({ right: 8 })
            Text('\u5199\u56DE\u590D...')
              .fontSize(FontSize.NORMAL)
              .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          }
          .layoutWeight(1)
          .height(38)
          .padding({ left: 16, right: 16 })
          .backgroundColor(ThemeColors.SEARCH_BG)
          .borderRadius(BorderRadius.EXTRA_LARGE)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.openReplyToThread();
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor(ThemeColors.SURFACE_LIGHT)
        .alignItems(VerticalAlign.Center)
        .shadow({ radius: 4, color: '#00000010', offsetX: 0, offsetY: -2 })
      }

      // 回复输入面板
      if (this.showReplyBar) {
        Column() {
          // 回复对象提示 + 关闭
          Row() {
            if (this.replyToFloor >= 0) {
              Text('\u56DE\u590D #' + this.replyToFloor + ' ' + this.replyToUser)
                .fontSize(FontSize.SMALL)
                .fontColor(ThemeColors.PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            } else {
              Text('\u56DE\u590D\u5E16\u5B50')
                .fontSize(FontSize.SMALL)
                .fontColor(ThemeColors.PRIMARY)
                .layoutWeight(1)
            }

            Text('\u2715')
              .fontSize(16)
              .fontColor(ThemeColors.TEXT_HINT_LIGHT)
              .width(32)
              .height(32)
              .textAlign(TextAlign.Center)
              .onClick(() => { this.closeReplyBar(); })
          }
          .width('100%')
          .padding({ left: 16, right: 8, top: 8 })

          // 输入区 + 发送
          Row() {
            TextArea({ placeholder: '\u8BF4\u70B9\u4EC0\u4E48...', text: this.replyContent })
              .layoutWeight(1)
              .height(80)
              .fontSize(FontSize.NORMAL)
              .backgroundColor(ThemeColors.SEARCH_BG)
              .borderRadius(BorderRadius.NORMAL)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .onChange((value: string) => { this.replyContent = value; })

            Column() {
              if (this.isReplying) {
                LoadingProgress().width(24).height(24).color(ThemeColors.PRIMARY)
              } else {
                Text('\u53D1\u9001')
                  .fontSize(FontSize.NORMAL)
                  .fontColor(this.replyContent.trim() !== '' ? '#FFFFFF' : ThemeColors.TEXT_HINT_LIGHT)
                  .backgroundColor(this.replyContent.trim() !== '' ? ThemeColors.PRIMARY : ThemeColors.SEARCH_BG)
                  .borderRadius(BorderRadius.EXTRA_LARGE)
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .onClick(() => { this.submitReply(); })
              }
            }
            .margin({ left: 8 })
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 12 })
          .alignItems(VerticalAlign.Bottom)
        }
        .width('100%')
        .backgroundColor(ThemeColors.SURFACE_LIGHT)
        .shadow({ radius: 8, color: '#00000015', offsetX: 0, offsetY: -4 })
      }
    }
    .width('100%')
    .height('100%')
    .opacity(this.appTheme.length > 0 ? 1 : 1)
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  @Builder
  ArticleCard(article: Article, index: number) {
    Column() {
      // 作者信息
      Row() {
        // 头像（可点击）
        AvatarView({
          url: this.avatarUrlForUid(article.author.uid),
          avatarSize: 36,
          placeholder: this.authorInitial(article.author.username)
        })
        .onClick(() => {
          this.goToUserProfile(article.author.uid, article.author.username);
        })

        Column() {
          Row() {
            // 用户名（可点击）
            Text(article.author.username || '\u533F\u540D')
              .fontSize(FontSize.NORMAL)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
              .fontFamily(ThemeColors.FONT_FAMILY_UI)
              .onClick(() => {
                this.goToUserProfile(article.author.uid, article.author.username);
              })

            // 楼主标签：楼主回复的楼层都显示
            if (article.isAuthor) {
              Text('\u697C\u4E3B')
                .fontSize(FontSize.EXTRA_SMALL)
                .fontColor(ThemeColors.PRIMARY)
                .backgroundColor(ThemeColors.PRIMARY_LIGHT)
                .borderRadius(BorderRadius.SMALL)
                .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                .margin({ left: 6 })
            }
          }

          Text('#' + article.floor + '  \u00B7  ' + article.getFormattedTime())
            .fontSize(FontSize.EXTRA_SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
      }
      .width('100%')

      // 楼层标题
      if (article.noteInfo) {
        Text(article.noteInfo)
          .fontSize(FontSize.MEDIUM)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .margin({ top: 10 })
          .width('100%')
      }

      // 正文内容（文字+图片混合渲染）
      this.RichContent(article)

      // 底部互动栏
      Row() {
        Row() {
          Text('\u{1F44D}')
            .fontSize(13)
            .fontColor(article.voteValue === 1 ? ThemeColors.PRIMARY : ThemeColors.TEXT_SECONDARY_LIGHT)
          Text('\u8D5E')
            .fontSize(FontSize.SMALL)
            .fontColor(article.voteValue === 1 ? ThemeColors.PRIMARY : ThemeColors.TEXT_SECONDARY_LIGHT)
            .margin({ left: 4 })
        }
        .padding({ top: 4, bottom: 4 })
        .opacity(article.isVoting ? 0.6 : 1)
        .onClick(() => {
          this.voteArticle(article, 1);
        })

        Row() {
          Text('\u{1F44E}')
            .fontSize(13)
            .fontColor(article.voteValue === -1 ? ThemeColors.ERROR : ThemeColors.TEXT_SECONDARY_LIGHT)
          Text('\u8E29')
            .fontSize(FontSize.SMALL)
            .fontColor(article.voteValue === -1 ? ThemeColors.ERROR : ThemeColors.TEXT_SECONDARY_LIGHT)
            .margin({ left: 4 })
        }
        .margin({ left: 16 })
        .padding({ top: 4, bottom: 4 })
        .opacity(article.isVoting ? 0.6 : 1)
        .onClick(() => {
          this.voteArticle(article, -1);
        })

        if (article.likes != 0) {
          Row() {
            Text(article.likes > 0 ? '\u{1F44D}' : '\u{1F44E}')
              .fontSize(13)
            Text((article.likes > 0 ? '+' : '') + article.likes)
              .fontSize(FontSize.SMALL)
              .fontColor(article.likes > 0 ? ThemeColors.SUCCESS : ThemeColors.ERROR)
              .margin({ left: 4 })
          }
          .margin({ left: 10 })
        }

        Blank()

        Text('\u56DE\u590D')
          .fontSize(FontSize.SMALL)
          .fontColor(ThemeColors.PRIMARY)
          .padding({ top: 4, bottom: 4 })
          .onClick(() => {
            this.openReplyTo(article);
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ThemeColors.CARD_BG)
    .borderRadius(BorderRadius.MEDIUM)
    .margin({ bottom: 8 })
    .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
    .alignItems(HorizontalAlign.Start)
  }

  collectImageUrls(segments: ContentSegment[]): string[] {
    const urls: string[] = [];
    for (let i = 0; i < segments.length; i++) {
      if (segments[i].type === 'image' && segments[i].originalImageUrl) {
        urls.push(segments[i].originalImageUrl);
      }
    }
    return urls;
  }

  private getArticleBlocks(article: Article): ContentBlock[] {
    return this.buildContentBlocks(this.parseContentSegments(article.content, article.attachments));
  }

  private getArticleImageUrls(article: Article): string[] {
    return this.collectImageUrls(this.parseContentSegments(article.content, article.attachments));
  }

  openImageViewer(imageUrls: string[], clickedUrl: string) {
    let idx = 0;
    for (let i = 0; i < imageUrls.length; i++) {
      if (imageUrls[i] === clickedUrl) {
        idx = i;
        break;
      }
    }
    const params: Record<string, Object> = {
      'imageUrls': imageUrls as Object,
      'currentIndex': idx as Object
    };
    router.pushUrl({
      url: 'pages/image/ImageViewerPage',
      params: params
    });
  }

  private inlineImageUrl(seg: ContentSegment): string {
    if (this.useOriginalImagesInPost && seg.originalImageUrl) {
      return seg.originalImageUrl;
    }
    return seg.imageUrl;
  }

  async openLink(url: string) {
    const normalizedUrl = this.normalizeLinkUrl(url);
    if (normalizedUrl === '') {
      promptAction.showToast({ message: '链接地址无效', duration: 1500 });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: normalizedUrl,
        type: 'text/html'
      });
    } catch (err) {
      console.error('Open link failed:', JSON.stringify(err));
      promptAction.showToast({ message: '打开链接失败', duration: 1500 });
    }
  }

  @Builder
  private InlineTextBlock(block: ContentBlock, keyPrefix: string) {
    Text() {
      ForEach(block.segments, (seg: ContentSegment, segIndex: number) => {
        if (seg.type === 'link') {
          Span(seg.text)
            .fontColor(block.isQuote ? ThemeColors.PRIMARY_DARK : ThemeColors.PRIMARY)
            .decoration({
              type: TextDecorationType.Underline,
              color: block.isQuote ? ThemeColors.PRIMARY_DARK : ThemeColors.PRIMARY
            })
            .onClick(() => {
              this.openLink(seg.linkUrl);
            })
        } else if (seg.type === 'user') {
          Span(seg.text)
            .fontColor(block.isQuote ? ThemeColors.PRIMARY_DARK : ThemeColors.PRIMARY)
            .fontWeight(FontWeight.Medium)
            .decoration({
              type: TextDecorationType.Underline,
              color: block.isQuote ? ThemeColors.PRIMARY_DARK : ThemeColors.PRIMARY
            })
            .onClick(() => {
              this.goToUserProfile(seg.userUid, seg.text);
            })
        } else {
          Span(seg.text)
            .fontColor(block.isQuote ? ThemeColors.TEXT_SECONDARY_LIGHT : ThemeColors.TEXT_PRIMARY_LIGHT)
        }
      }, (seg: ContentSegment, segIndex: number) => keyPrefix + '_' + seg.type + '_' + segIndex)
    }
      .fontSize(FontSize.ARTICLE_NORMAL)
      .lineHeight(FontSize.ARTICLE_NORMAL + 6)
      .width('100%')
      .copyOption(CopyOptions.LocalDevice)
  }

  @Builder
  private QuoteBlock(article: Article, block: ContentBlock, blockIndex: number) {
    Column() {
      Text('引用内容')
        .fontSize(FontSize.EXTRA_SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeColors.PRIMARY)
        .backgroundColor(ThemeColors.PRIMARY_LIGHT)
        .borderRadius(BorderRadius.SMALL)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .margin({ bottom: 10 })

      if (block.type === 'image') {
        Image(this.inlineImageUrl(block.segments[0]))
          .width('100%')
          .objectFit(ImageFit.Contain)
          .borderRadius(BorderRadius.NORMAL)
          .backgroundColor(ThemeColors.SURFACE_LIGHT)
          .constraintSize(this.useOriginalImagesInPost ? {} : { maxHeight: 320 })
          .onClick(() => {
            this.openImageViewer(this.getArticleImageUrls(article), block.segments[0].originalImageUrl);
          })
      } else {
        this.InlineTextBlock(block, 'quote_' + blockIndex)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFF8F9')
    .border({ width: 1, color: '#FFD9E0' })
    .borderRadius(BorderRadius.MEDIUM)
    .margin({ top: 6, bottom: 6 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RichContent(article: Article) {
    Column() {
      ForEach(this.getArticleBlocks(article),
        (block: ContentBlock, blockIndex: number) => {
          if (block.isQuote) {
            this.QuoteBlock(article, block, blockIndex)
          } else if (block.type === 'image') {
            Image(this.inlineImageUrl(block.segments[0]))
              .width('100%')
              .objectFit(ImageFit.Contain)
              .borderRadius(BorderRadius.NORMAL)
              .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
              .constraintSize(this.useOriginalImagesInPost ? {} : { maxHeight: 400 })
              .margin({ top: 8, bottom: 4 })
              .onClick(() => {
                this.openImageViewer(this.getArticleImageUrls(article), block.segments[0].originalImageUrl);
              })
          } else {
            this.InlineTextBlock(block, 'body_' + blockIndex)
          }
        },
        (block: ContentBlock, blockIndex: number) => block.type + '_' + blockIndex
      )
    }
    .width('100%')
    .margin({ top: 10 })
    .alignItems(HorizontalAlign.Start)
  }
}
