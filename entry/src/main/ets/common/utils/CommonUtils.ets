/**
 * 字符串工具类
 */
export class StringUtils {
  /**
   * 判断字符串是否为空
   */
  static isEmpty(str: string | null | undefined): boolean {
    return str === null || str === undefined || str.trim().length === 0;
  }

  /**
   * 判断字符串是否不为空
   */
  static isNotEmpty(str: string | null | undefined): boolean {
    return !StringUtils.isEmpty(str);
  }

  /**
   * 截取字符串
   */
  static truncate(str: string, maxLength: number, suffix: string = '...'): string {
    if (StringUtils.isEmpty(str) || str!.length <= maxLength) {
      return str || '';
    }
    return str!.substring(0, maxLength - suffix.length) + suffix;
  }

  /**
   * 格式化数字
   */
  static formatNumber(num: number): string {
    if (num >= 10000) {
      return (num / 10000).toFixed(1) + '万';
    }
    return num.toString();
  }

  /**
   * 格式化时间
   */
  static formatTime(timestamp: number): string {
    const now = Date.now();
    const diff = now - timestamp;

    if (diff < 60000) return '刚刚';
    if (diff < 3600000) return Math.floor(diff / 60000) + '分钟前';
    if (diff < 86400000) return Math.floor(diff / 3600000) + '小时前';
    if (diff < 604800000) return Math.floor(diff / 86400000) + '天前';

    const date = new Date(timestamp);
    const nowDate = new Date(now);
    if (date.getFullYear() === nowDate.getFullYear()) {
      return `${date.getMonth() + 1}-${date.getDate()}`;
    }
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }

  /**
   * 格式化日期时间
   */
  static formatDateTime(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hour}:${minute}`;
  }

  /**
   * 移除HTML标签
   */
  static stripHtml(html: string): string {
    return html.replace(/<[^>]*>/g, '');
  }

  /**
   * URL编码
   */
  static urlEncode(str: string): string {
    return encodeURIComponent(str);
  }

  /**
   * URL解码
   */
  static urlDecode(str: string): string {
    return decodeURIComponent(str);
  }

  /**
   * MD5加密（简化版，实际应使用系统API）
   */
  static md5(str: string): string {
    // 实际实现需要使用系统加密API
    return str;
  }
}

/**
 * 文件工具类
 */
export class FileUtils {
  /**
   * 获取文件扩展名
   */
  static getExtension(filename: string): string {
    const lastDot = filename.lastIndexOf('.');
    if (lastDot === -1) return '';
    return filename.substring(lastDot + 1).toLowerCase();
  }

  /**
   * 获取文件名（不含扩展名）
   */
  static getBaseName(filename: string): string {
    const lastDot = filename.lastIndexOf('.');
    const lastSlash = Math.max(filename.lastIndexOf('/'), filename.lastIndexOf('\\'));
    if (lastDot === -1) {
      return filename.substring(lastSlash + 1);
    }
    return filename.substring(lastSlash + 1, lastDot);
  }

  /**
   * 格式化文件大小
   */
  static formatSize(bytes: number): string {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + ' MB';
    return (bytes / 1024 / 1024 / 1024).toFixed(1) + ' GB';
  }

  /**
   * 判断是否是图片文件
   */
  static isImage(filename: string): boolean {
    const ext = FileUtils.getExtension(filename);
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext);
  }

  /**
   * 判断是否是视频文件
   */
  static isVideo(filename: string): boolean {
    const ext = FileUtils.getExtension(filename);
    return ['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'].includes(ext);
  }
}

/**
 * 验证工具类
 */
export class ValidateUtils {
  /**
   * 验证邮箱
   */
  static isEmail(email: string): boolean {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return regex.test(email);
  }

  /**
   * 验证手机号
   */
  static isPhone(phone: string): boolean {
    const regex = /^1[3-9]\d{9}$/;
    return regex.test(phone);
  }

  /**
   * 验证URL
   */
  static isUrl(url: string): boolean {
    const regex = /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/;
    return regex.test(url);
  }

  /**
   * 验证数字
   */
  static isNumber(str: string): boolean {
    return !isNaN(Number(str));
  }

  /**
   * 验证整数
   */
  static isInteger(str: string): boolean {
    const regex = /^-?\d+$/;
    return regex.test(str);
  }

  /**
   * 验证正整数
   */
  static isPositiveInteger(str: string): boolean {
    const regex = /^\d+$/;
    return regex.test(str) && parseInt(str) > 0;
  }
}

/**
 * 颜色工具类
 */
export class ColorUtils {
  /**
   * 十六进制转RGB
   */
  static hexToRgb(hex: string): { r: number, g: number, b: number } | null {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? {
      r: parseInt(result[1], 16),
      g: parseInt(result[2], 16),
      b: parseInt(result[3], 16)
    } : null;
  }

  /**
   * RGB转十六进制
   */
  static rgbToHex(r: number, g: number, b: number): string {
    return '#' + [r, g, b].map(x => {
      const hex = x.toString(16);
      return hex.length === 1 ? '0' + hex : hex;
    }).join('');
  }

  /**
   * 计算亮度
   */
  static getLuminance(r: number, g: number, b: number): number {
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  }

  /**
   * 判断是否需要深色文字
   */
  static needsDarkText(backgroundColor: string): boolean {
    const rgb = ColorUtils.hexToRgb(backgroundColor);
    if (!rgb) return true;
    return ColorUtils.getLuminance(rgb.r, rgb.g, rgb.b) > 0.5;
  }
}
