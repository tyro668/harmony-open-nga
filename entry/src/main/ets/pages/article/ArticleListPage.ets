import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';
import { Article, Attachment } from '../../model/entity/Article';
import { ngaApi } from '../../network/api/NgaApi';
import { NgaApi } from '../../network/api/NgaApi';
import { HttpClient } from '../../network/api/HttpClient';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { AppConstants } from '../../common/constants/AppConstants';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

class ContentSegment {
  type: string = 'text';
  text: string = '';
  imageUrl: string = '';
  isQuote: boolean = false;

  static makeText(text: string, isQuote: boolean = false): ContentSegment {
    const seg = new ContentSegment();
    seg.type = 'text';
    seg.text = text;
    seg.isQuote = isQuote;
    return seg;
  }

  static makeImage(url: string): ContentSegment {
    const seg = new ContentSegment();
    seg.type = 'image';
    seg.imageUrl = url;
    return seg;
  }
}

@Entry
@Component
struct ArticleListPage {
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
  @State contentFontSize: number = 16; // 内容字体大小
  @State titleFontSize: number = 17; // 标题字体大小
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
    this.loadFontSize();
    if (this.tid != '') {
      this.loadArticles();
    }
  }

  async loadFontSize() {
    try {
      const level = await PreferencesManager.getInstance().getString(AppConstants.PREF_FONT_SIZE, 'normal');
      this.applyFontSize(level);
    } catch (e) {
      console.error('Load font size failed:', e);
    }
  }

  applyFontSize(level: string) {
    // 字体大小映射：small=更小, normal=标准, large=更大
    switch (level) {
      case 'small':
        this.contentFontSize = 14;
        this.titleFontSize = 15;
        break;
      case 'large':
        this.contentFontSize = 18;
        this.titleFontSize = 19;
        break;
      default: // normal
        this.contentFontSize = 16;
        this.titleFontSize = 17;
        break;
    }
  }

  goToUserProfile(uid: string, username: string) {
    // 打印调试信息
    console.info('goToUserProfile called with uid=' + uid + ', username=' + username);
    
    // 确保 uid 有效
    let userId = uid;
    if (userId == null || userId === '' || userId === '0') {
      // 如果 uid 无效，尝试使用用户名
      userId = username || '0';
    }
    
    console.info('Navigating to profile with uid=' + userId);
    router.pushUrl({
      url: 'pages/profile/ProfilePage',
      params: { uid: userId, name: username || '' }
    });
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

  parseContentSegments(content: string, attachments: Attachment[]): ContentSegment[] {
    if (!content) return [];

    const segments: ContentSegment[] = [];
    let processed = content;

    // 先处理 HTML 换行
    processed = processed.replace(/<br\s*\/?>/g, '\n');
    // 去掉 HTML 标签（img 除外）
    processed = processed.replace(/<(?!\/?img)[^>]+>/g, '');
    // HTML 实体
    processed = processed.replace(/&nbsp;/g, ' ');
    processed = processed.replace(/&lt;/g, '<');
    processed = processed.replace(/&gt;/g, '>');
    processed = processed.replace(/&amp;/g, '&');
    processed = processed.replace(/&quot;/g, '"');

    // 收集附件图片 URL 映射（按 attachs key / aid）
    const attachMap: Map<string, string> = new Map();
    for (let i = 0; i < attachments.length; i++) {
      const att = attachments[i];
      if (att.url) {
        attachMap.set(att.id, att.url);
        attachMap.set(String(i), att.url);
      }
    }

    // 用正则拆分内容：匹配 [img]...[/img]、[quote]...[/quote]、[collapse=...]...[/collapse]
    // 使用手动扫描实现分段
    let pos = 0;
    let textBuf = '';

    const flushText = (): void => {
      const cleaned = this.cleanBBCode(textBuf);
      if (cleaned.trim()) {
        segments.push(ContentSegment.makeText(cleaned.trim()));
      }
      textBuf = '';
    };

    while (pos < processed.length) {
      // 查找下一个 [img] 标签
      const imgStart = processed.indexOf('[img]', pos);
      const imgStart2 = processed.indexOf('[img=', pos);

      // 找最近的图片标签位置
      let nextImgPos = -1;
      let isImgWithParams = false;

      if (imgStart >= 0 && imgStart2 >= 0) {
        if (imgStart <= imgStart2) { nextImgPos = imgStart; isImgWithParams = false; }
        else { nextImgPos = imgStart2; isImgWithParams = true; }
      } else if (imgStart >= 0) { nextImgPos = imgStart; isImgWithParams = false; }
      else if (imgStart2 >= 0) { nextImgPos = imgStart2; isImgWithParams = true; }

      if (nextImgPos < 0) {
        textBuf += processed.substring(pos);
        break;
      }

      // 将图片之前的文字加入
      textBuf += processed.substring(pos, nextImgPos);

      // 解析图片标签
      const imgEndTag = '[/img]';
      const imgEndPos = processed.indexOf(imgEndTag, nextImgPos);
      if (imgEndPos < 0) {
        textBuf += processed.substring(nextImgPos);
        break;
      }

      // 提取图片 URL
      let imgUrl = '';
      if (isImgWithParams) {
        const closeBracket = processed.indexOf(']', nextImgPos);
        if (closeBracket >= 0 && closeBracket < imgEndPos) {
          imgUrl = processed.substring(closeBracket + 1, imgEndPos).trim();
        }
      } else {
        imgUrl = processed.substring(nextImgPos + 5, imgEndPos).trim();
      }

      if (imgUrl) {
        flushText();
        const normalizedUrl = this.apiHelper.normalizeImageUrl(imgUrl);
        segments.push(ContentSegment.makeImage(normalizedUrl));
      }

      pos = imgEndPos + imgEndTag.length;
    }

    flushText();

    // 如果内容中没有 [img] 但有附件图片，在末尾追加
    if (attachments.length > 0) {
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
            segments.push(ContentSegment.makeImage(attachments[i].url));
          }
        }
      }
    }

    return segments;
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
    result = result.replace(/\[url\][^\[]*\[\/url\]/g, '[\u94FE\u63A5]');
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

        Text('\u{1F504}')
          .fontSize(18)
          .width(40)
          .height(48)
          .textAlign(TextAlign.Center)
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
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  @Builder
  ArticleCard(article: Article, index: number) {
    Column() {
      // 作者信息
      Row() {
        // 头像（可点击）
        Stack() {
          Circle().width(36).height(36).fill(ThemeColors.PRIMARY_LIGHT)
          Text((article.author.username || '?').substring(0, 1))
            .fontSize(14)
            .fontColor(ThemeColors.PRIMARY)
            .fontWeight(FontWeight.Bold)
        }
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
              .onClick(() => {
                this.goToUserProfile(article.author.uid, article.author.username);
              })

            if (article.floor === 0) {
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
        if (article.likes != 0) {
          Row() {
            Text(article.likes > 0 ? '\u{1F44D}' : '\u{1F44E}')
              .fontSize(13)
            Text((article.likes > 0 ? '+' : '') + article.likes)
              .fontSize(FontSize.SMALL)
              .fontColor(article.likes > 0 ? ThemeColors.SUCCESS : ThemeColors.ERROR)
              .margin({ left: 4 })
          }
        }

        Blank()

        Text('\u56DE\u590D')
          .fontSize(FontSize.SMALL)
          .fontColor(ThemeColors.PRIMARY)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .borderRadius(BorderRadius.EXTRA_LARGE)
          .backgroundColor(ThemeColors.PRIMARY_LIGHT)
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
      if (segments[i].type === 'image' && segments[i].imageUrl) {
        urls.push(segments[i].imageUrl);
      }
    }
    return urls;
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

  @Builder
  RichContent(article: Article) {
    Column() {
      ForEach(this.parseContentSegments(article.content, article.attachments),
        (seg: ContentSegment, segIndex: number) => {
          if (seg.type === 'image') {
            Image(seg.imageUrl)
              .width('100%')
              .constraintSize({ maxHeight: 400 })
              .objectFit(ImageFit.Contain)
              .borderRadius(BorderRadius.NORMAL)
              .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
              .margin({ top: 8, bottom: 4 })
              .onClick(() => {
                const segments = this.parseContentSegments(article.content, article.attachments);
                const allImgUrls = this.collectImageUrls(segments);
                this.openImageViewer(allImgUrls, seg.imageUrl);
              })
          } else {
            Text(seg.text)
              .fontSize(this.contentFontSize)
              .fontColor(seg.isQuote ? ThemeColors.TEXT_SECONDARY_LIGHT : ThemeColors.TEXT_PRIMARY_LIGHT)
              .lineHeight(this.contentFontSize + 6)
              .width('100%')
          }
        },
        (seg: ContentSegment, segIndex: number) => seg.type + '_' + segIndex
      )
    }
    .width('100%')
    .margin({ top: 10 })
    .alignItems(HorizontalAlign.Start)
  }
}
