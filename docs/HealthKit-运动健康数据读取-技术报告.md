# HarmonyOS 7 / API 26 ArkTS 读取运动健康数据（步数 / 活动热量 / 锻炼记录）技术报告

> 调研方法说明：`developer.huawei.com` 文档站是 JS 渲染的 SPA，`web_fetch` 只能拿到壳（返回"文档中心"三个字）。因此本报告的**代码级事实**主要来自三个可抓取的官方源：
> 1. Gitee 官方示例仓库 [harmonyos_samples/health_-service_-kit_-sample-code](https://gitee.com/harmonyos_samples/health_-service_-kit_-sample-code)（华为官方账号维护，源码可逐行核对）
> 2. [OpenHarmony docs 官方仓库](https://gitee.com/openharmony/docs)（`@ohos.sensor` 权威 API 定义）
> 3. 华为官方在开发者论坛/官方博客的回答原文（经 SegmentFault「HarmonyOS_SDK」官方号、51CTO 鸿蒙社区镜像）
>
> 凡官方文档站正文无法读取的，一律标注「未找到官方依据」，不做推测。

---

## 0. 结论速览

| 问题 | 结论 |
|---|---|
| Health Kit 对个人开发者开放吗 | **需要申请审批，且要自评资质**。官方教程明确"根据《应用开发者申请资质说明》进行自评，满足各项要求后进行权限申请"。**未能读到资质说明正文，因此"个人开发者是否被排除"未找到官方依据** |
| 依赖 | **`@kit.HealthServiceKit` 是系统内置 Kit，不需要装任何三方包**。官方示例的 `oh-package.json5` 中 `dependencies` 为空 |
| 权限 | **Health Service Kit 不使用 `ohos.permission.*`**。官方示例 `module.json5` 里**完全没有 `requestPermissions`**；取而代之的是 `metadata.client_id` + 在 AGC「联盟卡片」申请**数据类型权限** + 运行时 `requestAuthorizations` |
| 能否直接读到数值 | **能**。`healthStore` 系列 API 在应用内直接返回数值，不需要跳转华为运动健康 App |
| 步数/热量 | 走 `samplePointHelper.dailyActivities`（日常活动采样数据），用 `aggregateData` 聚合出 `step` / `calorie` |
| 锻炼记录 | 走 `exerciseSequenceHelper`，用 `readData<Model>(ExerciseSequenceReadRequest)` |
| 免 Health Kit 的替代 | `@kit.SensorServiceKit` 的 `SensorId.PEDOMETER` 可读步数，权限 `ohos.permission.ACTIVITY_MOTION`（user_grant）。但**后台/锁屏不回调，且无对应长时任务类型**——官方明确回复"长时任务中不支持记步" |
| 现实建议 | **"今日步数"这个语义只有 Health Kit 给得了**（系统传感器是开机累计值，不跨天分割）。若只要"App 在前台时的计步"，用传感器 30 行代码搞定 |

---

## 1. Health Kit 是否对个人开发者开放？

### 1.1 已确认：这是一个**申请制**服务，不是自助开通

官方《快速加入 Health Kit，一文了解审核流程》（华为 HMS Core 官方账号发布）给出的完整链路与周期：

| 环节 | 周期 | 说明 |
|---|---|---|
| 申请开发者账号 | 约 **3 个工作日** | 因为 Health Kit 依赖帐号服务能力，**需先申请帐号服务（Account Kit）**，才能申请 Health Kit |
| 申请 Health Kit 服务 | 约 **15 个工作日** | ① 先按《应用开发者申请资质说明》**自评**，满足后申请；② 按《申请 Health Kit 服务》指引选择数据读写权限、提交申请资料**和企业介绍** |
| 申请验证（解除限制） | 约 **15 个工作日** | 提交佐证视频 + 自检 Checklist，验收后开通正式权限 |

关键约束（官方原文）：

- **「Health Kit 服务测试阶段有 100 位用户数量的限制，申请验证并通过后将解除该限制。」**
- 官方 SDK FAQ 里的 201 错误排查也印证了这一点：「**测试用户数已达上限**」→「请尽快参考申请验证获取正式权限」。

来源：
- [快速加入Health Kit，一文了解审核流程](https://huaweicloud.csdn.net/6502d50b993dd34278ee312a.html)（华为 HMS Core 官方账号，2023-09）
- [应用开发者申请资质说明](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/health-application-qualifications)
- [接入流程](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/health-application-access)
- [申请验证获取正式权限](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/health-verification)

### 1.2 已确认：官方对开发者的一句关键定性 —— 步数是**基础数据**，审核门槛低于高阶数据

华为官方在开发者论坛回答"如何获取当天步数"时原文：

> 「现有的 api 有传感器的计步数据可以用于监听步数……**不支持直接调用获取，建议接入华为运动健康服务，该数据为基础的用户数据，审核条件比高阶的用户数据要低**，5.0 版本可以使用 Health Service Kit 的接口获得对应数据。」

来源：[HarmonyOS app需要获取到当天的步数](https://ost.51cto.com/answer/40606)（华为官方回答，2025-01）

**这是本报告对个人开发者最有价值的一条**：步数属于低门槛数据，你不需要去碰心率/血糖那套高门槛资质。

### 1.3 个人开发者？—— 我拿到的边界

**能确认的**：
- 官方文档标题就叫 [《应用开发者申请资质说明》](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/health-application-qualifications)，其页面锚点包含 **"企业事业单位政府机构社会团体开发者接入资质审核要求"**。这说明文档是按**组织机构类型**分档写的，且**存在一个面向"企业/事业单位/政府/社会团体"的专门审核要求章节**。
- 与 Android/HMS 时代同名的旧文档《应用开发者申请资质说明》仍在，且申请入口一致。

**未找到官方依据的（不猜）**：
- ❌ 官方文档中**"个人开发者不得接入"的明文表述** —— 我没有读到。
- ❌ 具体的资质硬指标（如注册资本≥50万/≥500万、软件著作权、ICP备案、医疗器械备案、《检测报告》等）。网上流传的这些数字**出自 AI 生成的内容农场文章**（见 §7），**不是官方依据**，不要拿去做决策。
- ❌ **是否收费** —— 官方接入流程文档中**没有出现任何收费环节**，但也**没有找到"免费"的明文声明**。

### 1.4 需要准备的接入前置条件（已确认部分）

综合官方示例 README 与官方 SDK FAQ：

1. **华为开发者账号**（实名认证）+ [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 中创建**项目**与**应用**
2. 用 AGC 配置的包名替换 `AppScope/app.json5` 的 `bundleName`
3. 用 AGC 配置的 **`client_id`** 替换 `entry/src/main/module.json5` 的 `metadata.client_id`
4. 生成 **SHA256 应用签名证书指纹**并添加到 AGC 对应应用配置中
5. 在 AGC **"联盟卡片"** 中，为该应用**申请具体的数据类型权限**（步数 → 申请"日常活动数据"权限）

来源：[官方示例 README](https://gitee.com/harmonyos_samples/health_-service_-kit_-sample-code/blob/master/readme_cn.md)、[【FAQ】HarmonyOS SDK 闭源开放能力 —Health Service Kit](https://segmentfault.com/a/1190000046455281)

> ⚠️ 官方 FAQ 明确警告：**`client_id` 配置错误 / 未在联盟卡片申请对应权限 → 查询权限接口返回空 / 接口报 201 鉴权失败**。这是接入最常见的坑。

---

## 2. 依赖怎么配？—— **什么都不用加**

### 2.1 官方示例的证据

官方示例仓库的两个 `oh-package.json5` **`dependencies` 均为空**：

```json5
// oh-package.json5（根目录，官方示例原文）
{
  "modelVersion": "5.0.0",
  "license": "",
  "devDependencies": { "@ohos/hypium": "1.0.11" },
  "author": "",
  "name": "newapplication",
  "description": "Please describe the basic information.",
  "main": "",
  "version": "1.0.0",
  "dynamicDependencies": {},
  "dependencies": {}          // ← 空
}
```

```json5
// entry/oh-package.json5（官方示例原文）
{
  "license": "",
  "devDependencies": {},
  "author": "",
  "name": "entry",
  "description": "Please describe the basic information.",
  "main": "",
  "version": "1.0.0",
  "dynamicDependencies": {},
  "dependencies": {}          // ← 空
}
```

### 2.2 结论

- ✅ **`@kit.HealthServiceKit` 是 HarmonyOS 系统内置 Kit**，import 即可用，**不需要 `ohpm install`**。
- ❌ **不存在也不需要 `@hwhealth/health` 这类三方包**。凡是让你在 `oh-package.json5` 里加 `@hwhealth/...` 的教程，都是编的。
- ⚠️ `@kit.HealthServiceKit` 是**闭源开放能力**（官方 FAQ 分类为"HarmonyOS SDK 闭源开放能力"），**模拟器上不可用，必须真机 + 已申请权限的签名证书**。

官方示例的 `build-profile.json5` 用的是 `"compatibleSdkVersion": "5.0.0(12)"`、`"runtimeOS": "HarmonyOS"`。要跑 API 26，把 `compatibleSdkVersion` 提到你本地 SDK 对应版本即可；**Health Service Kit 在 API 26 上是否有变更，未找到官方依据**（见 §6）。

---

## 3. 权限怎么声明？

### 3.1 核心事实：Health Service Kit **不用 `ohos.permission.*`**

官方示例 `entry/src/main/module.json5` **原文**（注意：**整个文件里没有 `requestPermissions`**）：

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "description": "$string:module_desc",
    "mainElement": "EntryAbility",
    "deviceTypes": ["phone", "tablet"],
    "deliveryWithInstall": true,
    "installationFree": false,
    "pages": "$profile:main_pages",
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "description": "$string:EntryAbility_desc",
        "icon": "$media:startIcon",
        "label": "$string:EntryAbility_label",
        "startWindowIcon": "$media:startIcon",
        "startWindowBackground": "$color:start_window_background",
        "exported": true,
        "skills": [
          { "entities": ["entity.system.home"], "actions": ["action.system.home"] }
        ]
      }
    ],
    "metadata": [
      {
        "name": "client_id",
        // Todo Configure client_id here   ← 官方注释原文
        "value": ""
      }
    ]
  }
}
```

**你要改的只有两处**：`metadata.client_id` 的 `value`，以及 `AppScope/app.json5` 的 `bundleName`。

```json5
// AppScope/app.json5（官方示例原文）
{
  "app": {
    // Todo Change the bundle name here
    "bundleName": "com.example.newapplication",
    "vendor": "example",
    "versionCode": 1000000,
    "versionName": "1.0.0",
    "icon": "$media:app_icon",
    "label": "$string:app_name"
  }
}
```

### 3.2 那么"权限"体现在哪？—— 三层，都不在 `requestPermissions`

| 层 | 机制 | 位置 |
|---|---|---|
| ① 应用级 | `client_id`（= AGC 的 AppID）+ SHA256 证书指纹 | `module.json5` 的 `metadata` + AGC 配置 |
| ② 数据类型级 | 在 AGC **"联盟卡片"** 申请具体**数据类型权限**（如"日常活动数据"、"锻炼记录"） | AGC 控制台，**人工审批** |
| ③ 用户级 | 运行时 `healthStore.requestAuthorizations()` 拉起华为账号登录 + 授权页 | 应用代码，`user_grant` 语义 |

官方 FAQ 原文印证：
> 「获取步数需要先在 **Health Service Kit 联盟卡片**中申请**日常活动采样数据权限**……权限申请通过后，**在用户授权的前提下**，可以通过以下接口获取步数数据」

> 「如果需要使用锻炼记录权限，请**在联盟卡片中为当前应用申请锻炼记录权限**」

> 「请检查 `module.json5` 文件中配置的 `client_id`，是否有在联盟卡片中申请锻炼记录权限」

### 3.3 对比：传感器方案**才**需要 `ohos.permission.*`

从 OpenHarmony 官方权限文档确认（这两条都是 **user_grant**，即需要运行时弹窗）：

```json5
// 传感器方案才需要写这个。Health Kit 方案不需要。
"requestPermissions": [
  {
    "name": "ohos.permission.ACTIVITY_MOTION",
    "reason": "$string:reason_activity_motion",
    "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
  }
]
```

| 权限 | 授权方式 | 权限级别 | 起始版本 | 用途 |
|---|---|---|---|---|
| `ohos.permission.ACTIVITY_MOTION` | **user_grant** | normal | API 7 | 读取用户运动状态与**步数**；计步传感器 `PEDOMETER` / `PEDOMETER_DETECTION` 必需 |
| `ohos.permission.READ_HEALTH_DATA` | **user_grant** | normal | API 7 | 读取用户健康数据；`SensorId.HEART_RATE` 传感器必需。**注意：这不是 Health Kit 的权限** |
| `ohos.permission.KEEP_BACKGROUND_RUNNING` | system_grant | normal | — | 长时任务必需（见 §5.3） |

来源：[Open user_grant Permissions](https://gitee.com/openharmony/docs/blob/master/en/application-dev/security/AccessToken/permissions-for-all-user.md)

> ✅ **结论：`ohos.permission.ACTIVITY_MOTION` 和 `ohos.permission.READ_HEALTH_DATA` 都是 user_grant，需要 `abilityAccessCtrl.requestPermissionsFromUser()` 弹窗。**
> ✅ **Health Service Kit 不需要任何 `ohos.permission.*`。**

---

## 4. ArkTS 代码（基于官方示例源码）

### 4.1 import 语句（确切模块路径）

```ts
import { healthStore } from '@kit.HealthServiceKit';   // 数据开放：读采样数据/锻炼记录/聚合
import { healthService } from '@kit.HealthServiceKit';  // 运动联动：读实时三环
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
```

### 4.2 授权流程（官方 `AuthManagement.ets` 原文，逐行核对）

```ts
import { healthStore } from '@kit.HealthServiceKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class AuthManagement {
  // 拉起华为账号登录 + 授权页
  public static async auth(context: common.UIAbilityContext) {
    try {
      let authorizationParameter: healthStore.AuthorizationRequest = {
        readDataTypes: [
          healthStore.exerciseSequenceHelper.DATA_TYPE,
          healthStore.samplePointHelper.dailyActivities.DATA_TYPE,   // ← 步数/活动热量靠这个
          healthStore.healthSequenceHelper.sleepRecord.DATA_TYPE,
          healthStore.samplePointHelper.bodyTemperature.DATA_TYPE
        ],
        writeDataTypes: [
          healthStore.exerciseSequenceHelper.DATA_TYPE,
          healthStore.healthSequenceHelper.sleepRecord.DATA_TYPE,
          healthStore.samplePointHelper.bodyTemperature.DATA_TYPE
        ]
      };

      let authorizationResponse: healthStore.AuthorizationResponse =
        await healthStore.requestAuthorizations(context, authorizationParameter);

      authorizationResponse.readDataTypes.forEach(dataType => {
        hilog.info(0x0000, 'testTag', `grantedReadDataTypes is : ${dataType.name}`);
      });
      return 'ok';
    } catch (err) {
      hilog.error(0x0000, 'testTag',
        `Failed to request authorization. Code: ${err.code}, message: ${err.message}`);
      return `Failed: ${err.code} ${err.message}`;
    }
  }

  // 查询已授权状态
  public static async getAuth(): Promise<string> {
    let parameter: healthStore.AuthorizationRequest = {
      readDataTypes: [healthStore.samplePointHelper.dailyActivities.DATA_TYPE],
      writeDataTypes: []
    };
    let queryAuthorizationResponse = await healthStore.getAuthorizations(parameter);
    let result: string = '';
    queryAuthorizationResponse.readDataTypes.forEach(dataType => {
      result += `grantedReadDataTypes is : ${dataType.name}\n`;
    });
    return result;
  }

  // 取消授权
  public static async cancelAuthAll(): Promise<string> {
    await healthStore.cancelAuthorizations();
    return 'cancelled';
  }
}
```

> ⚠️ **官方 SDK FAQ 补充**：「接口调用前，**需先使用 init 方法进行初始化**，没有回调的问题请确认是否已调用 init 方法。」
> 但**官方 Gitee 示例源码中没有显式调用 `init`**。这可能是 API 版本差异。**`healthStore.init` 的确切签名/参数未找到官方依据** —— 落地前请在 DevEco 中对 `healthStore.` 做代码补全确认，或查 API 参考。这是最容易踩的第一个坑。
> 来源：[【FAQ】HarmonyOS SDK 闭源开放能力 —Health Service Kit](https://segmentfault.com/a/1190000046455281)

### 4.3 读「今日步数」+「今日活动热量」（官方 `SamplePointManagement.ets` 的 `aggregateData` 原文）

官方示例用 `dailyActivities` 采样数据 + `aggregateData` 聚合，`metrics` 里 `step` 和 `calorie` 就是步数与热量：

```ts
import { healthStore } from '@kit.HealthServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// 工具：时间戳 → "MM/DD/YYYY" 字符串（官方 DateUtils.ets 原文）
export class DateUtils {
  private static readonly YEAR_FORMAT = 10000;
  private static readonly MONTH_FORMAT = 100;

  public static getYyyyMmDd(timeStamp: number | string): number {
    const date = new Date(timeStamp);
    return date.getFullYear() * DateUtils.YEAR_FORMAT
      + (date.getMonth() + 1) * DateUtils.MONTH_FORMAT
      + date.getDate();
  }

  public static parseYyyyMmDdToDate(date: number): string {
    const s = date + '';
    return `${s.slice(4, 6)}/${s.slice(6, 8)}/${s.slice(0, 4)}`;
  }
}

export class DailyActivityQuery {
  /** 读今日步数 + 活动热量（按天聚合，sum） */
  public static async readTodayStepsAndCalorie(): Promise<string> {
    const now = new Date().getTime();
    try {
      let aggregateRequest: healthStore.AggregateRequest<
        healthStore.samplePointHelper.dailyActivities.AggregateFields> = {
        dataType: healthStore.samplePointHelper.dailyActivities.DATA_TYPE,
        metrics: {
          step: ['sum'],                // ← 步数
          calorie: ['sum'],             // ← 活动热量（卡路里）
          distance: ['sum'],
          climbHighAltitude: ['sum'],
          isIntensity: ['sum'],
          isStand: ['sum']
        },
        groupBy: {
          unitType: healthStore.GroupUnitType.DAY,   // 按天分组
        },
        startLocalDate: DateUtils.parseYyyyMmDdToDate(DateUtils.getYyyyMmDd(now)),
        endLocalDate: DateUtils.parseYyyyMmDdToDate(DateUtils.getYyyyMmDd(now))
      };

      let aggregateResults: healthStore.AggregateResult[] =
        await healthStore.aggregateData<
          healthStore.samplePointHelper.dailyActivities.AggregateResult>(aggregateRequest);

      let out = '';
      aggregateResults.forEach((aggregateResult) => {
        out += `startTime=${aggregateResult.startTime} endTime=${aggregateResult.endTime}\n`;
        Object.keys(aggregateResult.fields).forEach((fieldName) => {
          out += `${fieldName} sum = ${aggregateResult.fields[fieldName].sum}\n`;
        });
      });
      hilog.info(0x0000, 'testTag', out);
      return out;   // 里面会有 step.sum / calorie.sum
    } catch (err) {
      hilog.error(0x0000, 'testTag',
        `Failed to aggregate. Code: ${err.code}, message: ${err.message}`);
      return '';
    }
  }
}
```

**也可读明细**（官方 `readData` 模式，把数据类型换成 `dailyActivities`）：

```ts
const samplePointReadRequest: healthStore.SamplePointReadRequest = {
  samplePointDataType: healthStore.samplePointHelper.dailyActivities.DATA_TYPE,
  startTime: 1690888800000,
  endTime:   1690888900000
};
let samplePoints: healthStore.SamplePoint[] =
  await healthStore.readData<healthStore.samplePointHelper.dailyActivities.Model>(
    samplePointReadRequest);
samplePoints.forEach((sp) => {
  hilog.info(0x0000, 'testTag', `step=${sp.fields.step}, calorie=${sp.fields.calorie}`);
});
```

> ✅ **数据及时性：官方 FAQ 明确 `readData` / `aggregateData` 的数据为「10 分钟级」**。所以「今日步数」会有最多约 10 分钟延迟。要"实时"就用 §4.5 的 `readActivityReport`。

**`dailyActivities` 已确认的字段（`metrics` / `AggregateFields` 键名，来自官方示例源码）**：
`step`、`calorie`、`distance`、`climbHighAltitude`、`isIntensity`、`isStand`

聚合结果的读取方式：`aggregateResult.fields[字段名].sum`、`aggregateResult.startTime`、`aggregateResult.endTime`。

### 4.4 读历史锻炼记录（官方 `ExerciseSequenceManagement.ets` 原文）

```ts
import { healthStore } from '@kit.HealthServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class ExerciseQuery {
  public static async readRunningRecords(): Promise<string> {
    const startTime = 1698040800000;   // 2023-10-23 14:00:00
    const endTime   = 1698042600000;   // 2023-10-23 14:30:00
    try {
      // 授权时必须已包含 healthStore.exerciseSequenceHelper.DATA_TYPE
      const sequenceReadRequest: healthStore.ExerciseSequenceReadRequest = {
        startTime: startTime,
        endTime: endTime,
        exerciseType: healthStore.exerciseSequenceHelper.running.EXERCISE_TYPE,
        count: 1,
        sortOrder: 1,
        readOptions: {
          withDetails: true,       // 是否带 details（心率/速度/海拔/轨迹）
        }
      };

      const runningSequences: healthStore.exerciseSequenceHelper.running.Model[] =
        await healthStore.readData<healthStore.exerciseSequenceHelper.running.Model>(
          sequenceReadRequest);

      let result = '';
      runningSequences.forEach((runningSequence) => {
        result += `start=${runningSequence.startTime} end=${runningSequence.endTime}\n`;
        Object.keys(runningSequence.summaries).forEach((key) => {
          Object.keys(runningSequence.summaries[key]).forEach((fieldName) => {
            result += `${key}.${fieldName} = ${runningSequence.summaries[key][fieldName]}\n`;
          });
        });
      });
      hilog.info(0x0000, 'testTag', result);
      return result;
    } catch (err) {
      hilog.error(0x0000, 'testTag',
        `Failed to read exercise sequence. Code: ${err.code}, message: ${err.message}`);
      return '';
    }
  }
}
```

**已确认的结构与字段（官方示例源码）**：

| 层级 | 字段 |
|---|---|
| 顶层 | `dataType`、`dataSourceId`、`startTime`、`endTime`、`localDate`、`timeZone`、`modifiedTime`、`exerciseType`、`duration` |
| `summaries.distance` | `totalDistance` |
| `summaries.calorie` | **`totalCalories`** ← 锻炼消耗热量 |
| `summaries.speed` | `avg`、`max` |
| `details` | `exerciseHeartRate[]`(`startTime`,`bpm`)、`speed[]`(`startTime`,`speed`)、`altitude[]`(`startTime`,`altitude`)、`location[]`(`startTime`,`latitude`,`longitude`) |
| 运动类型常量 | `healthStore.exerciseSequenceHelper.running.EXERCISE_TYPE`（其他运动类型的常量名**未找到官方依据**） |

> ⚠️ 注意 `duration` 的单位：官方示例在 `saveData` 里写 `duration: 1800000`（1800 秒 = 30 分钟，毫秒），在 `deleteByExerciseSequence` 里却写 `duration: 1800`。**官方示例自身不一致**，落地时请以 SDK 类型声明的注释为准。这是一个官方示例的已知瑕疵。

### 4.5 读「实时三环」（当日步数最及时的来源）

```ts
import { healthService } from '@kit.HealthServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class WorkoutManagement {
  // 官方 WorkoutManagement.ets 原文
  public static async readActivityReport(): Promise<string> {
    try {
      let activityReport: healthService.workout.ActivityReport =
        await healthService.workout.readActivityReport();
      let result = '';
      Object.keys(activityReport).forEach(key => {
        result += `the ${key} is ${activityReport[key]}\n`;
      });
      hilog.info(0x0000, 'testTag', result);
      return result;   // 包含当日实时步数/热量/活动小时数
    } catch (err) {
      hilog.error(0x0000, 'testTag',
        `Failed to read ActivityReport. Code: ${err.code}, message: ${err.message}`);
      return '';
    }
  }
}
```

官方论坛回答明确指出：**"可以通过接口 `readActivityReport` 获取到华为运动健康应用的实时步数"**。
来源：[HarmonyOS 对于系统传感器步数0点分割有什么方案或者最佳实践吗](https://ost.51cto.com/answer/37619)

> ⚠️ `ActivityReport` 的**具体字段名未找到官方依据**（官方示例用 `Object.keys` 动态遍历，没有硬编码字段名）。落地时打日志看 `ActivityReport` 的 key。
> ⚠️ 调用 `readActivityReport` 前必须：① 完成申请运动健康服务与配置 Client ID；② 用户已授权**日常活动数据类型读权限**。否则报 **201 鉴权失败**。

### 4.6 写数据前需要 DataSourceId（仅当你要**写**数据时）

读数据不需要；写采样数据/锻炼记录前必须先取 `dataSourceId`（官方 `InitUtils.ets` 原文）：

```ts
import { healthStore } from '@kit.HealthServiceKit';

export class InitUtils {
  private static dataSourceId: string;

  public static async getDataSourceId(): Promise<string> {
    if (InitUtils.dataSourceId) { return InitUtils.dataSourceId; }

    const request: healthStore.DataSourceReadRequest = { deviceUniqueId: 'deviceUuid_test' };
    let res: healthStore.DataSource[] = await healthStore.readDataSource(request);
    if (res) { InitUtils.dataSourceId = res[0]?.dataSourceId; }

    if (!InitUtils.dataSourceId) {
      const dataSource: healthStore.DataSourceBase = {
        deviceInfo: {
          uniqueId: 'deviceUuid_test',
          name: 'testDevice',
          category: healthStore.DeviceCategory.SMART_PHONE,
          productId: '0554',
          model: 'lotana',
          manufacturer: 'HUAWEI',
          mac: 'testDeviceMac',
          sn: 'testDeviceSn',
          hardwareVersion: '1',
          softwareVersion: '2',
          firmwareVersion: '3'
        }
      };
      InitUtils.dataSourceId = await healthStore.insertDataSource(dataSource);
    }
    return InitUtils.dataSourceId;
  }
}
```

### 4.7 已确认的 API 清单（用于代码补全核对）

| 分类 | 成员 |
|---|---|
| 授权 | `healthStore.requestAuthorizations(context, AuthorizationRequest)`、`getAuthorizations(req)`、`cancelAuthorizations()`、`AuthorizationRequest{readDataTypes,writeDataTypes}`、`AuthorizationResponse{readDataTypes,writeDataTypes}` |
| 数据读写 | `healthStore.readData<T>(req)`、`saveData(data)`、`deleteData(req \| data)` |
| 聚合 | `healthStore.aggregateData<T>(AggregateRequest)`、`AggregateRequest{dataType,metrics,groupBy,startLocalDate,endLocalDate}`、`AggregateResult{startTime,endTime,fields}`、`GroupUnitType.DAY` |
| 请求类型 | `SamplePointReadRequest`、`SamplePointDeleteRequest`、`ExerciseSequenceReadRequest`、`ExerciseSequenceDeleteRequest`、`SamplePoint` |
| 数据源 | `readDataSource`、`insertDataSource`、`updateDataSource`、`DataSourceReadRequest`、`DataSource`、`DataSourceBase`、`DeviceCategory.SMART_PHONE` |
| 数据类型 Helper | `samplePointHelper.dailyActivities.DATA_TYPE`、`samplePointHelper.bodyTemperature.DATA_TYPE`、`exerciseSequenceHelper.DATA_TYPE`、`healthSequenceHelper.sleepRecord.DATA_TYPE` |
| 运动联动 | `healthService.workout.readActivityReport()` → `healthService.workout.ActivityReport` |

---

## 5. 不需要 Health Kit 的替代方案：`@ohos.sensor` 计步传感器

### 5.1 能拿到什么 —— 已确认

`@ohos.sensor` 官方 API 文档原文：

> **`sensor.on('SensorId.PEDOMETER')`**
> `on(type: SensorId.PEDOMETER, callback: Callback<PedometerResponse>, options?: Options): void`
> 订阅计步器传感器数据。**计步传感器数据上报有一定延迟，延迟时间由具体的实现产品决定。**
> **需要权限：`ohos.permission.ACTIVITY_MOTION`**
> `options` 默认值 `200000000` ns

字段：`data.steps`（官方示例只出现这一个字段）。
`SensorId.PEDOMETER_DETECTION` 对应 `PedometerDetectionResponse`，字段 `data.scalar`，同样需要 `ohos.permission.ACTIVITY_MOTION`。

来源：[@ohos.sensor (传感器)](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-sensor-service-kit/js-apis-sensor.md)

### 5.2 可编译的完整示例

```ts
// entry/src/main/ets/entryability/EntryAbility.ets —— 在 onWindowStageCreate 后调用 StepService.start(this.context)
import { sensor } from '@kit.SensorServiceKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'StepService';
const PERMS: Permissions[] = ['ohos.permission.ACTIVITY_MOTION'];
const SENSOR_INTERVAL_NS = 1000000000;   // 1s

export class StepService {
  private static running: boolean = false;
  private static currentSteps: number = 0;

  /** 回调：把步数交给业务层 */
  private static onSteps(steps: number): void {
    StepService.currentSteps = steps;
    hilog.info(0x0000, TAG, `steps = ${steps}`);
  }

  /** 1) 运行时申请权限 → 2) 订阅计步器 */
  public static async start(context: common.UIAbilityContext): Promise<void> {
    if (StepService.running) { return; }

    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const data = await atManager.requestPermissionsFromUser(context, PERMS);
      if (data.authResults[0] !== 0) {
        hilog.error(0x0000, TAG, 'ACTIVITY_MOTION denied by user');
        return;
      }
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, `requestPermissionsFromUser failed. ${e.code} ${e.message}`);
      return;
    }

    // 建议先确认设备上存在该传感器（不存在时订阅会抛异常）
    try {
      const s: sensor.Sensor = sensor.getSingleSensorSync(sensor.SensorId.PEDOMETER);
      hilog.info(0x0000, TAG, `pedometer sensor: ${JSON.stringify(s)}`);
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, `no pedometer sensor. ${e.code} ${e.message}`);
      return;
    }

    try {
      sensor.on(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
        StepService.onSteps(data.steps);
      }, { interval: SENSOR_INTERVAL_NS });
      StepService.running = true;
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, `sensor.on failed. ${e.code} ${e.message}`);
    }
  }

  /** 单次读取（后台场景的推荐用法，见 §5.4） */
  public static readOnce(): void {
    try {
      sensor.once(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
        StepService.onSteps(data.steps);
      });
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, `sensor.once failed. ${e.code} ${e.message}`);
    }
  }

  /** 注销：on / off 必须成对出现 */
  public static stop(): void {
    if (!StepService.running) { return; }
    try {
      sensor.off(sensor.SensorId.PEDOMETER);
      StepService.running = false;
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, `sensor.off failed. ${e.code} ${e.message}`);
    }
  }
}
```

**配套 `module.json5`**（传感器必须写 `requestPermissions`，这是和 Health Kit 方案最大的差别）：

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    // ... 其余省略 ...
    "requestPermissions": [
      {
        "name": "ohos.permission.ACTIVITY_MOTION",
        "reason": "$string:reason_activity_motion",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "inuse"
        }
      }
    ]
  }
}
```

需要在 `entry/src/main/resources/base/element/string.json` 中补：

```json
{
  "string": [
    { "name": "reason_activity_motion", "value": "用于统计您的运动步数" }
  ]
}
```

> 官方文档要求：**订阅前先 `getSingleSensor` 确认传感器存在**，"订阅前可使用 getSingleSensor 接口获取该传感器的信息，获取该传感器信息成功时可正常订阅传感器"。**`on` 订阅与 `off` 取消订阅必须成对出现。**

### 5.3 后台能不能持续读？—— **不能**（已确认，这是硬结论）

**证据 1：官方长时任务类型表里没有任何"传感器/计步"类型。**
`BackgroundMode` 全集为：`DATA_TRANSFER`、`AUDIO_PLAYBACK`、`AUDIO_RECORDING`、`LOCATION`、`BLUETOOTH_INTERACTION`、`MULTI_DEVICE_CONNECTION`、`WIFI_INTERACTION`(系统应用)、`VOIP`(API13+)、`TASK_KEEPING`、`MODE_AV_PLAYBACK_AND_RECORD`(API22+)、`MODE_SPECIAL_SCENARIO_PROCESSING`(API22+)。**没有计步/传感器对应的 mode。**

而且 `TASK_KEEPING` 被严格限制：
> 「**TASK_KEEPING**（计算任务）：**从 API version 21 起**，该能力仅对 2-in-1 设备，以及已获得 ACL 权限 `ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM` 的非 2-in-1 设备可用。**在 API version 20 及更早版本，该任务类型仅限 PC/2-in-1 设备。**」

来源：[Continuous Task (ArkTS)](https://gitee.com/openharmony/docs/blob/master/en/application-dev/task-management/continuous-task.md)

**证据 2：官方论坛回答（最直接）**
> 「**长时任务中不支持记步**，但是根据应用的场景，可以申请**定位导航的长时任务**，在定位坐标回调里面，用**单次读取接口 `sensor.once()`** 去读取记步数据。」

提问者实测（官方贴出的复现表）：
| 场景 | 结果 |
|---|---|
| 前台亮屏 | ✅ 有回调 |
| 后台亮屏 | ❌ 无回调，**切回前台后补报** |
| 前台熄屏 | ❌ 无回调，**亮屏后补报** |
| 后台熄屏 | ❌ 无回调，**亮屏后补报** |

来源：[Sensor 步数传感器后台情况](https://ost.51cto.com/answer/16725)（华为官方回答，2024-09）

**证据 3：官方长时任务的合法性校验会拒绝不匹配的调用**
> 「如果应用申请了长时任务，但执行了与申请类型不匹配的业务，系统会对其进行限制。应用切到后台时将被挂起。」

也就是说：**申请 `LOCATION` 长时任务却不做定位 → 会被系统挂起。**"借壳"是有代价的。

**另一个已确认的硬限制**：`ohos.permission.KEEP_BACKGROUND_RUNNING` 是申请长时任务的前提，但即使有了它，也**不存在**一个能覆盖"纯计步"的后台模式。

> ⚠️ 我曾见到官方论坛存在一条标题《应用后台运行时使用传感器导致上架检测不通过怎么办？》，**但该页面正文无法抓取，因此"后台跑传感器会导致上架不通过"这一说法未找到官方依据**。

### 5.4 后台折中方案（官方推荐）

申请 `LOCATION` 长时任务（`ohos.permission.KEEP_BACKGROUND_RUNNING` + `ohos.permission.LOCATION` / `APPROXIMATELY_LOCATION`，`backgroundModes: ["location"]`），在定位回调里用 `sensor.once(SensorId.PEDOMETER, ...)` 读一次步数。官方示例代码：

```ts
// 官方论坛回答给出的模式
let requestInfo: geoLocationManager.LocationRequest = {
  'priority': geoLocationManager.LocationRequestPriority.FIRST_FIX,
  'scenario': geoLocationManager.LocationRequestScenario.UNSET,
  'timeInterval': 0,
  'distanceInterval': 0,
  'maxAccuracy': 0
};
let locationChange = (location: geoLocationManager.Location): void => {
  StepService.readOnce();   // 在定位回调里单次读计步
};
geoLocationManager.on('locationChange', requestInfo, locationChange);
```

**代价**：需要位置权限（用户敏感度更高）、持续定位功耗大、必须在通知栏挂常驻通知、且系统会校验"确实在做定位"。**为了计步而申请定位，在应用市场审核时是高风险项。**

### 5.5 传感器的语义陷阱：**它不是"今日步数"**

官方论坛明确提问并得到确认：
> 「目前传感器是累积步数，**如果用户把应用杀掉，此时应用无法计算步数，如果跨天打开应用，就会出现前一天的步数记录到了后一天**」

另一条官方回答直接指出：
> 「计步传感器，拿到的数据，**就是用户当天最新的步数数据**」

⚠️ 这两条**互相矛盾**：一条说会跨天串数据，一条说是当天数据。**"PEDOMETER 是否在 0 点归零"没有一致的官方依据，必须真机自测。**

来源：[步数0点分割](https://ost.51cto.com/answer/37619)、[怎么获取当天的运动步数](https://ost.51cto.com/answer/15168)

### 5.6 方案对比

| 维度 | Health Service Kit | `@ohos.sensor` PEDOMETER |
|---|---|---|
| 依赖 | 内置 Kit，零依赖 | 内置 Kit，零依赖 |
| 申请审批 | **需要**（AGC 建应用 + client_id + SHA256 指纹 + 联盟卡片申请数据类型 + 测试 100 用户上限 + 申请验证） | **不需要**，装上就能跑 |
| 权限 | 无 `ohos.permission.*`；`metadata.client_id` + 运行时授权 | `ohos.permission.ACTIVITY_MOTION`（user_grant，运行时弹窗） |
| 首次运行门槛 | 用户须登录华为账号、须已开启并同意**运动健康 App** 隐私授权 | 无 |
| 数据语义 | **真正的"当日活动数据"**（跨天正确），含活动热量/距离/站立 | 设备**开机以来累计**步数，跨天语义不确定 |
| 活动热量（卡路里） | ✅ `calorie` | ❌ **拿不到** |
| 历史锻炼记录 | ✅ `exerciseSequenceHelper` | ❌ 拿不到 |
| 数据及时性 | 10 分钟级（`readData`/`aggregateData`）；实时用 `readActivityReport` | 有延迟，"由具体实现产品决定" |
| 后台持续读 | 无此概念，按需查询 | ❌ 熄屏/后台不回调 |
| 模拟器 | ❌ 不可用，必须真机 | 部分可用，但传感器需真机 |
| 适合场景 | **正式的"今日步数/消耗卡路里"功能** | App 前台运动中的实时计步、原型验证 |

### 5.7 建议的落地策略

给你在 `D:\CaloriesApp` 的具体建议：

1. **先做传感器版跑通 UI**（30 行代码、无需审批），验证产品形态。但它给不了卡路里和历史锻炼记录。
2. **卡路里是刚需 → 必须走 Health Kit**，因为传感器方案**完全无法获得活动热量**。没有折中方案。
3. **现在就去 AGC 提申请**，因为审批以"工作日"计（账号服务约 3 天 + 服务权限约 15 天 + 验证约 15 天），是项目关键路径。同时确认你的开发者账号类型能否通过《应用开发者申请资质说明》自评——**这是唯一可能直接卡死项目的环节，且我未能读到该文档正文**。
4. 架构上把数据源做成适配层（`IStepSource` 接口 + Sensor 实现 / HealthKit 实现），这样审批没下来之前也能开发，批下来后切换实现即可。

---

## 6. 「已确认」与「不确定」清单

### ✅ 已确认（有官方文档/官方示例源码/官方账号回答原文支撑）

| 结论 | 来源 |
|---|---|
| `@kit.HealthServiceKit` 是系统内置 Kit，无需任何 `oh-package.json5` 依赖 | [官方示例 oh-package.json5](https://gitee.com/harmonyos_samples/health_-service_-kit_-sample-code/blob/master/oh-package.json5) |
| Health Kit 方案在 `module.json5` 中**不需要** `requestPermissions`，只需要 `metadata.client_id` | [官方示例 module.json5](https://gitee.com/harmonyos_samples/health_-service_-kit_-sample-code/blob/master/entry/src/main/module.json5) |
| 接入需：AGC 建应用 / 配 bundleName / 配 client_id / 配 SHA256 指纹 / 联盟卡片申请数据类型权限 | [官方示例 README](https://gitee.com/harmonyos_samples/health_-service_-kit_-sample-code/blob/master/readme_cn.md)、[官方 SDK FAQ](https://segmentfault.com/a/1190000046455281) |
| 审批周期：账号服务约 3 工作日；Health Kit 权限约 15 工作日；申请验证约 15 工作日 | [快速加入Health Kit，一文了解审核流程](https://huaweicloud.csdn.net/6502d50b993dd34278ee312a.html) |
| 测试阶段 100 用户上限，申请验证通过后解除 | 同上 + [官方 SDK FAQ](https://segmentfault.com/a/1190000046455281) |
| 步数属"基础的用户数据"，审核条件低于高阶数据 | [官方论坛回答](https://ost.51cto.com/answer/40606) |
| 步数走 `samplePointHelper.dailyActivities`，需在联盟卡片申请"日常活动数据"权限 | [官方 SDK FAQ](https://segmentfault.com/a/1190000046455281)、[官方论坛回答](https://ost.51cto.com/answer/30963) |
| `dailyActivities` 聚合字段：`step`/`calorie`/`distance`/`climbHighAltitude`/`isIntensity`/`isStand` | [官方示例 SamplePointManagement.ets](https://gitee.com/harmonyos_samples/health_-service_-kit_-sample-code/blob/master/entry/src/main/ets/common/bean/SamplePointManagement.ets) |
| 锻炼记录用 `exerciseSequenceHelper`，`summaries.calorie.totalCalories` | [官方示例 ExerciseSequenceManagement.ets](https://gitee.com/harmonyos_samples/health_-service_-kit_-sample-code/blob/master/entry/src/main/ets/common/bean/ExerciseSequenceManagement.ets) |
| `readData`/`aggregateData` 数据为 10 分钟级 | [官方 SDK FAQ](https://segmentfault.com/a/1190000046455281) |
| `readActivityReport` 可拿实时步数 | [官方论坛回答](https://ost.51cto.com/answer/37619) |
| 401/201 中 **201 = 鉴权失败**，成因含指纹错误、缺权限、白名单、测试用户超限 | [官方 SDK FAQ](https://segmentfault.com/a/1190000046455281) |
| 调用前需 `healthStore.init()`（但官方示例未调用） | [官方 SDK FAQ](https://segmentfault.com/a/1190000046455281) |
| `sensor.on(SensorId.PEDOMETER, cb, {interval})`，回调 `PedometerResponse.steps`，权限 `ohos.permission.ACTIVITY_MOTION` | [@ohos.sensor 官方 API 文档](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-sensor-service-kit/js-apis-sensor.md) |
| `ohos.permission.ACTIVITY_MOTION` / `READ_HEALTH_DATA` 均为 **user_grant, normal, since API 7** | [Open user_grant Permissions](https://gitee.com/openharmony/docs/blob/master/en/application-dev/security/AccessToken/permissions-for-all-user.md) |
| **长时任务中没有计步/传感器类型**；`TASK_KEEPING` 仅 2-in-1 或需 ACL 受限权限 | [Continuous Task (ArkTS)](https://gitee.com/openharmony/docs/blob/master/en/application-dev/task-management/continuous-task.md) |
| **后台/熄屏时计步传感器不回调**；长时任务不支持记步；官方建议用 LOCATION + `sensor.once()` | [官方论坛回答](https://ost.51cto.com/answer/16725) |
| 传感器方案拿不到活动热量、拿不到锻炼记录 | 由上述 API 面推导（`PedometerResponse` 仅有 `steps`） |
| 后台跑不匹配类型的长时任务会被系统挂起 | [Continuous Task (ArkTS)](https://gitee.com/openharmony/docs/blob/master/en/application-dev/task-management/continuous-task.md) |

### ❌ 未找到官方依据（不要猜）

| 问题 | 状态 |
|---|---|
| 《应用开发者申请资质说明》的**具体资质指标**（注册资本、软著、ICP、医疗资质、成立年限等） | **未找到官方依据**。文档站是 SPA，正文无法读取。所有网传具体数字均出自 AI 内容农场。链接：[应用开发者申请资质说明](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/health-application-qualifications) |
| **个人开发者是否被明确排除** | **未找到官方依据**。只能确认该文档按组织机构类型分档（存在"企业事业单位政府机构社会团体开发者接入资质审核要求"锚点） |
| Health Service Kit **是否收费** | **未找到官方依据**。接入流程中无收费环节，但也无"免费"明文 |
| **API 26 / HarmonyOS 7** 对 Health Service Kit 的变更 | **未找到官方依据**。未找到任何官方 release note 提到 Health Kit 运动数据读取的新增/变更。CSDN 上那篇《HarmonyOS 7 新特性（一百一十一）｜Health Kit 运动数据读取》是 AI 生成的空壳（正文含 `interface 111Capability` 这种非法标识符，零真实 API） |
| `healthStore.init()` 的确切签名与参数 | **未找到官方依据**（官方示例未调用，FAQ 只说"需先调用 init"） |
| 各数据类型的 **`DATA_TYPE` 字符串字面值** | **未找到官方依据**。官方示例只使用 `...dailyActivities.DATA_TYPE` 这类常量，未展示字符串值 |
| `PedometerResponse` 的**完整字段表** | **未找到官方依据**。官方文档只出现 `steps` |
| `healthService.workout.ActivityReport` 的**具体字段名** | **未找到官方依据**。官方示例用 `Object.keys` 动态遍历 |
| 除 `running` 外的**其他运动类型常量名** | **未找到官方依据** |
| `healthStore` 各 API 的**完整错误码表** | **未找到官方依据**（只确认 201 = 鉴权失败） |
| **PEDOMETER 是否在 0 点归零** | **官方说法自相矛盾**，必须真机自测 |
| 背后跑传感器的**上架审核政策** | **未找到官方依据**（相关论坛页正文无法抓取） |

---

## 7. ⚠️ 踩坑警告：网上大量 AI 生成的假 Health Kit 教程

调研中发现**至少三篇高排名文章在编造 API**。如果你照着它们写，编译不过：

| 假内容 | 出处 | 真相 |
|---|---|---|
| `ohos.permission.HEALTH_DATA_READ` / `HEALTH_DATA_WRITE` | [CSDN《HarmonyOS 5运动健康类应用集成HarmonyOS SDK应用服务的准备工作指南》](https://blog.csdn.net/csdn_hjj_/article/details/148846556) | **这两个权限不存在**。Health Kit 不用 `ohos.permission.*` |
| `import { HealthServiceKit } from '@kit.HealthServiceKit'; HealthServiceKit.requestAuthorization(...)` | 同上 | **成员名和 API 都是编的**。真实是 `healthStore.requestAuthorizations(context, req)` |
| `sensor.subscribeAccelerometer(...)` | 同上 | **不存在**。真实是 `sensor.on(sensor.SensorId.ACCELEROMETER, cb, opts)` |
| `android.permission.READ_HEALTH_DATA` + `reqPermissions` + `HealthDataObserver` | [51CTO《我用鸿蒙实现步数监听》](https://ost.51cto.com/posts/45471) | **全篇虚构**，把安卓权限名搬到鸿蒙，`reqPermissions` 是 FA 模型旧字段 |
| `interface 111Capability` 这样的"示例代码" | [CSDN《HarmonyOS 7 新特性（一百一十一）｜Health Kit 运动数据读取》](https://harmonyosdev.csdn.net/6aab9a99cf836948fcd2af32.html) | 标识符含数字开头，**根本无法编译**；该文没有任何真实 API |

**判据**：真文章会引用 `@kit.HealthServiceKit` / `healthStore.samplePointHelper.dailyActivities` 这类**具体到 helper 三级路径**的标识符；假文章只会写 `HealthServiceKit.requestAuthorization` 这种"看起来很像"的扁平 API。

---

## 8. 主要参考链接

**华为官方**
- [Health Service Kit 官方示例源码（Gitee）](https://gitee.com/harmonyos_samples/health_-service_-kit_-sample-code) ← **最高可信度，建议直接拉下来跑**
- [官方示例 README](https://gitee.com/harmonyos_samples/health_-service_-kit_-sample-code/blob/master/readme_cn.md)
- [接入流程](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/health-application-access)
- [应用开发者申请资质说明](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/health-application-qualifications)
- [申请验证获取正式权限](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/health-verification)
- [配置 Client ID](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/health-configuration-client-id)
- [读取实时三环数据](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/health-three-ring-read)
- [权限说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/health-permission-description)
- [healthStore ArkTS API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/health-api-healthstore)
- [healthService ArkTS API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/health-api-healthservice)
- [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)

**官方问答 / 官方账号文章（可抓取，内容已核对）**
- [【FAQ】HarmonyOS SDK 闭源开放能力 —Health Service Kit](https://segmentfault.com/a/1190000046455281)
- [快速加入 Health Kit，一文了解审核流程](https://huaweicloud.csdn.net/6502d50b993dd34278ee312a.html)
- [如何获取当天步数（官方回答）](https://ost.51cto.com/answer/40606)
- [获取用户的步数（官方回答，含三个接口指引）](https://ost.51cto.com/answer/30963)
- [Sensor 步数传感器后台情况（官方回答）](https://ost.51cto.com/answer/16725)
- [步数 0 点分割（官方回答）](https://ost.51cto.com/answer/37619)
- [怎么获取当天的运动步数（官方回答）](https://ost.51cto.com/answer/15168)

**系统 API 权威定义（OpenHarmony 官方仓库，静态可读）**
- [@ohos.sensor (传感器) 中文 API](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-sensor-service-kit/js-apis-sensor.md)
- [Sensor Development (ArkTS) 开发指南](https://gitee.com/openharmony/docs/blob/master/en/application-dev/device/sensor/sensor-guidelines.md)
- [Open user_grant Permissions](https://gitee.com/openharmony/docs/blob/master/en/application-dev/security/AccessToken/permissions-for-all-user.md)
- [Continuous Task (ArkTS)](https://gitee.com/openharmony/docs/blob/master/en/application-dev/task-management/continuous-task.md)
- [计步器应用 Codelab（官方，含后台任务范例）](https://cloud.tencent.cn/developer/article/2433021)
