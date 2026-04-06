import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { PreferencesManager } from '../data/preferences/PreferencesManager';
import { userManager } from '../common/manager/UserManager';
import { ThemeManager } from '../common/manager/ThemeManager';
import { FontManager } from '../common/manager/FontManager';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    // 严格按顺序初始化：Preferences → ThemeManager → FontManager → UserManager → 加载页面
    PreferencesManager.getInstance().init(this.context).then(() => {
      hilog.info(DOMAIN, TAG, 'PreferencesManager initialized');
      return ThemeManager.init();
    }).then(() => {
      hilog.info(DOMAIN, TAG, 'ThemeManager initialized');
      return FontManager.init();
    }).then(() => {
      hilog.info(DOMAIN, TAG, 'FontManager initialized');
      return userManager.init();
    }).then(() => {
      hilog.info(DOMAIN, TAG, 'UserManager initialized, isLoggedIn=%{public}s',
        String(userManager.isLoggedIn()));
      windowStage.loadContent('pages/main/MainPage', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      });
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Init failed: %{public}s', err.message);
      windowStage.loadContent('pages/main/MainPage');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
