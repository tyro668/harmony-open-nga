import { image } from '@kit.ImageKit';
import router from '@ohos.router';
import { UserManager } from '../../common/manager/UserManager';
import { NgaApi } from '../../network/api/NgaApi';
import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';

enum LoginStep {
  INPUT,
  CAPTCHA
}

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State captchaCode: string = '';
  @State captchaPixelMap: image.PixelMap | undefined = undefined;
  @State captchaRid: string = '';
  private captchaCookie: string = '';
  private captchaPrid: string = '';
  @State step: LoginStep = LoginStep.INPUT;
  @State isLogging: boolean = false;
  @State isCaptchaLoading: boolean = false;
  @State errorMsg: string = '';
  @State passwordVisible: boolean = false;
  @State captchaLoadFailed: boolean = false;

  private ngaApi: NgaApi = new NgaApi();

  async onLoginClicked(): Promise<void> {
    if (!this.username) {
      this.errorMsg = '请输入用户名';
      return;
    }
    if (!this.password) {
      this.errorMsg = '请输入密码';
      return;
    }
    this.errorMsg = '';
    await this.loadCaptchaAndShowStep();
  }

  async loadCaptchaAndShowStep(): Promise<void> {
    this.isCaptchaLoading = true;
    this.captchaLoadFailed = false;
    this.captchaCode = '';
    this.step = LoginStep.CAPTCHA;

    try {
      const captchaResult = await this.ngaApi.loadCaptcha();
      this.captchaRid = captchaResult.rid;
      this.captchaCookie = captchaResult.captchaCookie;
      this.captchaPrid = captchaResult.prid;

      if (captchaResult.imageData && captchaResult.imageData.byteLength > 0) {
        try {
          const imageSource = image.createImageSource(captchaResult.imageData);
          this.captchaPixelMap = await imageSource.createPixelMap();
        } catch (imgErr) {
          console.error('Create PixelMap failed: ' + JSON.stringify(imgErr));
          this.captchaLoadFailed = true;
        }
      } else {
        this.captchaLoadFailed = true;
      }
    } catch (err) {
      console.error('Load captcha failed: ' + JSON.stringify(err));
      this.captchaLoadFailed = true;
    } finally {
      this.isCaptchaLoading = false;
    }
  }

  async submitLogin(): Promise<void> {
    if (!this.captchaCode) {
      this.errorMsg = '请输入验证码';
      return;
    }

    this.isLogging = true;
    this.errorMsg = '';

    try {
      const result = await this.ngaApi.nativeLogin(
        this.username, this.password, this.captchaCode, this.captchaRid, this.captchaCookie, this.captchaPrid
      );

      if (result.success) {
        const userName = result.userName || this.username;
        await UserManager.getInstance().saveLoginInfo(result.uid, result.cid, userName);
        router.back();
      } else {
        this.errorMsg = result.errorMsg || '登录失败，请检查用户名和密码';
        await this.loadCaptchaAndShowStep();
      }
    } catch (err) {
      this.errorMsg = '登录失败：' + String(err);
      await this.loadCaptchaAndShowStep();
    } finally {
      this.isLogging = false;
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('\u{276E}')
          .fontSize(22)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            if (this.step === LoginStep.CAPTCHA) {
              this.step = LoginStep.INPUT;
              this.errorMsg = '';
              this.captchaCode = '';
            } else {
              router.back();
            }
          })

        Text(this.step === LoginStep.INPUT ? '登录' : '安全验证')
          .fontSize(FontSize.LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .margin({ left: 4 })

        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      Scroll() {
        Column() {
          if (this.step === LoginStep.INPUT) {
            this.InputStepContent();
          } else {
            this.CaptchaStepContent();
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.SURFACE_LIGHT)
  }

  @Builder
  InputStepContent() {
    Column() {
      // Logo
      Column() {
        Stack() {
          Circle().width(80).height(80).fill(ThemeColors.PRIMARY_LIGHT)
          Text('N')
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.PRIMARY)
        }

        Text('NGA 玩家社区')
          .fontSize(FontSize.EXTRA_LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .margin({ top: 16 })

        Text('登录账号，探索更多精彩')
          .fontSize(FontSize.NORMAL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .margin({ top: 6 })
      }
      .margin({ top: 40, bottom: 40 })

      // 输入表单
      Column() {
        // 用户名
        Column() {
          Text('用户名')
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
            .width('100%')
            .margin({ bottom: 6 })

          TextInput({ placeholder: '用户名 / 邮箱 / UID', text: this.username })
            .width('100%')
            .height(48)
            .fontSize(FontSize.MEDIUM)
            .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
            .borderRadius(BorderRadius.NORMAL)
            .padding({ left: Spacing.MEDIUM, right: Spacing.MEDIUM })
            .onChange((value: string) => { this.username = value; })
        }

        // 密码
        Column() {
          Text('密码')
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
            .width('100%')
            .margin({ bottom: 6 })

          Row() {
            TextInput({ placeholder: '请输入密码', text: this.password })
              .layoutWeight(1)
              .height(48)
              .fontSize(FontSize.MEDIUM)
              .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
              .borderRadius(BorderRadius.NORMAL)
              .padding({ left: Spacing.MEDIUM, right: 44 })
              .type(this.passwordVisible ? InputType.Normal : InputType.Password)
              .onChange((value: string) => { this.password = value; })

            Text(this.passwordVisible ? '\u{1F648}' : '\u{1F441}')
              .fontSize(18)
              .width(40)
              .height(48)
              .textAlign(TextAlign.Center)
              .position({ right: 4 })
              .onClick(() => { this.passwordVisible = !this.passwordVisible; })
          }
        }
        .margin({ top: Spacing.LARGE })

        // 错误提示
        if (this.errorMsg) {
          this.ErrorBanner();
        }

        // 登录按钮
        Button('登录')
          .width('100%')
          .height(48)
          .fontSize(FontSize.MEDIUM)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(ThemeColors.PRIMARY)
          .borderRadius(BorderRadius.EXTRA_LARGE)
          .margin({ top: 32 })
          .onClick(() => { this.onLoginClicked(); })
      }
      .width('100%')
      .padding({ left: Spacing.EXTRA_LARGE, right: Spacing.EXTRA_LARGE })

      // 底部条款
      Column() {
        Text('登录即表示同意')
          .fontSize(FontSize.EXTRA_SMALL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)

        Row() {
          Text('《用户协议》')
            .fontSize(FontSize.EXTRA_SMALL)
            .fontColor(ThemeColors.PRIMARY)

          Text(' 和 ')
            .fontSize(FontSize.EXTRA_SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)

          Text('《隐私政策》')
            .fontSize(FontSize.EXTRA_SMALL)
            .fontColor(ThemeColors.PRIMARY)
        }
        .margin({ top: 2 })
      }
      .margin({ top: 40 })
    }
    .width('100%')
  }

  @Builder
  CaptchaStepContent() {
    Column() {
      // 提示文字
      Column() {
        Text('请完成安全验证')
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)

        Text('请输入下方图片中的字符')
          .fontSize(FontSize.NORMAL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .margin({ top: 6 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 32 })
      .padding({ left: Spacing.EXTRA_LARGE, right: Spacing.EXTRA_LARGE })

      // 验证码图片区域
      Column() {
        if (this.isCaptchaLoading) {
          Column() {
            LoadingProgress().width(36).height(36).color(ThemeColors.PRIMARY)
            Text('加载验证码...')
              .fontSize(FontSize.SMALL)
              .fontColor(ThemeColors.TEXT_HINT_LIGHT)
              .margin({ top: 8 })
          }
          .width('100%')
          .height(100)
          .justifyContent(FlexAlign.Center)
        } else if (this.captchaLoadFailed) {
          Column() {
            Text('验证码加载失败')
              .fontSize(FontSize.NORMAL)
              .fontColor(ThemeColors.ERROR)

            Button('点击重试')
              .fontSize(FontSize.NORMAL)
              .fontColor('#FFFFFF')
              .backgroundColor(ThemeColors.PRIMARY)
              .borderRadius(BorderRadius.EXTRA_LARGE)
              .height(36)
              .padding({ left: 20, right: 20 })
              .margin({ top: 12 })
              .onClick(() => { this.loadCaptchaAndShowStep(); })
          }
          .width('100%')
          .height(100)
          .justifyContent(FlexAlign.Center)
        } else if (this.captchaPixelMap !== undefined) {
          Image(this.captchaPixelMap)
            .width('100%')
            .height(100)
            .objectFit(ImageFit.Contain)
            .borderRadius(BorderRadius.NORMAL)
            .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
            .onClick(() => { this.loadCaptchaAndShowStep(); })
        }
      }
      .width('100%')
      .padding({ left: Spacing.EXTRA_LARGE, right: Spacing.EXTRA_LARGE })
      .margin({ top: 24 })

      if (!this.isCaptchaLoading && !this.captchaLoadFailed) {
        Text('看不清？点击图片刷新')
          .fontSize(FontSize.SMALL)
          .fontColor(ThemeColors.PRIMARY)
          .margin({ top: 8 })
          .onClick(() => { this.loadCaptchaAndShowStep(); })
      }

      // 输入验证码
      Column() {
        TextInput({ placeholder: '请输入图形验证码(6字符)', text: this.captchaCode })
          .width('100%')
          .height(48)
          .fontSize(FontSize.MEDIUM)
          .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
          .borderRadius(BorderRadius.NORMAL)
          .padding({ left: Spacing.MEDIUM, right: Spacing.MEDIUM })
          .onChange((value: string) => { this.captchaCode = value; })

        if (this.errorMsg) {
          this.ErrorBanner();
        }

        Button(this.isLogging ? '验证中...' : '确认登录')
          .width('100%')
          .height(48)
          .fontSize(FontSize.MEDIUM)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.isLogging ? ThemeColors.ACCENT : ThemeColors.PRIMARY)
          .borderRadius(BorderRadius.EXTRA_LARGE)
          .margin({ top: 24 })
          .enabled(!this.isLogging && !this.isCaptchaLoading)
          .onClick(() => { this.submitLogin(); })
      }
      .width('100%')
      .padding({ left: Spacing.EXTRA_LARGE, right: Spacing.EXTRA_LARGE })
      .margin({ top: 24 })
    }
    .width('100%')
  }

  @Builder
  ErrorBanner() {
    Row() {
      Text('\u26A0')
        .fontSize(14)
        .fontColor(ThemeColors.ERROR)

      Text(this.errorMsg)
        .fontSize(FontSize.SMALL)
        .fontColor(ThemeColors.ERROR)
        .margin({ left: 6 })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('#FEF2F2')
    .borderRadius(BorderRadius.NORMAL)
    .margin({ top: Spacing.MEDIUM })
  }
}
