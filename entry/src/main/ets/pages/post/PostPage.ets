import router from '@ohos.router';
import { HttpClient } from '../../network/api/HttpClient';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { ThemeColors, FontSize, Spacing, BorderRadius } from '../../common/constants/ThemeColors';

class PostDraft {
  subject: string = '';
  content: string = '';
  isAnonymous: boolean = false;
  fid: string = '';
  tid: string = '';
  postType: string = 'new';
}

@Entry
@Component
struct PostPage {
  @State subject: string = '';
  @State content: string = '';
  @State isAnonymous: boolean = false;
  @State isPosting: boolean = false;
  @State fid: string = '';
  @State tid: string = '';
  @State pid: string = '';
  @State postType: string = 'new';

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params != null) {
      if (params['fid'] != null) this.fid = String(params['fid']);
      if (params['tid'] != null) { this.tid = String(params['tid']); this.postType = 'reply'; }
      if (params['pid'] != null) this.pid = String(params['pid']);
      if (params['type'] != null) this.postType = String(params['type']);
    }
  }

  async doPost() {
    if (this.content.trim() === '') return;
    if (this.postType === 'new' && this.subject.trim() === '') return;
    this.isPosting = true;
    try {
      const http = HttpClient.getInstance();
      let url = '/nuke.php?__lib=topic_post&__act=topic_post';
      if (this.postType === 'new') {
        url += '&action=new&fid=' + this.fid + '&subject=' + encodeURIComponent(this.subject);
      } else if (this.postType === 'reply') {
        url += '&action=reply&tid=' + this.tid;
      } else {
        url += '&action=modify&tid=' + this.tid + '&pid=' + this.pid;
      }
      url += '&content=' + encodeURIComponent(this.content);
      if (this.isAnonymous) url += '&anonymous=1';
      const response = await http.get(url);
      if (response.code === 200) router.back();
    } catch (err) {
      console.error('Post failed:', err);
    } finally {
      this.isPosting = false;
    }
  }

  async loadDraft() {
    try {
      const jsonStr = await PreferencesManager.getInstance().getString('post_draft');
      if (jsonStr != '') {
        const draft: PostDraft = JSON.parse(jsonStr);
        this.subject = draft.subject;
        this.content = draft.content;
        this.isAnonymous = draft.isAnonymous;
      }
    } catch (err) { console.error('Load draft failed:', err); }
  }

  getTitle(): string {
    if (this.postType === 'new') return '发帖';
    if (this.postType === 'reply') return '回复';
    return '编辑';
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Text('\u{276E}').fontSize(22).fontColor(ThemeColors.TEXT_PRIMARY_LIGHT)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })

        Text(this.getTitle()).fontSize(FontSize.LARGE).fontWeight(FontWeight.Bold)
          .fontColor(ThemeColors.TEXT_PRIMARY_LIGHT).margin({ left: 4 })

        Blank()

        Text('草稿').fontSize(FontSize.NORMAL).fontColor(ThemeColors.PRIMARY).margin({ right: 16 })
          .onClick(() => { this.loadDraft(); })

        if (this.isPosting) {
          LoadingProgress().width(24).height(24).color(ThemeColors.PRIMARY)
        } else {
          Text('发送')
            .fontSize(FontSize.NORMAL).fontColor('#FFFFFF')
            .backgroundColor(ThemeColors.PRIMARY)
            .borderRadius(BorderRadius.EXTRA_LARGE)
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .onClick(() => { this.doPost(); })
        }
      }
      .width('100%').height(56).padding({ left: 8, right: 16 })
      .backgroundColor(ThemeColors.SURFACE_LIGHT)

      Column() {
        if (this.postType === 'new') {
          TextInput({ placeholder: '请输入标题', text: this.subject })
            .width('100%').height(48).fontSize(FontSize.LARGE).fontWeight(FontWeight.Bold)
            .backgroundColor(Color.Transparent)
            .padding({ left: 20, right: 20 })
            .onChange((value: string) => { this.subject = value; })
          Divider().color(ThemeColors.DIVIDER_LIGHT).margin({ left: 20, right: 20 })
        }

        TextArea({ placeholder: '写点什么...', text: this.content })
          .width('100%').layoutWeight(1)
          .fontSize(FontSize.MEDIUM)
          .backgroundColor(Color.Transparent)
          .padding({ left: 20, right: 20, top: 12 })
          .onChange((value: string) => { this.content = value; })

        // 匿名选项
        Row() {
          Checkbox({ name: 'anonymous', group: 'post' })
            .select(this.isAnonymous)
            .selectedColor(ThemeColors.PRIMARY)
            .onChange((checked: boolean) => { this.isAnonymous = checked; })
          Text('匿名发帖（消耗100铜币）')
            .fontSize(FontSize.NORMAL).fontColor(ThemeColors.TEXT_SECONDARY_LIGHT).margin({ left: 8 })
        }
        .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

        // 工具栏
        Row() {
          this.ToolBtn('\u{1F600}')
          this.ToolBtn('B')
          this.ToolBtn('I')
          this.ToolBtn('U')
          this.ToolBtn('\u{1F517}')
          this.ToolBtn('\u{1F4F7}')
        }
        .width('100%').height(48).backgroundColor(ThemeColors.SEARCH_BG)
        .justifyContent(FlexAlign.SpaceAround)
      }
      .layoutWeight(1)
      .backgroundColor(ThemeColors.SURFACE_LIGHT)
    }
    .width('100%').height('100%').backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  @Builder
  ToolBtn(icon: string) {
    Text(icon).fontSize(18).fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
      .width(40).height(40).textAlign(TextAlign.Center)
  }
}
