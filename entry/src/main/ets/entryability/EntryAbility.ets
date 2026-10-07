import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import uiMaterial from '@ohos.arkui.uiMaterial';
// HDS（HMS SDK 的 UIDesignKit）：官方导航栏/页签组件与材质能力查询。
// ⚠️ 它在 sdk/default/hms 而不是 openharmony —— 这是之前误判「没有 HDS」的原因。
import { hdsMaterial } from '@kit.UIDesignKit';

import { SafeArea } from '../common/SafeArea';
import { Store } from '../common/Store';
import { AppState } from '../common/AppState';
// 画布用的色值是**字符串**（Canvas 不吃 Resource），所以它不能像
// Theme 那样自动跟随主题，得由这里把当前颜色模式写进去。
import { setCanvasDarkMode } from '../common/CanvasColors';
import { ImageService } from '../service/ImageService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  /** 持有主窗口，用于尺寸变化时重新测量安全区 */
  private mainWindow: window.Window | null = null;

  /**
   * 诊断：这台设备是否支持「沉浸光感」材质。
   *
   * 用 uiMaterial（API 26 起）的三个查询接口一次性打全：
   *   · isImmersiveMaterialSupported —— 能不能用 ImmersiveMaterial
   *   · getGlobalMaterialLevel        —— 设备的算力档（决定材质精细度）
   *   · getMaterialInfo().state       —— 应用级沉浸材质当前开没开
   *
   * 之前试过沉浸材质但 getMaterialInfo().state 恒为 0，
   * 这三行就是为了确认那到底是「设备不支持」还是「用法不对」。
   */
  private logMaterialSupport(): void {
    try {
      const supported: boolean = uiMaterial.isImmersiveMaterialSupported();
      const level: number = uiMaterial.getGlobalMaterialLevel();
      const info: uiMaterial.MaterialInfo = uiMaterial.getMaterialInfo();
      hilog.info(DOMAIN, 'CalorieLite',
        'material: supported=%{public}s level=%{public}d state=%{public}d type=%{public}d',
        `${supported}`, level, info.state, info.type);
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'material probe failed: %{public}s', JSON.stringify(err));
    }
    /*
     * HDS 侧的材质能力查询 —— 这才是那篇帖子里的 API。
     *
     * 与上面 uiMaterial 的区别：
     *   uiMaterial  = OpenHarmony 自带（API 26 新增），给普通组件用
     *   hdsMaterial = HMS 的 HDS 设计系统，HdsNavigation / HdsTabs 用它
     *
     * getSystemMaterialTypes() 返回设备支持的材质类型列表。
     * 若包含 IMMERSIVE(101)，说明 HDS 组件能拿到完整沉浸光感
     *（含交互形变、流光），帖子里的方案本机可用。
     */
    try {
      const types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
      const hasImmersive: boolean = types.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
      hilog.info(DOMAIN, 'CalorieLite',
        'hds material: count=%{public}d immersive=%{public}s',
        types.length, `${hasImmersive}`);
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'hds material probe failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 来自桌面卡片的目标页。
   *
   * 卡片底部的「拍照记录」用 FormLink 带 wantParams.fromCard 拉起本 ability，
   * 这里把它转交给首页去 push Camera。不能在 onWindowStageCreate 里直接
   * pushUrl —— 那时 pages/Index 还没加载完，路由栈是空的，push 会失败。
   * 按 want 的字段名取参数，键名与 form_config.json 里的 router 一致。
   */
  private cardRoute: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // 把当前颜色模式告诉画布色值表。
    // Theme 里的资源色会自动跟随主题，但画布用的是字符串，必须显式同步。
    this.syncCanvasColorMode(this.context.config.colorMode);

    // 必须在这里初始化偏好存储。
    // 漏掉这一步时 Store.prefs 一直是 null，所有写入都会被静默丢弃：
    // API Key、个人情况、饮食记录全都存不住，界面还照常显示，极难排查。
    Store.init(this.context);

    // 清掉缓存里过期的临时识别图。用户取消识别时那份压缩副本
    // 不会有人接手，长期会堆积占空间。
    ImageService.cleanOldShots(this.context);

    this.cardRoute = EntryAbility.readCardRoute(want);

    // 把 context 交给 AppState：页面里记完一笔要靠它刷新桌面卡片
    AppState.setAbilityContext(this.context);

    // 诊断：摸清这台设备的沉浸材质能力（见该方法注释）
    this.logMaterialSupport();

    hilog.info(DOMAIN, 'CalorieLite', '%{public}s', 'Ability onCreate');
  }

  /** 从 want 里读卡片带来的目标页（没有则为空串） */
  private static readCardRoute(want: Want): string {
    const p: Record<string, Object> | undefined = want.parameters;
    if (p === undefined) {
      return '';
    }
    const v: Object | undefined = p['cardRoute'];
    return typeof v === 'string' ? v : '';
  }

  /** 应用已在运行时再点卡片：走 onNewWant，同样要把目标页交给首页 */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const route: string = EntryAbility.readCardRoute(want);
    if (route.length > 0) {
      AppState.cardRoute = route;
      AppState.notifyDataChanged();
    }
  }

  /**
   * 把系统的颜色模式同步给画布色值表（common/CanvasColors）。
   *
   * 为什么需要：Theme 里的颜色是资源引用（$r），系统切深浅色时自动生效；
   * 但 **Canvas 只接受字符串**，所以那套色值必须由外部告知当前模式。
   *
   * 两个调用点：onCreate（冷启动）与 onConfigurationUpdate（运行中切主题）。
   */
  private syncCanvasColorMode(colorMode: ConfigurationConstant.ColorMode | undefined): void {
    const isDark: boolean = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    setCanvasDarkMode(isDark);
    hilog.info(DOMAIN, 'CalorieLite', 'canvas color mode: dark=%{public}s', `${isDark}`);
  }

  /**
   * 系统配置变化（深浅色、语言、字号…）时回调。
   *
   * 目前只关心深浅色：画布的色值是字符串，不会自动切，必须在这里更新。
   * 首页的热量环还要**重绘**一次 —— 画布不在 ArkUI 的重建通道里，
   * 光改色值不会触发重画。重绘由 Index 自己监听（见那里的 onConfigurationUpdate）。
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    this.syncCanvasColorMode(newConfig.colorMode);
    // 通知页面：主题变了，需要重建/重绘
    AppState.notifyThemeChanged();
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
      // 内容加载完成后才把卡片带来的目标页交给首页
      if (this.cardRoute.length > 0) {
        AppState.cardRoute = this.cardRoute;
        AppState.notifyDataChanged();
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
