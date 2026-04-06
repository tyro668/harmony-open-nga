import router from '@ohos.router';
import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { BusinessError } from '@ohos.base';

@Entry
@Component
struct ImageViewerPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State imageUrls: string[] = [];
  @State currentIndex: number = 0;
  @State imageScale: number = 1;
  @State imageTranslateX: number = 0;
  @State imageTranslateY: number = 0;
  @State showOriginalImage: boolean = false;
  @State showControls: boolean = true;
  @State showSaveDialog: boolean = false;
  @State isSaving: boolean = false;
  @State saveMessage: string = '';
  private swiperController: SwiperController = new SwiperController();
  private pinchStartScale: number = 1;
  private panStartX: number = 0;
  private panStartY: number = 0;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params != null) {
      const urls = params['imageUrls'];
      if (urls != null && Array.isArray(urls)) {
        this.imageUrls = urls as string[];
      }
      const idx = params['currentIndex'];
      if (idx != null) {
        this.currentIndex = Number(idx);
      }
    }
  }

  async requestWritePermission(): Promise<boolean> {
    const permission: Permissions = 'ohos.permission.WRITE_IMAGEVIDEO';
    const atManager = abilityAccessCtrl.createAtManager();
    const context = getContext(this);

    try {
      const grantStatus = await atManager.checkAccessToken(
        context.applicationInfo.accessTokenId, permission
      );
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
    } catch (e) {
      console.info('checkAccessToken not available, requesting directly');
    }

    try {
      const result = await atManager.requestPermissionsFromUser(
        context, [permission]
      );
      if (result.authResults.length > 0 && result.authResults[0] === 0) {
        return true;
      }
      return false;
    } catch (err) {
      const bizErr = err as BusinessError;
      console.error('requestPermission failed:', bizErr.code, bizErr.message);
      return false;
    }
  }

  async saveImageToGallery() {
    if (this.isSaving || this.currentIndex >= this.imageUrls.length) return;
    this.isSaving = true;
    this.saveMessage = '';

    const hasPermission = await this.requestWritePermission();
    if (!hasPermission) {
      this.isSaving = false;
      this.saveMessage = '\u672A\u83B7\u5F97\u76F8\u518C\u5199\u5165\u6743\u9650\uFF0C\u8BF7\u5728\u7CFB\u7EDF\u8BBE\u7F6E\u4E2D\u5F00\u542F';
      try {
        promptAction.showToast({ message: this.saveMessage, duration: 2500 });
      } catch (e) {
        console.info('Toast:', this.saveMessage);
      }
      this.showSaveDialog = false;
      return;
    }

    const imageUrl = this.imageUrls[this.currentIndex];

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(imageUrl, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://bbs.nga.cn/'
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });

      if (response.responseCode === 200 && response.result instanceof ArrayBuffer) {
        const imageData = response.result as ArrayBuffer;

        const context = getContext(this);
        const cacheDir = context.cacheDir;
        const ext = this.getFileExtension(imageUrl);
        const tmpFile = cacheDir + '/save_img_' + Date.now() + ext;

        const file = fs.openSync(tmpFile, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
        fs.writeSync(file.fd, imageData);
        fs.closeSync(file);

        try {
          const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
          const assetUri = await phAccessHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, ext.replace('.', ''));
          const assetFile = await fs.open(assetUri, fs.OpenMode.WRITE_ONLY);
          const srcFile = await fs.open(tmpFile, fs.OpenMode.READ_ONLY);
          const buf = new ArrayBuffer(imageData.byteLength);
          fs.readSync(srcFile.fd, buf);
          fs.writeSync(assetFile.fd, buf);
          fs.closeSync(assetFile);
          fs.closeSync(srcFile);
          fs.unlinkSync(tmpFile);
          this.saveMessage = '\u4FDD\u5B58\u6210\u529F';
        } catch (saveErr) {
          console.error('Save to gallery failed:', JSON.stringify(saveErr));
          this.saveMessage = '\u4FDD\u5B58\u5931\u8D25\uFF0C\u8BF7\u91CD\u8BD5';
        }
      } else {
        this.saveMessage = '\u56FE\u7247\u4E0B\u8F7D\u5931\u8D25';
      }
      httpRequest.destroy();
    } catch (err) {
      console.error('Download image failed:', JSON.stringify(err));
      this.saveMessage = '\u4E0B\u8F7D\u5931\u8D25\uFF0C\u8BF7\u91CD\u8BD5';
    } finally {
      this.isSaving = false;
      if (this.saveMessage) {
        try {
          promptAction.showToast({ message: this.saveMessage, duration: 2000 });
        } catch (e) {
          console.info('Toast:', this.saveMessage);
        }
      }
      this.showSaveDialog = false;
    }
  }

  getFileExtension(url: string): string {
    const cleaned = url.split('?')[0];
    const lower = cleaned.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.gif')) return '.gif';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.bmp')) return '.bmp';
    return '.jpg';
  }

  resetZoomState() {
    this.imageScale = 1;
    this.imageTranslateX = 0;
    this.imageTranslateY = 0;
  }

  clampScale(scale: number): number {
    if (scale < 1) {
      return 1;
    }
    if (scale > 4) {
      return 4;
    }
    return scale;
  }

  toggleZoom() {
    if (this.imageScale > 1.05) {
      this.resetZoomState();
    } else {
      this.imageScale = 2;
      this.imageTranslateX = 0;
      this.imageTranslateY = 0;
    }
  }

  toggleOriginalImage() {
    this.showOriginalImage = !this.showOriginalImage;
    this.resetZoomState();
  }

  @Builder
  buildFitImage(url: string, index: number) {
    Image(url)
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Contain)
      .draggable(false)
      .scale({
        x: this.currentIndex === index ? this.imageScale : 1,
        y: this.currentIndex === index ? this.imageScale : 1
      })
      .translate({
        x: this.currentIndex === index ? this.imageTranslateX : 0,
        y: this.currentIndex === index ? this.imageTranslateY : 0
      })
  }

  @Builder
  buildOriginalImage(url: string) {
    Scroll() {
      Column() {
        Image(url)
          .width('100%')
          .objectFit(ImageFit.Fill)
          .draggable(false)
      }
      .width('100%')
      .padding({ top: this.showControls ? 72 : 24, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    Stack() {
      // 黑色背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      // 图片 Swiper
      if (this.imageUrls.length > 0) {
        Swiper(this.swiperController) {
          ForEach(this.imageUrls, (url: string, index: number) => {
            Column() {
              if (this.showOriginalImage) {
                this.buildOriginalImage(url);
              } else {
                this.buildFitImage(url, index);
              }
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.showControls = !this.showControls;
            })
            .gesture(
              GestureGroup(
                GestureMode.Parallel,
                LongPressGesture({ repeat: false, duration: 600 })
                  .onAction(() => {
                    this.showSaveDialog = true;
                  }),
                TapGesture({ count: 2 })
                  .onAction(() => {
                    if (!this.showOriginalImage && this.currentIndex === index) {
                      this.toggleZoom();
                    }
                  }),
                PinchGesture({ fingers: 2 })
                  .onActionStart(() => {
                    if (!this.showOriginalImage && this.currentIndex === index) {
                      this.pinchStartScale = this.imageScale;
                    }
                  })
                  .onActionUpdate((event) => {
                    if (this.showOriginalImage || this.currentIndex !== index) {
                      return;
                    }
                    this.imageScale = this.clampScale(this.pinchStartScale * event.scale);
                    if (this.imageScale <= 1.01) {
                      this.imageTranslateX = 0;
                      this.imageTranslateY = 0;
                    }
                  }),
                PanGesture()
                  .onActionStart(() => {
                    if (!this.showOriginalImage && this.currentIndex === index) {
                      this.panStartX = this.imageTranslateX;
                      this.panStartY = this.imageTranslateY;
                    }
                  })
                  .onActionUpdate((event) => {
                    if (this.showOriginalImage || this.currentIndex !== index || this.imageScale <= 1.01) {
                      return;
                    }
                    this.imageTranslateX = this.panStartX + event.offsetX;
                    this.imageTranslateY = this.panStartY + event.offsetY;
                  })
              )
            )
          }, (url: string, index: number) => url + '_' + index)
        }
        .width('100%')
        .height('100%')
        .index(this.currentIndex)
        .indicator(false)
        .loop(false)
        .onChange((index: number) => {
          this.currentIndex = index;
          this.resetZoomState();
        })
      }

      // 顶部控制栏
      if (this.showControls) {
        Column() {
          Row() {
            Text('\u{2715}')
              .fontSize(22)
              .fontColor('#FFFFFF')
              .width(48)
              .height(48)
              .textAlign(TextAlign.Center)
              .onClick(() => { router.back(); })

            Blank()

            if (this.imageUrls.length > 1) {
              Text((this.currentIndex + 1) + ' / ' + this.imageUrls.length)
                .fontSize(FontSize.MEDIUM)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
            }

            Blank()

            Row() {
              Text('\u539F\u56FE')
                .fontSize(FontSize.SMALL)
                .fontColor(this.showOriginalImage ? '#FFD76A' : '#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .onClick(() => {
                  this.toggleOriginalImage();
                })

              Text('\u{2913}')
                .fontSize(22)
                .fontColor('#FFFFFF')
                .width(48)
                .height(48)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.showSaveDialog = true;
                })
            }
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .height(56)
          .padding({ left: 4, right: 4, top: 8 })
          .alignItems(VerticalAlign.Center)

          Blank()
        }
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Top,
          colors: [['#80000000', 0], ['#00000000', 0.15]]
        })
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // 保存弹窗
      if (this.showSaveDialog) {
        Column() {
          Blank()
            .layoutWeight(1)
            .onClick(() => { this.showSaveDialog = false; })

          Column() {
            // 保存按钮
            Row() {
              Text('\u{1F4BE}')
                .fontSize(20)
              Text(this.isSaving ? '\u4FDD\u5B58\u4E2D...' : '\u4FDD\u5B58\u56FE\u7247\u5230\u76F8\u518C')
                .fontSize(FontSize.MEDIUM)
                .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                .fontWeight(FontWeight.Medium)
                .margin({ left: 12 })
            }
            .width('100%')
            .height(56)
            .padding({ left: 24, right: 24 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              if (!this.isSaving) {
                this.saveImageToGallery();
              }
            })

            Divider().color(ThemeColors.DIVIDER_LIGHT)

            // 取消
            Text('\u53D6\u6D88')
              .fontSize(FontSize.MEDIUM)
              .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
              .width('100%')
              .height(52)
              .textAlign(TextAlign.Center)
              .onClick(() => { this.showSaveDialog = false; })
          }
          .width('100%')
          .backgroundColor(ThemeColors.CARD_BG)
          .borderRadius({ topLeft: BorderRadius.EXTRA_LARGE, topRight: BorderRadius.EXTRA_LARGE })
          .shadow({ radius: 16, color: '#00000030', offsetX: 0, offsetY: -4 })
        }
    .width('100%')
    .height('100%')
    .opacity(this.appTheme.length > 0 ? 1 : 1)
    .backgroundColor(ThemeColors.OVERLAY_BG)
      }
    }
    .width('100%')
    .height('100%')
  }
}
