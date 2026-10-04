import cameraPicker from "@ohos:multimedia.cameraPicker";
import camera from "@ohos:multimedia.camera";
import image from "@ohos:multimedia.image";
import fs from "@ohos:file.fs";
import fileUri from "@ohos:file.fileuri";
import photoPicker from "@ohos:file.photoAccessHelper";
import util from "@ohos:util";
import type common from "@ohos:app.ability.common";
import hilog from "@ohos:hilog";
import type { FoodRecord } from '../model/Types';
const DOMAIN = 0x0000;
/** 压缩后长边像素上限 */
const MAX_EDGE = 1024;
/** JPEG 质量 */
const JPEG_QUALITY = 80;
/** 单张图 base64 后的体积上限（约 4 MB 原图），超了就再降质量 */
const MAX_BASE64_CHARS = 5 * 1024 * 1024;
/** 压缩结果 */
export class PreparedImage {
    /** 纯 base64，不含 data URL 前缀 */
    base64: string = '';
    mimeType: string = 'image/jpeg';
    /** 压缩后存放在应用沙箱内的 uri，可长期用于展示 */
    localUri: string = '';
    /** 压缩后字节数 */
    bytes: number = 0;
    constructor(base64: string, mimeType: string, localUri: string, bytes: number) {
        this.base64 = base64;
        this.mimeType = mimeType;
        this.localUri = localUri;
        this.bytes = bytes;
    }
}
/** 认图失败时抛出，message 可直接展示 */
export class ImageError extends Error {
    constructor(message: string) {
        super(message);
    }
}
export class ImageService {
    /**
     * 拉起系统相机拍照。
     *
     * 传入 saveUri 把照片直接写进应用沙箱：这样 resultUri 就是沙箱路径，
     * 后续读取不受媒体库权限影响；否则照片会落进系统媒体库。
     *
     * @returns 拍照结果的 uri，用户取消返回空字符串
     */
    static async takePhoto(context: common.Context): Promise<string> {
        try {
            // saveUri 指向的文件必须已存在且有写权限，先建一个空文件
            const path: string = `${context.cacheDir}/cam_${Date.now()}.jpg`;
            const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
            fs.closeSync(file);
            const mediaTypes: cameraPicker.PickerMediaType[] = [cameraPicker.PickerMediaType.PHOTO];
            const profile: cameraPicker.PickerProfile = {
                cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
                saveUri: fileUri.getUriFromPath(path)
            };
            const result: cameraPicker.PickerResult = await cameraPicker.pick(context, mediaTypes, profile);
            // resultCode 为 0 表示成功，非 0 是用户取消或失败
            if (result.resultCode !== 0 || result.resultUri.length === 0) {
                return '';
            }
            return result.resultUri;
        }
        catch (err) {
            const e: Error = err as Error;
            hilog.error(DOMAIN, 'CalorieLite', 'takePhoto failed: %{public}s', e.message);
            throw new ImageError(ImageService.describePickerError(e.message));
        }
    }
    /**
     * 从相册选图。
     * @param maxCount 最多选几张
     * @returns 选中图片的 uri 列表，用户取消返回空数组
     */
    static async pickFromGallery(maxCount: number = 1): Promise<string[]> {
        try {
            const helper: photoPicker.PhotoViewPicker = new photoPicker.PhotoViewPicker();
            const options: photoPicker.PhotoSelectOptions = new photoPicker.PhotoSelectOptions();
            options.MIMEType = photoPicker.PhotoViewMIMETypes.IMAGE_TYPE;
            options.maxSelectNumber = maxCount > 0 ? maxCount : 1;
            const result: photoPicker.PhotoSelectResult = await helper.select(options);
            if (result.photoUris.length === 0) {
                return [];
            }
            return result.photoUris;
        }
        catch (err) {
            const e: Error = err as Error;
            hilog.error(DOMAIN, 'CalorieLite', 'pickFromGallery failed: %{public}s', e.message);
            throw new ImageError(ImageService.describePickerError(e.message));
        }
    }
    /**
     * 把 uri 指向的图片压成可上传的 base64。
     *
     * @param uri 相机或相册返回的 uri
     * @param context 应用上下文，用于把压缩结果落到沙箱
     */
    static async prepare(uri: string, context: common.Context): Promise<PreparedImage> {
        let source: image.ImageSource | null = null;
        let pixelMap: image.PixelMap | null = null;
        let packer: image.ImagePacker | null = null;
        try {
            // 先读成字节再解码：这样对沙箱路径、相机 uri、相册 uri 一视同仁，
            // 也避免不同来源 uri 的权限差异导致解码失败。
            const rawBuffer: ArrayBuffer = ImageService.readFile(uri);
            source = image.createImageSource(rawBuffer);
            const info: image.ImageInfo = await source.getImageInfo();
            const target: image.Size = ImageService.scaleToFit(info.size.width, info.size.height);
            const decodeOptions: image.DecodingOptions = {
                desiredSize: target,
                editable: false
            };
            pixelMap = await source.createPixelMap(decodeOptions);
            const packOptions: image.PackingOption = {
                format: 'image/jpeg',
                quality: JPEG_QUALITY
            };
            packer = image.createImagePacker();
            let buffer: ArrayBuffer = await packer.packToData(pixelMap, packOptions);
            // 极少见但确实会发生：压完还是太大，逐步降质量重压
            let quality: number = JPEG_QUALITY;
            while (buffer.byteLength > MAX_BASE64_CHARS && quality > 30) {
                quality -= 20;
                const retryOptions: image.PackingOption = { format: 'image/jpeg', quality: quality };
                buffer = await packer.packToData(pixelMap, retryOptions);
            }
            const bytes: Uint8Array = new Uint8Array(buffer);
            const base64: string = new util.Base64Helper().encodeToStringSync(bytes, util.Type.BASIC);
            // 同时落一份到沙箱，历史记录里才能一直看到这张图
            const localUri: string = await ImageService.saveToSandbox(buffer, context);
            return new PreparedImage(base64, 'image/jpeg', localUri, buffer.byteLength);
        }
        catch (err) {
            const e: Error = err as Error;
            hilog.error(DOMAIN, 'CalorieLite', 'prepare image failed: %{public}s', e.message);
            throw new ImageError(`图片处理失败：${e.message}`);
        }
        finally {
            if (packer !== null) {
                try {
                    packer.release();
                }
                catch (ignored) {
                    // 释放失败不影响主流程
                }
            }
            if (pixelMap !== null) {
                try {
                    await pixelMap.release();
                }
                catch (ignored) {
                    // 同上
                }
            }
            if (source !== null) {
                try {
                    await source.release();
                }
                catch (ignored) {
                    // 同上
                }
            }
        }
    }
    /** 把 uri（沙箱路径或媒体库 uri）指向的文件整个读进内存 */
    private static readFile(uri: string): ArrayBuffer {
        const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        try {
            const stat: fs.Stat = fs.statSync(file.fd);
            if (stat.size <= 0) {
                throw new ImageError('图片文件是空的，换一张试试');
            }
            const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
            fs.readSync(file.fd, buffer);
            return buffer;
        }
        finally {
            fs.closeSync(file);
        }
    }
    /** 按长边上限等比缩放，不放大原图 */
    private static scaleToFit(width: number, height: number): image.Size {
        const longer: number = Math.max(width, height);
        if (longer <= MAX_EDGE || longer === 0) {
            return { width: width, height: height };
        }
        const ratio: number = MAX_EDGE / longer;
        return {
            width: Math.max(1, Math.round(width * ratio)),
            height: Math.max(1, Math.round(height * ratio))
        };
    }
    /**
     * 把压缩后的 JPEG 写到应用缓存目录。
     *
     * 这里刻意用 cacheDir 而不是 filesDir：识别可能被用户取消，
     * 每次尝试都往持久目录写会堆积垃圾文件。缓存副本仅用于「识别前预览」，
     * 真正落库时再调 persist() 转存到 filesDir。
     */
    private static async saveToSandbox(buffer: ArrayBuffer, context: common.Context): Promise<string> {
        try {
            const dir: string = `${context.cacheDir}/shots`;
            if (!fs.accessSync(dir)) {
                fs.mkdirSync(dir, true);
            }
            const name: string = `shot_${Date.now()}_${Math.floor(Math.random() * 1000)}.jpg`;
            const path: string = `${dir}/${name}`;
            const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
            try {
                fs.writeSync(file.fd, buffer);
            }
            finally {
                fs.closeSync(file);
            }
            return `file://${path}`;
        }
        catch (err) {
            // 存本地失败不该阻断识别，返回空 uri 即可
            hilog.warn(DOMAIN, 'CalorieLite', 'saveToSandbox failed, continue without local copy');
            return '';
        }
    }
    /**
     * 把图片转存到应用持久目录，返回可长期使用的 uri。
     *
     * 为什么必须转存：相机/相册给的 uri 指向系统临时目录，
     * 缓存目录也可能被系统随时回收，直接把它写进记录的话
     * 过一段时间图片就打不开了。
     *
     * 只做拷贝不做重新压缩——传进来的已经是压缩过的那份，
     * 再压一次纯属掉画质。
     *
     * @param memo 来源 uri → 已转存 uri 的映射。
     *   同一个来源在一次批量处理里必须复用同一份文件：一次识别出的 N 道菜
     *   共享同一组照片，逐条调用会把这组照片复制 N 份
     *   （实测踩过：2 张照片被复制成 20 个文件，详情页里图片一直重复滚动）。
     */
    static persist(uri: string, context: common.Context, memo?: Map<string, string>): string {
        if (uri.length === 0) {
            return '';
        }
        // 已经是持久路径就直接返回，不重复拷贝
        if (uri.includes('/food_images/')) {
            return uri;
        }
        if (memo !== undefined) {
            const hit: string | undefined = memo.get(uri);
            if (hit !== undefined) {
                return hit;
            }
        }
        const src: string = uri.startsWith('file://') ? uri.substring(7) : uri;
        try {
            const dir: string = `${context.filesDir}/food_images`;
            if (!fs.accessSync(dir)) {
                fs.mkdirSync(dir, true);
            }
            const target: string = `${dir}/${Date.now()}_${Math.floor(Math.random() * 10000)}.jpg`;
            const from: fs.File = fs.openSync(src, fs.OpenMode.READ_ONLY);
            try {
                const stat: fs.Stat = fs.statSync(from.fd);
                const buf: ArrayBuffer = new ArrayBuffer(stat.size);
                fs.readSync(from.fd, buf);
                const to: fs.File = fs.openSync(target, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
                try {
                    fs.writeSync(to.fd, buf);
                }
                finally {
                    fs.closeSync(to);
                }
            }
            finally {
                fs.closeSync(from);
            }
            const saved: string = `file://${target}`;
            if (memo !== undefined) {
                memo.set(uri, saved);
            }
            return saved;
        }
        catch (err) {
            // 转存失败就退回原 uri：图片可能仍可用，总比完全没有强
            hilog.warn(DOMAIN, 'CalorieLite', 'persist image failed, keep original uri');
            return uri;
        }
    }
    /**
     * 转存一组图片，同一批内复用转存结果。
     *
     * 这是给「按天/按餐批量处理」用的入口，内部共用一个 memo，
     * 保证同一张原图不会在这一次批量里被复制多份。
     */
    static persistAll(uris: string[], context: common.Context): string[] {
        const memo: Map<string, string> = new Map<string, string>();
        const out: string[] = [];
        for (const u of uris) {
            out.push(ImageService.persist(u, context, memo));
        }
        return out;
    }
    /**
     * 清理缓存目录里的旧识别图。
     *
     * 用户取消识别时那份缓存副本不会有人接手，长期会堆积。
     * 应用启动时扫一遍，删掉超过 1 天的即可（正在用的都是刚生成的）。
     */
    static cleanOldShots(context: common.Context): void {
        try {
            const dir: string = `${context.cacheDir}/shots`;
            if (!fs.accessSync(dir)) {
                return;
            }
            const names: string[] = fs.listFileSync(dir);
            const cutoff: number = Date.now() - 24 * 60 * 60 * 1000;
            let removed: number = 0;
            for (const n of names) {
                try {
                    const st: fs.Stat = fs.statSync(`${dir}/${n}`);
                    if (st.mtime * 1000 < cutoff) {
                        fs.unlinkSync(`${dir}/${n}`);
                        removed++;
                    }
                }
                catch (e) {
                    // 单个文件清理失败不影响其它文件
                }
            }
            if (removed > 0) {
                hilog.info(DOMAIN, 'CalorieLite', 'cleaned %{public}d old shot(s)', removed);
            }
        }
        catch (err) {
            hilog.warn(DOMAIN, 'CalorieLite', 'cleanOldShots failed');
        }
    }
    /** 读文件全部字节，失败返回 null */
    private static readBytes(path: string): Uint8Array | null {
        try {
            const f: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
            try {
                const st: fs.Stat = fs.statSync(f.fd);
                const buf: ArrayBuffer = new ArrayBuffer(st.size);
                fs.readSync(f.fd, buf);
                return new Uint8Array(buf);
            }
            finally {
                fs.closeSync(f);
            }
        }
        catch (err) {
            return null;
        }
    }
    /** 两份字节是否完全相同 */
    private static sameBytes(a: Uint8Array, b: Uint8Array): boolean {
        if (a.length !== b.length) {
            return false;
        }
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) {
                return false;
            }
        }
        return true;
    }
    /**
     * 合并内容完全相同的图片文件，并删除不再被引用的文件。
     *
     * 背景：早期版本在补偿转存历史图片时按记录逐条调用 persist，
     * 一次识别出的 N 道菜共享的同一组照片被复制了 N 份
     * （实测 2 张照片变成 20 个文件，详情页里图片一直重复滚动）。
     *
     * 这里做一次性收敛：先按文件大小分组（便宜），只对同尺寸的候选
     * 做逐字节比对（贵但准确），把重复项全部指向保留的那一份。
     *
     * 被改写的记录通过 onRecordChanged 逐条回传，由调用方决定怎么落盘——
     * 不在这里直接写库，避免与本文件的职责耦合，也避免整表覆写
     * 把调用方在同一轮里做的其它改动冲掉。
     *
     * @returns 被删除的重复文件数
     */
    static dedupeImages(records: FoodRecord[], context: common.Context, onRecordChanged: (record: FoodRecord) => void): number {
        if (records.length === 0) {
            return 0;
        }
        // 1) 收集所有被引用的本地文件路径
        const referenced: string[] = [];
        for (const r of records) {
            for (const u of r.gallery()) {
                if (u.includes('/food_images/')) {
                    const p: string = u.startsWith('file://') ? u.substring(7) : u;
                    if (!referenced.includes(p)) {
                        referenced.push(p);
                    }
                }
            }
        }
        if (referenced.length === 0) {
            return 0;
        }
        // 2) 按大小分组，组内再做内容比对，决定每个路径的「规范路径」
        const canonical: Map<string, string> = new Map<string, string>();
        const bySize: Map<number, string[]> = new Map<number, string[]>();
        for (const p of referenced) {
            try {
                const st: fs.Stat = fs.statSync(p);
                const list: string[] | undefined = bySize.get(st.size);
                if (list === undefined) {
                    bySize.set(st.size, [p]);
                }
                else {
                    list.push(p);
                }
            }
            catch (e) {
                // 文件不存在：保持原样，不参与合并
                canonical.set(p, p);
            }
        }
        bySize.forEach((group: string[]) => {
            if (group.length === 1) {
                canonical.set(group[0], group[0]);
                return;
            }
            const kept: string[] = [];
            const keptBytes: Uint8Array[] = [];
            for (const p of group) {
                const bytes: Uint8Array | null = ImageService.readBytes(p);
                if (bytes === null) {
                    canonical.set(p, p);
                    continue;
                }
                let dupOf: string = '';
                for (let i = 0; i < kept.length; i++) {
                    if (ImageService.sameBytes(bytes, keptBytes[i])) {
                        dupOf = kept[i];
                        break;
                    }
                }
                if (dupOf.length > 0) {
                    canonical.set(p, dupOf);
                }
                else {
                    kept.push(p);
                    keptBytes.push(bytes);
                    canonical.set(p, p);
                }
            }
        });
        // 3) 改写记录：把重复引用替换成规范路径，并去掉组内重复项
        let rewritten: number = 0;
        for (const r of records) {
            const list: string[] = r.gallery();
            if (list.length === 0) {
                continue;
            }
            const next: string[] = [];
            let changed: boolean = false;
            for (const u of list) {
                let mapped: string = u;
                if (u.includes('/food_images/')) {
                    const p: string = u.startsWith('file://') ? u.substring(7) : u;
                    const c: string | undefined = canonical.get(p);
                    if (c !== undefined && c !== p) {
                        mapped = `file://${c}`;
                        changed = true;
                    }
                }
                if (!next.includes(mapped)) {
                    next.push(mapped);
                }
                else {
                    changed = true;
                }
            }
            if (changed) {
                r.imageUris = next;
                r.imageUri = next.length > 0 ? next[0] : '';
                rewritten++;
                onRecordChanged(r);
            }
        }
        // 4) 删除不再被任何记录引用的文件
        const stillUsed: string[] = [];
        for (const r of records) {
            for (const u of r.gallery()) {
                if (u.includes('/food_images/')) {
                    const p: string = u.startsWith('file://') ? u.substring(7) : u;
                    if (!stillUsed.includes(p)) {
                        stillUsed.push(p);
                    }
                }
            }
        }
        let removed: number = 0;
        for (const p of referenced) {
            if (!stillUsed.includes(p)) {
                try {
                    fs.unlinkSync(p);
                    removed++;
                }
                catch (e) {
                    // 删除失败不影响功能，顶多占点空间
                }
            }
        }
        if (removed > 0 || rewritten > 0) {
            hilog.info(DOMAIN, 'CalorieLite', 'dedupe images: removed %{public}d, rewrote %{public}d record(s)', removed, rewritten);
        }
        return removed;
    }
    /** 读一个本地文件成 base64（调试/复用历史图片时用） */
    static readAsBase64(uri: string): string {
        const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        try {
            const stat: fs.Stat = fs.statSync(file.fd);
            const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
            fs.readSync(file.fd, buffer);
            return new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer));
        }
        finally {
            fs.closeSync(file);
        }
    }
    /** 把 picker 抛出的原始错误翻译成人话 */
    private static describePickerError(message: string): string {
        const m: string = message.toLowerCase();
        if (m.includes('permission') || m.includes('201') || m.includes('denied')) {
            return '没有相机或相册权限，请到系统设置里授权后重试';
        }
        if (m.includes('cancel')) {
            return '已取消';
        }
        return `无法打开相机或相册：${message}`;
    }
}
