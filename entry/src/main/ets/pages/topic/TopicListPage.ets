import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';
import { Topic } from '../../model/entity/Topic';
import { ngaApi } from '../../network/api/NgaApi';
import { LoadingState } from '../../ui/components/CommonComponents';
import router from '@ohos.router';

@Entry
@Component
struct TopicListPage {
  @State topics: Topic[] = [];
  @State boardName: string = '帖子列表';
  @State fid: number = 0;
  @State stid: number = 0;
  @State page: number = 1;
  @State totalPages: number = 1;
  @State loadingState: LoadingState = LoadingState.LOADING;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = false;
  @State errorMsg: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params != null) {
      const fidParam = params['fid'];
      if (fidParam != null) {
        this.fid = parseInt(String(fidParam));
      }
      const stidParam = params['stid'];
      if (stidParam != null) {
        this.stid = parseInt(String(stidParam));
      }
      const nameParam = params['name'];
      if (nameParam != null) {
        this.boardName = String(nameParam);
      }
    }
    this.loadTopics();
  }

  async loadTopics(refresh: boolean = true) {
    if (refresh) {
      this.page = 1;
      this.loadingState = LoadingState.LOADING;
    } else {
      this.isLoadingMore = true;
    }

    try {
      const response = await ngaApi.getTopicList(this.fid, this.page, this.stid);
      if (response.code === 200 && response.data) {
        const topicList = response.data;
        if (topicList.errorMsg) {
          this.errorMsg = topicList.errorMsg;
          if (refresh) {
            this.loadingState = LoadingState.ERROR;
          }
          return;
        }
        if (refresh) {
          this.topics = topicList.topics;
        } else {
          for (let i = 0; i < topicList.topics.length; i++) {
            this.topics.push(topicList.topics[i]);
          }
        }
        this.totalPages = topicList.totalPages;
        this.hasMore = topicList.hasMore;
        this.loadingState = this.topics.length > 0 ? LoadingState.SUCCESS : LoadingState.EMPTY;
      } else {
        this.errorMsg = response.message || '加载失败';
        if (refresh) {
          this.loadingState = LoadingState.ERROR;
        }
      }
    } catch (error) {
      console.error('Load topics failed:', error);
      this.errorMsg = '网络错误';
      if (refresh) {
        this.loadingState = LoadingState.ERROR;
      }
    } finally {
      this.isLoadingMore = false;
    }
  }

  loadMore() {
    if (this.hasMore && !this.isLoadingMore) {
      this.page++;
      this.loadTopics(false);
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('\u{276E}')
          .fontSize(22)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .borderRadius(BorderRadius.CIRCLE)
          .onClick(() => { router.back(); })

        Text(this.boardName)
          .fontSize(FontSize.LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 4 })

        Text('\u{1F504}')
          .fontSize(18)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.loadTopics(); })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      // 内容区域
      if (this.loadingState === LoadingState.LOADING) {
        Column() {
          LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
          Text('正在加载...').fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.ERROR) {
        Column() {
          Text('Oops!')
            .fontSize(FontSize.EXTRA_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          Text(this.errorMsg || '加载失败')
            .fontSize(FontSize.NORMAL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
          Button('重新加载')
            .fontSize(FontSize.NORMAL)
            .fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .height(40)
            .padding({ left: 24, right: 24 })
            .margin({ top: 20 })
            .onClick(() => { this.loadTopics(); })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.EMPTY) {
        Column() {
          Text('暂无帖子')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.topics, (topic: Topic) => {
            ListItem() {
              this.TopicCard(topic);
            }
          })

          if (this.hasMore) {
            ListItem() {
              Row() {
                if (this.isLoadingMore) {
                  LoadingProgress().width(20).height(20).color(ThemeColors.PRIMARY)
                  Text('加载中...').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                    .margin({ left: 8 })
                } else {
                  Text('上拉加载更多').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                }
              }
              .width('100%')
              .height(50)
              .justifyContent(FlexAlign.Center)
            }
          } else if (this.topics.length > 0) {
            ListItem() {
              Text('\u2014 \u5DF2\u7ECF\u5230\u5E95\u4E86 \u2014')
                .fontSize(FontSize.SMALL)
                .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(20)
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
        .edgeEffect(EdgeEffect.Spring)
        .divider({ strokeWidth: 0 })
        .onReachEnd(() => { this.loadMore(); })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  @Builder
  TopicCard(topic: Topic) {
    Column() {
      // 标题
      Text(topic.subject)
        .fontSize(FontSize.MEDIUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(22)
        .width('100%')

      // 底部信息
      Row() {
        Row() {
          Stack() {
            Circle().width(20).height(20).fill(ThemeColors.PRIMARY_LIGHT)
            Text((topic.author.username || '?').substring(0, 1))
              .fontSize(9)
              .fontColor(ThemeColors.PRIMARY)
              .fontWeight(FontWeight.Bold)
          }
          Text(topic.author.username || '匿名')
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
            .margin({ left: 6 })
        }

        Text(topic.getFormattedTime())
          .fontSize(FontSize.EXTRA_SMALL)
          .fontColor(ThemeColors.TEXT_HINT_LIGHT)
          .margin({ left: 12 })

        Blank()

        Row() {
          Text('\u{1F4AC}')
            .fontSize(11)
          Text('' + topic.replies)
            .fontSize(FontSize.SMALL)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ left: 3 })
        }
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ThemeColors.CARD_BG)
    .borderRadius(BorderRadius.MEDIUM)
    .margin({ bottom: 8 })
    .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/article/ArticleListPage',
        params: { tid: topic.tid, title: topic.subject }
      });
    })
  }
}
