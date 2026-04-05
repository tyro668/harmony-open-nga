import router from '@ohos.router';
import { ngaApi } from '../../network/api/NgaApi';
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
  rvrc: string = '0';
  followCount: string = '0';
  title: string = '';
  honor: string = '';
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

  private nameFirstGlyph(name: string): string {
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

  async loadProfile() {
    this.loadingState = LoadingState.LOADING;
    try {
      const response = await ngaApi.getUserProfile(this.uid);

      if (response.code === 200 && response.data != null) {
        this.parseProfileData(response.data);
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

  private formatTimestamp(ts: number): string {
    if (ts <= 0) return '-';
    const d = new Date(ts * 1000);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return y + '-' + m + '-' + day;
  }

  parseProfileData(jsonObj: Record<string, Object>) {
    try {
      const errorField = jsonObj['error'];
      if (errorField != null) {
        console.error('Profile API error:', JSON.stringify(errorField));
        return;
      }

      const data: Record<string, Object> = jsonObj['data'] as Record<string, Object>;
      if (data == null) {
        console.error('Profile data is null');
        return;
      }

      let userData: Record<string, Object> | null = null;
      if (Array.isArray(data)) {
        const arr = data as Object[];
        if (arr.length > 0 && arr[0] != null && typeof arr[0] === 'object') {
          userData = arr[0] as Record<string, Object>;
        }
      } else {
        const data0 = data['0'];
        if (data0 != null && typeof data0 === 'object') {
          userData = data0 as Record<string, Object>;
        } else {
          userData = data;
        }
      }

      if (userData == null) {
        console.error('User data is null');
        return;
      }

      this.profile.uid = userData['uid'] != null ? String(userData['uid']) : this.uid;
      this.profile.userName = userData['username'] != null ? String(userData['username']) : '';

      const nickname = userData['nickname'];
      if (nickname != null && String(nickname) !== '' && String(nickname) !== 'null') {
        this.profile.userName = String(nickname);
      }
      // 若 API 只返回 UID 格式名（如 "UID42423334"），优先使用帖子中传入的用户名
      if (this.userName && this.profile.userName.startsWith('UID')) {
        this.profile.userName = this.userName;
      }

      this.profile.avatarUrl = userData['avatar'] != null ? String(userData['avatar']) : '';

      const postsVal = userData['posts'];
      const postNumVal = userData['postnum'];
      if (postNumVal != null && Number(postNumVal) > 0) {
        this.profile.postCount = String(postNumVal);
      } else if (postsVal != null) {
        this.profile.postCount = String(postsVal);
      }

      const regdate = userData['regdate'];
      if (regdate != null) {
        const ts = Number(regdate);
        this.profile.registerDate = (!isNaN(ts) && ts > 0) ? this.formatTimestamp(ts) : String(regdate);
      }

      this.profile.money = userData['money'] != null ? String(userData['money']) : '0';
      this.profile.memberGroup = userData['group'] != null ? String(userData['group']) : '';
      this.profile.signature = userData['sign'] != null ? String(userData['sign']) : '';
      this.profile.reputation = userData['fame'] != null ? String(userData['fame']) : '0';
      this.profile.ipLoc = userData['ipLoc'] != null ? String(userData['ipLoc']) : '';

      const rvrc = userData['rvrc'];
      if (rvrc != null) this.profile.rvrc = String(rvrc);
      const followBy = userData['follow_by_num'];
      if (followBy != null) this.profile.followCount = String(followBy);
      const title = userData['title'];
      if (title != null && String(title) !== '') this.profile.title = String(title);
      const honor = userData['honor'];
      if (honor != null && String(honor) !== '') this.profile.honor = String(honor);

      console.info('Parsed profile: uid=' + this.profile.uid + ', name=' + this.profile.userName +
        ', group=' + this.profile.memberGroup + ', ipLoc=' + this.profile.ipLoc);
    } catch (err) {
      console.error('Parse profile data failed:', err);
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
                Text(this.nameFirstGlyph(this.profile.userName))
                  .fontSize(32).fontColor(ThemeColors.PRIMARY).fontWeight(FontWeight.Bold)
                  .fontFamily(ThemeColors.FONT_FAMILY_UI)
              }
              Text(this.profile.userName || '用户')
                .fontSize(FontSize.TITLE).fontWeight(FontWeight.Bold)
                .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                .fontFamily(ThemeColors.FONT_FAMILY_UI)
                .margin({ top: 12 })
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
              this.StatItem(this.profile.followCount, '关注')
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
              if (this.profile.title != '') {
                Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 16 })
                this.InfoRow('头衔', this.profile.title)
              }
              if (this.profile.honor != '') {
                Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 16 })
                this.InfoRow('荣誉', this.profile.honor)
              }
              Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 16 })
              this.InfoRow('金钱', this.profile.money)
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
