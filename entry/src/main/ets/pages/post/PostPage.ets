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
  @StorageLink('pref_theme') appTheme: string = 'classic';
  @StorageLink('pref_font_size') fontSizeLevel: string = 'normal';
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
      const httpClient = HttpClient.getInstance();

      const bodyParts: string[] = [];
      bodyParts.push('step=2');

      if (this.postType === 'new') {
        bodyParts.push('action=new');
        bodyParts.push('fid=' + this.fid);
        bodyParts.push('post_subject=' + encodeURIComponent(this.subject));
      } else if (this.postType === 'reply') {
        bodyParts.push('action=reply');
        bodyParts.push('tid=' + this.tid);
      } else {
        bodyParts.push('action=modify');
        bodyParts.push('tid=' + this.tid);
        bodyParts.push('pid=' + this.pid);
      }

      bodyParts.push('post_content=' + encodeURIComponent(this.content));
      if (this.isAnonymous) bodyParts.push('anony=1');

      const postBody = bodyParts.join('&');
      const response = await httpClient.post('/post.php?__output=11', postBody);

      const body = response.raw || '';
      let hasError = false;

      try {
        let jsonStr = body;
        const prefixTag = 'window.script_muti_get_var_store=';
        const prefixIdx = jsonStr.indexOf(prefixTag);
        if (prefixIdx >= 0) {
          jsonStr = jsonStr.substring(prefixIdx + prefixTag.length);
        }
        const jsonObj = JSON.parse(jsonStr) as Record<string, Object>;
        const errorField = jsonObj['error'];
        if (errorField != null) {
          if (Array.isArray(errorField)) {
            const errArr = errorField as Object[];
            if (errArr.length > 0 && errArr[0] != null && String(errArr[0]) !== '') {
              hasError = true;
            }
          } else if (typeof errorField === 'object') {
            const errObj = errorField as Record<string, Object>;
            if (errObj['0'] != null && String(errObj['0']) !== '') {
              hasError = true;
            }
          }
        }
      } catch (e) {
        hasError = body.indexOf('\u53D1\u8D34\u5B8C\u6BD5') < 0;
      }

      if (response.code === 200 && !hasError) {
        router.back();
      } else {
        console.error('Post failed, response: ' + body.substring(0, 300));
      }
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
    .width('100%').height('100%').opacity(this.appTheme.length > 0 ? 1 : 1).backgroundColor(ThemeColors.BACKGROUND_LIGHT)
  }

  @Builder
  ToolBtn(icon: string) {
    Text(icon).fontSize(18).fontColor(ThemeColors.TEXT_SECONDARY_LIGHT)
      .width(40).height(40).textAlign(TextAlign.Center)
  }
}
