import router from '@ohos.router';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { UserManager } from '../../common/manager/UserManager';
import { AppConstants } from '../../common/constants/AppConstants';
import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';

@Entry
@Component
struct SettingsPage {
  @State userName: string = '';
  @State cacheSize: string = '0 KB';
  @State startPageIndex: number = 0;
  @State showStartPagePicker: boolean = false;
  @State fontSizeIndex: number = 1; // 0: 更小, 1: 标准, 2: 更大
  @State showFontSizePicker: boolean = false;

  private startPageOptions: string[] = ['首页', '版块', '消息', '我的'];
  private fontSizeOptions: string[] = ['更小', '标准', '更大'];

  aboutToAppear() {
    const user = UserManager.getInstance().getCurrentUser();
    if (user != null) {
      this.userName = user.getDisplayName();
    }
    this.loadStartPage();
    this.loadFontSize();
  }

  async loadStartPage() {
    try {
      const val = await PreferencesManager.getInstance().getString(AppConstants.PREF_START_PAGE, '0');
      const idx = parseInt(val);
      if (!isNaN(idx) && idx >= 0 && idx <= 3) {
        this.startPageIndex = idx;
      }
    } catch (e) {
      console.error('Load start page setting failed:', e);
    }
  }

  async saveStartPage(index: number) {
    try {
      await PreferencesManager.getInstance().putString(AppConstants.PREF_START_PAGE, '' + index);
      this.startPageIndex = index;
    } catch (e) {
      console.error('Save start page setting failed:', e);
    }
  }

  async loadFontSize() {
    try {
      const val = await PreferencesManager.getInstance().getString(AppConstants.PREF_FONT_SIZE, 'normal');
      if (val === 'small') {
        this.fontSizeIndex = 0;
      } else if (val === 'large') {
        this.fontSizeIndex = 2;
      } else {
        this.fontSizeIndex = 1;
      }
    } catch (e) {
      console.error('Load font size setting failed:', e);
    }
  }

  async saveFontSize(index: number) {
    let level = 'normal';
    if (index === 0) {
      level = 'small';
    } else if (index === 2) {
      level = 'large';
    }
    try {
      await PreferencesManager.getInstance().putString(AppConstants.PREF_FONT_SIZE, level);
      this.fontSizeIndex = index;
    } catch (e) {
      console.error('Save font size setting failed:', e);
    }
  }

  async clearCache() { this.cacheSize = '0 KB'; }
  async clearHistory() { await PreferencesManager.getInstance().remove('topic_history'); }
  async clearSearchHistory() { await PreferencesManager.getInstance().remove('search_history'); }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('\u{276E}')
            .fontSize(22)
            .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
            .width(44).height(44).textAlign(TextAlign.Center)
            .onClick(() => { router.back(); })
          Text('\u8BBE\u7F6E')
            .fontSize(FontSize.LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
            .margin({ left: 4 })
        }
        .width('100%').height(56).padding({ left: 8, right: 16 })
        .backgroundColor(ThemeColors.SURFACE_LIGHT)

        Scroll() {
          Column() {
            // 账号
            this.SectionTitle('\u8D26\u53F7\u8BBE\u7F6E')
            Column() {
              if (this.userName != '') {
                this.SettingRow('\u{1F464}', '\u5F53\u524D\u8D26\u53F7', this.userName, () => {})
                Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
                this.SettingRow('\u{1F504}', '\u5207\u6362\u8D26\u53F7', '', () => {})
                Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
                this.SettingRow('\u{1F6AA}', '\u9000\u51FA\u767B\u5F55', '', () => {
                  UserManager.getInstance().logout();
                  router.back();
                })
              } else {
                this.SettingRow('\u{1F464}', '\u767B\u5F55\u8D26\u53F7', '', () => {
                  router.pushUrl({ url: 'pages/login/LoginPage' });
                })
              }
            }
            .backgroundColor(ThemeColors.CARD_BG)
            .borderRadius(BorderRadius.MEDIUM)
            .margin({ left: 16, right: 16 })
            .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

            // 通用
            this.SectionTitle('\u901A\u7528\u8BBE\u7F6E')
            Column() {
              // 启动页面设置行
              Row() {
                Text('\u{1F3E0}').fontSize(20).width(32).textAlign(TextAlign.Center)
                Text('\u542F\u52A8\u9875\u9762')
                  .fontSize(FontSize.MEDIUM)
                  .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                  .margin({ left: 12 })
                  .layoutWeight(1)
                Text(this.startPageOptions[this.startPageIndex])
                  .fontSize(FontSize.NORMAL)
                  .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                Text('\u{276F}')
                  .fontSize(FontSize.NORMAL)
                  .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                  .margin({ left: 8 })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
              .onClick(() => { this.showStartPagePicker = true; })
              
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.SettingRow('\u{1F319}', '\u591C\u95F4\u6A21\u5F0F', '\u5173\u95ED', () => {})
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.SettingRow('\u{1F514}', '\u6D88\u606F\u901A\u77E5', '\u5F00\u542F', () => {})
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              
              // 字体大小设置行
              Row() {
                Text('\u{1F524}').fontSize(20).width(32).textAlign(TextAlign.Center)
                Text('\u5B57\u4F53\u5927\u5C0F')
                  .fontSize(FontSize.MEDIUM)
                  .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                  .margin({ left: 12 })
                  .layoutWeight(1)
                Text(this.fontSizeOptions[this.fontSizeIndex])
                  .fontSize(FontSize.NORMAL)
                  .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                Text('\u{276F}')
                  .fontSize(FontSize.NORMAL)
                  .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                  .margin({ left: 8 })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
              .onClick(() => { this.showFontSizePicker = true; })
            }
            .backgroundColor(ThemeColors.CARD_BG)
            .borderRadius(BorderRadius.MEDIUM)
            .margin({ left: 16, right: 16 })
            .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

            // 数据管理
            this.SectionTitle('\u6570\u636E\u7BA1\u7406')
            Column() {
              this.SettingRow('\u{1F4BE}', '\u6E05\u9664\u7F13\u5B58', this.cacheSize, () => { this.clearCache(); })
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.SettingRow('\u{1F4CB}', '\u6E05\u9664\u6D4F\u89C8\u5386\u53F2', '', () => { this.clearHistory(); })
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.SettingRow('\u{1F50D}', '\u6E05\u9664\u641C\u7D22\u5386\u53F2', '', () => { this.clearSearchHistory(); })
            }
            .backgroundColor(ThemeColors.CARD_BG)
            .borderRadius(BorderRadius.MEDIUM)
            .margin({ left: 16, right: 16 })
            .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

            // 关于
            this.SectionTitle('\u5173\u4E8E')
            Column() {
              this.SettingRow('\u{2139}\u{FE0F}', '\u7248\u672C', '1.2.1', () => {})
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.SettingRow('\u{2B50}', '\u7ED9\u4E2A\u597D\u8BC4', '', () => {})
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.SettingRow('\u{1F4E7}', '\u53CD\u9988\u95EE\u9898', '', () => {})
            }
            .backgroundColor(ThemeColors.CARD_BG)
            .borderRadius(BorderRadius.MEDIUM)
            .margin({ left: 16, right: 16 })
            .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

            Blank().height(30)
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%').height('100%')
      .backgroundColor(ThemeColors.BACKGROUND_LIGHT)

      // 启动页面选择弹窗
      if (this.showStartPagePicker) {
        this.StartPagePickerDialog()
      }

      // 字体大小选择弹窗
      if (this.showFontSizePicker) {
        this.FontSizePickerDialog()
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  StartPagePickerDialog() {
    // 遮罩层
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => { this.showStartPagePicker = false; })

      // 弹窗内容
      Column() {
        // 标题
        Text('\u542F\u52A8\u9875\u9762')
          .fontSize(FontSize.LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width('100%')
          .padding({ left: 20, top: 20, bottom: 12 })

        Text('\u9009\u62E9\u6253\u5F00\u5E94\u7528\u65F6\u9ED8\u8BA4\u8FDB\u5165\u7684\u9875\u9762')
          .fontSize(FontSize.NORMAL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .width('100%')
          .padding({ left: 20, bottom: 16 })

        // 选项列表
        ForEach(this.startPageOptions, (option: string, index: number) => {
          Row() {
            Text(this.getPageIcon(index))
              .fontSize(20)
              .width(32)
              .textAlign(TextAlign.Center)

            Text(option)
              .fontSize(FontSize.MEDIUM)
              .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
              .margin({ left: 12 })
              .layoutWeight(1)

            if (this.startPageIndex === index) {
              Text('\u{2713}')
                .fontSize(18)
                .fontColor(ThemeColors.PRIMARY)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width('100%')
          .height(52)
          .padding({ left: 20, right: 20 })
          .backgroundColor(this.startPageIndex === index ? ThemeColors.PRIMARY_LIGHT : Color.Transparent)
          .onClick(() => {
            this.saveStartPage(index);
            this.showStartPagePicker = false;
          })

          if (index < this.startPageOptions.length - 1) {
            Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 64 })
          }
        })

        // 取消按钮
        Text('\u53D6\u6D88')
          .fontSize(FontSize.MEDIUM)
          .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
          .width('100%')
          .textAlign(TextAlign.Center)
          .height(48)
          .margin({ top: 8 })
          .onClick(() => { this.showStartPagePicker = false; })
      }
      .width('100%')
      .backgroundColor(ThemeColors.CARD_BG)
      .borderRadius({ topLeft: BorderRadius.EXTRA_LARGE, topRight: BorderRadius.EXTRA_LARGE })
      .shadow({ radius: 16, color: '#00000020', offsetX: 0, offsetY: -4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.OVERLAY_BG)
  }

  getPageIcon(index: number): string {
    switch (index) {
      case 0: return '\u{1F3E0}';
      case 1: return '\u{1F4CB}';
      case 2: return '\u{1F4AC}';
      case 3: return '\u{1F464}';
      default: return '\u{1F3E0}';
    }
  }

  @Builder
  FontSizePickerDialog() {
    // 遮罩层
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => { this.showFontSizePicker = false; })

      // 弹窗内容
      Column() {
        // 标题
        Text('\u5B57\u4F53\u5927\u5C0F')
          .fontSize(FontSize.LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width('100%')
          .padding({ left: 20, top: 20, bottom: 12 })

        Text('\u8C03\u6574\u5E94\u7528\u5185\u6587\u5B57\u7684\u663E\u793A\u5927\u5C0F')
          .fontSize(FontSize.NORMAL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .width('100%')
          .padding({ left: 20, bottom: 16 })

        // 选项列表
        ForEach(this.fontSizeOptions, (option: string, index: number) => {
          Row() {
            Text(option)
              .fontSize(FontSize.MEDIUM)
              .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
              .layoutWeight(1)

            if (this.fontSizeIndex === index) {
              Text('\u{2713}')
                .fontSize(18)
                .fontColor(ThemeColors.PRIMARY)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width('100%')
          .height(52)
          .padding({ left: 20, right: 20 })
          .backgroundColor(this.fontSizeIndex === index ? ThemeColors.PRIMARY_LIGHT : Color.Transparent)
          .onClick(() => {
            this.saveFontSize(index);
            this.showFontSizePicker = false;
          })

          if (index < this.fontSizeOptions.length - 1) {
            Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 20 })
          }
        })

        // 取消按钮
        Text('\u53D6\u6D88')
          .fontSize(FontSize.MEDIUM)
          .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
          .width('100%')
          .textAlign(TextAlign.Center)
          .height(48)
          .margin({ top: 8 })
          .onClick(() => { this.showFontSizePicker = false; })
      }
      .width('100%')
      .backgroundColor(ThemeColors.CARD_BG)
      .borderRadius({ topLeft: BorderRadius.EXTRA_LARGE, topRight: BorderRadius.EXTRA_LARGE })
      .shadow({ radius: 16, color: '#00000020', offsetX: 0, offsetY: -4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.OVERLAY_BG)
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(FontSize.SMALL)
      .fontColor(ThemeColors.TEXT_HINT_LIGHT)
      .width('100%')
      .padding({ left: 32, top: 20, bottom: 8 })
  }

  @Builder
  SettingRow(icon: string, title: string, value: string, onClick: () => void) {
    Row() {
      Text(icon).fontSize(20).width(32).textAlign(TextAlign.Center)
      Text(title)
        .fontSize(FontSize.MEDIUM)
        .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
        .margin({ left: 12 })
        .layoutWeight(1)
      if (value != '') {
        Text(value)
          .fontSize(FontSize.NORMAL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
      }
      Text('\u{276F}')
        .fontSize(FontSize.NORMAL)
        .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        .margin({ left: 8 })
    }
    .width('100%').height(52).padding({ left: 16, right: 16 })
    .onClick(onClick)
  }
}
