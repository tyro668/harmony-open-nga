import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';
import { userManager } from '../../common/manager/UserManager';
import { User } from '../../model/entity/User';
import { BoardCategory, Board } from '../../model/entity/Board';
import { Topic } from '../../model/entity/Topic';
import { ngaApi } from '../../network/api/NgaApi';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { AppConstants } from '../../common/constants/AppConstants';
import router from '@ohos.router';

@Entry
@Component
struct MainPage {
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();
  @State initialized: boolean = false;
  @State user: User | null = null;
  @State boardCategories: BoardCategory[] = [];
  @State topics: Topic[] = [];
  @State currentFid: number = -447601;
  @State page: number = 1;
  @State isLoading: boolean = false;
  @State loadError: string = '';

  aboutToAppear() {
    this.initData();
  }

  onPageShow() {
    this.user = userManager.getCurrentUser();
  }

  async initData() {
    this.user = userManager.getCurrentUser();
    userManager.setOnUserChanged((user: User | null) => {
      this.user = user;
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
  }

  async loadBoards() {
    try {
      const response = await ngaApi.getForumList();
      if (response.code === 200 && response.data != null) {
        this.boardCategories = response.data;
      }
    } catch (err) {
      console.error('Load boards failed:', err);
    }
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
      })
    }
    .width('100%')
    .height('100%')
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
          Text((topic.author.username || '?').substring(0, 1))
            .fontSize(13)
            .fontColor(ThemeColors.PRIMARY)
            .fontWeight(FontWeight.Bold)
        }

        Text(topic.author.username || '匿名')
          .fontSize(FontSize.SMALL)
          .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
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
  BoardContent() {
    Column() {
      // 顶部标题
      Row() {
        Text('版块')
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 20 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      Scroll() {
        Column() {
          // 快捷入口卡片
          Row() {
            Column() {
              Stack() {
                Circle().width(44).height(44).fill('#EEF2FF')
                Text('\u{1F4CB}').fontSize(20)
              }
              Text('全部版块')
                .fontSize(FontSize.SMALL)
                .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
                .margin({ top: 6 })
            }
            .layoutWeight(1)
            .onClick(() => { router.pushUrl({ url: 'pages/board/BoardListPage' }); })

            Column() {
              Stack() {
                Circle().width(44).height(44).fill('#FFF7ED')
                Text('\u{2B50}').fontSize(20)
              }
              Text('收藏版块')
                .fontSize(FontSize.SMALL)
                .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
                .margin({ top: 6 })
            }
            .layoutWeight(1)
            .onClick(() => { router.pushUrl({ url: 'pages/board/BoardListPage' }); })
          }
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .backgroundColor(ThemeColors.CARD_BG)
          .borderRadius(BorderRadius.MEDIUM)
          .margin({ left: 16, right: 16, top: 12 })
          .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

          // 版块分类列表
          ForEach(this.boardCategories, (category: BoardCategory) => {
            Column() {
              // 分类标题
              Row() {
                Rect().width(3).height(16).fill(ThemeColors.PRIMARY).borderRadius(2)
                Text(category.name)
                  .fontSize(FontSize.MEDIUM)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                  .margin({ left: 8 })
              }
              .width('100%')
              .padding({ left: 20, top: 20, bottom: 10 })

              // 版块列表（网格形式）
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(category.boards, (board: Board) => {
                  Text(board.name)
                    .fontSize(FontSize.NORMAL)
                    .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                    .backgroundColor(ThemeColors.CARD_BG)
                    .borderRadius(BorderRadius.NORMAL)
                    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .margin({ left: 8, bottom: 8 })
                    .shadow({ radius: 2, color: '#00000008', offsetX: 0, offsetY: 1 })
                    .onClick(() => {
                      router.pushUrl({
                        url: 'pages/topic/TopicListPage',
                        params: { fid: board.id, stid: board.stid, name: board.name }
                      });
                    })
                })
              }
              .width('100%')
              .padding({ left: 12, right: 16 })
            }
          })

          Blank().height(20)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  // ==================== 消息 ====================
  @Builder
  MessageContent() {
    Column() {
      // 顶部标题
      Row() {
        Text('消息')
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
      }
      .width('100%')
      .height(56)
      .padding({ left: 20 })
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
        Column() {
          Text('暂无新消息')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
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
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.ProfileMenuItem('\u{1F6AA}', '退出登录', () => {
                userManager.logout();
                this.user = null;
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
