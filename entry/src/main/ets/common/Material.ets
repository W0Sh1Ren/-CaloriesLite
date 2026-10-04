/**
 * 沉浸光感材质（uiMaterial）。
 *
 * 这是 API 26 新增的系统材质能力，和手写 backgroundBlurStyle 完全是两件事：
 * 系统材质由 ArkUI 自己按设备算力决定模糊、亮度、描边和投影，
 * 并且自带「光感交互反馈」——按下时在材质上浮起一层光，
 * 这是手写模糊做不出来的。
 *
 * 使用前提（缺一不可）：
 *   1. module.json5 的 metadata 里开 state=1（MaterialState.ENABLE）；
 *   2. 设备支持——用 isImmersiveMaterialSupported() 判断，
 *      低端机或低版本系统会返回 false，此时要退回普通模糊，
 *      否则设了也没效果（材质不显示，组件变全透明，很难排查）。
 *
 * 材质参数说明（官方文档）：
 *   style          材质厚度。THIN/ULTRA_THIN 更透，THICK 更糊。
 *   materialColor  材质层的着色，必须带透明度，完全不透明会把材质滤镜整个盖住。
 *   colorInvert    子节点文字/图标是否自动取背景的互补色，需要 THIN 或更薄的材质。
 *   applyShadow    是否由材质自带投影，默认 true。
 *   interactive    是否开启交互动效变形。
 *   lightEffect    光感交互反馈的颜色；传 null 表示关闭该效果。
 */
import { uiMaterial } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

/** 当前设备是否支持沉浸材质。只探测一次并缓存 */
let supportCache: boolean | undefined = undefined;

/** 设备是否支持沉浸光感材质 */
export function immersiveSupported(): boolean {
  if (supportCache === undefined) {
    try {
      supportCache = uiMaterial.isImmersiveMaterialSupported();
      hilog.info(DOMAIN, 'CalorieLite',
        'immersive material supported = %{public}s, level = %{public}d, state = %{public}d',
        `${supportCache}`, uiMaterial.getGlobalMaterialLevel(), uiMaterial.getMaterialInfo().state);
    } catch (err) {
      // API 不可用时按不支持处理，走降级分支
      hilog.error(DOMAIN, 'CalorieLite', 'uiMaterial probe failed: %{public}s', JSON.stringify(err));
      supportCache = false;
    }
  }
  return supportCache;
}

/**
 * 取一份可用于 .systemMaterial() 的材质。
 *
 * 不支持时返回 uiMaterial.Material.empty（空材质，即不应用任何材质），
 * 调用方配合自己的降级背景色即可。
 *
 * @param style        材质厚度
 * @param tint         材质层着色，需带透明度
 * @param interactive  是否开启交互动效变形
 * @param lightColor   光感交互反馈颜色，不传则用系统默认（白）
 */
export function systemMaterial(style: uiMaterial.ImmersiveStyle, tint: string,
  interactive: boolean, lightColor?: string): uiMaterial.Material {
  if (!immersiveSupported()) {
    return uiMaterial.Material.empty;
  }
  const options: uiMaterial.ImmersiveOptions = {
    style: style,
    materialColor: tint,
    applyShadow: true,
    interactive: interactive
  };
  if (lightColor !== undefined) {
    options.lightEffect = { color: lightColor };
  }
  return new uiMaterial.ImmersiveMaterial(options);
}
