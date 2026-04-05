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
      // 使用正确的 API 格式：__lib=ucp&__act=get&lite=js&noprefix
      const params = 'uid=' + this.uid;
      const url = '/nuke.php?__lib=ucp&__act=get&lite=js&noprefix&' + params;
      console.info('Profile API URL: ' + url);
      
      const response = await http.get(url);
      console.info('Profile API response code: ' + response.code);
      console.info('Profile API raw (first 500): ' + (response.raw || '').substring(0, 500));
      
      if (response.code === 200 && response.raw != null) {
        this.parseProfile(response.raw);
        if (this.profile.userName != '') {
          this.loadingState = LoadingState.SUCCESS;
        } else {
          this.loadingState = LoadingState.ERROR;
        }
      } else {
        this.loadingState = LoadingState.ERROR;
      }
    } catch (err) {
      console.error('Load profile failed:', err);
      this.loadingState = LoadingState.ERROR;
    }
  }

  parseProfile(jsonStr: string) {
    try {
      let js = jsonStr;
      // 移除 JSONP 前缀
      if (js.indexOf('window.script_muti_get_var_store=') === 0) {
        js = js.substring('window.script_muti_get_var_store='.length);
      }
      const jsonObj: Record<string, Object> = JSON.parse(js);
      
      // 检查是否有错误
      const errorField = jsonObj['error'];
      if (errorField != null) {
        console.error('Profile API error:', errorField);
        return;
      }
      
      const data: Record<string, Object> = jsonObj['data'] as Record<string, Object>;
      if (data == null) {
        console.error('Profile data is null');
        return;
      }
      
      // data 可能是对象，key 是 "0", "1" 等
      let userData: Record<string, Object> | null = null;
      if (Array.isArray(data)) {
        const arr = data as Object[];
        if (arr.length > 0 && arr[0] != null && typeof arr[0] === 'object') {
          userData = arr[0] as Record<string, Object>;
        }
      } else {
        // 尝试获取 "0" 键
        const data0 = data['0'];
        if (data0 != null && typeof data0 === 'object') {
          userData = data0 as Record<string, Object>;
        } else {
          // 直接使用 data
          userData = data;
        }
      }
      
      if (userData == null) {
        console.error('User data is null');
        return;
      }
      
      this.profile.uid = userData['uid'] != null ? String(userData['uid']) : this.uid;
      this.profile.userName = userData['username'] != null ? String(userData['username']) : '';
      
      // 优先使用 nickname
      const nickname = userData['nickname'];
      if (nickname != null && String(nickname) !== '' && String(nickname) !== 'null') {
        this.profile.userName = String(nickname);
      }
      
      this.profile.avatarUrl = userData['avatar'] != null ? String(userData['avatar']) : '';
      this.profile.postCount = userData['posts'] != null ? String(userData['posts']) : '0';
      this.profile.registerDate = userData['regdate'] != null ? String(userData['regdate']) : '';
      this.profile.money = userData['money'] != null ? String(userData['money']) : '0';
      this.profile.memberGroup = userData['group'] != null ? String(userData['group']) : '';
      this.profile.signature = userData['sign'] != null ? String(userData['sign']) : '';
      this.profile.reputation = userData['fame'] != null ? String(userData['fame']) : '0';
      this.profile.ipLoc = userData['ipLoc'] != null ? String(userData['ipLoc']) : '';
      
      console.info('Parsed profile: uid=' + this.profile.uid + ', name=' + this.profile.userName);
    } catch (err) {
      console.error('Parse profile failed:', err);
      console.error('Raw response:', jsonStr.substring(0, 1000));
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
