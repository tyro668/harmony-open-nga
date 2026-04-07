import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';
import { userManager } from '../../common/manager/UserManager';
import { boardManager } from '../../common/manager/BoardManager';
import { User } from '../../model/entity/User';
import { BoardCategory, Board } from '../../model/entity/Board';
import { Topic } from '../../model/entity/Topic';
import { MessageThread } from '../../model/entity/Message';
import { ngaApi } from '../../network/api/NgaApi';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { AppConstants } from '../../common/constants/AppConstants';
import { LoadingState } from '../../ui/components/CommonComponents';
import { LogUtils } from '../../common/utils/LogUtils';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct MainPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();
  @State initialized: boolean = false;
  @State user: User | null = null;
  @State boardCategories: BoardCategory[] = [];
  /** 版块页顶栏 6 段分类（不含「我的收藏」） */
  @State boardSectionCategories: BoardCategory[] = [];
  @State bookmarkBoards: Board[] = [];
  @State boardTopTabIndex: number = 0;
  @State topics: Topic[] = [];
  @State currentFid: number = -447601;
  @State page: number = 1;
  @State isLoading: boolean = false;
  @State loadError: string = '';
  @State messageThreads: MessageThread[] = [];
  @State messagePage: number = 1;
  @State messageTotalPages: number = 1;
  @State messageLoadingState: LoadingState = LoadingState.LOADING;
  @State isMessageLoadingMore: boolean = false;
  @State isMessageRefreshing: boolean = false;
  @State hasMoreMessages: boolean = false;
  @State messageError: string = '';
  private messageListScroller: Scroller = new Scroller();
  private readonly MESSAGE_REFRESH_THRESHOLD: number = 80;
  private messageRefreshInFlight: boolean = false;

  aboutToAppear() {
    this.initData();
  }

  onPageShow() {
    this.user = userManager.getCurrentUser();
    this.bookmarkBoards = boardManager.getBookmarks();
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

  async initData() {
    this.user = userManager.getCurrentUser();
    userManager.setOnUserChanged((user: User | null) => {
      this.user = user;
      if (user == null || !user.isLoggedIn()) {
        this.resetMessageThreads();
      } else if (this.currentIndex === 2 || this.messageThreads.length === 0) {
        this.ensureMessageThreadsLoaded(true);
      }
    });

    // 加载启动页面设置
    try {
      const startPage = await PreferencesManager.getInstance().getString(AppConstants.PREF_START_PAGE, '0');
      const idx = parseInt(startPage);
      if (!isNaN(idx) && idx >= 0 && idx <= 3) {
        this.currentIndex = idx;
        // 使用 controller 切换 Tab
        if (idx > 0) {
          setTimeout(() => {
            this.tabsController.changeIndex(idx);
          }, 100);
        }
      }
    } catch (e) {
      console.error('Load start page failed:', e);
    }

    this.initialized = true;
    await this.loadBoards();
    await this.loadTopics();
    if (this.currentIndex === 2 && this.user != null && this.user.isLoggedIn()) {
      this.ensureMessageThreadsLoaded(true);
    }
  }

  async loadBoards() {
    try {
      await boardManager.init();
      this.bookmarkBoards = boardManager.getBookmarks();
      this.boardSectionCategories = ngaApi.getMainBoardTabSections();
      const response = await ngaApi.getForumList();
      if (response.code === 200 && response.data != null) {
        this.boardCategories = response.data;
      }
    } catch (err) {
      console.error('Load boards failed:', err);
      this.boardSectionCategories = ngaApi.getMainBoardTabSections();
    }
  }

  private boardEntryEmoji(board: Board): string {
    const fid = board.id;
    if (fid === '-7') {
      return '\u{1F37A}';
    }
    if (fid === '7') {
      return '\u{1F3DB}';
    }
    if (fid === '321') {
      return '\u{1F3AE}';
    }
    if (fid === '-447601') {
      return '\u{1F5FA}';
    }
    if (fid === '-152678' || fid === '708') {
      return '\u{1F3AF}';
    }
    if (fid === '459' || fid === '422') {
      return '\u{1F525}';
    }
    return '\u{1F4C4}';
  }

  /** 版块网格行号 0..n-1，每行最多 3 个，严格从左到右、从上到下 */
  private boardGridRowIndexes(boardCount: number): number[] {
    const rows = boardCount <= 0 ? 0 : Math.ceil(boardCount / 3);
    const out: number[] = [];
    for (let i = 0; i < rows; i++) {
      out.push(i);
    }
    return out;
  }

  private boardSlotIndexesForRow(boardCount: number, rowIndex: number): number[] {
    const start = rowIndex * 3;
    const out: number[] = [];
    for (let c = 0; c < 3; c++) {
      const idx = start + c;
      if (idx < boardCount) {
        out.push(idx);
      }
    }
    return out;
  }

  async loadTopics() {
    this.isLoading = true;
    this.loadError = '';
    try {
      const response = await ngaApi.getTopicList(this.currentFid, this.page);
      if (response.code === 200 && response.data != null) {
        if (response.data.errorMsg) {
          this.loadError = response.data.errorMsg;
          this.topics = [];
        } else {
          this.topics = response.data.topics;
        }
      }
    } catch (err) {
      console.error('Load topics failed:', err);
      this.loadError = '加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private resetMessageThreads() {
    this.messageThreads = [];
    this.messagePage = 1;
    this.messageTotalPages = 1;
    this.messageLoadingState = LoadingState.LOADING;
    this.isMessageLoadingMore = false;
    this.isMessageRefreshing = false;
    this.hasMoreMessages = false;
    this.messageError = '';
    this.messageRefreshInFlight = false;
  }

  private messageAuthorName(thread: MessageThread): string {
    const fromUser = thread.fromUserName != null ? thread.fromUserName.trim() : '';
    if (fromUser !== '') {
      return fromUser;
    }
    return '#SYSTEM#';
  }

  private messageLastAuthorName(thread: MessageThread): string {
    const lastUser = thread.lastFromUserName != null ? thread.lastFromUserName.trim() : '';
    if (lastUser !== '') {
      return lastUser;
    }
    return this.messageAuthorName(thread);
  }

  private ensureMessageThreadsLoaded(force: boolean = false) {
    if (this.user == null || !this.user.isLoggedIn()) {
      this.messageLoadingState = LoadingState.EMPTY;
      return;
    }
    if (force || this.messageThreads.length === 0) {
      this.loadMessageThreads(true);
    }
  }

  async loadMessageThreads(refresh: boolean = true) {
    if (this.user == null || !this.user.isLoggedIn()) {
      this.messageLoadingState = LoadingState.EMPTY;
      return;
    }

    const hasVisibleThreads = this.messageThreads.length > 0;
    if (refresh) {
      this.messagePage = 1;
      if (!hasVisibleThreads) {
        this.messageLoadingState = LoadingState.LOADING;
      }
    } else {
      this.isMessageLoadingMore = true;
    }

    try {
      LogUtils.i('MainPage', 'loadMessageThreads start, refresh=' + refresh + ', page=' + this.messagePage);
      const response = await ngaApi.getMessageThreadList(this.messagePage);
      LogUtils.i(
        'MainPage',
        'loadMessageThreads response code=' + response.code +
        ', message=' + response.message +
        ', hasData=' + String(response.data != null)
      );
      if (response.code === 200 && response.data != null) {
        const threadList = response.data;
        if (threadList.errorMsg !== '') {
          LogUtils.w(
            'MainPage',
            'loadMessageThreads data error, page=' + this.messagePage + ', errorMsg=' + threadList.errorMsg
          );
          this.messageError = threadList.errorMsg;
          if (refresh && !hasVisibleThreads) {
            this.messageLoadingState = LoadingState.ERROR;
          } else if (refresh) {
            promptAction.showToast({ message: this.messageError, duration: 1500 });
          } else {
            this.messagePage--;
          }
          return;
        }

        this.messageError = '';
        LogUtils.i(
          'MainPage',
          'loadMessageThreads success, page=' + threadList.page +
          ', threads=' + threadList.threads.length +
          ', hasMore=' + threadList.hasMore
        );
        if (refresh) {
          this.messageThreads = threadList.threads;
        } else {
          for (let i = 0; i < threadList.threads.length; i++) {
            this.messageThreads.push(threadList.threads[i]);
          }
        }
        this.messageTotalPages = threadList.totalPages;
        this.hasMoreMessages = threadList.hasMore;
        this.messageLoadingState = this.messageThreads.length > 0 ? LoadingState.SUCCESS : LoadingState.EMPTY;
      } else {
        LogUtils.e(
          'MainPage',
          'loadMessageThreads failed response, page=' + this.messagePage + ', message=' + response.message
        );
        this.messageError = response.message || '加载失败';
        if (refresh && !hasVisibleThreads) {
          this.messageLoadingState = LoadingState.ERROR;
        } else if (refresh) {
          promptAction.showToast({ message: this.messageError, duration: 1500 });
        } else {
          this.messagePage--;
        }
      }
    } catch (err) {
      LogUtils.e('MainPage', 'loadMessageThreads exception=' + JSON.stringify(err));
      this.messageError = '加载失败';
      if (refresh && !hasVisibleThreads) {
        this.messageLoadingState = LoadingState.ERROR;
      } else if (refresh) {
        promptAction.showToast({ message: this.messageError, duration: 1500 });
      } else {
        this.messagePage--;
      }
    } finally {
      this.isMessageLoadingMore = false;
      this.isMessageRefreshing = false;
      this.messageRefreshInFlight = false;
    }
  }

  loadMoreMessageThreads() {
    if (!this.hasMoreMessages || this.isMessageLoadingMore || this.messageLoadingState !== LoadingState.SUCCESS) {
      return;
    }
    this.messagePage++;
    this.loadMessageThreads(false);
  }

  async doMessageRefresh() {
    if (this.messageRefreshInFlight) {
      return;
    }
    this.messageRefreshInFlight = true;
    this.isMessageRefreshing = true;
    this.messagePage = 1;
    await this.loadMessageThreads(true);
  }

  openMessageThread(thread: MessageThread) {
    router.pushUrl({
      url: 'pages/message/MessageDetailPage',
      params: { mid: thread.mid, title: thread.subject }
    });
  }

  @Builder
  TabIcon(icon: string, label: string, index: number) {
    Column() {
      Text(icon)
        .fontSize(22)
        .fontColor(this.currentIndex === index ? ThemeColors.PRIMARY : ThemeColors.ICON_INACTIVE)
      Text(label)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? ThemeColors.PRIMARY : ThemeColors.ICON_INACTIVE)
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Tabs({ controller: this.tabsController }) {
        TabContent() {
          this.HomeContent();
        }.tabBar(this.TabIcon('\u{1F3E0}', '首页', 0))

        TabContent() {
          this.BoardContent();
        }.tabBar(this.TabIcon('\u{1F4CB}', '版块', 1))

        TabContent() {
          this.MessageContent();
        }.tabBar(this.TabIcon('\u{1F4AC}', '消息', 2))

        TabContent() {
          this.ProfileContent();
        }.tabBar(this.TabIcon('\u{1F464}', '我的', 3))
      }
      .layoutWeight(1)
      .barMode(BarMode.Fixed)
      .barPosition(BarPosition.End)
      .barHeight(56)
      .barBackgroundColor(ThemeColors.SURFACE_LIGHT)
      .onChange((index: number) => {
        this.currentIndex = index;
        if (index === 2) {
          this.ensureMessageThreadsLoaded();
        }
      })
    }
    .width('100%')
    .height('100%')
    .opacity(this.appTheme.length > 0 ? 1 : 1)
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  // ==================== 首页 ====================
  @Builder
  HomeContent() {
    Column() {
      // 顶部栏
      Row() {
        Text('NGA')
          .fontSize(FontSize.LARGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.PRIMARY)

        Blank().layoutWeight(1)

        // 搜索按钮
        Stack() {
          Circle()
            .width(36)
            .height(36)
            .fill(ThemeColors.SEARCH_BG)
          Text('\u{1F50D}')
            .fontSize(16)
        }
        .margin({ right: 12 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/search/SearchPage' });
        })

        // 用户头像/登录
        if (this.user != null && this.user.isLoggedIn()) {
          Stack() {
            Circle()
              .width(36)
              .height(36)
              .fill(ThemeColors.PRIMARY_LIGHT)
            Text(this.user.getDisplayName().substring(0, 1))
              .fontSize(FontSize.MEDIUM)
              .fontColor(ThemeColors.PRIMARY)
              .fontWeight(FontWeight.Bold)
          }
          .onClick(() => {
            this.currentIndex = 3;
          })
        } else {
          Text('登录')
            .fontSize(FontSize.NORMAL)
            .fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/login/LoginPage' });
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 20 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      // 快捷功能区
      Row() {
        this.QuickEntry('\u{270F}\u{FE0F}', '发帖', () => {
          router.pushUrl({ url: 'pages/post/PostPage', params: { fid: this.currentFid } });
        })
        this.QuickEntry('\u{2B50}', '收藏', () => {
          router.pushUrl({ url: 'pages/favorite/FavoritePage' });
        })
        this.QuickEntry('\u{1F4D6}', '历史', () => {
          router.pushUrl({ url: 'pages/history/HistoryPage' });
        })
        this.QuickEntry('\u{1F514}', '通知', () => {
          router.pushUrl({ url: 'pages/notification/NotificationPage' });
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 4 })
      .justifyContent(FlexAlign.SpaceEvenly)

      // 帖子列表标题
      Row() {
        Text('推荐')
          .fontSize(FontSize.LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)

        Blank()

        if (this.isLoading) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(ThemeColors.PRIMARY)
        } else {
          Text('刷新')
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.PRIMARY)
            .onClick(() => {
              this.loadTopics();
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 8 })

      // 帖子列表
      if (this.topics.length > 0) {
        List() {
          ForEach(this.topics, (topic: Topic) => {
            ListItem() {
              this.TopicCard(topic);
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .edgeEffect(EdgeEffect.Spring)
        .listDirection(Axis.Vertical)
        .divider({ strokeWidth: 0 })
      } else {
        Column() {
          if (this.isLoading) {
            LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
            Text('正在加载...').fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
              .margin({ top: 12 })
          } else if (this.loadError) {
            Text(this.loadError)
              .fontSize(FontSize.NORMAL)
              .fontColor(ThemeColors.ERROR)
            Button('重新加载')
              .fontSize(FontSize.NORMAL)
              .fontColor('#FFFFFF')
              .backgroundColor(ThemeColors.PRIMARY)
              .borderRadius(BorderRadius.EXTRA_LARGE)
              .height(40)
              .padding({ left: 24, right: 24 })
              .margin({ top: 16 })
              .onClick(() => { this.loadTopics(); })
          } else {
            Text('暂无数据').fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
          }
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
  TopicCard(topic: Topic) {
    Column() {
      // 作者信息
      Row() {
        Stack() {
          Circle()
            .width(32)
            .height(32)
            .fill(ThemeColors.PRIMARY_LIGHT)
          Text(this.authorInitial(topic.author.username))
            .fontSize(13)
            .fontColor(ThemeColors.PRIMARY)
            .fontWeight(FontWeight.Bold)
            .fontFamily(ThemeColors.FONT_FAMILY_UI)
        }

        Text(topic.author.username || '匿名')
          .fontSize(FontSize.SMALL)
          .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
          .fontFamily(ThemeColors.FONT_FAMILY_UI)
          .margin({ left: 8 })

        Blank()

        Text(topic.getFormattedTime())
          .fontSize(FontSize.EXTRA_SMALL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
      }
      .width('100%')

      // 标题
      Text(topic.subject)
        .fontSize(FontSize.MEDIUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(22)
        .margin({ top: 10 })
        .width('100%')

      // 底部信息
      Row() {
        Row() {
          Text('\u{1F4AC}')
            .fontSize(12)
          Text('' + topic.replies)
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ left: 4 })
        }

        if (topic.lastPoster) {
          Text('最后回复: ' + topic.lastPoster)
            .fontSize(FontSize.EXTRA_SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 16 })
            .constraintSize({ maxWidth: 160 })
        }
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ThemeColors.CARD_BG)
    .borderRadius(BorderRadius.MEDIUM)
    .margin({ bottom: 10 })
    .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/article/ArticleListPage',
        params: { tid: topic.tid, title: topic.subject }
      });
    })
  }

  @Builder
  QuickEntry(icon: string, label: string, onClick: () => void) {
    Column() {
      Stack() {
        Circle()
          .width(48)
          .height(48)
          .fill(ThemeColors.PRIMARY_LIGHT)
        Text(icon)
          .fontSize(20)
      }
      Text(label)
        .fontSize(FontSize.EXTRA_SMALL)
        .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
        .margin({ top: 6 })
    }
    .onClick(onClick)
  }

  // ==================== 版块 ====================
  @Builder
  BoardTopTabBar(index: number, title: string) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontColor(this.boardTopTabIndex === index ? ThemeColors.PRIMARY : ThemeColors.ICON_INACTIVE)
        .fontFamily(ThemeColors.FONT_FAMILY_UI)
        .fontWeight(this.boardTopTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
      Row()
        .width(28)
        .height(3)
        .backgroundColor(ThemeColors.PRIMARY)
        .margin({ top: 6 })
        .visibility(this.boardTopTabIndex === index ? Visibility.Visible : Visibility.Hidden)
    }
    .padding({ left: 10, right: 10, top: 10, bottom: 8 })
    .justifyContent(FlexAlign.Center)
  }

  /** 版块页内层分类：横向滚动 + 点击切换，避免 Tabs/TabContent 将内容垂直居中 */
  @Builder
  BoardSectionTabBar() {
    Scroll() {
      Row() {
        Column() {
          this.BoardTopTabBar(0, '\u6211\u7684\u6536\u85cf');
        }
        .onClick(() => {
          this.boardTopTabIndex = 0;
        })

        Column() {
          this.BoardTopTabBar(1, '\u95f2\u4e8b\u6742\u8c08');
        }
        .onClick(() => {
          this.boardTopTabIndex = 1;
        })

        Column() {
          this.BoardTopTabBar(2, '\u62f3\u5934\u6e38\u620f');
        }
        .onClick(() => {
          this.boardTopTabIndex = 2;
        })

        Column() {
          this.BoardTopTabBar(3, '\u66b4\u96ea\u6e38\u620f');
        }
        .onClick(() => {
          this.boardTopTabIndex = 3;
        })

        Column() {
          this.BoardTopTabBar(4, '\u9b54\u517d\u4e16\u754c');
        }
        .onClick(() => {
          this.boardTopTabIndex = 4;
        })

        Column() {
          this.BoardTopTabBar(5, '\u6e38\u620f\u4e13\u7248');
        }
        .onClick(() => {
          this.boardTopTabIndex = 5;
        })

        Column() {
          this.BoardTopTabBar(6, '\u56fd\u5bb6\u4ff1\u4e50\u90e8');
        }
        .onClick(() => {
          this.boardTopTabIndex = 6;
        })
      }
      .padding({ left: 4, right: 4 })
      .alignItems(VerticalAlign.Center)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(48)
    .backgroundColor(ThemeColors.SURFACE_LIGHT)
  }

  @Builder
  BoardGridItem(board: Board) {
    Column() {
      Stack() {
        Circle().width(56).height(56).fill(ThemeColors.PRIMARY_LIGHT)
        Text(this.boardEntryEmoji(board))
          .fontSize(28)
      }
      Text(board.name)
        .fontSize(FontSize.EXTRA_SMALL)
        .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
        .fontFamily(ThemeColors.FONT_FAMILY_UI)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 4 })
    .onClick(() => {
      const p: Record<string, Object> = {
        'fid': board.id,
        'stid': board.stid,
        'name': board.name
      };
      router.pushUrl({ url: 'pages/topic/TopicListPage', params: p });
    })
  }

  @Builder
  BoardTabPanel(boards: Board[]) {
    if (boards.length === 0) {
      Column() {
        Text('\u{1F4C4}')
          .fontSize(40)
        Text('\u6682\u65e0\u677f\u5757')
          .fontSize(FontSize.MEDIUM)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .margin({ top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 40 })
    } else {
      Scroll() {
        Column() {
          ForEach(this.boardGridRowIndexes(boards.length), (rowIndex: number) => {
            Row() {
              ForEach(this.boardSlotIndexesForRow(boards.length, rowIndex), (boardIndex: number) => {
                Column() {
                  this.BoardGridItem(boards[boardIndex])
                }
                .width('33.33%')
              }, (boardIndex: number) => {
                const board = boards[boardIndex];
                // 直接使用属性而不是方法调用，避免 JSON 解析后的对象没有方法
                const key = board != null && board.id != null ? `${board.id}_${board.stid}` : `${boardIndex}`;
                return `${rowIndex}_${key}`;
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .margin({ bottom: 12 })
          }, (rowIndex: number) => `board_row_${rowIndex}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 28 })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
    }
  }

  @Builder
  BoardTabPanelSection(sectionIndex: number) {
    if (sectionIndex >= 0 && sectionIndex < this.boardSectionCategories.length) {
      this.BoardTabPanel(this.boardSectionCategories[sectionIndex].boards);
    } else {
      Column() {
        Text('\u52a0\u8f7d\u4e2d\u2026')
          .fontSize(FontSize.SMALL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, top: 24 })
    }
  }

  @Builder
  BoardFavoritesPanel() {
    if (this.bookmarkBoards.length === 0) {
      Column() {
        Text('\u{2B50}')
          .fontSize(44)
        Text('\u6682\u65e0\u6536\u85cf\u677f\u5757')
          .fontSize(FontSize.MEDIUM)
          .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
          .margin({ top: 16 })
          .fontFamily(ThemeColors.FONT_FAMILY_UI)
        Text('\u5728\u300c\u5168\u90e8\u677f\u5757\u300d\u4e2d\u70b9\u661f\u6807\u6dfb\u52a0')
          .fontSize(FontSize.SMALL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .margin({ top: 8 })
          .fontFamily(ThemeColors.FONT_FAMILY_UI)
        Button('\u53bb\u5168\u90e8\u677f\u5757')
          .fontSize(FontSize.NORMAL)
          .fontColor('#FFFFFF')
          .backgroundColor(ThemeColors.PRIMARY)
          .borderRadius(0)
          .height(40)
          .padding({ left: 28, right: 28 })
          .margin({ top: 20 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/board/BoardListPage' });
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 40 })
    } else {
      this.BoardTabPanel(this.bookmarkBoards);
    }
  }

  @Builder
  BoardContent() {
    Column() {
      Row() {
        Text('\u677f\u5757')
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .fontFamily(ThemeColors.FONT_FAMILY_UI)
        Blank().layoutWeight(1)
        Text('\u5168\u90e8\u677f\u5757')
          .fontSize(FontSize.SMALL)
          .fontColor(ThemeColors.PRIMARY)
          .fontFamily(ThemeColors.FONT_FAMILY_UI)
          .onClick(() => {
            router.pushUrl({ url: 'pages/board/BoardListPage' });
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 20, right: 20 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      Column() {
        this.BoardSectionTabBar();
        // 用 ForEach + 随 tab 变化的 key 强制重建内容区，避免 @Builder 子树在切换时不刷新
        Column() {
          ForEach([this.boardTopTabIndex], (activeTab: number) => {
            if (activeTab === 0) {
              this.BoardFavoritesPanel();
            } else {
              this.BoardTabPanelSection(activeTab - 1);
            }
          }, (activeTab: number) => `board_section_${activeTab}`)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  // ==================== 消息 ====================
  @Builder
  MessageContent() {
    Column() {
      Row() {
        Text('消息')
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
        Blank()
        Text('通知')
          .fontSize(FontSize.NORMAL)
          .fontColor(ThemeColors.PRIMARY)
          .onClick(() => {
            router.pushUrl({ url: 'pages/notification/NotificationPage' });
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 20 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      if (this.user == null || !this.user.isLoggedIn()) {
        Column() {
          Stack() {
            Circle().width(80).height(80).fill(ThemeColors.PRIMARY_LIGHT)
            Text('\u{1F4AC}').fontSize(36)
          }
          Text('登录后查看消息')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
            .margin({ top: 16 })
          Button('去登录')
            .fontSize(FontSize.NORMAL)
            .fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .height(40)
            .padding({ left: 32, right: 32 })
            .margin({ top: 20 })
            .onClick(() => { router.pushUrl({ url: 'pages/login/LoginPage' }); })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        if (this.messageLoadingState === LoadingState.LOADING && this.messageThreads.length === 0) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(ThemeColors.PRIMARY)
            Text('正在加载消息...')
              .fontSize(FontSize.NORMAL)
              .fontColor(ThemeColors.TEXT_HINT_LIGHT)
              .margin({ top: 12 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.messageLoadingState === LoadingState.ERROR && this.messageThreads.length === 0) {
          Column() {
            Text(this.messageError !== '' ? this.messageError : '消息加载失败')
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
                this.loadMessageThreads(true);
              })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.messageLoadingState === LoadingState.EMPTY) {
          Column() {
            Text('暂无消息')
              .fontSize(FontSize.MEDIUM)
              .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Column() {
            Text('第 ' + this.messagePage + ' / ' + this.messageTotalPages + ' 页')
              .fontSize(FontSize.EXTRA_SMALL)
              .fontColor(ThemeColors.TEXT_HINT_LIGHT)
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 2 })

            Refresh({ refreshing: $$this.isMessageRefreshing }) {
              List({ scroller: this.messageListScroller }) {
                ForEach(this.messageThreads, (thread: MessageThread) => {
                  ListItem() {
                    Column() {
                      Text(thread.subject !== '' ? thread.subject : '(无标题消息)')
                        .fontSize(FontSize.MEDIUM)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .lineHeight(22)
                        .width('100%')

                      Row() {
                        Row() {
                          Stack() {
                            Circle().width(26).height(26).fill(ThemeColors.PRIMARY_LIGHT)
                            Text(this.authorInitial(this.messageAuthorName(thread)))
                              .fontSize(12)
                              .fontColor(ThemeColors.PRIMARY)
                              .fontWeight(FontWeight.Bold)
                          }
                          Column() {
                            Text(this.messageAuthorName(thread))
                              .fontSize(FontSize.SMALL)
                              .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
                            if (thread.time !== '') {
                              Text(thread.time)
                                .fontSize(FontSize.EXTRA_SMALL)
                                .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                                .margin({ top: 2 })
                            }
                          }
                          .alignItems(HorizontalAlign.Start)
                          .margin({ left: 8 })
                        }

                        Blank()

                        Column() {
                          Text(this.messageLastAuthorName(thread))
                            .fontSize(FontSize.SMALL)
                            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
                          Text((thread.posts > 0 ? String(thread.posts) + ' 条 · ' : '') +
                            (thread.lastTime !== '' ? thread.lastTime : ''))
                            .fontSize(FontSize.EXTRA_SMALL)
                            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                            .margin({ top: 2 })
                        }
                        .alignItems(HorizontalAlign.End)
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
                    .onClick(() => {
                      this.openMessageThread(thread);
                    })
                  }
                }, (thread: MessageThread) => thread.mid)

                if (this.hasMoreMessages) {
                  ListItem() {
                    Row() {
                      if (this.isMessageLoadingMore) {
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
                } else if (this.messageThreads.length > 0) {
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
                this.loadMoreMessageThreads();
              })
            }
            .layoutWeight(1)
            .width('100%')
            .refreshOffset(this.MESSAGE_REFRESH_THRESHOLD)
            .pullToRefresh(true)
            .onRefreshing(() => {
              this.doMessageRefresh();
            })
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  // ==================== 我的 ====================
  @Builder
  ProfileContent() {
    Column() {
      if (this.user == null || !this.user.isLoggedIn()) {
        // 未登录
        Column() {
          Stack() {
            Circle().width(100).height(100).fill(ThemeColors.PRIMARY_LIGHT)
            Text('\u{1F464}').fontSize(44)
          }
          Text('登录发现更多精彩')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
            .margin({ top: 20 })
          Button('登录 / 注册')
            .fontSize(FontSize.MEDIUM)
            .fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .width(200)
            .height(44)
            .margin({ top: 24 })
            .onClick(() => { router.pushUrl({ url: 'pages/login/LoginPage' }); })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
      } else {
        Scroll() {
          Column() {
            // 用户信息头部卡片
            Column() {
              Row() {
                Stack() {
                  Circle().width(60).height(60).fill(ThemeColors.PRIMARY_LIGHT)
                  Text(this.user.getDisplayName().substring(0, 1))
                    .fontSize(FontSize.LARGE_TITLE)
                    .fontColor(ThemeColors.PRIMARY)
                    .fontWeight(FontWeight.Bold)
                }

                Column() {
                  Text(this.user.getDisplayName())
                    .fontSize(FontSize.EXTRA_LARGE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)

                  Text('UID: ' + this.user.uid)
                    .fontSize(FontSize.SMALL)
                    .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 16 })

                Text('\u{276F}')
                  .fontSize(FontSize.LARGE)
                  .fontColor(ThemeColors.TEXT_HINT_LIGHT)
              }
              .width('100%')
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 24, bottom: 24 })
            .backgroundColor(ThemeColors.SURFACE_LIGHT)
            .onClick(() => {
              router.pushUrl({ url: 'pages/profile/ProfilePage', params: { uid: this.user?.uid } });
            })

            // 功能区
            Column() {
              this.ProfileMenuItem('\u{1F464}', '个人资料', () => {
                router.pushUrl({ url: 'pages/profile/ProfilePage', params: { uid: this.user?.uid } });
              })
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.ProfileMenuItem('\u{2B50}', '我的收藏', () => {
                router.pushUrl({ url: 'pages/favorite/FavoritePage' });
              })
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.ProfileMenuItem('\u{1F4D6}', '浏览历史', () => {
                router.pushUrl({ url: 'pages/history/HistoryPage' });
              })
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.ProfileMenuItem('\u{1F514}', '通知', () => {
                router.pushUrl({ url: 'pages/notification/NotificationPage' });
              })
            }
            .width('100%')
            .backgroundColor(ThemeColors.CARD_BG)
            .borderRadius(BorderRadius.MEDIUM)
            .margin({ left: 16, right: 16, top: 12 })
            .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

            Column() {
              this.ProfileMenuItem('\u{2699}\u{FE0F}', '设置', () => {
                router.pushUrl({ url: 'pages/settings/SettingsPage' });
              })
            }
            .width('100%')
            .backgroundColor(ThemeColors.CARD_BG)
            .borderRadius(BorderRadius.MEDIUM)
            .margin({ left: 16, right: 16, top: 12 })
            .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

            Blank().height(30)
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ProfileMenuItem(icon: string, text: string, onClick: () => void) {
    Row() {
      Text(icon)
        .fontSize(20)
        .width(32)
        .textAlign(TextAlign.Center)

      Text(text)
        .fontSize(FontSize.MEDIUM)
        .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
        .margin({ left: 12 })

      Blank()

      Text('\u{276F}')
        .fontSize(FontSize.NORMAL)
        .fontColor(ThemeColors.TEXT_HINT_LIGHT)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(onClick)
  }
}
