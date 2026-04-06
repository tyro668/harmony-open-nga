import { AppConstants } from '../constants/AppConstants';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { ThemeColors } from '../constants/ThemeColors';

/**
 * 应用主题管理
 */
export class ThemeManager {
  static readonly STORAGE_KEY: string = AppConstants.PREF_THEME;
  static readonly DEFAULT_THEME: string = AppConstants.THEME_CLASSIC;

  static bootstrap(): void {
    AppStorage.SetOrCreate(ThemeManager.STORAGE_KEY, ThemeManager.DEFAULT_THEME);
  }

  static async init(): Promise<void> {
    ThemeManager.bootstrap();
    const savedTheme = await PreferencesManager.getInstance().getString(ThemeManager.STORAGE_KEY, ThemeManager.DEFAULT_THEME);
    const normalizedTheme = ThemeManager.normalizeTheme(savedTheme);
    ThemeColors.applyTheme(normalizedTheme);
    AppStorage.Set(ThemeManager.STORAGE_KEY, normalizedTheme);
    if (savedTheme !== normalizedTheme) {
      await PreferencesManager.getInstance().putString(ThemeManager.STORAGE_KEY, normalizedTheme);
    }
  }

  static getCurrentTheme(): string {
    ThemeManager.bootstrap();
    const theme: string | undefined = AppStorage.Get<string>(ThemeManager.STORAGE_KEY);
    return ThemeManager.normalizeTheme(theme != null ? String(theme) : ThemeManager.DEFAULT_THEME);
  }

  static async setTheme(theme: string): Promise<void> {
    const normalizedTheme = ThemeManager.normalizeTheme(theme);
    ThemeManager.bootstrap();
    ThemeColors.applyTheme(normalizedTheme);
    AppStorage.Set(ThemeManager.STORAGE_KEY, normalizedTheme);
    await PreferencesManager.getInstance().putString(ThemeManager.STORAGE_KEY, normalizedTheme);
  }

  static normalizeTheme(theme: string): string {
    switch (theme) {
      case AppConstants.THEME_CLASSIC:
      case AppConstants.THEME_CREAM:
        return theme;
      case AppConstants.THEME_LIGHT:
      case AppConstants.THEME_DARK:
      case AppConstants.THEME_SYSTEM:
      default:
        return ThemeManager.DEFAULT_THEME;
    }
  }
}
