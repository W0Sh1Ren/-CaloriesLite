# 03 · ArkTS 语法入门

这一章**只讲这个项目里出现的语法**，不追求完整。
目标：你打开任意一个 `.ets` 文件，能看懂它在说什么。

代码都可以在项目里找到，我标了文件路径，建议边读边对照。

---

## 一、ArkTS 是什么

**ArkTS = TypeScript + 鸿蒙的界面写法**。

| | 说明 |
|---|---|
| **TypeScript** | 微软做的语言，是 JavaScript 的加强版（加了类型） |
| **ArkTS** | 华为在此基础上又加了一套「描述界面」的语法 |

文件扩展名是 **`.ets`**（不是 `.ts`）。

### 和 JavaScript 最大的区别：**必须有类型**

```ts
// JavaScript 里可以这样，不说明 a 是什么
let a = 1;

// ArkTS 里必须写明类型
let a: number = 1;              // 数字
let name: string = '红烧肉';     // 文字
let ok: boolean = true;         // 真/假
```

看项目里的真实例子 —— `common\DateUtil.ets` 第 13 行：

```ts
export function toDayKey(timestamp: number): string {
  const d = new Date(timestamp);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}
```

拆开读：

| 片段 | 含义 |
|---|---|
| `export` | 这个函数**别的文件也能用** |
| `function` | 定义一个函数 |
| `toDayKey` | 函数名（把时间戳转成日期字符串） |
| `(timestamp: number)` | 收一个参数，名叫 `timestamp`，**类型是数字** |
| `: string` | **返回**一个文字 |
| `` `${...}` `` | 模板字符串，用反引号，里面可以嵌变量 |

---

## 二、变量：`const` 和 `let`

```ts
const COLOR_PRIMARY: string = '#22C55E';   // 常量，之后不能改
let count: number = 0;                      // 变量，之后可以改
```

**习惯**：能用 `const` 就用 `const`。
看 `common\Theme.ets` —— 所有颜色都是 `const`，因为定义好就不该改。

---

## 三、`interface` 和 `class`：描述数据长什么样

这是**这个项目最重要的概念**，因为几乎所有数据都靠它定义。

### `class`：一个正式的「数据模板」

`model\Types.ets` 里定义「一条饮食记录」：

```ts
export class FoodRecord {
  id: string = '';                      // 唯一编号
  dayKey: string = '';                  // 属于哪一天，如 "2026-10-05"
  name: string = '';                    // 食物名，如 "红烧肉"
  grams: number = 0;                    // 克重
  kcal: number = 0;                     // 热量
  protein: number = 0;                  // 蛋白质
  mealType: MealType = MealType.LUNCH;  // 属于哪一餐
  // …还有其他字段
}
```

**读法**：字段名 + `:` + 类型 + `= 默认值`

| 部分 | 作用 |
|---|---|
| `name: string` | 声明有个叫 `name` 的字段，放文字 |
| `= ''` | **默认值**。不特别指定时就是空字符串 |
| `mealType: MealType = MealType.LUNCH` | 类型不是基础类型，而是一个**枚举**（下面讲） |

### 为什么必须有默认值

ArkTS 里 `class` 的字段**都要给默认值或不给**，写代码时如果忘了赋值，
取到的就是默认值而不是「报错」。这样界面不会崩，但可能显示空。

**好处**：安全。**坏处**：忘了赋值不会报错，数据会「悄悄是空的」。

### 怎么用它

```ts
// 新建一条记录
const rec = new FoodRecord();
rec.name = '红烧肉';
rec.grams = 90;
rec.kcal = 315;
```

`new` 就是「按模板造一个新对象」。

---

## 四、`enum`：固定的几个选项

`model\Enums.ets` 里：

```ts
export enum MealType {
  BREAKFAST = 'breakfast',
  LUNCH = 'lunch',
  DINNER = 'dinner',
  SNACK = 'snack'
}
```

**为什么不用中文直接写？**

假设到处写 `'早餐'`，某天你想改成 `'早饭'`，就得全项目搜索替换，还容易漏。
用 `MealType.BREAKFAST` 的话，**只改枚举定义那一处**。

而且写错了编译器会报错 —— 写 `MealType.BREAKFEST`（拼错）立刻会发现，
但写 `'早参'`（打错字）编译器不管。

**枚举的两种形态**（项目里都有）：

```ts
// 形态一：带具体值（存到文件里的是 'breakfast'）
export enum MealType { BREAKFAST = 'breakfast' }

// 形态二：不带值（自动编号 0, 1, 2…）
export enum Gender { MALE, FEMALE }
```

**经验**：**要存进文件的值一定用形态一**（写死字符串）。
因为不带值的枚举，以后你插一个新选项，所有旧数据的编号就错位了。

---

## 五、界面怎么写：`@Component` + `build()`

这是 ArkTS 最特别的地方。看真实例子 —— `components\ProfileOption.ets`：

```ts
@Component
export struct ProfileOption {
  @Prop label: string = '';
  @Prop selected: boolean = false;

  build() {
    Column({ space: 2 }) {
      Text(this.label)
        .fontSize(14)
        .fontColor(this.selected ? COLOR_PRIMARY : COLOR_TEXT)

      Text(this.desc)
        .fontSize(10)
    }
    .width('100%')
    .padding({ left: 8, right: 8 })
  }
}
```

### 逐行拆解

| 片段 | 含义 |
|---|---|
| `@Component` | 标记「**这是一个界面组件**」 |
| `struct` | 鸿蒙特有的关键字，类似 `class`，但专用于界面 |
| `@Prop label: string` | 一个**从外面传进来**的属性 |
| `build() { … }` | **必写的方法**，描述这个组件长什么样 |

### 关键：`build()` 里是「声明」不是「命令」

对比一下两种思路：

```ts
// ❌ 命令式（传统写法，鸿蒙不用）
创建一个 Column
设置它的宽度为 100%
创建第一个 Text，内容是 xxx
把它加到 Column 里
创建第二个 Text…
```

```ts
// ✅ 声明式（ArkTS 的写法）
Column() {
  Text('第一行')
  Text('第二行')
}
.width('100%')
```

**声明式的意思**：你只描述「我要什么结构」，不去管「怎么一步步搭出来」。
框架负责把它变成真实界面。

**嵌套关系靠大括号表示**：`Column { }` 里包着的就是它的子元素。

### 链式调用：`.fontSize(14)`

紧跟在一个组件后面的 `.xxx()` 是**给它设置属性**：

```ts
Text('红烧肉')
  .fontSize(14)          // 字号 14
  .fontColor(COLOR_TEXT) // 颜色
  .width('100%')         // 宽度占满
```

**可以连着写任意多个**，顺序一般不影响。
（一个例外：同一个属性不能设两次，比如两个 `.border()`，后面的会覆盖前面的——
这类问题项目里踩过，见第 7 章。）

---

## 六、`@State` / `@Prop`：数据变了，界面自动变

这是 ArkTS 的**核心机制**，也是新手最容易懵的地方。

### 问题

普通变量改了，界面**不会**跟着变：

```ts
struct Demo {
  count: number = 0;        // 普通字段

  build() {
    Column() {
      Text(`${this.count}`)
        .onClick(() => { this.count++ })   // 点了不会刷新！
    }
  }
}
```

### 解决：加 `@State`

```ts
struct Demo {
  @State count: number = 0;   // ← 加了这个

  build() {
    Column() {
      Text(`${this.count}`)
        .onClick(() => { this.count++ })   // 点了数字会变 ✅
    }
  }
}
```

**`@State` 的含义**：「这个值变了，请重新画一遍用到它的界面。」

### 几种装饰器的区别

| 写法 | 数据从哪来 | 改了会不会刷新 |
|---|---|---|
| （无） | 组件自己的普通字段 | ❌ 不会 |
| `@State` | 组件自己持有 | ✅ 会 |
| `@Prop` | **父组件传进来** | ✅ 会（跟着父组件变） |
| `@Link` | 父组件传进来，**双向绑定** | ✅ 会，且改它父组件也变 |
| `@Watch('方法名')` | 配合上面几个用 | 值变化时**额外调用一个方法** |

### `@Prop` 的实际例子

`components\ProfileOption.ets` 里：

```ts
@Component
export struct ProfileOption {
  @Prop label: string = '';        // 外面传进来
  @Prop selected: boolean = false;
}
```

父组件这样用它（`pages\ProfileTab.ets`）：

```ts
ProfileOption({
  label: '轻度活动',
  desc: '每周运动 1-3 天',
  selected: this.profile.activityLevel === level
})
```

**`@Prop` 是单向的**：父组件改了会传给子组件，子组件改不了父组件。

### `@Watch`：值变了顺便做点事

```ts
@Prop @Watch('onChange') data: string = '';

onChange(): void {
  // data 变了会自动调这里
}
```

项目里用它来「数据来了就播动画」。

---

## 七、`@Builder`：可复用的一小段界面

当同一段界面要写两遍时，抽成 `@Builder`：

```ts
@Builder
macroBar(label: string, pct: string, color: string) {
  Column() {
    Text(label).fontSize(10)
    // …进度条
  }
}
```

用的时候直接当函数调：

```ts
this.macroBar('蛋白', '62%', '#22C55E')
this.macroBar('脂肪', '30%', '#F5C142')
```

**⚠️ 这里有个大坑**（项目里踩了不止一次）：

> **`@Builder` 的参数只在「第一次构建时」求值一次，之后不更新。**
>
> 如果你传 `this.proteinTarget` 进去，父组件的数据后来变了，
> `@Builder` 里拿到的**还是旧值**。
>
> **解法**：① 传函数 `() => this.proteinTarget`；
> ② 或者干脆把它做成 `@Component` 而不是 `@Builder`。
>
> 详见第 7 章。

---

## 八、`ForEach`：列表渲染

要显示「很多条」时用它。项目里渲染每天的营养素条：

```ts
ForEach(GOAL_ORDER, (goal: Goal) => {
  ProfileOption({
    label: goalLabel(goal),
    selected: this.profile.goal === goal
  })
}, (goal: Goal) => `g-${goal}`)
```

三个参数：

| 参数 | 作用 |
|---|---|
| 第 1 个：`GOAL_ORDER` | **数据数组**，要循环的列表 |
| 第 2 个：`(goal) => { … }` | **每一项怎么渲染** |
| 第 3 个：`(goal) => \`g-${goal}\`` | **这一项的唯一标识**（key） |

### 第三个参数（key）非常重要

框架靠它判断「列表变了之后，哪一项是新的、哪一项只是内容改了」。

**规则**：key 必须**包含所有会变化的值**。

```ts
// ❌ 只用了下标：内容变了但 key 没变 → 框架以为没变，不重新渲染
(item, i) => `${i}`

// ✅ 包含内容：内容变 key 就变 → 会重新渲染
(item, i) => `${i}-${item.name}`
```

**项目里踩过这个坑**：日历的格子用了只含日期的 key，
结果「有没有记录」这个状态变了，界面却不刷新。

---

## 九、`if / else` 和三元表达式

```ts
// 三元：简单二选一，写在表达式里
.fontColor(this.selected ? COLOR_PRIMARY : COLOR_TEXT)
```

```ts
// if：在 build() 里控制「这块要不要显示」
Column() {
  if (this.emptyDay) {
    Text('今天还没记录')
  } else {
    Text('已记录 3 条')
  }
}
```

**注意**：在 `build()` 里用 `if` 切换，高度会**瞬间跳变**没有动画。
想要动画得用「始终显示，只改高度」的写法（第 6 章讲餐次折叠时会说）。

---

## 十、箭头函数 `=>`

看到 `() => { ... }` 就理解成「**一小段可以传来传去的代码**」。

```ts
// 点击时执行
.onClick(() => {
  this.saveWeight();
})

// 带参数
ForEach(list, (item: FoodRecord) => {
  // 每一项
})

// 直接返回一个值（省略了 return）
this.list.filter((r: FoodRecord) => r.kcal > 100)
```

**为什么需要它**：界面里到处是「等发生某事时，做这个」。
把动作当成值传进去，就是这么写的。

---

## 十一、`async / await`：等一个慢操作

调 AI 接口要等几秒。这种「要等」的操作写成 `async`：

```ts
private async analyze(): Promise<void> {
  this.busy = true;
  try {
    const result = await VisionService.recognize(...);   // ← 等它回来
    // 拿到结果继续
  } catch (err) {
    // 出错了
  } finally {
    this.busy = false;
  }
}
```

| 关键字 | 含义 |
|---|---|
| `async` | 标记「这个函数里面有等待」 |
| `await` | 「**在这里等**，等完了再往下走」 |
| `try / catch` | 出错时走 `catch`，不让整个 App 崩掉 |
| `finally` | 不管成功失败都执行（常用来关掉「加载中」状态） |

**新手常见错误**：忘了写 `await`，结果代码没等操作完成就往下跑了。

---

## 十二、`import / export`：文件之间怎么协作

```ts
// 文件 A：导出（让别人能用）
export const COLOR_PRIMARY = '#22C55E';
export function todayKey(): string { … }

// 文件 B：导入（用别人的）
import { COLOR_PRIMARY } from '../common/Theme';
import { todayKey } from '../common/DateUtil';
```

### 路径里的 `../` 和 `./`

| 写法 | 含义 |
|---|---|
| `'./Store'` | **同目录**下的 `Store` |
| `'../common/Theme'` | **上一级目录**再进 `common` |

从 `pages\Index.ets` 出发，`'../common/Theme'` 就是：
退到 `ets\` → 进 `common\` → 找 `Theme`。

---

## 十三、看懂一个真实文件的完整流程

以 `components\ProfileOption.ets` 为例，实战演练一遍：

```ts
import { COLOR_BG, COLOR_PRIMARY, … } from '../common/Theme';   // ① 引进颜色

export const OPTION_ROW_H: number = 44;                          // ② 导出一个常量

@Component                                                       // ③ 这是个界面组件
export struct ProfileOption {
  @Prop label: string = '';                                      // ④ 外面传标题进来
  @Prop desc: string = '';
  @Prop selected: boolean = false;
  onPick: () => void = () => {};                                 // ⑤ 外面传「点了干啥」

  build() {                                                      // ⑥ 描述长相
    Column({ space: 2 }) {                                       // ⑦ 竖着排，间隔2
      Row({ space: 4 }) {                                        // ⑧ 横着排
        Text(this.label)                                         // ⑨ 显示标题
          .fontSize(14)
          .fontColor(this.selected ? COLOR_PRIMARY : COLOR_TEXT) // ⑩ 选中就绿，否则黑
          .layoutWeight(1)                                       // ⑪ 占满剩余宽度
        if (this.selected) {                                     // ⑫ 选中才显示勾
          Text('✓').fontColor(COLOR_PRIMARY)
        }
      }
      .width('100%')

      Text(this.desc).fontSize(10).maxLines(2)                   // ⑬ 说明文字，最多2行
    }
    .height(OPTION_ROW_H)                                        // ⑭ 固定高度（见下）
    .backgroundColor(this.selected ? COLOR_PRIMARY_SOFT : COLOR_BG)
    .borderRadius(10)
    .onClick(() => { this.onPick(); })                           // ⑮ 点了调外部传的
  }
}
```

**⑭ 为什么固定高度？** 因为两列并排时，左右两边的文字行数不同，
不固定高度就会「一个高一个矮」，看起来错落。固定成 44 就对齐了。

---

## 小结

| 语法 | 一句话 |
|---|---|
| `.ets` | ArkTS 文件，= TypeScript + 鸿蒙界面语法 |
| `const` / `let` | 常量 / 变量；必须写类型 |
| `class` | 数据模板，字段要给默认值 |
| `enum` | 固定选项，要存盘就用字符串值 |
| `@Component` + `build()` | 界面组件；`build()` 里**声明**长相 |
| `.fontSize(14)` | 链式设置属性 |
| `@State` | 自己持有，变了会自动重画 |
| `@Prop` | 父组件传进来，跟着变 |
| `@Watch` | 值变了顺便调个方法 |
| `@Builder` | 可复用的一小段界面（**参数只求值一次，有坑**） |
| `ForEach` | 列表渲染，**key 要含所有会变的值** |
| `() => {}` | 箭头函数，「一段可传递的代码」 |
| `async` / `await` | 等慢操作 |
| `import` / `export` | 文件之间共享代码 |

下一章：[04-数据存在哪](04-数据存在哪.md) —— 记录怎么存的、为什么不会丢。
