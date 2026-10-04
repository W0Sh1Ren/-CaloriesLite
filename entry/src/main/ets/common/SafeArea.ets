/**
 * 窗口安全区测量。
 *
 * 窗口用 setWindowLayoutFullScreen(true) 铺满整屏后，状态栏和底部手势条会盖在内容上，
 * 页面必须自己避让。这里把两处避让尺寸量出来存进 AppState（单位 vp）：
 *
 *   顶部：从 AvoidArea(TYPE_SYSTEM) 的 topRect 读，实测 136px（39vp），可信。
 *   底部：**不能只信 AvoidArea**。实测这台机器 TYPE_SYSTEM_GESTURE 返回 0，
 *        但屏幕底部确实有一条手势区，压在它上面的按钮点不动。
 *        所以改用「屏幕高度 − 窗口底边」反算，这个差值是真实被系统占掉的像素。
 *
 * 单位换算：AvoidArea 与 windowRect 都是 px，布局用 vp，
 * 依据 display 的 densityPixels（每 vp 多少 px）换算。
 */
import { display, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppState } from './AppState';

const DOMAIN = 0x0000;

export class SafeArea {
  /**
   * 读取并记录安全区尺寸。
   *
   * @param win 已经 setWindowLayoutFullScreen(true) 的窗口
   */
  static measure(win: window.Window): void {
    try {
      const props: window.WindowProperties = win.getWindowProperties();
      const d: display.Display = display.getDefaultDisplaySync();
      const ratio: number = d.densityPixels > 0 ? 1 / d.densityPixels : 1;

      // 顶部：状态栏高度
      const system: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const topPx: number = system.visible ? system.topRect.height : 0;

      // 底部：手势条。先取避让区，取不到再用屏幕与窗口的高度差兜底。
      const gesture: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM_GESTURE);
      const navBarPx: number = system.visible ? system.bottomRect.height : 0;
      const gesturePx: number = gesture.visible ? gesture.bottomRect.height : 0;
      const screenGapPx: number = d.height - (props.windowRect.top + props.windowRect.height);
      const bottomPx: number = Math.max(navBarPx, gesturePx, screenGapPx > 0 ? screenGapPx : 0);

      AppState.topInset = Math.round(topPx * ratio);
      AppState.bottomInset = Math.round(bottomPx * ratio);

      hilog.info(DOMAIN, 'CalorieLite',
        'safe area vp: top=%{public}d bottom=%{public}d | px top=%{public}d navBar=%{public}d gesture=%{public}d screenGap=%{public}d',
        AppState.topInset, AppState.bottomInset, topPx, navBarPx, gesturePx, screenGapPx);
    } catch (err) {
      // 读不到就退回 0，页面仍可用，只是贴边而已
      hilog.error(DOMAIN, 'CalorieLite', 'measure safe area failed: %{public}s', JSON.stringify(err));
      AppState.topInset = 0;
      AppState.bottomInset = 0;
    }
  }
}
