import router from '@ohos.router';
import { Topic } from '../../model/entity/Topic';
import { User } from '../../model/entity/User';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { ThemeColors, FontSize, BorderRadius } from '../../common/constants/ThemeColors';

/**
 * 浏览历史页面
 */
@Entry
@Component
struct HistoryPage {
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
  @State topics: Topic[] = [];
  @State isLoading: boolean = true;
  @State errorMsg: string = '';

  private readonly MAX_HISTORY: number = 100;
  private readonly KEY_HISTORY: string = 'topic_history';

  aboutToAppear() {
    console.info('HistoryPage aboutToAppear');
    this.loadHistory();
  }

  async loadHistory() {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      console.info('Loading history from preferences...');
      const jsonStr = await PreferencesManager.getInstance().getString(this.KEY_HISTORY);
      console.info('History jsonStr length: ' + jsonStr.length);
      if (jsonStr != '' && jsonStr.length > 2) {
        const parsed = JSON.parse(jsonStr) as Array<Record<string, Object>>;
        this.topics = this.restoreTopics(parsed);
        console.info('Loaded ' + this.topics.length + ' history items');
      } else {
        this.topics = [];
        console.info('No history items found');
      }
    } catch (err) {
      console.error('Load history failed:', err);
      this.errorMsg = '加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  async saveHistory() {
    try { await PreferencesManager.getInstance().putString(this.KEY_HISTORY, JSON.stringify(this.topics)); }
    catch (err) { console.error('Save history failed:', err); }
  }

  async removeHistory(index: number) { this.topics.splice(index, 1); await this.saveHistory(); }
  async clearHistory() { this.topics = []; await this.saveHistory(); }

  private restoreTopics(items: Array<Record<string, Object>>): Topic[] {
    const restored: Topic[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (item == null || typeof item !== 'object') {
        continue;
      }

      const topic = new Topic();
      topic.tid = item['tid'] != null ? String(item['tid']) : '';
      topic.fid = item['fid'] != null ? String(item['fid']) : '';
      topic.forumName = item['forumName'] != null ? String(item['forumName']) : '';
      topic.subject = item['subject'] != null ? String(item['subject']) : '';
      topic.content = item['content'] != null ? String(item['content']) : '';
      topic.postDate = item['postDate'] != null ? String(item['postDate']) : '';
      topic.lastPostDate = item['lastPostDate'] != null ? String(item['lastPostDate']) : '';
      topic.replies = item['replies'] != null ? Number(item['replies']) : 0;
      topic.views = item['views'] != null ? Number(item['views']) : 0;
      topic.likes = item['likes'] != null ? Number(item['likes']) : 0;
      topic.isTop = item['isTop'] === true;
      topic.isDigest = item['isDigest'] === true;
      topic.isHot = item['isHot'] === true;
      topic.isClosed = item['isClosed'] === true;
      topic.hasAttachment = item['hasAttachment'] === true;
      topic.hasImage = item['hasImage'] === true;
      topic.lastPoster = item['lastPoster'] != null ? String(item['lastPoster']) : '';
      topic.page = item['page'] != null ? Number(item['page']) : 1;
      topic.totalPages = item['totalPages'] != null ? Number(item['totalPages']) : 1;

      const authorData = item['author'];
      const author = new User();
      if (authorData != null && typeof authorData === 'object' && !Array.isArray(authorData)) {
        const authorObj = authorData as Record<string, Object>;
        author.uid = authorObj['uid'] != null ? String(authorObj['uid']) : '';
        author.username = authorObj['username'] != null ? String(authorObj['username']) : '';
        author.nickname = authorObj['nickname'] != null ? String(authorObj['nickname']) : '';
        author.avatar = authorObj['avatar'] != null ? String(authorObj['avatar']) : '';
      }
      topic.author = author;

      const tagsData = item['tags'];
      if (tagsData != null && Array.isArray(tagsData)) {
        topic.tags = (tagsData as Object[]).map((tag: Object) => String(tag));
      }

      restored.push(topic);
    }
    return restored;
  }

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
    .width('100%').height('100%').opacity(this.appTheme.length > 0 ? 1 : 1).backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }
}
