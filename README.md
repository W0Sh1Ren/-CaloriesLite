# 轻卡记 · Calorie Lite

一个极简的热量控制应用，HarmonyOS 7 / **API 26**，ArkTS 开发。

只做三件事：**算出你一天该吃多少**、**帮你记下吃了多少**、**告诉你今天差多少**。
没有会员、没有广告、没有社交、没有打卡任务。所有数据只存在本机。

---

## 功能

| 功能 | 说明 |
|---|---|
| 基础热量推算 | 用 Mifflin-St Jeor 公式算 BMR，乘活动系数得 TDEE，再按目标（减脂/保持/增重）调整出每日预算 |
| 拍照识别热量 | 拍食物照片，压缩后发给**你自己的** AI 视觉接口识别，先查内置食物表拿精确值，表里没有的才用 AI 估算 |
| 一天热量缺口 | 首页一个环讲清收支：`缺口 = 每日预算 + 运动消耗 − 摄入`，正数是缺口，负数是超标 |
| 内置食物表 | 约 290 条常见中式食物的每 100 克营养值（主食/肉蛋/蔬菜/水果/菜肴/零食/饮品） |
| 手动添加 | 搜索食物表挑条目、改克重，或直接手填 |
| 饮食历史日历 | 月历热力图标出每天的缺口健康程度，点某天看当天明细 |
| 体重记录 + 趋势曲线 | 手绘折线图，记体重后基础热量会随真实体重自动重算 |
| 运动消耗 | 按 MET 值 × 体重 × 时长算消耗（比按分钟拍脑袋准），支持手动录入 |

### 关于 AI 接口

**本应用不提供、不代管任何 AI 额度。** 识别功能用你自己申请的 API Key，
Key 只保存在本机应用沙箱里，识别时由手机直连你填的服务商，不经过任何中间服务器。

支持两类接口：

- **OpenAI 兼容** 的 `/chat/completions`（覆盖智谱 GLM、通义千问、硅基流动、Kimi、DeepSeek、OpenAI 及各类中转站）
- **Google Gemini** 的 `generateContent`

设置页内置了常见服务商的预设，点一下自动填好接口地址和模型名，还有「测试连接」按钮当场验证配置。
**模型必须支持图片输入（识图），纯文本模型无法识别照片。**

---

## 技术要点

### 热量算法

```
BMR(男) = 10×体重kg + 6.25×身高cm − 5×年龄 + 5
BMR(女) = 10×体重kg + 6.25×身高cm − 5×年龄 − 161
TDEE    = BMR × 活动系数(1.2 ~ 1.9)
每日预算 = TDEE + 目标调整(−500 / −300 / 0 / +300)，且不低于 BMR
缺口    = 每日预算 + 运动消耗 − 摄入
```

### 识别的两层策略

图片先在本机压到长边 1024、JPEG 质量 80（原图动辄 4–8 MB，直接 base64 会撑爆请求体），
然后：

1. 让视觉模型只回答「这是什么食物、大概多少克」；
2. 拿到食物名后**先查内置食物表**，命中就用表里的精确营养值按克重折算；
3. 表里没有的条目（比如某家店的招牌菜）才采用 AI 的热量估算，并在界面上标注来源，让用户知道这个数字有多可信。

结果页每一条都能改名字、克重、餐次，确认后才写进记录——AI 估错不会直接污染当天数据。

### 数据存储

`@kit.ArkData` 的 preferences，一天一个键 + 日期索引。全部数据留在本机，不联网同步。

---

## 目录结构

```
entry/src/main/ets/
├── common/            DateUtil(日期) JsonUtil(JSON) Store(存储) Theme(样式)
│                      PermissionUtil(权限) AppState(跨页状态)
├── model/             Types(类型定义) Enums(枚举与文案) FoodDatabase(食物表)
├── service/           CalorieCalc(热量算法) DailyService(每日结算)
│                      FoodRepo/BodyRepo/ExerciseRepo/SettingsRepo(仓库层)
│                      FoodMatcher(食物表检索) VisionService(AI 识别) ImageService(图片处理)
├── components/        CalorieRing(热量环) MacroBar(营养素条) RecordRow(记录行)
│                      CalendarHeatmap(日历热力) WeightChart(体重曲线)
└── pages/             Index(今天/记录/我的) Camera(拍照识别) ResultConfirm(结果确认)
                       ManualAdd(手动添加) AiSettings(AI 配置)
```

---

## 构建

### 环境要求

- DevEco Studio **26.0.0** 或更高（内含 API 26 SDK）
- Node.js 18+

### 用 DevEco Studio（推荐）

1. 用 DevEco Studio 打开本目录，等 Sync 完成
2. `File > Project Structure > Signing Configs`，勾选 **`Automatically generate signature`**
   （需要已登录华为开发者账号；本项目已在 `build-profile.json5` 里预留 `signingConfig: "default"` 引用）
3. 顶部设备下拉框选你的设备，点 ▶ 运行

### 命令行构建

脚本在 `tools/` 下：

```powershell
# 1) 把 DevEco 工具链复制进工作区（约 410 MB，只需一次）
powershell -ExecutionPolicy Bypass -File tools\prepare-toolchain.ps1

# 2) 同步源码到编译副本并安装依赖
powershell -ExecutionPolicy Bypass -File tools\sync-src.ps1

# 3) 构建
powershell -ExecutionPolicy Bypass -File tools\build.ps1
```

产物在 `tools/proj/entry/build/default/outputs/default/`。

> 若已在 DevEco 里配好自动签名，`sync-src.ps1` 会把签名配置一起带过去，
> 构建直接产出 `entry-default-signed.hap`（脚本会打印 `signing config found` 提示）。
> 否则产出 `entry-default-unsigned.hap`，装不到真机。

### 安装到真机

```powershell
# 检查设备（需在手机上打开 USB 调试）
& 'D:\DevEco26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets

# 安装（用签名后的 hap）
& '...\hdc.exe' install -r tools\proj\entry\build\default\outputs\default\entry-default-signed.hap
```

也可以直接用 `tools\sign-and-install.ps1`，它用 SDK 自带的 `OpenHarmony.p12`
离线签发调试证书和 Profile 并安装。注意：这种方式用的是 OpenHarmony 的根证书，
**华为商用机不一定信任**；如果安装报签名校验失败，就走 DevEco 自动签名那条路。

#### 这些脚本在绕开什么

| 限制 | 绕法 |
|---|---|
| hvigor 用户缓存默认在 `~/.hvigor`，当前环境不可写 | 用 `HVIGOR_USER_HOME` 重定向到工作区内 |
| hvigor 以**符号链接**注入 `@ohos/hvigor` 等包；Windows 普通用户建符号链接需要开发者模式或管理员权限 | 把工具链复制进工作区（`tools/prepare-toolchain.ps1`），让链接两端都在可写区域内 |
| 当前环境禁止命名管道，`child_process.fork` 与管道 stdio 的 spawn 全部 EPERM | `tools/run-hvigor.js` 把 spawn 系列补丁成 `stdio: 'inherit'` 后重试 |
| `restool.exe` 需要同目录 DLL，找不到就报 `11201001 (126)` | 构建脚本把 SDK 各 toolchains 目录加进 `PATH` |
| npm 官方源在本机证书链异常 | 走 `registry.npmmirror.com` 镜像 |

> **在正常的 DevEco Studio 图形界面里构建不需要以上任何绕法**，这些只是因为当前开发环境受限。
> `tools/local/`、`tools/proj/`、`tools/.hvigorhome/`、`tools/.npmcache/` 都是可再生的中间产物，已在 `.gitignore` 中排除。

---

## 已知限制

- **运动数据目前是手动录入**。华为运动健康（Health Kit）需要走申请流程：开发者账号 → 申请帐号服务（约 3 工作日）→ 在 AGC「联盟卡片」申请具体数据类型权限（约 15 工作日）→ 测试期上限 100 用户 → 申请验证解除限制（约 15 工作日）。
  卡路里是刚需，而计步传感器拿不到活动热量和锻炼记录，所以没有折中方案。`ExerciseRepo.mergeFromHealth()`
  已经预留了按「日期+来源+名称」去重的同步入口，审批下来后接上即可。
  详见 `docs/HealthKit-运动健康数据读取-技术报告.md`。
- AI 识别准确率取决于所选模型，份量估算误差通常在 10–20%。结果页支持逐条修正。
- 内置食物表的营养值为代表性均值，实际因品种和烹饪方式浮动，表中菜肴类为烹饪后估算值。
- 热量环用 **Canvas 自绘**，不是 ArkUI 的 `Progress`。实测 `Progress` 在 Ring 模式下
  不会把尺寸撑开给父 `Stack`（210vp 的环被压成 75vp 高，只露出一小段弧），自绘才可靠。
  体重曲线同样用 Canvas 手绘。

### 构建产物与包名

- DevEco Studio 生成自动签名时会把 `bundleName` 从 `com.calorielite.app` 改写成
  `Calories.Lite.Test`（它的自动签名要求包名匹配它的命名规则）。如果换成正式包名，
  记得同步更新 `tools/sign-and-install.ps1` 里的默认值——该脚本已改为从
  `AppScope/app.json5` 自动读取，一般不用手改。
- 已实测设备：HUAWEI Mate 80（VYG-AL00），HarmonyOS 7.0.0.109，API 26。

---

## 文档

- `Teach/` —— **面向新手的教程**：从「App 是什么」讲到每个功能的实现，
  外加一份踩坑笔记。**完全没做过 App 开发也能看懂**，建议从这里开始：
  [`Teach/00-索引.md`](Teach/00-索引.md)
- `docs/harmonyos-api26-photo-ai-vision.md` —— 拍照/选图 → 压缩 → base64 → 调 AI 视觉接口的 API 取证报告（含官方文档链接与 ArkTS 严格模式踩坑清单）
- `docs/HealthKit-运动健康数据读取-技术报告.md` —— 华为运动健康接入调研（申请流程、权限、代码、传感器替代方案对比）

---

## 隐私

- 所有饮食、体重、运动记录只写在本机应用沙箱，不上传任何服务器
- 不含任何统计、埋点或第三方 SDK
- 食物照片只在本机压缩后发送给你自己配置的 AI 服务商
- API Key 只存本机；「我的」页可一键清空全部数据
