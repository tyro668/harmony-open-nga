import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';

/**
 * 加载状态
 */
export enum LoadingState {
  IDLE = 'idle',
  LOADING = 'loading',
  SUCCESS = 'success',
  ERROR = 'error',
  EMPTY = 'empty'
}

@Component
export struct LoadingView {
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @Prop state: LoadingState = LoadingState.LOADING;
  @Prop errorText: string = '加载失败';
  @Prop emptyText: string = '暂无数据';
  onRetry?: () => void;

  build() {
    Column() {
      if (this.state === LoadingState.LOADING) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color(ThemeColors.PRIMARY)
        Text('正在加载...')
          .fontSize(FontSize.NORMAL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .margin({ top: Spacing.MEDIUM })
      } else if (this.state === LoadingState.ERROR) {
        Column() {
          Text('Oops!')
            .fontSize(FontSize.EXTRA_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          Text(this.errorText)
            .fontSize(FontSize.NORMAL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: Spacing.SMALL })
          if (this.onRetry) {
            Button('重新加载')
              .fontSize(FontSize.NORMAL)
              .fontColor('#FFFFFF')
              .backgroundColor(ThemeColors.PRIMARY)
              .borderRadius(BorderRadius.EXTRA_LARGE)
              .height(40)
              .padding({ left: 24, right: 24 })
              .margin({ top: Spacing.LARGE })
              .onClick(() => {
                if (this.onRetry) {
                  this.onRetry();
                }
              })
          }
        }
      } else if (this.state === LoadingState.EMPTY) {
        Column() {
          Text('暂无内容')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
          Text(this.emptyText)
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: Spacing.SMALL })
        }
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct EmptyView {
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @Prop message: string = '暂无数据';

  build() {
    Column() {
      Text('暂无内容')
        .fontSize(FontSize.MEDIUM)
        .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
      Text(this.message)
        .fontSize(FontSize.SMALL)
        .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        .margin({ top: Spacing.SMALL })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct ErrorView {
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @Prop message: string = '出错了';
  onRetry?: () => void;

  build() {
    Column() {
      Text('Oops!')
        .fontSize(FontSize.EXTRA_LARGE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
      Text(this.message)
        .fontSize(FontSize.NORMAL)
        .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        .margin({ top: Spacing.SMALL })
      if (this.onRetry) {
        Button('重新加载')
          .fontSize(FontSize.NORMAL)
          .fontColor('#FFFFFF')
          .backgroundColor(ThemeColors.PRIMARY)
          .borderRadius(BorderRadius.EXTRA_LARGE)
          .height(40)
          .padding({ left: 24, right: 24 })
          .margin({ top: Spacing.LARGE })
          .onClick(() => {
            if (this.onRetry) {
              this.onRetry();
            }
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct AvatarView {
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @Prop url: string = '';
  @Prop avatarSize: number = 40;
  @Prop placeholder: string = '';

  build() {
    if (this.url) {
      Image(this.url)
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(this.avatarSize / 2)
        .objectFit(ImageFit.Cover)
    } else {
      Stack() {
        Circle()
          .width(this.avatarSize)
          .height(this.avatarSize)
          .fill(ThemeColors.PRIMARY_LIGHT)
        Text(this.placeholder || '?')
          .fontSize(this.avatarSize * 0.4)
          .fontColor(ThemeColors.PRIMARY)
          .fontWeight(FontWeight.Bold)
      }
    }
  }
}

@Component
export struct TagView {
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @Prop text: string = '';
  @Prop color: string = ThemeColors.TAG_BG;
  @Prop textColor: string = ThemeColors.TAG_TEXT;

  build() {
    Text(this.text)
      .fontSize(FontSize.EXTRA_SMALL)
      .fontColor(this.textColor)
      .backgroundColor(this.color)
      .borderRadius(BorderRadius.SMALL)
      .padding({ left: Spacing.SMALL, right: Spacing.SMALL, top: 2, bottom: 2 })
  }
}

@Component
export struct DividerView {
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @Prop dividerColor: string = ThemeColors.DIVIDER_LIGHT;
  @Prop dividerHeight: number = 0.5;
  @Prop dividerMargin: number = 0;

  build() {
    Divider()
      .color(this.dividerColor)
      .height(this.dividerHeight)
      .margin({ left: this.dividerMargin, right: this.dividerMargin })
  }
}

@Component
export struct ListItemView {
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @BuilderParam content: () => void;
  @Prop itemPadding: number = Spacing.MEDIUM;
  onItemClick?: () => void;

  build() {
    Row() {
      this.content();
    }
    .width('100%')
    .padding(this.itemPadding)
    .backgroundColor(ThemeColors.CARD_BG)
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick();
      }
    })
  }
}

@Component
export struct SearchBar {
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @Link text: string;
  @Prop placeholder: string = '搜索';
  onSearch?: (text: string) => void;
  onClear?: () => void;

  build() {
    Row() {
      Text('\u{1F50D}')
        .fontSize(14)
        .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        .margin({ left: Spacing.NORMAL })

      TextInput({ text: this.text, placeholder: this.placeholder })
        .layoutWeight(1)
        .height(36)
        .backgroundColor(Color.Transparent)
        .fontSize(FontSize.NORMAL)
        .placeholderColor(ThemeColors.TEXT_HINT_LIGHT)
        .onChange((value: string) => {
          this.text = value;
        })
        .onSubmit(() => {
          if (this.onSearch) {
            this.onSearch(this.text);
          }
        })

      if (this.text) {
        Text('\u2715')
          .fontSize(14)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .margin({ right: Spacing.NORMAL })
          .onClick(() => {
            this.text = '';
            if (this.onClear) {
              this.onClear();
            }
          })
      }
    }
    .width('100%')
    .height(40)
    .backgroundColor(ThemeColors.SEARCH_BG)
    .borderRadius(BorderRadius.EXTRA_LARGE)
  }
}
