import router from '@ohos.router';
import { HttpClient } from '../../network/api/HttpClient';
import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';
import { LoadingState } from '../../ui/components/CommonComponents';

class NotificationInfo {
  type: number = 0;
  userName: string = '';
  title: string = '';
  pidStr: string = '';
  tidStr: string = '';
  time: string = '';

  getTypeText(): string {
    switch (this.type) {
      case 1: return '回复了你的主题';
      case 2: return '回复了你的回复';
      case 3: return '评论了你的主题';
      case 4: return '评论了你的回复';
      case 7: return '在主题中@了你';
      case 8: return '在回复中@了你';
      case 10: return '新消息';
      case 11: return '消息回复';
      default: return '通知';
    }
  }
}

@Entry
@Component
struct NotificationPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State notifications: NotificationInfo[] = [];
  @State loadingState: LoadingState = LoadingState.LOADING;

  aboutToAppear() { this.loadNotifications(); }

  async loadNotifications() {
    this.loadingState = LoadingState.LOADING;
    try {
      const http = HttpClient.getInstance();
      const response = await http.get('/nuke.php?__lib=noti&__output=8&__act=get_all');
      if (response.code === 200 && response.data != null) {
        this.parseNotifications(response.raw);
        this.loadingState = this.notifications.length > 0 ? LoadingState.SUCCESS : LoadingState.EMPTY;
      } else {
        this.loadingState = LoadingState.ERROR;
      }
    } catch (err) {
      this.loadingState = LoadingState.ERROR;
    }
  }

  parseNotifications(jsonStr: string) {
    try {
      let js = jsonStr;
      if (js.indexOf('window.script_muti_get_var_store=') === 0) {
        js = js.substring('window.script_muti_get_var_store='.length);
      }
      const jsonObj: Record<string, Object> = JSON.parse(js);
      const data: Record<string, Object> = jsonObj['data'] as Record<string, Object>;
      if (data == null) return;
      const t: Record<string, Object> = data['t'] as Record<string, Object>;
      if (t == null) return;

      const keys: string[] = Object.keys(t);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        if (key.indexOf('__') === 0) continue;
        const item: Record<string, Object> = t[key] as Record<string, Object>;
        if (item == null) continue;
        const notification = new NotificationInfo();
        notification.type = item['type'] != null ? (item['type'] as number) : 0;
        notification.userName = item['user'] != null ? String(item['user']) : '';
        notification.title = item['title'] != null ? String(item['title']) : '';
        notification.pidStr = item['pid'] != null ? String(item['pid']) : '';
        notification.tidStr = item['tid'] != null ? String(item['tid']) : '';
        notification.time = item['time'] != null ? String(item['time']) : '';
        this.notifications.push(notification);
      }
    } catch (err) {
      console.error('Parse notifications failed:', err);
    }
  }

  build() {
    Column() {
      Row() {
        Text('\u{276E}').fontSize(22).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })
        Text('通知').fontSize(FontSize.LARGE).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).margin({ left: 4 })
        Blank()
        if (this.notifications.length > 0) {
          Text('全部已读').fontSize(FontSize.NORMAL).fontColor(ThemeColors.PRIMARY)
        }
      }
      .width('100%').height(56).padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      if (this.loadingState === LoadingState.LOADING) {
        Column() {
          LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
          Text('正在加载...').fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_HINT_LIGHT).margin({ top: 12 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.ERROR) {
        Column() {
          Text('加载失败').fontSize(FontSize.MEDIUM).fontColor(ThemeColors.TEXT_HINT_LIGHT)
          Button('重试').fontSize(FontSize.NORMAL).fontColor('#FFFFFF').backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE).height(40).padding({ left: 24, right: 24 })
            .margin({ top: 16 }).onClick(() => { this.loadNotifications(); })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.EMPTY) {
        Column() {
          Text('暂无通知').fontSize(FontSize.MEDIUM).fontColor(ThemeColors.TEXT_HINT_LIGHT)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.notifications, (notification: NotificationInfo) => {
            ListItem() {
              Column() {
                Row() {
                  Stack() {
                    Circle().width(36).height(36).fill(ThemeColors.PRIMARY_LIGHT)
                    Text((notification.userName || '?').substring(0, 1))
                      .fontSize(14).fontColor(ThemeColors.PRIMARY).fontWeight(FontWeight.Bold)
                  }
                  Column() {
                    Row() {
                      Text(notification.userName)
                        .fontSize(FontSize.NORMAL).fontWeight(FontWeight.Medium)
                        .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                      Text(notification.getTypeText())
                        .fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
                        .margin({ left: 4 })
                    }
                    Text(notification.time)
                      .fontSize(FontSize.EXTRA_SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                      .margin({ top: 2 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })
                }.width('100%')

                if (notification.title) {
                  Text(notification.title)
                    .fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                    .maxLines(2).lineHeight(20).width('100%')
                    .padding({ left: 46, top: 6 })
                }
              }
              .width('100%').padding(16)
              .backgroundColor(ThemeColors.CARD_BG).borderRadius(BorderRadius.MEDIUM)
              .margin({ bottom: 8 })
              .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                if (notification.tidStr != '') {
                  router.pushUrl({ url: 'pages/article/ArticleListPage', params: { tid: notification.tidStr } });
                }
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
