/**
 * 偏好存储的薄封装。
 *
 * 用同步读写 + 异步落盘（flush）的方式，页面代码就不必到处 await。
 * 存复杂结构时统一走 JSON 字符串，读回来由各 Repository 负责还原成对象。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const STORE_NAME = 'calorie_lite_store';

export class Store {
  private static prefs: preferences.Preferences | null = null;

  /** 在 EntryAbility.onCreate 里调用一次即可 */
  static init(context: common.Context): void {
    if (Store.prefs !== null) {
      return;
    }
    try {
      const options: preferences.Options = { name: STORE_NAME };
      Store.prefs = preferences.getPreferencesSync(context, options);
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Store init failed: %{public}s', JSON.stringify(err));
      Store.prefs = null;
    }
  }

  /** 未初始化时回退到调用方给的默认值，避免崩溃 */
  static getString(key: string, defValue: string): string {
    if (Store.prefs === null) {
      return defValue;
    }
    try {
      const v: preferences.ValueType = Store.prefs.getSync(key, defValue);
      return typeof v === 'string' ? v : defValue;
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Store getString %{public}s failed', key);
      return defValue;
    }
  }

  static getNumber(key: string, defValue: number): number {
    if (Store.prefs === null) {
      return defValue;
    }
    try {
      const v: preferences.ValueType = Store.prefs.getSync(key, defValue);
      return typeof v === 'number' ? v : defValue;
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Store getNumber %{public}s failed', key);
      return defValue;
    }
  }

  static getBool(key: string, defValue: boolean): boolean {
    if (Store.prefs === null) {
      return defValue;
    }
    try {
      const v: preferences.ValueType = Store.prefs.getSync(key, defValue);
      return typeof v === 'boolean' ? v : defValue;
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Store getBool %{public}s failed', key);
      return defValue;
    }
  }

  static has(key: string): boolean {
    if (Store.prefs === null) {
      return false;
    }
    try {
      return Store.prefs.hasSync(key);
    } catch (err) {
      return false;
    }
  }

  /** 写入内存后异步落盘；落盘失败只记日志，不打断交互 */
  static put(key: string, value: string | number | boolean): void {
    if (Store.prefs === null) {
      hilog.warn(DOMAIN, 'CalorieLite', 'Store not initialized, drop key %{public}s', key);
      return;
    }
    try {
      Store.prefs.putSync(key, value);
      Store.prefs.flush().catch((e: Error) => {
        hilog.error(DOMAIN, 'CalorieLite', 'Store flush failed: %{public}s', e.message);
      });
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Store put %{public}s failed: %{public}s', key, JSON.stringify(err));
    }
  }

  static remove(key: string): void {
    if (Store.prefs === null) {
      return;
    }
    try {
      Store.prefs.deleteSync(key);
      Store.prefs.flush().catch((e: Error) => {
        hilog.error(DOMAIN, 'CalorieLite', 'Store flush failed: %{public}s', e.message);
      });
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Store remove %{public}s failed', key);
    }
  }

  /** 清空全部数据（设置页的「清空所有记录」用） */
  static clearAll(): void {
    if (Store.prefs === null) {
      return;
    }
    try {
      Store.prefs.clearSync();
      Store.prefs.flush().catch((e: Error) => {
        hilog.error(DOMAIN, 'CalorieLite', 'Store flush failed: %{public}s', e.message);
      });
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Store clear failed');
    }
  }
}
