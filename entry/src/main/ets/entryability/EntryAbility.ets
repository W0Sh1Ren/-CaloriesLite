import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { SafeArea } from '../common/SafeArea';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  /** 持有主窗口，用于尺寸变化时重新测量安全区 */
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
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
    } catch (err) {
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
      } catch (err) {
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
