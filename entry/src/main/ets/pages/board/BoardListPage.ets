import router from '@ohos.router';
import { Board, BoardCategory } from '../../model/entity/Board';
import { boardManager } from '../../common/manager/BoardManager';
import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';

@Entry
@Component
struct BoardListPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State categories: BoardCategory[] = [];
  @State bookmarkBoards: Board[] = [];
  @State expandedCategories: Set<string> = new Set<string>();
  @State expandedSubCategories: Set<string> = new Set<string>();
  @State showBookmarks: boolean = false;

  aboutToAppear() { this.loadData(); }

  async loadData() {
    await boardManager.init();
    this.categories = boardManager.getCategories();
    this.bookmarkBoards = boardManager.getBookmarks();
    if (this.categories.length > 0) {
      this.expandedCategories.add(this.categories[0].id);
    }
  }

  toggleCategory(id: string) {
    if (this.expandedCategories.has(id)) this.expandedCategories.delete(id);
    else this.expandedCategories.add(id);
    this.categories = this.categories;
  }

  toggleSubCategory(key: string) {
    if (this.expandedSubCategories.has(key)) this.expandedSubCategories.delete(key);
    else this.expandedSubCategories.add(key);
    this.categories = this.categories;
  }

  async toggleBookmark(board: Board) {
    if (boardManager.isBookmark(board.id, board.stid)) {
      await boardManager.removeBookmark(board.id, board.stid);
    } else {
      await boardManager.addBookmark(board);
    }
    this.bookmarkBoards = boardManager.getBookmarks();
    this.categories = this.categories;
  }

  isBookmarked(board: Board): boolean {
    return boardManager.isBookmark(board.id, board.stid);
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Text('\u{276E}').fontSize(22).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })

        Text('版块列表').fontSize(FontSize.LARGE).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).margin({ left: 4 })

        Blank()

        Row() {
          Text('\u{2B50}').fontSize(14)
          Text('(' + this.bookmarkBoards.length + ')')
            .fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_SECONDARY_LIGHT).margin({ left: 2 })
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(this.showBookmarks ? ThemeColors.PRIMARY_LIGHT : ThemeColors.SEARCH_BG)
        .borderRadius(BorderRadius.EXTRA_LARGE)
        .onClick(() => { this.showBookmarks = !this.showBookmarks; })
      }
      .width('100%').height(56).padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      if (this.showBookmarks) {
        this.BookmarkList();
      } else {
        this.CategoryList();
      }
    }
    .width('100%').height('100%').opacity(this.appTheme.length > 0 ? 1 : 1).backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  @Builder
  BookmarkList() {
    if (this.bookmarkBoards.length === 0) {
      Column() {
        Text('暂无收藏版块').fontSize(FontSize.MEDIUM).fontColor(ThemeColors.TEXT_HINT_LIGHT)
        Text('点击版块右侧星标添加收藏').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .margin({ top: 6 })
      }.layoutWeight(1).justifyContent(FlexAlign.Center)
    } else {
      List() {
        ForEach(this.bookmarkBoards, (board: Board) => {
          ListItem() {
            Row() {
              Column() {
                Text(board.name).fontSize(FontSize.MEDIUM).fontWeight(FontWeight.Medium)
                  .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                if (board.description != '') {
                  Text(board.description).fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                    .margin({ top: 2 })
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)

              Text('\u{2605}').fontSize(22).fontColor('#FFD700')
                .width(40).height(40).textAlign(TextAlign.Center)
                .onClick(() => { this.toggleBookmark(board); })
            }
            .width('100%').padding(16)
            .backgroundColor(ThemeColors.CARD_BG).borderRadius(BorderRadius.MEDIUM)
            .margin({ bottom: 8 })
            .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/topic/TopicListPage',
                params: { fid: board.id, stid: board.stid, name: board.name } });
            })
          }
        })
      }
      .layoutWeight(1).width('100%').padding({ left: 16, right: 16, top: 8 })
      .divider({ strokeWidth: 0 }).edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  CategoryList() {
    List() {
      ForEach(this.categories, (category: BoardCategory) => {
        ListItem() {
          Column() {
            // 分类标题
            Row() {
              Text(this.expandedCategories.has(category.id) ? '\u{25BC}' : '\u{25B6}')
                .fontSize(10).fontColor(ThemeColors.TEXT_HINT_LIGHT)
              Rect().width(3).height(16).fill(ThemeColors.PRIMARY).borderRadius(2).margin({ left: 8 })
              Text(category.name)
                .fontSize(FontSize.MEDIUM).fontWeight(FontWeight.Bold)
                .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).margin({ left: 8 })
            }
            .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
            .backgroundColor(ThemeColors.SURFACE_LIGHT)
            .onClick(() => { this.toggleCategory(category.id); })

            if (this.expandedCategories.has(category.id)) {
              ForEach(category.boards, (board: Board) => {
                this.BoardRow(board, false);
              })

              ForEach(category.subCategories, (subCategory: BoardCategory, subIndex: number) => {
                Column() {
                  Row() {
                    Text(this.expandedSubCategories.has(category.id + '_' + subIndex) ? '\u{25BC}' : '\u{25B6}')
                      .fontSize(8).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                    Text(subCategory.name)
                      .fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
                      .fontWeight(FontWeight.Medium).margin({ left: 8 })
                  }
                  .width('100%').padding({ left: 32, right: 16, top: 10, bottom: 10 })
                  .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
                  .onClick(() => { this.toggleSubCategory(category.id + '_' + subIndex); })

                  if (this.expandedSubCategories.has(category.id + '_' + subIndex)) {
                    ForEach(subCategory.boards, (board: Board) => {
                      this.BoardRow(board, true);
                    })
                  }
                }
              })
            }
          }
        }
      })
    }
    .layoutWeight(1).width('100%')
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  BoardRow(board: Board, isSubLevel: boolean) {
    Row() {
      Column() {
        Text(board.name)
          .fontSize(isSubLevel ? FontSize.NORMAL : FontSize.MEDIUM)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
        if (board.description != '') {
          Text(board.description).fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 2 })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Text(this.isBookmarked(board) ? '\u{2605}' : '\u{2606}')
        .fontSize(18)
        .fontColor(this.isBookmarked(board) ? '#FFD700' : ThemeColors.TEXT_HINT_LIGHT)
        .width(36).height(36).textAlign(TextAlign.Center)
    }
    .width('100%').padding({ left: isSubLevel ? 48 : 32, right: 16, top: 12, bottom: 12 })
    .backgroundColor(ThemeColors.CARD_BG)
    .onClick((event: ClickEvent) => {
      // 检查点击位置是否在星号区域
      const targetWidth = event.target.area.width as number;
      if (event.x > (targetWidth - 52)) {
        // 点击星号区域，切换收藏状态
        this.toggleBookmark(board);
      } else {
        // 点击其他区域，跳转到主题列表
        router.pushUrl({ url: 'pages/topic/TopicListPage',
          params: { fid: board.id, stid: board.stid, name: board.name } });
      }
    })
  }
}
