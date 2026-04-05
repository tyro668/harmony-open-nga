import router from '@ohos.router';
import { Topic } from '../../model/entity/Topic';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';

@Entry
@Component
struct HistoryPage {
  @State topics: Topic[] = [];
  @State isLoading: boolean = true;

  private readonly MAX_HISTORY: number = 100;
  private readonly KEY_HISTORY: string = 'topic_history';

  aboutToAppear() { this.loadHistory(); }

  async loadHistory() {
    this.isLoading = true;
    try {
      const jsonStr = await PreferencesManager.getInstance().getString(this.KEY_HISTORY);
      if (jsonStr != '') this.topics = JSON.parse(jsonStr);
    } catch (err) { console.error('Load history failed:', err); }
    finally { this.isLoading = false; }
  }

  async saveHistory() {
    try { await PreferencesManager.getInstance().putString(this.KEY_HISTORY, JSON.stringify(this.topics)); }
    catch (err) { console.error('Save history failed:', err); }
  }

  async removeHistory(index: number) { this.topics.splice(index, 1); await this.saveHistory(); }
  async clearHistory() { this.topics = []; await this.saveHistory(); }

  build() {
    Column() {
      Row() {
        Text('\u{276E}').fontSize(22).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })
        Text('浏览历史').fontSize(FontSize.LARGE).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).margin({ left: 4 })
        Blank()
        if (this.topics.length > 0) {
          Text('清空').fontSize(FontSize.NORMAL).fontColor(ThemeColors.PRIMARY)
            .onClick(() => { this.clearHistory(); })
        }
      }
      .width('100%').height(56).padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40).color(ThemeColors.PRIMARY)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.topics.length === 0) {
        Column() {
          Text('暂无历史记录').fontSize(FontSize.MEDIUM).fontColor(ThemeColors.TEXT_HINT_LIGHT)
          Text('浏览过的帖子将显示在这里').fontSize(FontSize.SMALL).fontColor(ThemeColors.TEXT_HINT_LIGHT)
            .margin({ top: 6 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.topics, (topic: Topic, index: number) => {
            ListItem() {
              Row() {
                Column() {
                  Text(topic.subject)
                    .fontSize(FontSize.MEDIUM).fontWeight(FontWeight.Medium)
                    .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).maxLines(2).width('100%')
                  Row() {
                    Text(topic.author.username || '匿名').fontSize(FontSize.SMALL)
                      .fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
                    Text(topic.getFormattedTime()).fontSize(FontSize.EXTRA_SMALL)
                      .fontColor(ThemeColors.TEXT_HINT_LIGHT).margin({ left: 12 })
                  }.margin({ top: 6 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                Text('\u{2715}').fontSize(16).fontColor(ThemeColors.TEXT_HINT_LIGHT)
                  .width(36).height(36).textAlign(TextAlign.Center)
                  .onClick(() => { this.removeHistory(index); })
              }
              .width('100%').padding(16)
              .backgroundColor(ThemeColors.CARD_BG).borderRadius(BorderRadius.MEDIUM)
              .margin({ bottom: 8 })
              .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 2 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/article/ArticleListPage', params: { tid: topic.tid } });
              })
            }
          })
        }
        .layoutWeight(1).width('100%').padding({ left: 16, right: 16, top: 8 })
        .divider({ strokeWidth: 0 }).edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%').height('100%').backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }
}
