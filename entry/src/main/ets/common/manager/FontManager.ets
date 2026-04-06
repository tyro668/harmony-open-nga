import { AppConstants } from '../constants/AppConstants';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';
import { FontSize } from '../constants/ThemeColors';

export class FontManager {
  static readonly STORAGE_KEY: string = AppConstants.PREF_FONT_SIZE;
  static readonly DEFAULT_LEVEL: string = 'normal';

  static bootstrap(): void {
    AppStorage.SetOrCreate(FontManager.STORAGE_KEY, FontManager.DEFAULT_LEVEL);
  }

  static async init(): Promise<void> {
    FontManager.bootstrap();
    const savedLevel = await PreferencesManager.getInstance().getString(FontManager.STORAGE_KEY, FontManager.DEFAULT_LEVEL);
    const normalizedLevel = FontManager.normalizeLevel(savedLevel);
    FontSize.applyLevel(normalizedLevel);
    AppStorage.Set(FontManager.STORAGE_KEY, normalizedLevel);
    if (savedLevel !== normalizedLevel) {
      await PreferencesManager.getInstance().putString(FontManager.STORAGE_KEY, normalizedLevel);
    }
  }

  static getCurrentLevel(): string {
    FontManager.bootstrap();
    const level: string | undefined = AppStorage.Get<string>(FontManager.STORAGE_KEY);
    return FontManager.normalizeLevel(level != null ? String(level) : FontManager.DEFAULT_LEVEL);
  }

  static async setLevel(level: string): Promise<void> {
    const normalizedLevel = FontManager.normalizeLevel(level);
    FontManager.bootstrap();
    FontSize.applyLevel(normalizedLevel);
    AppStorage.Set(FontManager.STORAGE_KEY, normalizedLevel);
    await PreferencesManager.getInstance().putString(FontManager.STORAGE_KEY, normalizedLevel);
  }

  static normalizeLevel(level: string): string {
    switch (level) {
      case 'small':
      case 'large':
      case 'normal':
        return level;
      default:
        return FontManager.DEFAULT_LEVEL;
    }
  }
}
