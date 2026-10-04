import abilityAccessCtrl from "@ohos:abilityAccessCtrl";
import type common from "@ohos:app.ability.common";
import bundleManager from "@ohos:bundle.bundleManager";
import type { Permissions } from "@ohos:abilityAccessCtrl";
import hilog from "@ohos:hilog";
const DOMAIN = 0x0000;
export class PermissionUtil {
    /** 检查单个权限是否已授予 */
    static async isGranted(context: common.Context, permission: Permissions): Promise<boolean> {
        try {
            const tokenId: number = context.applicationInfo.accessTokenId;
            const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
            const status: abilityAccessCtrl.GrantStatus = await atManager.checkAccessToken(tokenId, permission);
            return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
        }
        catch (err) {
            hilog.error(DOMAIN, 'CalorieLite', 'checkAccessToken failed: %{public}s', JSON.stringify(err));
            return false;
        }
    }
    /**
     * 申请一批权限，返回是否全部授予。
     *
     * 用 requestPermissionsFromUser 会一次弹出所有未授予的权限；
     * 用户拒绝后返回 false，调用方负责给出友好提示。
     */
    static async request(context: common.UIAbilityContext, permissions: Permissions[]): Promise<boolean> {
        try {
            const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
            // 不写显式类型标注：PermissionRequestResult 在 SDK 里是全局 class，
            // 仅通过 `export type` 转发到 abilityAccessCtrl 命名空间，ArkTS 解析不到
            // 该限定名；这里让编译器从返回值推导即可。
            const result = await atManager.requestPermissionsFromUser(context, permissions);
            // authResults 里 0 表示已授权，-1 表示拒绝，2 表示权限未声明或名称无效。
            // 用下标循环而不是 for...of，避免元素类型推导落到 any。
            const results: number[] = result.authResults as number[];
            for (let i = 0; i < results.length; i++) {
                const code: number = results[i];
                if (code !== 0) {
                    return false;
                }
            }
            return true;
        }
        catch (err) {
            hilog.error(DOMAIN, 'CalorieLite', 'requestPermissions failed: %{public}s', JSON.stringify(err));
            return false;
        }
    }
    /**
     * 确保相机权限可用。
     *
     * 注意：cameraPicker 走的是系统相机，多数情况下不强制要求 CAMERA 权限，
     * 但部分设备与系统版本会校验，所以这里做一次「能要就要」的宽松处理：
     * 用户拒绝也放行，让系统 picker 自己决定是否报错。
     */
    static async ensureCamera(context: common.UIAbilityContext): Promise<boolean> {
        const granted: boolean = await PermissionUtil.isGranted(context, 'ohos.permission.CAMERA');
        if (granted) {
            return true;
        }
        const ok: boolean = await PermissionUtil.request(context, ['ohos.permission.CAMERA']);
        if (!ok) {
            hilog.warn(DOMAIN, 'CalorieLite', 'camera permission denied by user, try system picker anyway');
        }
        // 即便被拒也返回 true，交给系统 picker 兜底
        return true;
    }
    /**
     * 确保相册读取权限可用。
     *
     * 同样地，PhotoViewPicker 是系统级选择器，用户选中的图会临时授权给本应用，
     * 所以权限被拒也不阻塞流程。
     */
    static async ensurePhotoRead(context: common.UIAbilityContext): Promise<boolean> {
        const granted: boolean = await PermissionUtil.isGranted(context, 'ohos.permission.READ_IMAGEVIDEO');
        if (granted) {
            return true;
        }
        await PermissionUtil.request(context, ['ohos.permission.READ_IMAGEVIDEO']);
        return true;
    }
    /** 判断某权限是否在 module.json5 里声明过，便于排查配置遗漏 */
    static async isDeclared(context: common.Context, permission: Permissions): Promise<boolean> {
        try {
            const bundleInfo: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_REQUESTED_PERMISSION);
            const details = bundleInfo.reqPermissionDetails;
            if (details === undefined) {
                return false;
            }
            for (const d of details) {
                if (d.name === permission) {
                    return true;
                }
            }
            return false;
        }
        catch (err) {
            return false;
        }
    }
}
