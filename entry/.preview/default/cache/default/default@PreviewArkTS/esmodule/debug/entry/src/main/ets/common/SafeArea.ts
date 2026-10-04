import display from "@ohos:display";
import window from "@ohos:window";
import hilog from "@ohos:hilog";
import { AppState } from "@normalized:N&&&entry/src/main/ets/common/AppState&";
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
            hilog.info(DOMAIN, 'CalorieLite', 'safe area vp: top=%{public}d bottom=%{public}d | px top=%{public}d navBar=%{public}d gesture=%{public}d screenGap=%{public}d', AppState.topInset, AppState.bottomInset, topPx, navBarPx, gesturePx, screenGapPx);
        }
        catch (err) {
            // 读不到就退回 0，页面仍可用，只是贴边而已
            hilog.error(DOMAIN, 'CalorieLite', 'measure safe area failed: %{public}s', JSON.stringify(err));
            AppState.topInset = 0;
            AppState.bottomInset = 0;
        }
    }
}
