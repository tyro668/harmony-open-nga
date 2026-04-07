import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';
import { NotificationItem } from '../../model/entity/Notification';
import { ngaApi } from '../../network/api/NgaApi';
import { LoadingState, AvatarView } from '../../ui/components/CommonComponents';
import { avatarCacheManager } from '../../common/manager/AvatarCacheManager';
import { userManager } from '../../common/manager/UserManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';

@Entry
@Component
struct NotificationPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State notifications: NotificationItem[] = [];
  @State loadingState: LoadingState = LoadingState.LOADING;
  @State isRefreshing: boolean = false;
  @State errorMsg: string = '';
  @State loggedIn: boolean = false;
  @State avatarUrls: Record<string, string> = {};
  private readonly REFRESH_THRESHOLD: number = 80;
  private refreshInFlight: boolean = false;
  private listScroller: Scroller = new Scroller();

  aboutToAppear() {
    this.syncLoginState();
    if (this.loggedIn) {
      this.loadNotifications(true);
    } else {
      this.loadingState = LoadingState.EMPTY;
    }
  }

  onPageShow() {
    const wasLoggedIn = this.loggedIn;
    this.syncLoginState();
    if (!this.loggedIn) {
      this.notifications = [];
      this.loadingState = LoadingState.EMPTY;
      return;
    }
    if (!wasLoggedIn || this.notifications.length === 0) {
      this.loadNotifications(false);
    }
  }

  private syncLoginState() {
    const user = userManager.getCurrentUser();
    this.loggedIn = user != null && user.isLoggedIn();
  }

  private typeText(type: number): string {
    switch (type) {
      case 1:
        return '回复了你的主题';
      case 2:
        return '回复了你的回复';
      case 3:
        return '评论了你的主题';
      case 4:
        return '评论了你的回复';
      case 7:
        return '在主题中@了你';
      case 8:
        return '在回复中@了你';
      case 10:
        return '新消息';
      case 11:
        return '消息回复';
      default:
        return '通知';
    }
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

  private async warmNotificationAvatars(notificationsToWarm: NotificationItem[]) {
    if (notificationsToWarm.length === 0) {
      return;
    }

    const context = getContext(this) as common.UIAbilityContext;
    const allowNetwork = await avatarCacheManager.isWifiConnection();
    const seen: Set<string> = new Set<string>();

    for (let i = 0; i < notificationsToWarm.length; i++) {
      const uid = notificationsToWarm[i].userId != null ? String(notificationsToWarm[i].userId).trim() : '';
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

  async loadNotifications(showLoading: boolean = true) {
    if (!this.loggedIn) {
      this.loadingState = LoadingState.EMPTY;
      return;
    }
    if (showLoading && this.notifications.length === 0) {
      this.loadingState = LoadingState.LOADING;
    }

    try {
      const response = await ngaApi.getNotificationList();
      if (response.code === 200 && response.data != null) {
        const list = response.data;
        if (list.errorMsg !== '') {
          this.errorMsg = list.errorMsg;
          this.loadingState = this.notifications.length > 0 ? LoadingState.SUCCESS : LoadingState.ERROR;
          return;
        }
        this.errorMsg = '';
        this.notifications = list.notifications;
        this.loadingState = this.notifications.length > 0 ? LoadingState.SUCCESS : LoadingState.EMPTY;
        this.warmNotificationAvatars(this.notifications);
      } else {
        this.errorMsg = response.message || '加载失败';
        this.loadingState = this.notifications.length > 0 ? LoadingState.SUCCESS : LoadingState.ERROR;
      }
    } catch (err) {
      console.error('Load notifications failed:', err);
      this.errorMsg = '加载失败';
      this.loadingState = this.notifications.length > 0 ? LoadingState.SUCCESS : LoadingState.ERROR;
    } finally {
      this.isRefreshing = false;
      this.refreshInFlight = false;
    }
  }

  async doRefresh() {
    if (this.refreshInFlight) {
      return;
    }
    this.refreshInFlight = true;
    this.isRefreshing = true;
    await this.loadNotifications(false);
  }

  async clearAll() {
    if (this.notifications.length === 0) {
      return;
    }
    try {
      const response = await ngaApi.clearAllNotifications();
      if (response.code === 200) {
        this.notifications = [];
        this.loadingState = LoadingState.EMPTY;
        promptAction.showToast({ message: '已清空通知', duration: 1500 });
      } else {
        promptAction.showToast({ message: response.message || '操作失败', duration: 1500 });
      }
    } catch (err) {
      console.error('Clear notifications failed:', err);
      promptAction.showToast({ message: '操作失败', duration: 1500 });
    }
  }

  openNotification(item: NotificationItem) {
    if (item.tidStr !== '') {
      router.pushUrl({
        url: 'pages/article/ArticleListPage',
        params: { tid: item.tidStr, title: item.title }
      });
      return;
    }
    if (item.midStr !== '') {
      router.pushUrl({
        url: 'pages/message/MessageDetailPage',
        params: { mid: item.midStr, title: item.title }
      });
      return;
    }
    if (item.isMessageNotice) {
      promptAction.showToast({ message: '请到消息页查看会话详情', duration: 1500 });
    }
  }

  @Builder
  private LoginPrompt() {
    Column() {
      Stack() {
        Circle().width(80).height(80).fill(ThemeColors.PRIMARY_LIGHT)
        Text('\u{1F514}').fontSize(34)
      }
      Text('登录后查看通知')
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
        .onClick(() => {
          router.pushUrl({ url: 'pages/login/LoginPage' });
        })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private NotificationCard(item: NotificationItem) {
    Column() {
      Row() {
        AvatarView({
          url: this.avatarUrlForUid(item.userId),
          avatarSize: 36,
          placeholder: this.authorInitial(item.userName)
        })
        Column() {
          Row() {
            Text(item.userName !== '' ? item.userName : '系统')
              .fontSize(FontSize.NORMAL)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
            Text(this.typeText(item.type))
              .fontSize(FontSize.NORMAL)
              .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
              .margin({ left: 6 })
          }
          if (item.timeText !== '') {
            Text(item.timeText)
              .fontSize(FontSize.EXTRA_SMALL)
              .fontColor(ThemeColors.TEXT_HINT_LIGHT)
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })

        if (item.isUnread) {
          Circle()
            .width(8)
            .height(8)
            .fill(ThemeColors.PRIMARY)
        }
      }
      .width('100%')

      if (item.title !== '') {
        Text(item.title)
          .fontSize(FontSize.NORMAL)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(20)
          .width('100%')
          .padding({ left: 46, top: 8 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ThemeColors.CARD_BG)
    .borderRadius(BorderRadius.MEDIUM)
    .margin({ bottom: 8 })
    .border(item.isUnread ? { width: 1, color: ThemeColors.PRIMARY_LIGHT } : { width: 0 })
    .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openNotification(item);
    })
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
          .onClick(() => {
            router.back();
          })
        Text('通知')
          .fontSize(FontSize.LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .margin({ left: 4 })
        Blank()

        if (this.notifications.length > 0) {
          Text('清空通知')
            .fontSize(FontSize.NORMAL)
            .fontColor(ThemeColors.PRIMARY)
            .margin({ right: 8 })
            .onClick(() => {
              this.clearAll();
            })
        }

        Stack() {
          Circle()
            .width(34)
            .height(34)
            .fill(this.loadingState === LoadingState.LOADING ? ThemeColors.PRIMARY_LIGHT : ThemeColors.SEARCH_BG)

          if (this.loadingState === LoadingState.LOADING) {
            LoadingProgress()
              .width(15)
              .height(15)
              .color(ThemeColors.PRIMARY)
          } else {
            Text('\u27F3')
              .fontSize(16)
              .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width(36)
        .height(36)
        .onClick(() => {
          this.doRefresh();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      if (!this.loggedIn) {
        this.LoginPrompt()
      } else if (this.loadingState === LoadingState.LOADING && this.notifications.length === 0) {
        Column() {
          LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
          Text('正在加载...')
            .fontSize(FontSize.NORMAL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.ERROR && this.notifications.length === 0) {
        Column() {
          Text(this.errorMsg !== '' ? this.errorMsg : '加载失败')
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
              this.loadNotifications(true);
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.EMPTY) {
        Column() {
          Text('暂无通知')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ scroller: this.listScroller }) {
            ForEach(this.notifications, (item: NotificationItem) => {
              ListItem() {
                this.NotificationCard(item)
              }
            }, (item: NotificationItem) => item.type + '_' + item.pidStr + '_' + item.midStr + '_' + item.timeStamp)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8 })
          .divider({ strokeWidth: 0 })
          .edgeEffect(EdgeEffect.Spring)
        }
        .layoutWeight(1)
        .width('100%')
        .refreshOffset(this.REFRESH_THRESHOLD)
        .pullToRefresh(true)
        .onRefreshing(() => {
          this.doRefresh();
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }
}
