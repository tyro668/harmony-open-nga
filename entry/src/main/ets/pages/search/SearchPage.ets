import router from '@ohos.router';
import { Topic } from '../../model/entity/Topic';
import { ngaApi } from '../../network/api/NgaApi';
import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';
import { LoadingState } from '../../ui/components/CommonComponents';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';

@Entry
@Component
struct SearchPage {
  @State searchText: string = '';
  @State topics: Topic[] = [];
  @State searchHistory: string[] = [];
  @State loadingState: LoadingState = LoadingState.SUCCESS;
  @State hasSearched: boolean = false;

  private readonly MAX_HISTORY: number = 20;
  private readonly KEY_SEARCH_HISTORY: string = 'search_history';

  aboutToAppear() {
    this.loadSearchHistory();
  }

  async loadSearchHistory() {
    try {
      const jsonStr = await PreferencesManager.getInstance().getString(this.KEY_SEARCH_HISTORY);
      if (jsonStr != '') {
        this.searchHistory = JSON.parse(jsonStr);
      }
    } catch (err) {
      console.error('Load search history failed:', err);
    }
  }

  async saveSearchHistory() {
    try {
      await PreferencesManager.getInstance().putString(this.KEY_SEARCH_HISTORY, JSON.stringify(this.searchHistory));
    } catch (err) {
      console.error('Save search history failed:', err);
    }
  }

  async doSearch() {
    if (this.searchText.trim() === '') return;
    const keyword = this.searchText.trim();
    const index = this.searchHistory.indexOf(keyword);
    if (index >= 0) this.searchHistory.splice(index, 1);
    this.searchHistory.unshift(keyword);
    if (this.searchHistory.length > this.MAX_HISTORY) {
      this.searchHistory = this.searchHistory.slice(0, this.MAX_HISTORY);
    }
    await this.saveSearchHistory();

    this.hasSearched = true;
    this.loadingState = LoadingState.LOADING;
    try {
      const response = await ngaApi.getTopicList(0, 1);
      if (response.code === 200 && response.data != null) {
        this.topics = response.data.topics;
        this.loadingState = this.topics.length > 0 ? LoadingState.SUCCESS : LoadingState.EMPTY;
      } else {
        this.loadingState = LoadingState.ERROR;
      }
    } catch (err) {
      this.loadingState = LoadingState.ERROR;
    }
  }

  build() {
    Column() {
      // 顶部搜索栏
      Row() {
        Text('\u{276E}')
          .fontSize(22)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })

        TextInput({ placeholder: '搜索帖子、用户...', text: this.searchText })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(ThemeColors.SEARCH_BG)
          .borderRadius(BorderRadius.EXTRA_LARGE)
          .fontSize(FontSize.NORMAL)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => { this.searchText = value; })
          .onSubmit(() => { this.doSearch(); })

        Text('搜索')
          .fontSize(FontSize.NORMAL)
          .fontColor(ThemeColors.PRIMARY)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 })
          .onClick(() => { this.doSearch(); })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      if (!this.hasSearched) {
        Scroll() {
          Column() {
            // 搜索历史
            if (this.searchHistory.length > 0) {
              Row() {
                Text('搜索历史')
                  .fontSize(FontSize.MEDIUM)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                Blank()
                Text('清空')
                  .fontSize(FontSize.NORMAL)
                  .fontColor(ThemeColors.PRIMARY)
                  .onClick(() => {
                    this.searchHistory = [];
                    this.saveSearchHistory();
                  })
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 20 })

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.searchHistory, (keyword: string) => {
                  Text(keyword)
                    .fontSize(FontSize.NORMAL)
                    .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                    .backgroundColor(ThemeColors.SEARCH_BG)
                    .borderRadius(BorderRadius.EXTRA_LARGE)
                    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .margin({ left: 8, top: 10 })
                    .onClick(() => {
                      this.searchText = keyword;
                      this.doSearch();
                    })
                })
              }
              .width('100%')
              .padding({ left: 12, right: 20 })
            }

            // 热门搜索
            Row() {
              Text('热门搜索')
                .fontSize(FontSize.MEDIUM)
                .fontWeight(FontWeight.Bold)
                .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
            }
            .width('100%')
            .padding({ left: 20, top: 28 })

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(['原神', '崩坏星穹铁道', '绝区零', '魔兽世界', '英雄联盟', '明日方舟'], (keyword: string) => {
                Text(keyword)
                  .fontSize(FontSize.NORMAL)
                  .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                  .backgroundColor(ThemeColors.SEARCH_BG)
                  .borderRadius(BorderRadius.EXTRA_LARGE)
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .margin({ left: 8, top: 10 })
                  .onClick(() => {
                    this.searchText = keyword;
                    this.doSearch();
                  })
              })
            }
            .width('100%')
            .padding({ left: 12, right: 20 })
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else if (this.loadingState === LoadingState.LOADING) {
        Column() {
          LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
          Text('搜索中...').fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_HINT_LIGHT).margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.EMPTY) {
        Column() {
          Text('未找到相关结果')
            .fontSize(FontSize.MEDIUM)
            .fontColor(ThemeColors.TEXT_HINT_LIGHT)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadingState === LoadingState.ERROR) {
        Column() {
          Text('搜索失败')
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
            .onClick(() => { this.doSearch(); })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.topics, (topic: Topic) => {
            ListItem() {
              Column() {
                Text(topic.subject)
                  .fontSize(FontSize.MEDIUM)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
                  .maxLines(2)
                  .width('100%')

                Row() {
                  Text(topic.author.username || '匿名')
                    .fontSize(FontSize.SMALL)
                    .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
                  Text(topic.getFormattedTime())
                    .fontSize(FontSize.EXTRA_SMALL)
                    .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                    .margin({ left: 12 })
                  Blank()
                  Text('\u{1F4AC} ' + topic.replies)
                    .fontSize(FontSize.SMALL)
                    .fontColor(ThemeColors.TEXT_HINT_LIGHT)
                }
                .width('100%')
                .margin({ top: 8 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(ThemeColors.CARD_BG)
              .borderRadius(BorderRadius.MEDIUM)
              .margin({ bottom: 8 })
              .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/article/ArticleListPage', params: { tid: topic.tid } });
              })
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
        .divider({ strokeWidth: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }
}
