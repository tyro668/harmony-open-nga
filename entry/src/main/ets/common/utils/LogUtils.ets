import hilog from '@ohos.hilog';

/**
 * 日志工具类
 */
export class LogUtils {
  private static readonly DOMAIN: number = 0x0000;
  private static readonly TAG: string = 'OpenNGA';
  private static isDebug: boolean = true;

  /**
   * 设置调试模式
   */
  static setDebug(isDebug: boolean): void {
    LogUtils.isDebug = isDebug;
  }

  /**
   * 调试日志
   */
  static d(tag: string, message: string, ...args: Object[]): void {
    if (LogUtils.isDebug) {
      hilog.debug(LogUtils.DOMAIN, tag, message, ...args);
    }
  }

  /**
   * 信息日志
   */
  static i(tag: string, message: string, ...args: Object[]): void {
    hilog.info(LogUtils.DOMAIN, tag, message, ...args);
  }

  /**
   * 警告日志
   */
  static w(tag: string, message: string, ...args: Object[]): void {
    hilog.warn(LogUtils.DOMAIN, tag, message, ...args);
  }

  /**
   * 错误日志
   */
  static e(tag: string, message: string, ...args: Object[]): void {
    hilog.error(LogUtils.DOMAIN, tag, message, ...args);
  }

  /**
   * 致命错误日志
   */
  static f(tag: string, message: string, ...args: Object[]): void {
    hilog.fatal(LogUtils.DOMAIN, tag, message, ...args);
  }

  /**
   * 简便方法
   */
  static debug(message: string, ...args: Object[]): void {
    LogUtils.d(LogUtils.TAG, message, ...args);
  }

  static info(message: string, ...args: Object[]): void {
    LogUtils.i(LogUtils.TAG, message, ...args);
  }

  static warn(message: string, ...args: Object[]): void {
    LogUtils.w(LogUtils.TAG, message, ...args);
  }

  static error(message: string, ...args: Object[]): void {
    LogUtils.e(LogUtils.TAG, message, ...args);
  }

  static fatal(message: string, ...args: Object[]): void {
    LogUtils.f(LogUtils.TAG, message, ...args);
  }
}
