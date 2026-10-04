import type AbilityConstant from "@ohos:app.ability.AbilityConstant";
import ConfigurationConstant from "@ohos:app.ability.ConfigurationConstant";
import UIAbility from "@ohos:app.ability.UIAbility";
import type Want from "@ohos:app.ability.Want";
import hilog from "@ohos:hilog";
import type window from "@ohos:window";
import { SafeArea } from "@normalized:N&&&entry/src/main/ets/common/SafeArea&";
import { Store } from "@normalized:N&&&entry/src/main/ets/common/Store&";
import { ImageService } from "@normalized:N&&&entry/src/main/ets/service/ImageService&";
const DOMAIN = 0x0000;
export default class EntryAbility extends UIAbility {
    /** 持有主窗口，用于尺寸变化时重新测量安全区 */
    private mainWindow: window.Window | null = null;
    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        try {
            this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
        }
        catch (err) {
            hilog.error(DOMAIN, 'CalorieLite', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
        }
        // 必须在这里初始化偏好存储。
        // 漏掉这一步时 Store.prefs 一直是 null，所有写入都会被静默丢弃：
        // API Key、个人情况、饮食记录全都存不住，界面还照常显示，极难排查。
        Store.init(this.context);
        // 清掉缓存里过期的临时识别图。用户取消识别时那份压缩副本
        // 不会有人接手，长期会堆积占空间。
        ImageService.cleanOldShots(this.context);
        hilog.info(DOMAIN, 'CalorieLite', '%{public}s', 'Ability onCreate');
    }
    onDestroy(): void {
        hilog.info(DOMAIN, 'CalorieLite', '%{public}s', 'Ability onDestroy');
    }
    onWindowStageCreate(windowStage: window.WindowStage): void {
        hilog.info(DOMAIN, 'CalorieLite', '%{public}s', 'Ability onWindowStageCreate');
        // 先把窗口设为全屏布局，再加载内容。
        // 不全屏的话，窗口会被状态栏和底部系统导航栏夹住：顶部柔光铺不到顶，
        // 底部导航栏也会被系统手势区压住导致点不动——这两点都是实测踩出来的。
        try {
            const win: window.Window = windowStage.getMainWindowSync();
            this.mainWindow = win;
            win.setWindowLayoutFullScreen(true)
                .then(() => {
                SafeArea.measure(win);
            })
                .catch((e: Error) => {
                hilog.error(DOMAIN, 'CalorieLite', 'setWindowLayoutFullScreen failed: %{public}s', e.message);
            });
            // 折叠、旋转、分屏都会改变安全区，尺寸一变就重新量
            win.on('windowSizeChange', () => {
                SafeArea.measure(win);
            });
        }
        catch (err) {
            hilog.error(DOMAIN, 'CalorieLite', 'window setup failed: %{public}s', JSON.stringify(err));
        }
        windowStage.loadContent('pages/Index', (err) => {
            if (err.code) {
                hilog.error(DOMAIN, 'CalorieLite', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
                return;
            }
            hilog.info(DOMAIN, 'CalorieLite', 'Succeeded in loading the content.');
        });
    }
    onWindowStageDestroy(): void {
        if (this.mainWindow !== null) {
            try {
                this.mainWindow.off('windowSizeChange');
            }
            catch (err) {
                // 解绑失败不影响退出
            }
            this.mainWindow = null;
        }
        hilog.info(DOMAIN, 'CalorieLite', '%{public}s', 'Ability onWindowStageDestroy');
    }
    onForeground(): void {
        hilog.info(DOMAIN, 'CalorieLite', '%{public}s', 'Ability onForeground');
    }
    onBackground(): void {
        hilog.info(DOMAIN, 'CalorieLite', '%{public}s', 'Ability onBackground');
    }
}
