# HarmonyOS 7 / API 26：拍照/选图 → 读字节 → 压缩 → base64 → 调用 AI 视觉接口

> **取证方式说明（重要）**
> `developer.huawei.com` 文档中心是 JavaScript 单页应用（SPA），`web_fetch` 只能拿到空壳（HTTP 200 但正文为空），因此本报告的 API 细节全部取自**华为文档中心所渲染内容的上游 Markdown 源**——OpenHarmony `docs` 仓库（`raw.giteeusercontent.com/openharmony/docs/raw/master/...`）。
> 该仓库 `master` 分支已包含 `起始版本：26.0.0` 的条目（例如 `fileIo.listFileExt`、`ImageSource.createThumbnail`、`HttpRequestOptions.reuseConnections`），与 API 26 对齐。
> 凡未能在文档中核实的点，一律标注 **「未找到官方依据」**，不做猜测。

---

## 0. 结论速览

| 环节 | 官方推荐 API | 关键事实 |
|---|---|---|
| 拍照 | `cameraPicker.pick()`（`@kit.CameraKit`） | API 11+；必须在**界面 UIAbility** 中调用；返回 `PickerResult.resultUri` |
| 选图 | `photoAccessHelper.PhotoViewPicker`（`@kit.MediaLibraryKit`） | **`@ohos.file.picker` 的 `PhotoViewPicker` 自 API 12 起已废弃** |
| uri → 字节 | `fileIo.openSync(uri, READ_ONLY)` + `fileIo.readSync(fd, buf)` | 官方《使用Picker选择媒体库资源》明确给出的写法；picker 本身**无需申请权限** |
| 压缩 | `image.createImageSource` → `createPixelMap({desiredSize})` → `ImagePacker.packToData(pm, {format:'image/jpeg', quality})` | `desiredSize` 会**拉伸**到指定尺寸，必须自己按比例算；API 26 新增 `createThumbnail()` |
| base64 | `new util.Base64Helper().encodeToStringSync(uint8Array, util.Type.BASIC)` | 入参必须是 `Uint8Array`，不是 `ArrayBuffer` |
| 上传 | `@ohos.net.http`（`@kit.NetworkKit`） | **不存在 `@ohos.net.httpclient`**；`requestInStream` 用于流式/大响应 |
| 权限 | `ohos.permission.INTERNET`：level `normal`、`system_grant`、起始版本 9 | `module.json5` 里只写 `name` 即可 |
| 明文 http | Network Kit **默认允许**明文（API 18+）；RCP **默认禁止** | 配置在 `resources/base/profile/network_config.json`，错误码 `2300997` |

---

## 1. 调起系统相机拍照（CameraPicker）

导入模块（官方写法）：

```ts
import { cameraPicker } from '@kit.CameraKit';
import { camera } from '@kit.CameraKit';
import { BusinessError } from '@kit.BasicServicesKit';
```

官方签名与返回值（原文照抄）：

```
pick(context: Context, mediaTypes: Array<PickerMediaType>, pickerProfile: PickerProfile): Promise<PickerResult>
```

| 类型 | 字段 | 说明（官方原文摘要） |
|---|---|---|
| `PickerMediaType` | `PHOTO='photo'` / `VIDEO='video'` | 媒体类型 |
| `PickerProfile` | `cameraPosition`（必填，`camera.CameraPosition.CAMERA_POSITION_BACK`）<br>`saveUri?`（可选）<br>`videoDuration?` | 「若未配置该参数，则拍摄的照片和视频会默认存入媒体库中；若不想将照片和视频存入媒体库中，请自行配置应用沙箱内的文件资源路径，如自行传入资源路径时请确保该文件存在且具备写入权限，否则会保存失败。」 |
| `PickerResult` | `resultCode: number`（成功 0，失败 -1）<br>`resultUri: string`<br>`mediaType: PickerMediaType` | 「若 `saveUri` 为空，`resultUri` 为公共媒体路径。若 `saveUri` 不为空且具备写权限，`resultUri` 与 `saveUri` 相同。」 |

**可编译示例（ArkTS 1.1 严格类型）**：把照片直接落到应用沙箱，避免拿到媒体库 URI 后还要考虑读权限。

```ts
import { cameraPicker } from '@kit.CameraKit';
import { camera } from '@kit.CameraKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** 拉起系统相机拍照，返回可直接用 fileIo 读取的 uri（指向应用沙箱文件） */
export async function takePhoto(context: common.UIAbilityContext): Promise<string> {
  // 1) 先在沙箱内创建空文件：saveUri 指向的文件必须已存在且有写权限
  const picPath: string = context.filesDir + '/capture_' + Date.now() + '.jpg';
  const empty: fileIo.File = fileIo.openSync(
    picPath,
    fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE
  );
  fileIo.closeSync(empty);
  const saveUri: string = fileUri.getUriFromPath(picPath); // 由沙箱路径生成文件 uri

  // 2) 构造 PickerProfile（只拍照，后置摄像头）
  const profile: cameraPicker.PickerProfile = {
    cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
    saveUri: saveUri
  };

  try {
    const result: cameraPicker.PickerResult = await cameraPicker.pick(
      context,
      [cameraPicker.PickerMediaType.PHOTO],
      profile
    );
    if (result.resultCode !== 0) {
      throw new Error('camera picker failed, resultCode=' + result.resultCode);
    }
    return result.resultUri; // saveUri 有写权限时即等于 saveUri
  } catch (error) {
    const err = error as BusinessError;
    console.error(`cameraPicker.pick failed. code=${err.code}, message=${err.message}`);
    throw error as Error;
  }
}
```

注意（官方原文）：「调用此类接口时，应用**必须在界面 UIAbility 中调用**，否则无法启动 cameraPicker 应用。」`context` 用 `this.getUIContext().getHostContext() as common.UIAbilityContext` 获取。

---

## 2. 从相册选图（PhotoViewPicker）

### 2.1 新版（推荐）：`photoAccessHelper.PhotoViewPicker`

```ts
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** 拉起图库选 1 张图片；返回的 uri 带只读权限 */
export async function pickPhoto(): Promise<string> {
  const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  options.maxSelectNumber = 1;

  const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
  try {
    const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
    if (result.photoUris.length === 0) {
      throw new Error('no photo selected');
    }
    // 关键：不要在这里（picker 回调/紧接着的作用域）立刻打开 uri，
    // 官方要求先把 uri 存到全局/成员变量，等界面从图库返回后再由按钮事件去打开。
    return result.photoUris[0];
  } catch (error) {
    const err = error as BusinessError;
    console.error(`PhotoViewPicker.select failed. code=${err.code}, message=${err.message}`);
    throw error as Error;
  }
}
```

官方补充约束：

- 「此接口本身**无需申请权限**，目前适用于界面 UIAbility，使用窗口组件触发。」
- 「`select` 返回的 uri 权限是**只读权限**，可以根据结果集中 uri 进行读取文件数据操作。注意**不能在 picker 的回调里直接使用此 uri 进行打开文件操作**，需要定义一个全局变量保存 uri。」
- 「如果需要重复拉起 PhotoViewPicker，需要先通过 NavDestination 或跟随进程销毁前一个 photoViewPicker。」
- 新版返回的 `photoUris` **具有永久授权**（旧 `file.picker` 版只有临时授权）。

### 2.2 老版（已废弃，别再用）：`@ohos.file.picker`

官方原文：`PhotoViewPicker`（`@kit.CoreFileKit` 的 `picker`）「从 API version 9 开始支持，**从 API version 12 开始废弃**。建议使用 `photoAccessHelper.PhotoViewPicker` 替代」；其 `constructor(context)` 也从 API 18 起废弃；`picker.PhotoViewMIMETypes`、`picker.PhotoSelectOptions`、`picker.PhotoSelectResult` 同样废弃（API 18）。

**结论：新代码一律用 `photoAccessHelper`。** 只有 `DocumentViewPicker` / `AudioViewPicker`（文档类、音频类文件）仍属于 `@ohos.file.picker`，未废弃。

---

## 3. uri → ArrayBuffer → 压缩 → base64

### 3.1 uri 读成 ArrayBuffer（官方明确写法）

官方《使用Picker选择媒体库资源 → 指定URI读取文件数据》给出的两步：

```ts
const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);   // 权限参数必须是 READ_ONLY
const buffer = new ArrayBuffer(bufferSize);
const readLen = fileIo.readSync(fileObj.fd, buffer);
```

`fileIo.openSync` / `fileIo.open` 文档原文：「打开文件或目录，支持使用URI打开文件」，参数 `path` 为「应用沙箱路径**或 URI**」。`readSync(fd, buffer, options?)` 的 `ReadOptions`：`offset`（默认从当前位置读）、`length`（默认缓冲区长度），返回实际读取字节数。

```ts
import { fileIo } from '@kit.CoreFileKit';

/** uri（沙箱路径 / 媒体库 uri 均可）→ ArrayBuffer */
export function readUriToArrayBuffer(uri: string): ArrayBuffer {
  const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const stat: fileIo.Stat = fileIo.statSync(file.fd); // 传 fd 拿文件信息
    const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    const readLen: number = fileIo.readSync(file.fd, buffer);
    return readLen === stat.size ? buffer : buffer.slice(0, readLen);
  } finally {
    fileIo.closeSync(file); // 必须关闭，否则 fd 泄漏
  }
}
```

> 若走 `photoAccessHelper` 路线拿 `PhotoAsset`：官方还提供 `photoAccessHelper.MediaAssetManager.requestImageData()`（`DeliveryMode.HIGH_QUALITY_MODE`）直接回调 `ArrayBuffer`，适合需要原图质量的场景。

### 3.2 压缩：ImageSource + desiredSize + ImagePacker

已核实的签名：

```
image.createImageSource(uri: string) | (fd: number) | (buf: ArrayBuffer) | (rawFd: RawFileDescriptor)   // 官方解码指南“方法一~四”
ImageSource.getImageInfo(index?: number): Promise<ImageInfo>          // ImageInfo.size: { width, height }
ImageSource.createPixelMap(options?: DecodingOptions): Promise<PixelMap>
ImageSource.release(): Promise<void>
ImagePacker.packToData(source: PixelMap, options: PackingOption): Promise<ArrayBuffer>
ImagePacker.release(): Promise<void>
PixelMap.release(): Promise<void>
```

关键参数语义（`arkts-apis-image-i.md` 原文）：

- `DecodingOptions.desiredSize`: 「期望输出大小，必须为正整数，**若与原尺寸比例不一致，则会进行拉伸/缩放到指定尺寸**，默认为原始尺寸。」→ 必须自己按比例换算，否则会变形。
- `DecodingOptions.sampleSize`: 「缩略图采样大小，默认值为 1。**当前只能取 1**。」→ 别指望用 sampleSize 降采样。
- `PackingOption.quality`: 「仅对 **JPEG 和 HEIF** 生效。取值范围 [0,100]」（PNG/WebP 是无损，调 quality 没用）。
- `PackingOption.bufferSize`: 「如果不设置大小，默认为 25M」（`packToData` 用；`packToFile` 不受限）。

```ts
import { image } from '@kit.ImageKit';

/**
 * 把任意图片字节压成“长边 <= maxSide、JPEG quality”的字节流，用于上传。
 * 先 getImageInfo 拿原尺寸，再按比例 desiredSize 解码，避免 12MP 原图全解码导致 OOM。
 */
export async function compressForUpload(
  src: ArrayBuffer,
  maxSide: number,
  quality: number
): Promise<ArrayBuffer> {
  const source: image.ImageSource = image.createImageSource(src);
  const packer: image.ImagePacker = image.createImagePacker();
  try {
    const info: image.ImageInfo = await source.getImageInfo();
    const w: number = info.size.width;
    const h: number = info.size.height;
    const longest: number = Math.max(w, h);
    const ratio: number = longest > maxSide ? maxSide / longest : 1;
    const targetW: number = Math.max(1, Math.round(w * ratio));
    const targetH: number = Math.max(1, Math.round(h * ratio));

    const decodeOpts: image.DecodingOptions = {
      desiredSize: { width: targetW, height: targetH }
    };
    const pixelMap: image.PixelMap = await source.createPixelMap(decodeOpts);
    try {
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: quality };
      return await packer.packToData(pixelMap, packOpts);
    } finally {
      await pixelMap.release(); // 大图内存必须及时释放
    }
  } finally {
    await source.release();
    await packer.release();
  }
}
```

**API 26 新增的更省事选项**：`ImageSource.createThumbnail(options?: DecodingOptionsForThumbnail)`（**起始版本 26.0.0**），`options.maxGeneratedPixelDimension` 指定生成缩略图的最大边长，官方明说无缩略图时会「对原图进行解码后，根据解码参数 options 下采样生成缩略图，生成后的缩略图宽和高都限制在 512 像素以内」；错误码含 `7700303 图片不包含缩略图数据`。仅支持 JPEG/HEIF，适合“预览/快速上传”，不适合需要精确尺寸控制的场景。

### 3.3 ArrayBuffer → base64（ArkTS 严格模式）

`Base64Helper` 官方签名：

```
encodeToStringSync(src: Uint8Array, options?: Type): string     // API 9+
encodeToString(src: Uint8Array, options?: Type): Promise<string>
decodeSync(src: Uint8Array | string, options?: Type): Uint8Array
```

`Type` 取值：`util.Type.BASIC`（默认，无换行）、`MIME`（每 76 字符 `\r\n` 换行；**少于 76 字符会抛异常**）、`BASIC_URL_SAFE`、`MIME_URL_SAFE`。**上传 JSON 用 `BASIC`**，`MIME` 的换行会污染 base64。

```ts
import { util } from '@kit.ArkTS';

/** ArrayBuffer → 标准 base64 字符串（无换行），可直接拼 data URL */
export function arrayBufferToBase64(buf: ArrayBuffer): string {
  const bytes: Uint8Array = new Uint8Array(buf); // ArkTS 里必须显式构造 Uint8Array，没有隐式转换
  const helper: util.Base64Helper = new util.Base64Helper();
  return helper.encodeToStringSync(bytes, util.Type.BASIC);
}

/** 供 OpenAI 风格 image_url 使用 */
export function toJpegDataUrl(buf: ArrayBuffer): string {
  return 'data:image/jpeg;base64,' + arrayBufferToBase64(buf);
}
```

### 3.4 「新版推荐 photoAccessHelper 还是老的 file.picker？」

**`photoAccessHelper`。** 依据：`file.picker` 文档的 `PhotoViewPicker` 及其选项/结果类型全部标记 `(deprecated)`，废弃于 API 12（构造函数 API 18），替代项就是 `photoAccessHelper.PhotoViewPicker`；且新版 `photoUris` 带永久授权。`file.picker` 只保留 `DocumentViewPicker` / `AudioViewPicker` 的使用场景。

---

## 4. 发 HTTP 请求给 AI 视觉接口

### 4.1 方案 A（**本次推荐**）：`@ohos.net.http`

```ts
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

interface ChatContentPart { type: string; text?: string; image_url?: ImageUrl; }
interface ImageUrl { url: string; }
interface ChatMessage { role: string; content: string | ChatContentPart[]; }
interface VisionReq { model: string; messages: ChatMessage[]; max_tokens: number; }
interface VisionResp { choices?: VisionChoice[]; error?: VisionError; }
interface VisionChoice { message?: ChatMessage; finish_reason?: string; }
interface VisionError { message: string; }

/**
 * 调用 OpenAI 兼容的视觉接口（base64 data URL 方式）
 * @param baseUrl 例如 'https://api.example.com' 或 'http://192.168.1.10:8000'
 */
export async function recognizeFood(
  baseUrl: string,
  apiKey: string,
  model: string,
  jpegBase64DataUrl: string
): Promise<string> {
  const httpRequest: http.HttpRequest = http.createHttp();
  try {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + apiKey
    };
    const part: ChatContentPart = { type: 'image_url', image_url: { url: jpegBase64DataUrl } };
    const textPart: ChatContentPart = { type: 'text', text: '识别图中食物并给出热量估算，返回JSON。' };
    const body: VisionReq = {
      model: model,
      max_tokens: 1024,
      messages: [{ role: 'user', content: [textPart, part] }]
    };

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(body),          // POST body 用 extraData
      expectDataType: http.HttpDataType.STRING, // 期望返回字符串（JSON 文本）
      usingCache: false,
      connectTimeout: 15000,                    // 默认 60000ms
      readTimeout: 90000                        // 默认 60000ms；视觉大模型常超过 60s
    };

    const resp: http.HttpResponse = await httpRequest.request(
      baseUrl + '/v1/chat/completions',
      options
    );
    if (resp.responseCode !== http.ResponseCode.OK) {
      throw new Error('HTTP status ' + resp.responseCode);
    }
    // resp.result 的类型是 string | Object | ArrayBuffer —— 必须收窄
    if (typeof resp.result !== 'string') {
      throw new Error('unexpected result type');
    }
    const parsed: VisionResp = JSON.parse(resp.result) as VisionResp;
    const first: VisionChoice | undefined = parsed.choices?.[0];
    return first?.message?.content?.toString() ?? '';
  } catch (error) {
    const err = error as BusinessError;
    console.error(`request failed. code=${err.code}, message=${err.message}`);
    throw error as Error;
  } finally {
    httpRequest.destroy(); // 官方：不 destroy 会内存泄漏
  }
}
```

要点（官方文档原文）：`request` 接口「仅支持接收 5MB 以内的数据……自 API version 23 开始，本接口支持的最大接收数据量为 50MB」，需要更大就设 `HttpRequestOptions.maxLimit`（默认 `5*1024*1024`，上限 `100*1024*1024`）或改流式。`header` 的官方示例既出现过类实例，也出现过 `{...} as Record<string, string>`——ArkTS 下用 `Record<string, string>` 最稳。
**API 26 新增**：`HttpRequestOptions.reuseConnections`（默认 true）、`inactivityMs`（默认 118s）、`http.RequestMethod.PATCH`。

**大/长响应：`requestInStream`**（返回响应码 `number`，数据在事件回调里增量给）

```ts
import { http } from '@kit.NetworkKit';

export async function callVisionStreaming(url: string, options: http.HttpRequestOptions): Promise<string> {
  const req: http.HttpRequest = http.createHttp();
  let acc: ArrayBuffer = new ArrayBuffer(0);
  req.on('dataReceive', (data: ArrayBuffer) => {
    const merged: ArrayBuffer = new ArrayBuffer(acc.byteLength + data.byteLength);
    const view: Uint8Array = new Uint8Array(merged);
    view.set(new Uint8Array(acc));
    view.set(new Uint8Array(data), acc.byteLength);
    acc = merged;                       // 官方示例同款合并写法
  });
  req.on('dataEnd', () => { /* 不再有数据 */ });
  req.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo) => {
    console.info(`recv ${info.receiveSize}/${info.totalSize}`);
  });
  try {
    const code: number = await req.requestInStream(url, options);
    if (code !== 200) {
      throw new Error('HTTP status ' + code);
    }
    return new Uint8Array(acc).length > 0 ? 'ok' : 'empty'; // 实际项目里在 dataEnd 后解析 acc
  } finally {
    req.off('dataReceive');
    req.off('dataEnd');
    req.off('dataReceiveProgress');
    req.destroy();
  }
}
```

**multipart 上传（可选，不想自己 base64 时）**：`HttpRequestOptions.multiFormDataList`（API 11+），仅当 `content-Type` 为 `multipart/form-data` 时生效，每项可传 `data`（`string | Object | ArrayBuffer`）或 `filePath` + `contentType`（如 `'image/jpeg'`）+ `remoteFileName`。此时可把压缩后的 JPEG 写进 `context.cacheDir` 再按文件路径上传。

### 4.2 方案 B：`@kit.RemoteCommunicationKit`（RCP）

- **RCP 是 HarmonyOS 专有 Kit**：本次抓取的 OpenHarmony 官方 Network Kit 参考目录（`zh-cn/application-dev/reference/apis-network-kit`）中**没有** RCP 的 API 参考，其文档只发布在 `developer.huawei.com`。
- **RCP 的正文本次无法取证**：`developer.huawei.com` 为 SPA，`web_fetch` 只能得到空壳。以下是第三方博客给出的写法（**未从官方正文核实**，字段名仅供参考）：

```ts
// 未找到官方正文依据：以下字段名来自第三方博客，请在 IDE 中核对 rcp 的类型定义后再使用
import { rcp } from '@kit.RemoteCommunicationKit';

const conf: rcp.SessionConfiguration = {
  baseAddress: 'https://api.example.com',
  headers: { 'Content-Type': 'application/json' },
  requestConfiguration: {
    transfer: {
      autoRedirect: true,
      timeout: { connectMs: 15000, transferMs: 90000 }
    }
  }
};
const session = rcp.createSession(conf);
const request = new rcp.Request('/v1/chat/completions', 'POST', undefined, JSON.stringify(body));
const resp = await session.fetch(request);
const text: string = await resp.toString();   // 字段/方法名未经官方核实
```

- **`@ohos.net.httpclient` 不存在**：官方 Network Kit 的 API 目录里只有 `@ohos.net.http`、`@ohos.net.socket`、`@ohos.net.webSocket`、`@ohos.net.connection` 等，没有任何 `httpclient` 模块（未找到任何官方文档）。
- **本次任务选哪个**：**用 `@ohos.net.http`**。理由（均可官方取证）：① 有完整的官方参考（签名、错误码表、`multiFormDataList`、`requestInStream`、`maxLimit`）；② **明文 http 默认放行**（见第 6 节），而 RCP 默认**禁止**明文，用 `http://` 自建/局域网地址时要额外改配置；③ 单次 POST + base64 不需要会话复用/拦截器。
  RCP 更适合：需要连接复用、HTTP/3、统一拦截器、上传下载进度等工程化能力的项目。**「官方是否声明 RCP 比 http 更推荐」——未找到官方依据**（RCP 指南标题为《Sending a Network Request (ArkTS)》，未见对比性推荐语）。

---

## 5. 网络权限声明

`ohos.permission.INTERNET` 官方条目原文：**权限级别：normal；授权方式：系统授权（system_grant）；起始版本：9**。system_grant 权限「系统将在用户安装应用时，自动把相应权限授予给应用」。而《声明权限》规定：`reason`、`usedScene` 仅在申请 **user_grant / manual_settings** 权限时必填，其他情况选填。

因此最小写法（`entry/src/main/module.json5`）：

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    // ...
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
      }
    ]
  }
}
```

补充：**拍照/选图本身不需要任何权限**（官方：「此接口本身无需申请权限」）。只有当你**不用 picker、直接查相册**时才需要 `ohos.permission.READ_IMAGEVIDEO`（user_grant，那时 `reason` + `usedScene` 必填）。

---

## 6. 明文 HTTP（`http://`）问题

### 6.1 默认是否禁止？

**对 `@ohos.net.http`（Network Kit）：默认允许。** 官方《使用HTTP访问网络》原文（`component-config` 字段表）：

> Network Kit 从 API version 18 开始默认支持明文 HTTP 功能，不可配置。从 API version 20 开始支持配置开启或关闭明文 HTTP 功能。true 表示支持，false 表示不支持，**默认为 true**。

同表还写明：**Remote Communication Kit 默认值为 false**（即 RCP 默认**禁止**明文），Media Kit 默认 false，ArkWeb 默认 false，Request 默认 true。

被禁止时 `@ohos.net.http` 会抛 **错误码 `2300997`：Cleartext traffic not permitted**（官方错误码表）。

### 6.2 配置文件（确切写法）

官方给出的路径是 `src/main/resources/base/profile/network_config.json`，内容示例（原文照抄结构）：

```json5
// src/main/resources/base/profile/network_config.json
{
  "network-security-config": {
    "base-config": {
      "cleartextTrafficPermitted": true // 可选，自 API version 20 开始支持该属性
    },
    "domain-config": [
      {
        "domains": [
          {
            "include-subdomains": true,
            "name": "example.com"
          }
        ],
        "cleartextTrafficPermitted": false
      }
    ],
    "component-config": {
      "Request": true,
      "Network Kit": true,
      "ArkWeb": false,
      "Media Kit": false,
      "Remote Communication Kit": false
    }
  }
}
```

字段语义（官方）：`cleartextTrafficPermitted`=true 允许明文、false 不允许，**默认 true**；优先级 **component-config > domain-config > base-config**，「优先级高的配置会覆盖优先级低的规则」；`include-subdomains`=true 时 `name` 支持正则匹配。

同一文件还可配置证书锁定（`pin-set` / `digest-algorithm: "sha256"`）与 `trust-global-user-ca` / `trust-current-user-ca`。

**⚠️ 未找到官方依据**：是否需要额外在 `module.json5` 的 `metadata` 里注册 `network_config.json`（例如某个 `ohos.net.*` metadata 名）。官方《使用HTTP访问网络》只给出文件路径与优先级，**未提及任何 metadata 声明**；配套的《网络连接安全配置》最佳实践页在 `developer.huawei.com`（SPA，抓不到正文）。**如果你的 `http://` 请求报 `2300997`，先按上面写 `"Network Kit": true`（以及在 `base-config` 里 `cleartextTrafficPermitted: true`）再验证；若仍不生效，再考虑 metadata 方案。**

---

## 7. 风险与注意事项（ArkTS 严格模式 + 图片/网络实战）

1. **`header` 不要依赖“无类型对象字面量”**。ArkTS 规则 `arkts-no-untyped-obj-literals`（错误码 10605038）要求对象字面量有显式类型；官方拦截器示例自己就写成 `{ 'content-type': 'text/html' } as Record<string, string>`。统一用 `const headers: Record<string, string> = {...}`。
2. **`resp.result` 必须收窄**。类型是 `string | Object | ArrayBuffer`，直接当字符串用会编译失败：`if (typeof resp.result !== 'string') { throw ... }`。
3. **`JSON.parse` 的返回类型**。官方 ArkTS 版 JSON（`import { JSON } from '@kit.ArkTS'`，API 12+）签名是 `parse(text: string, reviver?: Transformer, options?: ParseOptions): Object | null`，官方示例用 `(obj as object)?.["name"]` 这种方式取值。把整体断言成自定义 `interface` 是常见写法，但**「断言为 interface」未在官方文档中找到明确示例**；若编译器/运行时拒绝，退化方案是 `const root: Record<string, Object> = parsed as Record<string, Object>` 逐层取值。
4. **`ArrayBuffer` 与 `Uint8Array` 不通用**。`Base64Helper` 只吃 `Uint8Array`：`new Uint8Array(buf)`。反向：`uint8Array.buffer` 的类型是 `ArrayBufferLike`，官方在 resourceManager 场景用的是 `fileData.buffer.slice(0)` 来得到 `ArrayBuffer`。
5. **禁止索引访问对象属性**。规则 `arkts-no-props-by-index`（10605029）：`person['name']` 是编译错误（`TypedArray`、`Record`、`Map` 例外）。动态键场景用 `Record<string, string>` / `Map<Object, string>`。
6. **没有结构化类型（structural typing）**。规则 `arkts-no-structural-typing`（10605030）：两个字段相同的类/接口不能互相赋值，必须用 `extends` / `implements` / `type 别名` 建立关系。给“拍照结果 / 相册结果”定义统一的接口再由两边适配。
7. **强制严格检查，不能关闭**。`arkts-strict-typing-required`（10605999）强制 `noImplicitReturns`、`strictFunctionTypes`、`strictNullChecks`、`strictPropertyInitialization`，且禁止 `@ts-ignore`/`@ts-nocheck`；`any`/`unknown` 被禁（10605008），`Object` 也基本不能用于字面量初始化。表现：类字段必须初始化、可空类型要写 `string | undefined`、用 `?.` 与 `??` 兜底、函数所有分支都要 return。
8. **回调改 Promise，但 picker 的 uri 不能马上用**。官方示例已全面 Promise 化（`await picker.select()`、`await httpRequest.request()`）；但官方明确要求 picker 返回的 uri 先存全局变量、等界面从图库返回后再由组件事件打开，否则打不开文件。
9. **内存与生命周期**：`PixelMap` / `ImageSource` / `ImagePacker` 用完必须 `release()`，`HttpRequest` 用完必须 `destroy()`（官方：否则内存泄漏）。上传前先 `getImageInfo()` 拿尺寸再 `desiredSize` 解码，避免 12MP 原图全解码（RGBA 约 48MB）OOM。
10. **超时与体积**：`readTimeout` 默认 60s，视觉大模型经常更慢，建议 90~120s；`request` 默认只收 5MB（API 23+ 为 50MB），需要更大设 `maxLimit` 或 `requestInStream`。base64 会让体积膨胀约 33%，`maxSide` 建议 1024~1568、JPEG `quality` 75~85。

---

## 附：本次实际成功抓取的官方文档（上游 Markdown / 文档中心页）

**华为文档中心页（HTTP 200，但为 SPA，正文需浏览器渲染）**

- [@ohos.multimedia.cameraPicker (相机选择器)](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/js-apis-camerapicker)
- [@ohos.file.picker (选择器)](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/js-apis-file-picker)
- [Class (PhotoViewPicker)](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/arkts-apis-photoaccesshelper-photoviewpicker?docScope=all)

**OpenHarmony docs 仓库（上述页面的内容源，本次逐字取证处）**

- [js-apis-cameraPicker.md](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-camera-kit/js-apis-cameraPicker.md)
- [arkts-apis-photoAccessHelper-PhotoViewPicker.md](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-media-library-kit/arkts-apis-photoAccessHelper-PhotoViewPicker.md)
- [photoAccessHelper-photoviewpicker.md（使用Picker选择媒体库资源，含“指定URI读取文件数据”）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/media/medialibrary/photoAccessHelper-photoviewpicker.md)
- [js-apis-file-picker.md（PhotoViewPicker 废弃说明）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-core-file-kit/js-apis-file-picker.md)
- [js-apis-file-fs.md（open/openSync 支持 URI、readSync、ReadOptions、OpenMode）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-core-file-kit/js-apis-file-fs.md)
- [user-file-uri-intro.md（媒体文件 URI 使用方式）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/file-management/user-file-uri-intro.md)
- [arkts-apis-image-ImagePacker.md](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-image-kit/arkts-apis-image-ImagePacker.md)
- [arkts-apis-image-ImageSource.md（getImageInfo / createPixelMap / createThumbnail(26+)）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-image-kit/arkts-apis-image-ImageSource.md)
- [arkts-apis-image-i.md（PackingOption / DecodingOptions）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-image-kit/arkts-apis-image-i.md)
- [image-decoding.md](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/media/image/image-decoding.md) ・ [image-encoding.md](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/media/image/image-encoding.md) ・ [image-transformation.md（getImageInfo/scale）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/media/image/image-transformation.md)
- [js-apis-util.md（Base64Helper）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkts/js-apis-util.md)
- [js-apis-json.md（@ohos.util.json，JSON.parse 返回 Object | null）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkts/js-apis-json.md)
- [js-apis-http.md（@ohos.net.http，error 2300997）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-network-kit/js-apis-http.md)
- [http-request.md（明文 HTTP 配置、component-config 默认值、network_config.json）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/network/http-request.md)
- [declare-permissions.md（requestPermissions 写法与 reason/usedScene 规则）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/security/AccessToken/declare-permissions.md)
- [permissions-for-all.md（INTERNET：normal / system_grant / 起始版本 9）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/security/AccessToken/permissions-for-all.md)
- [typescript-to-arkts-migration-guide.md（ArkTS 约束与错误码）](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/quick-start/typescript-to-arkts-migration-guide.md)

**仅作定位、未能抓取正文（SPA）**：Remote Communication Kit 指南 <https://developer.huawei.com/consumer/en/doc/harmonyos-guides/remote-communication-netsend-arkts>；《网络连接安全配置》最佳实践 <https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-network-ca-security>。
