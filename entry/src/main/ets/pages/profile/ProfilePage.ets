import router from '@ohos.router';
import { HttpClient } from '../../network/api/HttpClient';
import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';
import { LoadingState } from '../../ui/components/CommonComponents';

class ProfileData {
  uid: string = '';
  userName: string = '';
  avatarUrl: string = '';
  postCount: string = '0';
  registerDate: string = '';
  money: string = '0';
  memberGroup: string = '';
  signature: string = '';
  reputation: string = '0';
  ipLoc: string = '';
}

@Entry
@Component
struct ProfilePage {
  @State profile: ProfileData = new ProfileData();
  @State loadingState: LoadingState = LoadingState.LOADING;
  @State uid: string = '';
  @State userName: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params != null) {
      const uidParam = params['uid'];
      if (uidParam != null) this.uid = String(uidParam);
      const nameParam = params['name'];
      if (nameParam != null) this.userName = String(nameParam);
    }
    // 如果有用户名但没有 uid，先显示用户名
    if (this.userName != '' && this.uid == '') {
      this.profile.userName = this.userName;
    }
    if (this.uid != '') this.loadProfile();
  }

  async loadProfile() {
    this.loadingState = LoadingState.LOADING;
    try {
      const http = HttpClient.getInstance();
      const response = await http.get('/nuke.php?func=ucp&uid=' + this.uid);
      if (response.code === 200 && response.data != null) {
        this.parseProfile(response.raw);
        this.loadingState = LoadingState.SUCCESS;
      } else {
        this.loadingState = LoadingState.ERROR;
      }
    } catch (err) {
      this.loadingState = LoadingState.ERROR;
    }
  }

  parseProfile(jsonStr: string) {
    try {
      let js = jsonStr;
      if (js.indexOf('window.script_muti_get_var_store=') === 0) {
        js = js.substring('window.script_muti_get_var_store='.length);
      }
      const jsonObj: Record<string, Object> = JSON.parse(js);
      const data: Record<string, Object> = jsonObj['data'] as Record<string, Object>;
      if (data == null) return;
      this.profile.uid = data['uid'] != null ? String(data['uid']) : '';
      this.profile.userName = data['username'] != null ? String(data['username']) : '';
      this.profile.avatarUrl = data['avatar'] != null ? String(data['avatar']) : '';
      this.profile.postCount = data['postnum'] != null ? String(data['postnum']) : '0';
      this.profile.registerDate = data['regdate'] != null ? String(data['regdate']) : '';
      this.profile.money = data['money'] != null ? String(data['money']) : '0';
      this.profile.memberGroup = data['member_group'] != null ? String(data['member_group']) : '';
      this.profile.signature = data['sign'] != null ? String(data['sign']) : '';
      this.profile.reputation = data['rvrc'] != null ? String(data['rvrc']) : '0';
      this.profile.ipLoc = data['iploc'] != null ? String(data['iploc']) : '';
    } catch (err) {
      console.error('Parse profile failed:', err);
    }
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Text('\u{276E}').fontSize(22).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })
        Text('个人资料').fontSize(FontSize.LARGE).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).margin({ left: 4 })
      }
      .width('100%').height(56).padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      if (this.loadingState === LoadingState.LOADING) {
        Column() {
          LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.ERROR) {
        Column() {
          Text('加载失败').fontSize(FontSize.MEDIUM).fontColor(ThemeColors.TEXT_HINT_LIGHT)
          Button('重试').fontSize(FontSize.NORMAL).fontColor('#FFFFFF').backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE).height(40).padding({ left: 24, right: 24 })
            .margin({ top: 16 }).onClick(() => { this.loadProfile(); })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // 用户头像卡片
            Column() {
              Stack() {
                Circle().width(80).height(80).fill(ThemeColors.PRIMARY_LIGHT)
                Text((this.profile.userName || '?').substring(0, 1))
                  .fontSize(32).fontColor(ThemeColors.PRIMARY).fontWeight(FontWeight.Bold)
              }
              Text(this.profile.userName || '用户')
                .fontSize(FontSize.TITLE).fontWeight(FontWeight.Bold)
                .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).margin({ top: 12 })
              Text('UID: ' + this.profile.uid)
                .fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT).margin({ top: 4 })
              if (this.profile.ipLoc != '') {
                Text('IP 属地: ' + this.profile.ipLoc)
                  .fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT).margin({ top: 4 })
              }
            }
            .width('100%').padding(32).alignItems(HorizontalAlign.Center)
            .backgroundColor(ThemeColors.SURFACE_LIGHT)

            // 统计数据
            Row() {
              this.StatItem(this.profile.postCount, '发帖')
              this.StatItem(this.profile.reputation, '威望')
              this.StatItem(this.profile.money, '金钱')
            }
            .width('100%')
            .backgroundColor(ThemeColors.CARD_BG)
            .borderRadius(BorderRadius.MEDIUM)
            .margin({ left: 16, right: 16, top: 12 })
            .padding({ top: 16, bottom: 16 })
            .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

            // 详细信息
            Column() {
              this.InfoRow('用户组', this.profile.memberGroup)
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 16 })
              this.InfoRow('注册时间', this.profile.registerDate)
            }
            .backgroundColor(ThemeColors.CARD_BG)
            .borderRadius(BorderRadius.MEDIUM)
            .margin({ left: 16, right: 16, top: 12 })
            .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })

            if (this.profile.signature != '') {
              Column() {
                Text('签名')
                  .fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                  .width('100%').margin({ bottom: 8 })
                Text(this.profile.signature)
                  .fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                  .width('100%')
              }
              .backgroundColor(ThemeColors.CARD_BG)
              .borderRadius(BorderRadius.MEDIUM)
              .margin({ left: 16, right: 16, top: 12 })
              .padding(16)
              .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
            }

            // 操作按钮
            Row() {
              Button('查看主题')
                .fontSize(FontSize.NORMAL).fontColor('#FFFFFF').backgroundColor(ThemeColors.PRIMARY)
                .borderRadius(BorderRadius.EXTRA_LARGE).height(44).layoutWeight(1)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/topic/TopicListPage', params: { authorId: this.profile.uid } });
                })
              Button('发送消息')
                .fontSize(FontSize.NORMAL).fontColor(ThemeColors.PRIMARY)
                .backgroundColor(ThemeColors.PRIMARY_LIGHT)
                .borderRadius(BorderRadius.EXTRA_LARGE).height(44).layoutWeight(1).margin({ left: 12 })
            }
            .width('100%').padding({ left: 16, right: 16, top: 20 })

            Blank().height(30)
          }
        }
        .layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%').height('100%').backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  @Builder
  StatItem(value: string, label: string) {
    Column() {
      Text(value || '0')
        .fontSize(FontSize.EXTRA_LARGE).fontWeight(FontWeight.Bold).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
      Text(label)
        .fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT).margin({ top: 4 })
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
      Blank()
      Text(value || '-').fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
    }
    .width('100%').height(48).padding({ left: 16, right: 16 })
  }
}
