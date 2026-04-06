import { AppConstants } from './AppConstants';

interface ThemePalette {
  PRIMARY: string;
  PRIMARY_DARK: string;
  PRIMARY_LIGHT: string;
  ACCENT: string;
  BACKGROUND_LIGHT: string;
  BACKGROUND_DARK: string;
  SURFACE_LIGHT: string;
  SURFACE_DARK: string;
  CARD_BG: string;
  TEXT_PRIMARY_LIGHT: string;
  TEXT_PRIMARY_DARK: string;
  TEXT_SECONDARY_LIGHT: string;
  TEXT_SECONDARY_DARK: string;
  TEXT_HINT_LIGHT: string;
  TEXT_HINT_DARK: string;
  DIVIDER_LIGHT: string;
  DIVIDER_DARK: string;
  SUCCESS: string;
  WARNING: string;
  ERROR: string;
  INFO: string;
  GRADIENT_START: string;
  GRADIENT_END: string;
  BADGE_BG: string;
  LIKE_COLOR: string;
  TAG_BG: string;
  TAG_TEXT: string;
  SEARCH_BG: string;
  ICON_ACTIVE: string;
  ICON_INACTIVE: string;
  SKELETON_BG: string;
  OVERLAY_BG: string;
}

/**
 * 现代化主题配色 - 灵感源自小红书 / 现代社交应用
 */
export class ThemeColors {
  /** 中文/多语言昵称优先使用系统无衬线字体，避免非拉丁字符显示为空白或方框 */
  static readonly FONT_FAMILY_UI: string = 'HarmonyOS Sans SC, HarmonyOS Sans, PingFang SC, Noto Sans CJK SC, sans-serif';

  private static readonly CLASSIC_PALETTE: ThemePalette = {
    PRIMARY: '#FF2442',
    PRIMARY_DARK: '#E01E3C',
    PRIMARY_LIGHT: '#FFE8EC',
    ACCENT: '#FF6B81',
    BACKGROUND_LIGHT: '#F5F6FA',
    BACKGROUND_DARK: '#121212',
    SURFACE_LIGHT: '#FFFFFF',
    SURFACE_DARK: '#1E1E1E',
    CARD_BG: '#FFFFFF',
    TEXT_PRIMARY_LIGHT: '#1A1A2E',
    TEXT_PRIMARY_DARK: '#FFFFFF',
    TEXT_SECONDARY_LIGHT: '#6B7280',
    TEXT_SECONDARY_DARK: '#B0B0B0',
    TEXT_HINT_LIGHT: '#9CA3AF',
    TEXT_HINT_DARK: '#6E6E6E',
    DIVIDER_LIGHT: '#F0F0F5',
    DIVIDER_DARK: '#333333',
    SUCCESS: '#10B981',
    WARNING: '#F59E0B',
    ERROR: '#EF4444',
    INFO: '#3B82F6',
    GRADIENT_START: '#FF2442',
    GRADIENT_END: '#FF6B81',
    BADGE_BG: '#FF2442',
    LIKE_COLOR: '#FF2442',
    TAG_BG: '#FFF0F3',
    TAG_TEXT: '#FF2442',
    SEARCH_BG: '#F0F1F5',
    ICON_ACTIVE: '#FF2442',
    ICON_INACTIVE: '#9CA3AF',
    SKELETON_BG: '#E5E7EB',
    OVERLAY_BG: '#00000066'
  };

  private static readonly CREAM_PALETTE: ThemePalette = {
    PRIMARY: '#B8842F',
    PRIMARY_DARK: '#986C1F',
    PRIMARY_LIGHT: '#F7E7B2',
    ACCENT: '#D3A04A',
    BACKGROUND_LIGHT: '#FFF8E9',
    BACKGROUND_DARK: '#2D2516',
    SURFACE_LIGHT: '#FFFDF6',
    SURFACE_DARK: '#3B311D',
    CARD_BG: '#FFFCF3',
    TEXT_PRIMARY_LIGHT: '#4D3917',
    TEXT_PRIMARY_DARK: '#FFF9EA',
    TEXT_SECONDARY_LIGHT: '#7A6540',
    TEXT_SECONDARY_DARK: '#D7C59A',
    TEXT_HINT_LIGHT: '#A18D63',
    TEXT_HINT_DARK: '#B6A06C',
    DIVIDER_LIGHT: '#F0E1B8',
    DIVIDER_DARK: '#5E4E2A',
    SUCCESS: '#5E9D63',
    WARNING: '#D29128',
    ERROR: '#C65B3D',
    INFO: '#6D8FCF',
    GRADIENT_START: '#E3C36B',
    GRADIENT_END: '#F3DE9A',
    BADGE_BG: '#C99835',
    LIKE_COLOR: '#C99835',
    TAG_BG: '#FFF0C8',
    TAG_TEXT: '#946116',
    SEARCH_BG: '#FAEFCF',
    ICON_ACTIVE: '#B8842F',
    ICON_INACTIVE: '#B3A078',
    SKELETON_BG: '#EFE0B8',
    OVERLAY_BG: '#00000066'
  };

  private static applyPalette(palette: ThemePalette): void {
    ThemeColors.PRIMARY = palette.PRIMARY;
    ThemeColors.PRIMARY_DARK = palette.PRIMARY_DARK;
    ThemeColors.PRIMARY_LIGHT = palette.PRIMARY_LIGHT;
    ThemeColors.ACCENT = palette.ACCENT;
    ThemeColors.BACKGROUND_LIGHT = palette.BACKGROUND_LIGHT;
    ThemeColors.BACKGROUND_DARK = palette.BACKGROUND_DARK;
    ThemeColors.SURFACE_LIGHT = palette.SURFACE_LIGHT;
    ThemeColors.SURFACE_DARK = palette.SURFACE_DARK;
    ThemeColors.CARD_BG = palette.CARD_BG;
    ThemeColors.TEXT_PRIMARY_LIGHT = palette.TEXT_PRIMARY_LIGHT;
    ThemeColors.TEXT_PRIMARY_DARK = palette.TEXT_PRIMARY_DARK;
    ThemeColors.TEXT_SECONDARY_LIGHT = palette.TEXT_SECONDARY_LIGHT;
    ThemeColors.TEXT_SECONDARY_DARK = palette.TEXT_SECONDARY_DARK;
    ThemeColors.TEXT_HINT_LIGHT = palette.TEXT_HINT_LIGHT;
    ThemeColors.TEXT_HINT_DARK = palette.TEXT_HINT_DARK;
    ThemeColors.DIVIDER_LIGHT = palette.DIVIDER_LIGHT;
    ThemeColors.DIVIDER_DARK = palette.DIVIDER_DARK;
    ThemeColors.SUCCESS = palette.SUCCESS;
    ThemeColors.WARNING = palette.WARNING;
    ThemeColors.ERROR = palette.ERROR;
    ThemeColors.INFO = palette.INFO;
    ThemeColors.GRADIENT_START = palette.GRADIENT_START;
    ThemeColors.GRADIENT_END = palette.GRADIENT_END;
    ThemeColors.BADGE_BG = palette.BADGE_BG;
    ThemeColors.LIKE_COLOR = palette.LIKE_COLOR;
    ThemeColors.TAG_BG = palette.TAG_BG;
    ThemeColors.TAG_TEXT = palette.TAG_TEXT;
    ThemeColors.SEARCH_BG = palette.SEARCH_BG;
    ThemeColors.ICON_ACTIVE = palette.ICON_ACTIVE;
    ThemeColors.ICON_INACTIVE = palette.ICON_INACTIVE;
    ThemeColors.SKELETON_BG = palette.SKELETON_BG;
    ThemeColors.OVERLAY_BG = palette.OVERLAY_BG;
  }

  static applyTheme(theme: string): void {
    if (theme === AppConstants.THEME_CREAM) {
      ThemeColors.applyPalette(ThemeColors.CREAM_PALETTE);
      return;
    }
    ThemeColors.applyPalette(ThemeColors.CLASSIC_PALETTE);
  }

  // 品牌色
  static PRIMARY: string = ThemeColors.CLASSIC_PALETTE.PRIMARY;
  static PRIMARY_DARK: string = ThemeColors.CLASSIC_PALETTE.PRIMARY_DARK;
  static PRIMARY_LIGHT: string = ThemeColors.CLASSIC_PALETTE.PRIMARY_LIGHT;
  static ACCENT: string = ThemeColors.CLASSIC_PALETTE.ACCENT;

  // 背景色
  static BACKGROUND_LIGHT: string = ThemeColors.CLASSIC_PALETTE.BACKGROUND_LIGHT;
  static BACKGROUND_DARK: string = ThemeColors.CLASSIC_PALETTE.BACKGROUND_DARK;
  static SURFACE_LIGHT: string = ThemeColors.CLASSIC_PALETTE.SURFACE_LIGHT;
  static SURFACE_DARK: string = ThemeColors.CLASSIC_PALETTE.SURFACE_DARK;
  static CARD_BG: string = ThemeColors.CLASSIC_PALETTE.CARD_BG;

  // 文字颜色
  static TEXT_PRIMARY_LIGHT: string = ThemeColors.CLASSIC_PALETTE.TEXT_PRIMARY_LIGHT;
  static TEXT_PRIMARY_DARK: string = ThemeColors.CLASSIC_PALETTE.TEXT_PRIMARY_DARK;
  static TEXT_SECONDARY_LIGHT: string = ThemeColors.CLASSIC_PALETTE.TEXT_SECONDARY_LIGHT;
  static TEXT_SECONDARY_DARK: string = ThemeColors.CLASSIC_PALETTE.TEXT_SECONDARY_DARK;
  static TEXT_HINT_LIGHT: string = ThemeColors.CLASSIC_PALETTE.TEXT_HINT_LIGHT;
  static TEXT_HINT_DARK: string = ThemeColors.CLASSIC_PALETTE.TEXT_HINT_DARK;

  // 分割线颜色
  static DIVIDER_LIGHT: string = ThemeColors.CLASSIC_PALETTE.DIVIDER_LIGHT;
  static DIVIDER_DARK: string = ThemeColors.CLASSIC_PALETTE.DIVIDER_DARK;

  // 状态颜色
  static SUCCESS: string = ThemeColors.CLASSIC_PALETTE.SUCCESS;
  static WARNING: string = ThemeColors.CLASSIC_PALETTE.WARNING;
  static ERROR: string = ThemeColors.CLASSIC_PALETTE.ERROR;
  static INFO: string = ThemeColors.CLASSIC_PALETTE.INFO;

  // 渐变 & 特殊颜色
  static GRADIENT_START: string = ThemeColors.CLASSIC_PALETTE.GRADIENT_START;
  static GRADIENT_END: string = ThemeColors.CLASSIC_PALETTE.GRADIENT_END;
  static BADGE_BG: string = ThemeColors.CLASSIC_PALETTE.BADGE_BG;
  static LIKE_COLOR: string = ThemeColors.CLASSIC_PALETTE.LIKE_COLOR;
  static TAG_BG: string = ThemeColors.CLASSIC_PALETTE.TAG_BG;
  static TAG_TEXT: string = ThemeColors.CLASSIC_PALETTE.TAG_TEXT;
  static SEARCH_BG: string = ThemeColors.CLASSIC_PALETTE.SEARCH_BG;
  static ICON_ACTIVE: string = ThemeColors.CLASSIC_PALETTE.ICON_ACTIVE;
  static ICON_INACTIVE: string = ThemeColors.CLASSIC_PALETTE.ICON_INACTIVE;
  static SKELETON_BG: string = ThemeColors.CLASSIC_PALETTE.SKELETON_BG;
  static OVERLAY_BG: string = ThemeColors.CLASSIC_PALETTE.OVERLAY_BG;
}

/**
 * 字体大小配置
 */
export class FontSize {
  static EXTRA_SMALL: number = 10;
  static SMALL: number = 11;
  static NORMAL: number = 13;
  static MEDIUM: number = 15;
  static LARGE: number = 17;
  static EXTRA_LARGE: number = 20;
  static TITLE: number = 22;
  static LARGE_TITLE: number = 26;

  static ARTICLE_SMALL: number = 14;
  static ARTICLE_NORMAL: number = 16;
  static ARTICLE_LARGE: number = 18;
  static ARTICLE_EXTRA_LARGE: number = 20;

  static applyLevel(level: string): void {
    let uiDelta = 0;
    let articleDelta = 0;
    switch (level) {
      case 'small':
        uiDelta = -2;
        articleDelta = -3;
        break;
      case 'large':
        uiDelta = 2;
        articleDelta = 3;
        break;
      default:
        uiDelta = 0;
        articleDelta = 0;
        break;
    }

    FontSize.EXTRA_SMALL = Math.max(8, 10 + uiDelta);
    FontSize.SMALL = Math.max(9, 11 + uiDelta);
    FontSize.NORMAL = Math.max(11, 13 + uiDelta);
    FontSize.MEDIUM = Math.max(13, 15 + uiDelta);
    FontSize.LARGE = Math.max(15, 17 + uiDelta);
    FontSize.EXTRA_LARGE = Math.max(18, 20 + uiDelta);
    FontSize.TITLE = Math.max(20, 22 + uiDelta);
    FontSize.LARGE_TITLE = Math.max(24, 26 + uiDelta);

    FontSize.ARTICLE_SMALL = Math.max(11, 14 + articleDelta);
    FontSize.ARTICLE_NORMAL = Math.max(13, 16 + articleDelta);
    FontSize.ARTICLE_LARGE = Math.max(15, 18 + articleDelta);
    FontSize.ARTICLE_EXTRA_LARGE = Math.max(17, 20 + articleDelta);
  }
}

/**
 * 间距配置
 */
export class Spacing {
  static readonly EXTRA_SMALL: number = 4;
  static readonly SMALL: number = 8;
  static readonly NORMAL: number = 12;
  static readonly MEDIUM: number = 16;
  static readonly LARGE: number = 20;
  static readonly EXTRA_LARGE: number = 24;
  static readonly XX_LARGE: number = 32;
}

/**
 * 圆角配置
 */
export class BorderRadius {
  static readonly SMALL: number = 6;
  static readonly NORMAL: number = 10;
  static readonly MEDIUM: number = 14;
  static readonly LARGE: number = 20;
  static readonly EXTRA_LARGE: number = 24;
  static readonly CIRCLE: number = 9999;
}
