import router from '@ohos.router';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { UserManager } from '../../common/manager/UserManager';
import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';

@Entry
@Component
struct SettingsPage {
  @State userName: string = '';
  @State cacheSize: string = '0 KB';

  aboutToAppear() {
    const user = UserManager.getInstance().getCurrentUser();
    if (user != null) {
      this.userName = user.getDisplayName();
    }
  }

  async clearCache() { this.cacheSize = '0 KB'; }
  async clearHistory() { await PreferencesManager.getInstance().remove('topic_history'); }
  async clearSearchHistory() { await PreferencesManager.getInstance().remove('search_history'); }

  build() {
    Column() {
      Row() {
        Text('\u{276E}')
          .fontSize(22)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })
        Text('设置')
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
          this.SectionTitle('账号设置')
          Column() {
            if (this.userName != '') {
              this.SettingRow('\u{1F464}', '当前账号', this.userName, () => {})
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.SettingRow('\u{1F504}', '切换账号', '', () => {})
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
              this.SettingRow('\u{1F6AA}', '退出登录', '', () => {
                UserManager.getInstance().logout();
                router.back();
              })
            } else {
              this.SettingRow('\u{1F464}', '登录账号', '', () => {
                router.pushUrl({ url: 'pages/login/LoginPage' });
              })
            }
          }
          .backgroundColor(ThemeColors.CARD_BG)
          .borderRadius(BorderRadius.MEDIUM)
          .margin({ left: 16, right: 16 })
          .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

          // 通用
          this.SectionTitle('通用设置')
          Column() {
            this.SettingRow('\u{1F319}', '夜间模式', '关闭', () => {})
            Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
            this.SettingRow('\u{1F514}', '消息通知', '开启', () => {})
            Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
            this.SettingRow('\u{1F524}', '字体大小', '标准', () => {})
          }
          .backgroundColor(ThemeColors.CARD_BG)
          .borderRadius(BorderRadius.MEDIUM)
          .margin({ left: 16, right: 16 })
          .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

          // 数据管理
          this.SectionTitle('数据管理')
          Column() {
            this.SettingRow('\u{1F4BE}', '清除缓存', this.cacheSize, () => { this.clearCache(); })
            Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
            this.SettingRow('\u{1F4CB}', '清除浏览历史', '', () => { this.clearHistory(); })
            Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
            this.SettingRow('\u{1F50D}', '清除搜索历史', '', () => { this.clearSearchHistory(); })
          }
          .backgroundColor(ThemeColors.CARD_BG)
          .borderRadius(BorderRadius.MEDIUM)
          .margin({ left: 16, right: 16 })
          .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

          // 关于
          this.SectionTitle('关于')
          Column() {
            this.SettingRow('\u{2139}\u{FE0F}', '版本', '1.2.1', () => {})
            Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
            this.SettingRow('\u{2B50}', '给个好评', '', () => {})
            Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 52 })
            this.SettingRow('\u{1F4E7}', '反馈问题', '', () => {})
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
