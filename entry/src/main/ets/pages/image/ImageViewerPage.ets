import router from '@ohos.router';
import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct ImageViewerPage {
  @State imageUrls: string[] = [];
  @State currentIndex: number = 0;
  @State showControls: boolean = true;
  @State showSaveDialog: boolean = false;
  @State isSaving: boolean = false;
  @State saveMessage: string = '';
  private swiperController: SwiperController = new SwiperController();

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

  async saveImageToGallery() {
    if (this.isSaving || this.currentIndex >= this.imageUrls.length) return;
    this.isSaving = true;
    this.saveMessage = '';

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
          this.saveMessage = '\u4FDD\u5B58\u5931\u8D25\uFF0C\u8BF7\u68C0\u67E5\u6743\u9650';
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
              Image(url)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain)
                .draggable(false)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.showControls = !this.showControls;
            })
            .gesture(
              LongPressGesture({ repeat: false, duration: 600 })
                .onAction(() => {
                  this.showSaveDialog = true;
                })
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
        .backgroundColor(ThemeColors.OVERLAY_BG)
      }
    }
    .width('100%')
    .height('100%')
  }
}
