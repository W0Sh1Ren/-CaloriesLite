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
      hilog.info(DOMAIN, 'CalorieLite', 'Store ready: %{public}s', STORE_NAME);
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Store init failed: %{public}s', JSON.stringify(err));
      Store.prefs = null;
    }
  }

  /**
   * 强制重新打开偏好存储，丢掉本进程的旧快照。
   *
   * ── 为什么需要它（桌面卡片踩过的坑）
   *
   * preferences 在**框架层**还维护了一份进程内缓存，而且这份缓存
   * 不会因为别的进程写了新值就失效。卡片进程是长驻的，于是出现：
   *   应用里记完一笔 → 卡片点「刷新」→ 卡片进程读到的还是几十分钟前的旧值
   *   → 只有等系统把卡片进程回收、重启后重新读文件，卡片才更新。
   * 用户看到的就是「刷新没用，过一阵自己好了」。
   *
   * 实测证据（一次记录后的连续 7 次刷新 + 一次进程重启）：
   *   pid=49312 连续 7 次刷新 → records=7  intake=1880  （全是旧值）
   *   pid=49969（进程重启后） → records=9  intake=2280  （新值）
   * 说明旧值不是我们这层缓存的 —— 把 Store.prefs 置空再 getPreferencesSync
   * 拿回来的**仍然是旧的**，所以必须连框架的缓存一起清掉。
   *
   * 关键就是 removePreferencesFromCacheSync：它把 Preferences 实例从
   * 框架缓存中移除，之后 getPreferencesSync 才会**重新读文件**。
   * 只把自己的引用置空是不够的。
   *
   * 只有卡片进程需要调 —— 主应用自己是写入方，它那份缓存就是最新值。
   */
  static reload(context: common.Context): void {
    const hadCache: boolean = Store.prefs !== null;
    Store.prefs = null;
    try {
      preferences.removePreferencesFromCacheSync(context, STORE_NAME);
    } catch (err) {
      hilog.warn(DOMAIN, 'CalorieLite', 'removePreferencesFromCache failed, will reopen');
    }
    Store.init(context);
    hilog.info(DOMAIN, 'CalorieLite', 'Store reload: hadCache=%{public}s ready=%{public}s',
      `${hadCache}`, `${Store.isReady()}`);
  }

  /**
   * 存储是否可用。
   *
   * 曾经踩过的坑：EntryAbility 漏调 init()，prefs 一直是 null，
   * 所有写入被静默丢弃——界面照常显示，只是重启后数据全没了，极难排查。
   * 所以保留这个检查，未就绪时统一告警而不是无声失败。
   */
  static isReady(): boolean {
    return Store.prefs !== null;
  }

  /** 未就绪时统一在这里告警，避免每个调用点各写一遍 */
  private static warnNotReady(op: string, key: string): void {
    hilog.warn(DOMAIN, 'CalorieLite',
      'Store not ready (%{public}s %{public}s) — data will NOT persist. Did EntryAbility call Store.init()?',
      op, key);
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
      Store.warnNotReady('put', key);
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
      Store.warnNotReady('remove', key);
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
