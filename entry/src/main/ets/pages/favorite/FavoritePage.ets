import router from '@ohos.router';
import { Topic } from '../../model/entity/Topic';
import { ngaApi } from '../../network/api/NgaApi';
import { LoadingState } from '../../ui/components/CommonComponents';
import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';
import { userManager } from '../../common/manager/UserManager';

@Entry
@Component
struct FavoritePage {
  @State topics: Topic[] = [];
  @State page: number = 1;
  @State loadingState: LoadingState = LoadingState.LOADING;
  @State hasMore: boolean = false;
  @State isLoadingMore: boolean = false;

  aboutToAppear() { this.loadFavorites(); }

  async loadFavorites(refresh: boolean = true) {
    if (!userManager.isLoggedIn()) { this.loadingState = LoadingState.EMPTY; return; }
    if (refresh) { this.page = 1; this.loadingState = LoadingState.LOADING; }
    else { this.isLoadingMore = true; }

    try {
      const response = await ngaApi.getFavoriteTopics(this.page);
      if (response.code === 200 && response.data != null) {
        if (refresh) { this.topics = response.data.topics; }
        else {
          for (let i = 0; i < response.data.topics.length; i++) {
            this.topics.push(response.data.topics[i]);
          }
        }
        this.hasMore = response.data.hasMore;
        this.loadingState = this.topics.length > 0 ? LoadingState.SUCCESS : LoadingState.EMPTY;
      } else { this.loadingState = LoadingState.ERROR; }
    } catch (err) {
      this.loadingState = LoadingState.ERROR;
    } finally { this.isLoadingMore = false; }
  }

  build() {
    Column() {
      Row() {
        Text('\u{276E}').fontSize(22).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })
        Text('我的收藏').fontSize(FontSize.LARGE).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).margin({ left: 4 })
        Blank()
        Text('\u{1F504}').fontSize(18).width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { this.loadFavorites(); })
      }
      .width('100%').height(56).padding({ left: 8, right: 8 })
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
            .margin({ top: 16 }).onClick(() => { this.loadFavorites(); })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.EMPTY) {
        Column() {
          Text(userManager.isLoggedIn() ? '暂无收藏' : '请先登录')
            .fontSize(FontSize.MEDIUM).fontColor(ThemeColors.TEXT_HINT_LIGHT)
          if (!userManager.isLoggedIn()) {
            Button('去登录').fontSize(FontSize.NORMAL).fontColor('#FFFFFF').backgroundColor(ThemeColors.PRIMARY)
              .borderRadius(BorderRadius.EXTRA_LARGE).height(40).padding({ left: 24, right: 24 })
              .margin({ top: 16 }).onClick(() => { router.pushUrl({ url: 'pages/login/LoginPage' }); })
          }
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.topics, (topic: Topic) => {
            ListItem() {
              Column() {
                Text(topic.subject).fontSize(FontSize.MEDIUM).fontWeight(FontWeight.Medium)
                  .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).maxLines(2).width('100%')
                Row() {
                  Text(topic.author.username || '匿名').fontSize(FontSize.SMALL)
                    .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
                  Text(topic.getFormattedTime()).fontSize(FontSize.EXTRA_SMALL)
                    .fontColor(ThemeColors.TEXT_HINT_LIGHT).margin({ left: 12 })
                  Blank()
                  Text('\u{1F4AC} ' + topic.replies).fontSize(FontSize.SMALL)
                    .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                }.width('100%').margin({ top: 8 })
              }
              .width('100%').padding(16)
              .backgroundColor(ThemeColors.CARD_BG).borderRadius(BorderRadius.MEDIUM)
              .margin({ bottom: 8 })
              .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/article/ArticleListPage',
                  params: { tid: topic.tid, title: topic.subject } });
              })
            }
          })
          if (this.hasMore) {
            ListItem() {
              Row() {
                LoadingProgress().width(20).height(20).color(ThemeColors.PRIMARY)
                Text('加载更多...').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT).margin({ left: 8 })
              }.width('100%').height(50).justifyContent(FlexAlign.Center)
            }
          }
        }
        .layoutWeight(1).width('100%').padding({ left: 16, right: 16, top: 8 })
        .divider({ strokeWidth: 0 }).edgeEffect(EdgeEffect.Spring)
        .onReachEnd(() => { if (this.hasMore && !this.isLoadingMore) { this.page++; this.loadFavorites(false); } })
      }
    }
    .width('100%').height('100%').backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }
}
