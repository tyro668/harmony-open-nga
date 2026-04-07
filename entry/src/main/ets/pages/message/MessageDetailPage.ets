import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';
import { AppConstants } from '../../common/constants/AppConstants';
import { MessageDetailEntry } from '../../model/entity/Message';
import { ngaApi, NgaApi } from '../../network/api/NgaApi';
import { AvatarView, LoadingState } from '../../ui/components/CommonComponents';
import { avatarCacheManager } from '../../common/manager/AvatarCacheManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';

class ContentSegment {
  type: string = 'text';
  text: string = '';
  linkUrl: string = '';
  userUid: string = '';
  imageUrl: string = '';
  isQuote: boolean = false;

  static makeText(text: string, isQuote: boolean = false): ContentSegment {
    const seg = new ContentSegment();
    seg.type = 'text';
    seg.text = text;
    seg.isQuote = isQuote;
    return seg;
  }

  static makeImage(url: string, isQuote: boolean = false): ContentSegment {
    const seg = new ContentSegment();
    seg.type = 'image';
    seg.imageUrl = url;
    seg.isQuote = isQuote;
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
struct MessageDetailPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State mid: string = '';
  @State title: string = '消息详情';
  @State participants: string = '';
  @State entries: MessageDetailEntry[] = [];
  @State page: number = 1;
  @State totalPages: number = 1;
  @State loadingState: LoadingState = LoadingState.LOADING;
  @State isLoadingMore: boolean = false;
  @State isRefreshing: boolean = false;
  @State hasMore: boolean = false;
  @State errorMsg: string = '';
  @State avatarUrls: Record<string, string> = {};
  private readonly REFRESH_THRESHOLD: number = 80;
  private listScroller: Scroller = new Scroller();
  private refreshInFlight: boolean = false;
  private apiHelper: NgaApi = new NgaApi();

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params != null) {
      const midParam = params['mid'];
      if (midParam != null) {
        this.mid = String(midParam);
      }
      const titleParam = params['title'];
      if (titleParam != null && String(titleParam) !== '') {
        this.title = String(titleParam);
      }
    }
    if (this.mid !== '') {
      this.loadMessageDetail();
    } else {
      this.loadingState = LoadingState.ERROR;
      this.errorMsg = '消息 ID 无效';
    }
  }

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

  private async warmEntryAvatars(entriesToWarm: MessageDetailEntry[]) {
    if (entriesToWarm.length === 0) {
      return;
    }

    const context = getContext(this) as common.UIAbilityContext;
    const allowNetwork = await avatarCacheManager.isWifiConnection();
    const seen: Set<string> = new Set<string>();

    for (let i = 0; i < entriesToWarm.length; i++) {
      const uid = entriesToWarm[i].fromUid != null ? String(entriesToWarm[i].fromUid).trim() : '';
      if (!/^\d+$/.test(uid) || uid === '0' || seen.has(uid)) {
        continue;
      }
      seen.add(uid);
      const knownAvatarUrl = entriesToWarm[i].avatarUrl != null ? entriesToWarm[i].avatarUrl : '';
      const avatarUrl = await avatarCacheManager.loadAvatar(
        context,
        uid,
        allowNetwork,
        false,
        knownAvatarUrl,
        false
      );
      if (avatarUrl !== '') {
        this.updateAvatarUrl(uid, avatarUrl);
      }
    }
  }

  async loadMessageDetail(refresh: boolean = true) {
    if (refresh) {
      this.page = 1;
      if (this.entries.length === 0) {
        this.loadingState = LoadingState.LOADING;
      }
    } else {
      this.isLoadingMore = true;
    }

    try {
      const response = await ngaApi.getMessageDetail(this.mid, this.page);
      if (response.code === 200 && response.data != null) {
        const detail = response.data;
        if (detail.errorMsg !== '') {
          this.errorMsg = detail.errorMsg;
          this.loadingState = this.entries.length > 0 ? LoadingState.SUCCESS : LoadingState.ERROR;
          return;
        }

        this.errorMsg = '';
        this.title = detail.title !== '' ? detail.title : this.title;
        this.participants = detail.allUsers;
        this.totalPages = detail.totalPages;
        this.hasMore = detail.hasMore;

        if (refresh) {
          this.entries = detail.entries;
        } else {
          for (let i = 0; i < detail.entries.length; i++) {
            this.entries.push(detail.entries[i]);
          }
        }

        this.loadingState = this.entries.length > 0 ? LoadingState.SUCCESS : LoadingState.EMPTY;
        this.warmEntryAvatars(this.entries);
      } else {
        this.errorMsg = response.message || '加载失败';
        this.loadingState = this.entries.length > 0 ? LoadingState.SUCCESS : LoadingState.ERROR;
      }
    } catch (err) {
      console.error('Load message detail failed:', err);
      this.errorMsg = '加载失败';
      this.loadingState = this.entries.length > 0 ? LoadingState.SUCCESS : LoadingState.ERROR;
    } finally {
      this.isLoadingMore = false;
      this.isRefreshing = false;
      this.refreshInFlight = false;
    }
  }

  loadMore() {
    if (!this.hasMore || this.isLoadingMore || this.loadingState !== LoadingState.SUCCESS) {
      return;
    }
    this.page++;
    this.loadMessageDetail(false);
  }

  async doRefresh() {
    if (this.refreshInFlight) {
      return;
    }
    this.refreshInFlight = true;
    this.isRefreshing = true;
    this.page = 1;
    await this.loadMessageDetail(true);
  }

  goToUserProfile(uid: string, username: string) {
    const id = uid != null ? String(uid).trim() : '';
    if (id === '' || id === '0' || !/^\d+$/.test(id)) {
      promptAction.showToast({ message: '暂无法打开资料：缺少该用户的数字 UID' });
      return;
    }
    router.pushUrl({ url: 'pages/profile/ProfilePage', params: { uid: id, name: username } });
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

  private normalizeImageUrl(url: string): string {
    const trimmed = this.decodeHtmlEntities(url).trim();
    if (trimmed === '') {
      return '';
    }
    if (/^https?:\/\//i.test(trimmed) || trimmed.indexOf('//') === 0 || trimmed.indexOf('/') === 0) {
      return this.apiHelper.normalizeImageUrl(trimmed);
    }
    return this.apiHelper.normalizeImageUrl(trimmed);
  }

  parseContentSegments(content: string): ContentSegment[] {
    if (!content) {
      return [];
    }

    const segments: ContentSegment[] = [];
    let processed = content;
    processed = processed.replace(/<br\s*\/?>/g, '\n');
    processed = processed.replace(/<a\b[^>]*href=(['"])(.*?)\1[^>]*>(.*?)<\/a>/gi, '[url=$2]$3[/url]');
    processed = processed.replace(/<(?!\/?img)[^>]+>/g, '');
    processed = this.decodeHtmlEntities(processed);
    const lowerProcessed = processed.toLowerCase();

    let pos = 0;
    let textBuf = '';

    const flushText = (): void => {
      const cleaned = this.cleanBBCode(textBuf);
      if (cleaned.trim() !== '') {
        segments.push(ContentSegment.makeText(cleaned));
      }
      textBuf = '';
    };

    while (pos < processed.length) {
      const imgStart = lowerProcessed.indexOf('[img]', pos);
      const imgStart2 = lowerProcessed.indexOf('[img=', pos);
      const urlStart = lowerProcessed.indexOf('[url]', pos);
      const urlStart2 = lowerProcessed.indexOf('[url=', pos);
      const uidStart = lowerProcessed.indexOf('[uid=', pos);
      const quoteStart = lowerProcessed.indexOf('[quote', pos);

      let nextImgPos = -1;
      let isImgWithParams = false;
      let nextUrlPos = -1;
      let isUrlWithParams = false;
      let nextUidPos = -1;
      let nextQuotePos = -1;

      if (imgStart >= 0 && imgStart2 >= 0) {
        if (imgStart <= imgStart2) {
          nextImgPos = imgStart;
          isImgWithParams = false;
        } else {
          nextImgPos = imgStart2;
          isImgWithParams = true;
        }
      } else if (imgStart >= 0) {
        nextImgPos = imgStart;
        isImgWithParams = false;
      } else if (imgStart2 >= 0) {
        nextImgPos = imgStart2;
        isImgWithParams = true;
      }

      if (urlStart >= 0 && urlStart2 >= 0) {
        if (urlStart <= urlStart2) {
          nextUrlPos = urlStart;
          isUrlWithParams = false;
        } else {
          nextUrlPos = urlStart2;
          isUrlWithParams = true;
        }
      } else if (urlStart >= 0) {
        nextUrlPos = urlStart;
        isUrlWithParams = false;
      } else if (urlStart2 >= 0) {
        nextUrlPos = urlStart2;
        isUrlWithParams = true;
      }

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
        const quoteSegments = this.parseContentSegments(quoteInner);
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

        if (imgUrl !== '') {
          flushText();
          segments.push(ContentSegment.makeImage(this.normalizeImageUrl(imgUrl)));
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
    result = result.replace(/\[quote\]/g, '「');
    result = result.replace(/\[\/quote\]/g, '」\n');
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
    result = result.replace(/\[\*\]/g, '• ');
    result = result.replace(/\[tid=[^\]]*\]/g, '');
    result = result.replace(/\[\/tid\]/g, '');
    result = result.replace(/\[pid=[^\]]*\]/g, '');
    result = result.replace(/\[\/pid\]/g, '');
    result = result.replace(/\[flash\][^\[]*\[\/flash\]/g, '[视频]');
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

  private getEntryBlocks(entry: MessageDetailEntry): ContentBlock[] {
    return this.buildContentBlocks(this.parseContentSegments(entry.content));
  }

  private getEntryImageUrls(entry: MessageDetailEntry): string[] {
    const urls: string[] = [];
    const segments = this.parseContentSegments(entry.content);
    for (let i = 0; i < segments.length; i++) {
      if (segments[i].type === 'image' && segments[i].imageUrl !== '') {
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
    router.pushUrl({
      url: 'pages/image/ImageViewerPage',
      params: {
        imageUrls: imageUrls as Object,
        currentIndex: idx as Object
      }
    });
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
  private QuoteBlock(entry: MessageDetailEntry, block: ContentBlock, blockIndex: number) {
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
        Image(block.segments[0].imageUrl)
          .width('100%')
          .objectFit(ImageFit.Contain)
          .borderRadius(BorderRadius.NORMAL)
          .backgroundColor(ThemeColors.SURFACE_LIGHT)
          .constraintSize({ maxHeight: 320 })
          .onClick(() => {
            this.openImageViewer(this.getEntryImageUrls(entry), block.segments[0].imageUrl);
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
  private RichContent(entry: MessageDetailEntry) {
    Column() {
      ForEach(this.getEntryBlocks(entry), (block: ContentBlock, blockIndex: number) => {
        if (block.isQuote) {
          this.QuoteBlock(entry, block, blockIndex)
        } else if (block.type === 'image') {
          Image(block.segments[0].imageUrl)
            .width('100%')
            .objectFit(ImageFit.Contain)
            .borderRadius(BorderRadius.NORMAL)
            .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
            .constraintSize({ maxHeight: 400 })
            .margin({ top: 8, bottom: 4 })
            .onClick(() => {
              this.openImageViewer(this.getEntryImageUrls(entry), block.segments[0].imageUrl);
            })
        } else {
          this.InlineTextBlock(block, 'body_' + blockIndex)
        }
      }, (block: ContentBlock, blockIndex: number) => block.type + '_' + blockIndex)
    }
    .width('100%')
    .margin({ top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private MessageEntryCard(entry: MessageDetailEntry) {
    Column() {
      Row() {
        AvatarView({
          url: this.avatarUrlForUid(entry.fromUid),
          avatarSize: 34,
          placeholder: this.authorInitial(entry.fromUserName)
        })
        Column() {
          Row() {
            Text(entry.fromUserName)
              .fontSize(FontSize.NORMAL)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
            Text('#' + entry.floor)
              .fontSize(FontSize.EXTRA_SMALL)
              .fontColor(ThemeColors.TEXT_HINT_LIGHT)
              .margin({ left: 8 })
          }
          Text(entry.time)
            .fontSize(FontSize.EXTRA_SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
      }
      .width('100%')
      .onClick(() => {
        this.goToUserProfile(entry.fromUid, entry.fromUserName);
      })

      if (entry.subject !== '') {
        Text(entry.subject)
          .fontSize(FontSize.NORMAL)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .margin({ top: 10 })
          .width('100%')
      }

      this.RichContent(entry)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ThemeColors.CARD_BG)
    .borderRadius(BorderRadius.MEDIUM)
    .margin({ bottom: 8 })
    .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        Text('\u{276E}')
          .fontSize(22)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(40)
          .height(48)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })

        Column() {
          Text(this.title)
            .fontSize(FontSize.MEDIUM)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.participants !== '' ? this.participants : '私信会话')
            .fontSize(FontSize.EXTRA_SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .margin({ left: 4 })

        Stack() {
          Circle()
            .width(36)
            .height(36)
            .fill(this.loadingState === LoadingState.LOADING ? ThemeColors.PRIMARY_LIGHT : ThemeColors.SEARCH_BG)

          if (this.loadingState === LoadingState.LOADING) {
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
          this.doRefresh();
        })
      }
      .width('100%')
      .height(52)
      .padding({ left: 8, right: 12 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      if (this.loadingState === LoadingState.LOADING && this.entries.length === 0) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(ThemeColors.PRIMARY)
          Text('正在加载...')
            .fontSize(FontSize.NORMAL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.ERROR && this.entries.length === 0) {
        Column() {
          Text(this.errorMsg !== '' ? this.errorMsg : '加载失败')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          Button('重试')
            .fontSize(FontSize.NORMAL)
            .fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .height(40)
            .padding({ left: 24, right: 24 })
            .margin({ top: 16 })
            .onClick(() => {
              this.loadMessageDetail(true);
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.EMPTY) {
        Column() {
          Text('暂无消息内容')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text('第 ' + this.page + ' / ' + this.totalPages + ' 页')
            .fontSize(FontSize.EXTRA_SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 2 })

          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ scroller: this.listScroller }) {
              ForEach(this.entries, (entry: MessageDetailEntry) => {
                ListItem() {
                  this.MessageEntryCard(entry)
                }
              }, (entry: MessageDetailEntry) => entry.floor + '_' + entry.time + '_' + entry.fromUid)

              if (this.hasMore) {
                ListItem() {
                  Row() {
                    if (this.isLoadingMore) {
                      LoadingProgress().width(20).height(20).color(ThemeColors.PRIMARY)
                      Text('加载中...')
                        .fontSize(FontSize.SMALL)
                        .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                        .margin({ left: 8 })
                    } else {
                      Text('上拉加载更多')
                        .fontSize(FontSize.SMALL)
                        .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                    }
                  }
                  .width('100%')
                  .height(50)
                  .justifyContent(FlexAlign.Center)
                }
              } else if (this.entries.length > 0) {
                ListItem() {
                  Text('— 已经到底了 —')
                    .fontSize(FontSize.SMALL)
                    .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding(20)
                }
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8 })
            .edgeEffect(EdgeEffect.Spring)
            .divider({ strokeWidth: 0 })
            .onReachEnd(() => {
              this.loadMore();
            })
          }
          .layoutWeight(1)
          .width('100%')
          .refreshOffset(this.REFRESH_THRESHOLD)
          .pullToRefresh(true)
          .onRefreshing(() => {
            this.doRefresh();
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }
}
