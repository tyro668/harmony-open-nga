import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';
import { Topic } from '../../model/entity/Topic';
import { Board } from '../../model/entity/Board';
import { ngaApi } from '../../network/api/NgaApi';
import { boardManager } from '../../common/manager/BoardManager';
import { LoadingState, AvatarView } from '../../ui/components/CommonComponents';
import { avatarCacheManager } from '../../common/manager/AvatarCacheManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';

@Entry
@Component
struct TopicListPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State topics: Topic[] = [];
  @State boardName: string = '帖子列表';
  @State fid: number = 0;
  @State stid: number = 0;
  @State page: number = 1;
  @State totalPages: number = 1;
  @State loadingState: LoadingState = LoadingState.LOADING;
  @State isLoadingMore: boolean = false;
  @State isRefreshing: boolean = false;
  @State hasMore: boolean = false;
  @State errorMsg: string = '';
  @State showMenu: boolean = false;
  @State isBookmarked: boolean = false;
  @State avatarUrls: Record<string, string> = {};

  private listScroller: Scroller = new Scroller();
  private readonly REFRESH_THRESHOLD: number = 80;
  private loadedTopicIds: Set<string> = new Set<string>();
  private refreshInFlight: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params != null) {
      const fidParam = params['fid'];
      if (fidParam != null) {
        this.fid = parseInt(String(fidParam));
      }
      const stidParam = params['stid'];
      if (stidParam != null) {
        this.stid = parseInt(String(stidParam));
      }
      const nameParam = params['name'];
      if (nameParam != null) {
        this.boardName = String(nameParam);
      }
    }
    this.checkBookmark();
    this.loadTopics();
  }

  async checkBookmark() {
    await boardManager.init();
    this.isBookmarked = boardManager.isBookmark(String(this.fid), String(this.stid));
  }

  async toggleBookmark() {
    await boardManager.init();
    if (this.isBookmarked) {
      await boardManager.removeBookmark(String(this.fid), String(this.stid));
      promptAction.showToast({ message: '已取消收藏' });
    } else {
      const board = new Board();
      board.id = String(this.fid);
      board.stid = String(this.stid);
      board.name = this.boardName;
      await boardManager.addBookmark(board);
      promptAction.showToast({ message: '已添加收藏' });
    }
    this.isBookmarked = boardManager.isBookmark(String(this.fid), String(this.stid));
  }

  goToSearch() {
    router.pushUrl({
      url: 'pages/search/SearchPage',
      params: { fid: this.fid, stid: this.stid, boardName: this.boardName }
    });
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

  private resetLoadedTopics() {
    this.loadedTopicIds.clear();
  }

  private topicIdentity(topic: Topic): string {
    if (topic.tid && topic.tid.length > 0) {
      return topic.tid;
    }
    return topic.subject + '_' + topic.postDate + '_' + topic.author.username;
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

  private async warmTopicAvatars(topicsToWarm: Topic[]) {
    if (topicsToWarm.length === 0) {
      return;
    }

    const context = getContext(this) as common.UIAbilityContext;
    const allowNetwork = await avatarCacheManager.isWifiConnection();
    const seen: Set<string> = new Set<string>();

    for (let i = 0; i < topicsToWarm.length; i++) {
      const uid = topicsToWarm[i].author.uid != null ? String(topicsToWarm[i].author.uid).trim() : '';
      if (!/^\d+$/.test(uid) || uid === '0' || seen.has(uid)) {
        continue;
      }
      seen.add(uid);
      const avatarUrl = await avatarCacheManager.loadAvatar(context, uid, allowNetwork, false, '', false);
      if (avatarUrl !== '') {
        this.updateAvatarUrl(uid, avatarUrl);
      }
    }
  }

  private appendUniqueTopics(incomingTopics: Topic[], refresh: boolean): number {
    const uniqueTopics: Topic[] = [];
    for (let i = 0; i < incomingTopics.length; i++) {
      const topic = incomingTopics[i];
      const topicId = this.topicIdentity(topic);
      if (this.loadedTopicIds.has(topicId)) {
        continue;
      }
      this.loadedTopicIds.add(topicId);
      uniqueTopics.push(topic);
    }

    if (refresh) {
      this.topics = uniqueTopics;
    } else {
      for (let i = 0; i < uniqueTopics.length; i++) {
        this.topics.push(uniqueTopics[i]);
      }
    }

    return uniqueTopics.length;
  }

  async loadTopics(refresh: boolean = true) {
    const hasVisibleTopics = this.topics.length > 0;
    if (refresh) {
      this.page = 1;
      if (!hasVisibleTopics) {
        this.loadingState = LoadingState.LOADING;
      }
    } else {
      this.isLoadingMore = true;
    }

    try {
      let continueLoading = true;
      while (continueLoading) {
        continueLoading = false;
        const response = await ngaApi.getTopicList(this.fid, this.page, this.stid);
        if (response.code === 200 && response.data) {
          const topicList = response.data;
          if (topicList.errorMsg) {
            this.errorMsg = topicList.errorMsg;
            if (refresh && !hasVisibleTopics) {
              this.loadingState = LoadingState.ERROR;
            } else if (refresh) {
              promptAction.showToast({ message: this.errorMsg });
            } else {
              this.page--;
            }
            return;
          }

          this.errorMsg = '';
          if (refresh) {
            this.resetLoadedTopics();
          }
          const appendedCount = this.appendUniqueTopics(topicList.topics, refresh);
          this.totalPages = topicList.totalPages;
          this.hasMore = topicList.hasMore;
          this.loadingState = this.topics.length > 0 ? LoadingState.SUCCESS : LoadingState.EMPTY;
          this.warmTopicAvatars(this.topics);

          if (!refresh && appendedCount === 0 && topicList.hasMore && this.page < topicList.totalPages) {
            this.page++;
            continueLoading = true;
          }
        } else {
          this.errorMsg = response.message || '加载失败';
          if (refresh && !hasVisibleTopics) {
            this.loadingState = LoadingState.ERROR;
          } else if (refresh) {
            promptAction.showToast({ message: this.errorMsg });
          } else {
            this.page--;
          }
          return;
        }
      }
    } catch (error) {
      console.error('Load topics failed:', error);
      this.errorMsg = '网络错误';
      if (refresh && !hasVisibleTopics) {
        this.loadingState = LoadingState.ERROR;
      } else if (refresh) {
        promptAction.showToast({ message: this.errorMsg });
      } else {
        this.page--;
      }
    } finally {
      this.isLoadingMore = false;
    }
  }

  loadMore() {
    if (this.hasMore && !this.isLoadingMore) {
      this.page++;
      this.loadTopics(false);
    }
  }

  async doRefresh() {
    if (this.refreshInFlight) {
      return;
    }
    this.refreshInFlight = true;
    this.isRefreshing = true;
    try {
      await this.loadTopics(true);
    } finally {
      this.isRefreshing = false;
      this.refreshInFlight = false;
    }
  }

  private scrollTopicListToTop() {
    if (this.topics.length === 0) {
      return;
    }
    try {
      this.listScroller.scrollEdge(Edge.Top);
    } catch (error) {
      console.error('Scroll topic list to top failed:', error);
    }
  }

  private refreshFromToolbar() {
    this.scrollTopicListToTop();
    this.doRefresh();
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('\u{276E}')
          .fontSize(22)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .borderRadius(BorderRadius.CIRCLE)
          .onClick(() => { router.back(); })

        Text(this.boardName)
          .fontSize(FontSize.LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 4 })

        Stack() {
          Circle()
            .width(36)
            .height(36)
            .fill(this.isRefreshing ? ThemeColors.PRIMARY_LIGHT : ThemeColors.SEARCH_BG)

          if (this.isRefreshing) {
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
          .width(44)
          .height(44)
          .onClick(() => { this.refreshFromToolbar(); })

        // 菜单按钮
        Text('\u22EF')
          .fontSize(20)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showMenu = !this.showMenu; })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      // 下拉菜单
      if (this.showMenu) {
        Row() {
          Blank()
          Column() {
            // 收藏选项
            Row() {
              Text(this.isBookmarked ? '\u{2605}' : '\u{2606}')
                .fontSize(18)
                .fontColor(this.isBookmarked ? '#FFD700' : ThemeColors.TEXT_PRIMARY_LIGHT)
              Text(this.isBookmarked ? '取消收藏' : '收藏板块')
                .fontSize(FontSize.NORMAL)
                .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                .margin({ left: 12 })
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.showMenu = false;
              this.toggleBookmark();
            })

            // 分割线
            Row().width('100%').height(1).backgroundColor(ThemeColors.DIVIDER_LIGHT)

            // 搜索选项
            Row() {
              Text('\u{1F50D}')
                .fontSize(18)
              Text('板块内搜索')
                .fontSize(FontSize.NORMAL)
                .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                .margin({ left: 12 })
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.showMenu = false;
              this.goToSearch();
            })
          }
          .width(160)
          .backgroundColor(ThemeColors.SURFACE_LIGHT)
          .borderRadius(BorderRadius.MEDIUM)
          .shadow({ radius: 8, color: '#0000001A', offsetX: 0, offsetY: 4 })
          .margin({ top: 4, right: 8 })
        }
        .width('100%')
      }

      // 内容区域
      if (this.loadingState === LoadingState.LOADING) {
        Column() {
          LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
          Text('正在加载...').fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.ERROR) {
        Column() {
          Text('Oops!')
            .fontSize(FontSize.EXTRA_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          Text(this.errorMsg || '加载失败')
            .fontSize(FontSize.NORMAL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
          Button('重新加载')
            .fontSize(FontSize.NORMAL)
            .fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .height(40)
            .padding({ left: 24, right: 24 })
            .margin({ top: 20 })
            .onClick(() => { this.loadTopics(); })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.EMPTY) {
        Column() {
          Text('暂无帖子')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Stack() {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ scroller: this.listScroller }) {
              ForEach(this.topics, (topic: Topic) => {
                ListItem() {
                  this.TopicCard(topic);
                }
              })

              if (this.hasMore) {
                ListItem() {
                  Row() {
                    if (this.isLoadingMore) {
                      LoadingProgress().width(20).height(20).color(ThemeColors.PRIMARY)
                      Text('加载中...').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                        .margin({ left: 8 })
                    } else {
                      Text('上拉加载更多').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                    }
                  }
                  .width('100%')
                  .height(50)
                  .justifyContent(FlexAlign.Center)
                }
              } else if (this.topics.length > 0) {
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
            .width('100%')
            .padding({ left: 16, right: 16, top: 8 })
            .edgeEffect(EdgeEffect.Spring)
            .divider({ strokeWidth: 0 })
            .onReachEnd(() => { this.loadMore(); })
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
        .alignContent(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .opacity(this.appTheme.length > 0 ? 1 : 1)
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  @Builder
  TopicCard(topic: Topic) {
    Column() {
      // 标题
      Text(topic.subject)
        .fontSize(FontSize.MEDIUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(22)
        .width('100%')

      // 底部信息
      Row() {
        Row() {
          AvatarView({
            url: this.avatarUrlForUid(topic.author.uid),
            avatarSize: 20,
            placeholder: this.authorInitial(topic.author.username)
          })
          Text(topic.author.username || '匿名')
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
            .fontFamily(ThemeColors.FONT_FAMILY_UI)
            .margin({ left: 6 })
        }

        Text(topic.getFormattedTime())
          .fontSize(FontSize.EXTRA_SMALL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .margin({ left: 12 })

        Blank()

        Row() {
          Text('\u{1F4AC}')
            .fontSize(11)
          Text('' + topic.replies)
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ left: 3 })
        }
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
    .onClick(() => {
      router.pushUrl({
        url: 'pages/article/ArticleListPage',
        params: { tid: topic.tid, title: topic.subject }
      });
    })
  }
}
