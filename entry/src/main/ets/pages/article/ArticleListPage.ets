import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';
import { Article, Attachment } from '../../model/entity/Article';
import { ngaApi } from '../../network/api/NgaApi';
import { NgaApi } from '../../network/api/NgaApi';
import router from '@ohos.router';

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
    if (this.tid != '') {
      this.loadArticles();
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
          Text('\u6682\u65E0\u5185\u5BB9').fontSize(FontSize.MEDIUM).fontColor(ThemeColors.TEXT_HINT_LIGHT)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
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
        Stack() {
          Circle().width(36).height(36).fill(ThemeColors.PRIMARY_LIGHT)
          Text((article.author.username || '?').substring(0, 1))
            .fontSize(14)
            .fontColor(ThemeColors.PRIMARY)
            .fontWeight(FontWeight.Bold)
        }

        Column() {
          Row() {
            Text(article.author.username || '\u533F\u540D')
              .fontSize(FontSize.NORMAL)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)

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
          } else {
            Text(seg.text)
              .fontSize(FontSize.NORMAL)
              .fontColor(seg.isQuote ? ThemeColors.TEXT_SECONDARY_LIGHT : ThemeColors.TEXT_PRIMARY_LIGHT)
              .lineHeight(22)
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
