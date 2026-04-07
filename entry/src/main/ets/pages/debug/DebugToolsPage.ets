import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';
import { LogUtils } from '../../common/utils/LogUtils';

@Entry
@Component
struct DebugToolsPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State testThreadInput: string = '';

  private normalizeDebugTid(raw: string): string {
    const text = raw != null ? String(raw).trim() : '';
    if (text === '') {
      return '';
    }
    if (/^\d+$/.test(text)) {
      return text;
    }

    const queryMatch = /(?:[?&#])tid=(\d+)/i.exec(text);
    if (queryMatch != null) {
      return queryMatch[1];
    }

    return text;
  }

  private openDebugThreadViewer() {
    const normalizedTid = this.normalizeDebugTid(this.testThreadInput);
    if (!/^\d+$/.test(normalizedTid)) {
      promptAction.showToast({ message: '请输入有效的帖子 ID 或 read.php 链接', duration: 1800 });
      return;
    }

    LogUtils.i('DebugToolsPage', 'openDebugThreadViewer tid=' + normalizedTid + ', rawInput=' + this.testThreadInput);
    router.pushUrl({
      url: 'pages/article/ArticleListPage',
      params: {
        tid: normalizedTid,
        title: '测试查看 ' + normalizedTid,
        debugLogContent: true,
        debugSource: 'debug_tools'
      }
    });
  }

  build() {
    Column() {
      Row() {
        Text('\u{276E}')
          .fontSize(22)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })
        Text('调试')
          .fontSize(FontSize.LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      Scroll() {
        Column() {
          Column() {
            Row() {
              Text('\u{1F9EA}')
                .fontSize(20)
                .margin({ right: 10 })
              Text('帖子测试查看')
                .fontSize(FontSize.MEDIUM)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
              Blank()
            }
            .width('100%')

            Text('输入帖子 ID 或完整帖子链接，进入详情页时自动输出当前页楼层内容日志。')
              .fontSize(FontSize.SMALL)
              .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
              .width('100%')
              .margin({ top: 10, bottom: 12 })

            Row() {
              TextInput({ placeholder: '例如 46525366 或 read.php?tid=46525366', text: this.testThreadInput })
                .layoutWeight(1)
                .height(40)
                .fontSize(FontSize.NORMAL)
                .backgroundColor(ThemeColors.SEARCH_BG)
                .borderRadius(BorderRadius.EXTRA_LARGE)
                .padding({ left: 14, right: 14 })
                .onChange((value: string) => {
                  this.testThreadInput = value;
                })
                .onSubmit(() => {
                  this.openDebugThreadViewer();
                })

              Button('测试查看')
                .fontSize(FontSize.SMALL)
                .fontColor('#FFFFFF')
                .backgroundColor(ThemeColors.PRIMARY)
                .borderRadius(BorderRadius.EXTRA_LARGE)
                .height(40)
                .margin({ left: 10 })
                .onClick(() => {
                  this.openDebugThreadViewer();
                })
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor(ThemeColors.CARD_BG)
          .borderRadius(BorderRadius.MEDIUM)
          .margin({ left: 16, right: 16, top: 16 })
          .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

          Blank()
            .height(24)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }
}
