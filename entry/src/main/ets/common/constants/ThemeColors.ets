/**
 * 现代化主题配色 - 灵感源自小红书 / 现代社交应用
 */
export class ThemeColors {
  // 品牌色
  static readonly PRIMARY: string = '#FF2442';
  static readonly PRIMARY_DARK: string = '#E01E3C';
  static readonly PRIMARY_LIGHT: string = '#FFE8EC';
  static readonly ACCENT: string = '#FF6B81';

  // 背景色
  static readonly BACKGROUND_LIGHT: string = '#F5F6FA';
  static readonly BACKGROUND_DARK: string = '#121212';
  static readonly SURFACE_LIGHT: string = '#FFFFFF';
  static readonly SURFACE_DARK: string = '#1E1E1E';
  static readonly CARD_BG: string = '#FFFFFF';

  // 文字颜色
  static readonly TEXT_PRIMARY_LIGHT: string = '#1A1A2E';
  static readonly TEXT_PRIMARY_DARK: string = '#FFFFFF';
  static readonly TEXT_SECONDARY_LIGHT: string = '#6B7280';
  static readonly TEXT_SECONDARY_DARK: string = '#B0B0B0';
  static readonly TEXT_HINT_LIGHT: string = '#9CA3AF';
  static readonly TEXT_HINT_DARK: string = '#6E6E6E';

  // 分割线颜色
  static readonly DIVIDER_LIGHT: string = '#F0F0F5';
  static readonly DIVIDER_DARK: string = '#333333';

  // 状态颜色
  static readonly SUCCESS: string = '#10B981';
  static readonly WARNING: string = '#F59E0B';
  static readonly ERROR: string = '#EF4444';
  static readonly INFO: string = '#3B82F6';

  // 渐变 & 特殊颜色
  static readonly GRADIENT_START: string = '#FF2442';
  static readonly GRADIENT_END: string = '#FF6B81';
  static readonly BADGE_BG: string = '#FF2442';
  static readonly LIKE_COLOR: string = '#FF2442';
  static readonly TAG_BG: string = '#FFF0F3';
  static readonly TAG_TEXT: string = '#FF2442';
  static readonly SEARCH_BG: string = '#F0F1F5';
  static readonly ICON_ACTIVE: string = '#FF2442';
  static readonly ICON_INACTIVE: string = '#9CA3AF';
  static readonly SKELETON_BG: string = '#E5E7EB';
  static readonly OVERLAY_BG: string = '#00000066';
}

/**
 * 字体大小配置
 */
export class FontSize {
  static readonly EXTRA_SMALL: number = 10;
  static readonly SMALL: number = 11;
  static readonly NORMAL: number = 13;
  static readonly MEDIUM: number = 15;
  static readonly LARGE: number = 17;
  static readonly EXTRA_LARGE: number = 20;
  static readonly TITLE: number = 22;
  static readonly LARGE_TITLE: number = 26;

  static readonly ARTICLE_SMALL: number = 14;
  static readonly ARTICLE_NORMAL: number = 16;
  static readonly ARTICLE_LARGE: number = 18;
  static readonly ARTICLE_EXTRA_LARGE: number = 20;
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
