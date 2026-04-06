import router from '@ohos.router';
import { Board } from '../../model/entity/Board';
import { boardManager } from '../../common/manager/BoardManager';
import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';

/**
 * 我的收藏页面 - 展示收藏的板块
 */
@Entry
@Component
struct FavoritePage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State bookmarkBoards: Board[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadBookmarks();
  }

  async loadBookmarks() {
    this.isLoading = true;
    try {
      await boardManager.init();
      this.bookmarkBoards = boardManager.getBookmarks();
    } catch (err) {
      console.error('Load bookmarks failed:', err);
    } finally {
      this.isLoading = false;
    }
  }

  async removeBookmark(board: Board, index: number) {
    await boardManager.removeBookmark(board.id, board.stid);
    this.bookmarkBoards = boardManager.getBookmarks();
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Text('\u{276E}').fontSize(22).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })

        Text('我的收藏').fontSize(FontSize.LARGE).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).margin({ left: 4 })

        Blank()

        Text('(' + this.bookmarkBoards.length + ')')
          .fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
      }
      .width('100%').height(56).padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
          Text('正在加载...').fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 12 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.bookmarkBoards.length === 0) {
        Column() {
          Text('\u{2B50}').fontSize(48).margin({ bottom: 16 })
          Text('暂无收藏版块').fontSize(FontSize.MEDIUM).fontColor(ThemeColors.TEXT_HINT_LIGHT)
          Text('在版块列表中点击星标添加收藏').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 6 })
          Button('去版块列表').fontSize(FontSize.NORMAL).fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY).borderRadius(BorderRadius.EXTRA_LARGE)
            .height(40).padding({ left: 24, right: 24 }).margin({ top: 16 })
            .onClick(() => { router.pushUrl({ url: 'pages/board/BoardListPage' }); })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.bookmarkBoards, (board: Board, index: number) => {
            ListItem() {
              Row() {
                Column() {
                  Text(board.name).fontSize(FontSize.MEDIUM).fontWeight(FontWeight.Medium)
                    .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).maxLines(1)
                  if (board.description != '') {
                    Text(board.description).fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                      .margin({ top: 2 }).maxLines(1)
                  }
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                // 取消收藏按钮
                Text('\u{2605}').fontSize(22).fontColor('#FFD700')
                  .width(40).height(40).textAlign(TextAlign.Center)
                  .onClick(() => { this.removeBookmark(board, index); })
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
    .width('100%').height('100%').opacity(this.appTheme.length > 0 ? 1 : 1).backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }
}
