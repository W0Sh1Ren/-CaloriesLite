/**
 * 拍照 / 选图 / 压缩 / 转 base64。
 *
 * 上传给视觉模型前一定要压：手机原图动辄 4-8 MB，
 * 直接 base64 会撑爆请求体并显著变慢。这里统一压到长边 1024、质量 80。
 */
import { cameraPicker } from '@kit.CameraKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper as photoPicker } from '@kit.MediaLibraryKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

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
    } catch (err) {
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
    } catch (err) {
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
    } catch (err) {
      const e: Error = err as Error;
      hilog.error(DOMAIN, 'CalorieLite', 'prepare image failed: %{public}s', e.message);
      throw new ImageError(`图片处理失败：${e.message}`);
    } finally {
      if (packer !== null) {
        try {
          packer.release();
        } catch (ignored) {
          // 释放失败不影响主流程
        }
      }
      if (pixelMap !== null) {
        try {
          await pixelMap.release();
        } catch (ignored) {
          // 同上
        }
      }
      if (source !== null) {
        try {
          await source.release();
        } catch (ignored) {
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
    } finally {
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

  /** 把压缩后的 JPEG 写进应用缓存目录 */
  private static async saveToSandbox(buffer: ArrayBuffer, context: common.Context): Promise<string> {
    try {
      const dir: string = `${context.cacheDir}/shots`;
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      const name: string = `shot_${Date.now()}.jpg`;
      const path: string = `${dir}/${name}`;
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      try {
        fs.writeSync(file.fd, buffer);
      } finally {
        fs.closeSync(file);
      }
      return `file://${path}`;
    } catch (err) {
      // 存本地失败不该阻断识别，返回空 uri 即可
      hilog.warn(DOMAIN, 'CalorieLite', 'saveToSandbox failed, continue without local copy');
      return '';
    }
  }

  /** 读一个本地文件成 base64（调试/复用历史图片时用） */
  static readAsBase64(uri: string): string {
    const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat: fs.Stat = fs.statSync(file.fd);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      return new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer));
    } finally {
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
