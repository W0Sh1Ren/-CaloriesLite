/**
 * 照片 → 食物识别服务。
 *
 * 策略（对应「先查表，查不到再用 AI 估」）：
 *   1. 把图片发给用户自配的视觉模型，只让它回答「这是什么食物、大概多少克」；
 *   2. 拿到食物名后先查内置食物表，命中就用表里的精确营养值；
 *   3. 表里没有的条目（比如具体某家店的招牌菜）才采用 AI 给出的热量估算，
 *      并在界面上标注来源，让用户知道这个数字的可靠程度。
 *
 * 支持两种服务商：OpenAI 兼容的 /v1/chat/completions，以及 Google Gemini。
 */
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AiConfig, AiProvider, FoodDraft, FoodSource } from '../model/Types';
import { estimateGrams } from './FoodMatcher';
import { getNum, getStr, JsonMap, parseObject } from '../common/JsonUtil';

const DOMAIN = 0x0000;
/** 单次识别最长等待时间，视觉模型推理较慢，给足 60 秒 */
const TIMEOUT_MS = 60000;

/** 识别失败时抛出，message 已是可直接展示给用户的中文 */
export class VisionError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export class VisionResult {
  /** 直接可提交的草稿列表 */
  drafts: FoodDraft[] = [];
  /** 模型对整张图的说明，展示在结果页顶部 */
  overallNote: string = '';
  /** 本次使用的模型名，便于用户排查 */
  model: string = '';
}

/**
 * 让模型返回结构化 JSON 的系统提示词。
 *
 * 营养值全部由模型直接给出，不查内置食物表：
 * 模型能结合画面判断烹饪方式与份量（比如「红烧」比「清蒸」油多），
 * 比按食物名查表更贴近照片里的实际情况。代价是数值是估算值，
 * 所以结果页仍然允许逐条修改。
 */
const SYSTEM_PROMPT: string = `你是一位专业的中餐营养师，擅长通过照片估算食物份量与营养。
请仔细观察照片中的食物，只输出一个 JSON 对象，不要输出任何解释文字、不要用 markdown 代码块包裹。
JSON 格式严格如下：
{"foods":[{"name":"食物中文名","amount":"份量描述","grams":估算克重,"kcal":该份量的总热量,"protein":蛋白质克数,"fat":脂肪克数,"carb":碳水克数,"confidence":0到100的整数,"note":"判断依据，20字以内"}],"summary":"整张照片的一句话总结"}
要求：
1. name 用最常见的中文食物名，不要带品牌名、不要带形容词，例如「红烧肉」而不是「妈妈做的红烧肉」。
2. amount 用中文写份量，例如「一碗」「两块」「约150克」。
3. grams 是你对这份食物克重的整数估算，针对照片中实际可见的份量，不是每100克。
4. kcal / protein / fat / carb 都是**照片中这份实际份量**的总量，不是每100克；热量与三大营养素要能对得上。
5. 估算时把烹饪方式算进去：同样一块肉，油炸/红烧的脂肪明显高于清蒸/水煮。
6. 如果照片里没有食物，foods 返回空数组，summary 说明原因。
7. 如果画面里有餐具或手，请借助它们推算份量大小。
8. 最多识别 8 种食物，合并同类项。`;

/**
 * 纯文字记录的提示词（不带照片）。
 *
 * 与带照片那版共用同一套 JSON 结构，只是判断依据从「看到什么」
 * 换成「用户描述了什么」——所以要点里强调按常见做法估算，
 * 并在信息不足时按最典型的份量给一个合理值，而不是拒绝回答。
 */
const TEXT_SYSTEM_PROMPT: string = `你是一位专业的中餐营养师，擅长根据文字描述估算食物份量与营养。
用户会用自然语言描述吃了什么，可能很简略（例如「一碗牛肉面」），也可能很详细（带克重与做法）。
请只输出一个 JSON 对象，不要输出任何解释文字、不要用 markdown 代码块包裹。
JSON 格式严格如下：
{"foods":[{"name":"食物中文名","amount":"份量描述","grams":估算克重,"kcal":该份量的总热量,"protein":蛋白质克数,"fat":脂肪克数,"carb":碳水克数,"confidence":0到100的整数,"note":"判断依据，20字以内"}],"summary":"这次记录的一句话总结"}
要求：
1. name 用最常见的中文食物名，不要带品牌名、不要带形容词。
2. amount 用中文写份量，例如「一碗」「两块」「约150克」。
3. grams 是这份食物克重的整数估算。
4. kcal / protein / fat / carb 都是**这份实际份量**的总量，不是每100克；热量与三大营养素要能对得上。
5. 把烹饪方式算进去：同样一块肉，油炸/红烧的脂肪明显高于清蒸/水煮。
6. 用户给出的信息不足时，**按最常见的做法与份量给出一个合理估算**，
   并在 note 里说明依据；不要因为信息少就返回空数组。
7. 用户说的量词要当真：「半碗」就是半碗，「两块」就是两块，不要按一整份算。
8. 最多 8 种食物，同一餐里的同类项合并。`;

/**
 * 对话调整用的提示词。
 *
 * 用户在确认页可以继续用自然语言修正结果
 *（「米饭其实是两碗」「还喝了一碗汤」「这个不要了」）。
 * 这里把**当前明细**一起发过去，让模型在既有结果上**增量修改**，
 * 而不是重新识别一遍 —— 重新识别会把用户已经手动改过的字段冲掉。
 */
const REVISE_SYSTEM_PROMPT: string = `你是一位专业的中餐营养师，正在帮用户修正一份饮食记录。
用户会针对当前记录提出修改要求（例如「米饭其实是两碗」「还喝了一碗汤」「这个不要了」「少算油了」）。
请只输出一个 JSON 对象，不要输出任何解释文字、不要用 markdown 代码块包裹。
JSON 格式严格如下：
{"foods":[{"name":"食物中文名","amount":"份量描述","grams":估算克重,"kcal":该份量的总热量,"protein":蛋白质克数,"fat":脂肪克数,"carb":碳水克数,"confidence":0到100的整数,"note":"判断依据，20字以内"}],"summary":"这次修改的一句话说明"}
要求：
1. **只改用户提到的地方**，其余条目原样保留（名称、克重、营养值都不要动）。
2. 用户说「不要了」「去掉」就删除对应条目；说「还有」「另外」「再加」就新增条目。
   即使当前记录为空，也要能按用户说的新增。
3. 用户改了份量（例如「两碗」「一半」）时，按比例重算该条的 grams 与热量、
   以及三大营养素 —— 热量与营养素必须与新的份量对得上。
4. foods 里是所有仍然有效的条目（不是只有变化的那些）。
5. 用户只是提问（例如「这个热量对吗」）而没有要求修改时，
   foods 返回与输入完全相同的列表，summary 里回答他的问题。
6. 份量要按常识判断上限：一个人一餐不可能吃 100 碗面。
   遇到明显不合理的数量，按最接近的合理值处理，并在 summary 里说明你的理解。
7. 最多 8 种食物，同类项合并。`;

/** 供最终解析使用的中间结构 */
class ParsedFood {
  name: string = '';
  amount: string = '';
  grams: number = 0;
  kcal: number = 0;
  protein: number = 0;
  fat: number = 0;
  carb: number = 0;
  confidence: number = 0;
  note: string = '';

  constructor(name: string, amount: string, grams: number, kcal: number, protein: number,
    fat: number, carb: number, confidence: number, note: string) {
    this.name = name;
    this.amount = amount;
    this.grams = grams;
    this.kcal = kcal;
    this.protein = protein;
    this.fat = fat;
    this.carb = carb;
    this.confidence = confidence;
    this.note = note;
  }
}

export class VisionService {

  /**
   * 识别一组图片。
   *
   * 支持多张：一次把同一餐的几张照片（比如主食、菜、饮料各拍一张）一起发过去，
   * 模型能合并同类项并综合判断总份量，比逐张识别再相加更准。
   *
   * @param images   图片列表，每项是纯 base64（不含 data URL 前缀）
   * @param notes    用户手写的补充说明，直接拼进提示词。
   *                 比如「这碗面只吃了一半」，模型据此调整份量估算。
   */
  static async recognize(config: AiConfig, images: string[], notes: string): Promise<VisionResult> {
    VisionService.validate(config);
    if (images.length === 0) {
      throw new VisionError('图片内容为空，请重新拍摄');
    }
    for (const b of images) {
      if (b.length === 0) {
        throw new VisionError('有图片内容为空，请重新拍摄');
      }
    }

    const content: string = config.provider === AiProvider.GEMINI
      ? await VisionService.callGemini(config, images, notes)
      : await VisionService.callOpenAiCompatible(config, images, notes);

    const parsed: ParsedFood[] = VisionService.parseFoods(content);
    if (parsed.length === 0) {
      throw new VisionError('没有在照片里认出食物，换个角度或拍清楚一点再试');
    }

    const result: VisionResult = new VisionResult();
    result.model = config.model;
    result.overallNote = VisionService.extractSummary(content);
    result.drafts = VisionService.toDrafts(parsed);
    return result;
  }

  /**
   * 只凭文字描述识别（不带照片）。
   *
   * 用户可能只写「一碗牛肉面」而不拍照 —— 这条路径让纯文字也能记录。
   * 与带图版本的差别只有两点：系统提示词换成文字版、
   * 用户消息是纯字符串（不发多模态 content 数组）。
   *
   * @param description 用户的自然语言描述，必须非空
   */
  static async recognizeText(config: AiConfig, description: string): Promise<VisionResult> {
    VisionService.validate(config);
    const text: string = description.trim();
    if (text.length === 0) {
      throw new VisionError('请先写一句吃了什么');
    }

    const content: string = await VisionService.callTextOnly(config, text);
    const parsed: ParsedFood[] = VisionService.parseFoods(content);
    if (parsed.length === 0) {
      throw new VisionError('没能从这段描述里认出食物，写得更具体一点再试（比如「一碗牛肉面」）');
    }

    const result: VisionResult = new VisionResult();
    result.model = config.model;
    result.overallNote = VisionService.extractSummary(content);
    result.drafts = VisionService.toDrafts(parsed);
    return result;
  }

  /**
   * 纯文字请求（OpenAI 兼容格式）。
   *
   * 这里不用「content 数组 + 文字分片」那种多模态写法：
   * 纯文字时 content 直接给字符串更通用，也少一层服务端差异。
   */
  private static async callTextOnly(config: AiConfig, text: string): Promise<string> {
    const url: string = `${VisionService.trimSlash(config.baseUrl)}/chat/completions`;

    const body: Record<string, Object> = {};
    body['model'] = config.model;
    body['max_tokens'] = 1500;

    // 思考模式与图片路径保持一致：显式下发，不依赖服务端默认
    const thinking: Record<string, Object> = {};
    thinking['type'] = config.thinking ? 'enabled' : 'disabled';
    body['thinking'] = thinking;
    if (config.thinking) {
      body['reasoning_effort'] = 'low';
    } else {
      body['temperature'] = 0.2;
    }

    const messages: Record<string, Object>[] = [];
    const sysMsg: Record<string, Object> = {};
    sysMsg['role'] = 'system';
    sysMsg['content'] = TEXT_SYSTEM_PROMPT;
    messages.push(sysMsg);

    const userMsg: Record<string, Object> = {};
    userMsg['role'] = 'user';
    userMsg['content'] = `我吃了：${text}`;
    messages.push(userMsg);

    body['messages'] = messages;

    const raw: string = await VisionService.postJson(url, JSON.stringify(body), config.apiKey, true);
    return VisionService.extractOpenAiContent(raw);
  }

  /**
   * 按用户的自然语言要求，在当前结果上做增量修改。
   *
   * 确认页的「和模型聊聊」用它：用户说「米饭其实是两碗」，
   * 模型只改这一条，其余原样返回，页面据此实时刷新热量合计。
   *
   * 与重复调用 recognize 的区别：这条路径把**当前明细**作为上下文发过去，
   * 所以用户已经手动改过的字段不会被重新识别的结果冲掉。
   *
   * **允许 drafts 为空**：用户可能先把条目全删了，再靠聊天重新加回来
   *（「再加一碗米饭」）。所以这里不把空列表当错误。
   * 两者都空（没明细也没说话）才会被上面的 ask.length 检查拦住。
   *
   * @param drafts 当前明细（页面上正在显示的内容，可为空）
   * @param request 用户的修改要求
   */
  static async revise(config: AiConfig, drafts: FoodDraft[], request: string): Promise<VisionResult> {
    VisionService.validate(config);
    const ask: string = request.trim();
    if (ask.length === 0) {
      throw new VisionError('请先写下要改什么');
    }

    const content: string = await VisionService.callRevise(config, drafts, ask);
    const parsed: ParsedFood[] = VisionService.parseFoods(content);
    if (parsed.length === 0) {
      /*
       * 允许「全部删掉」是合法结果：用户可能说「都不要了」。
       * 所以这里不报错，返回空明细让页面表现为清空。
       */
      const empty: VisionResult = new VisionResult();
      empty.model = config.model;
      empty.overallNote = VisionService.extractSummary(content);
      empty.drafts = [];
      return empty;
    }

    const result: VisionResult = new VisionResult();
    result.model = config.model;
    result.overallNote = VisionService.extractSummary(content);
    result.drafts = VisionService.toDrafts(parsed);
    return result;
  }

  /**
   * 把当前明细序列化成「模型能读的清单」。
   *
   * 用紧凑的 JSON 而不是自然语言：字段名与返回格式一一对应，
   * 模型更容易理解「要改的是哪一条」，也不会把数值读错位。
   */
  private static draftsToContext(drafts: FoodDraft[]): string {
    if (drafts.length === 0) {
      // 空列表也要给出明确信号，否则模型会以为上下文丢了
      return '（当前没有任何条目）';
    }
    const items: Record<string, Object>[] = [];
    for (const d of drafts) {
      const it: Record<string, Object> = {};
      it['name'] = d.name;
      it['grams'] = d.grams;
      it['kcal'] = d.kcal;
      it['protein'] = d.protein;
      it['fat'] = d.fat;
      it['carb'] = d.carb;
      items.push(it);
    }
    return JSON.stringify(items);
  }

  /** 对话调整请求（OpenAI 兼容） */
  private static async callRevise(config: AiConfig, drafts: FoodDraft[], request: string): Promise<string> {
    const url: string = `${VisionService.trimSlash(config.baseUrl)}/chat/completions`;

    const body: Record<string, Object> = {};
    body['model'] = config.model;
    body['max_tokens'] = 1500;

    const thinking: Record<string, Object> = {};
    thinking['type'] = config.thinking ? 'enabled' : 'disabled';
    body['thinking'] = thinking;
    if (config.thinking) {
      body['reasoning_effort'] = 'low';
    } else {
      body['temperature'] = 0.2;
    }

    const messages: Record<string, Object>[] = [];
    const sysMsg: Record<string, Object> = {};
    sysMsg['role'] = 'system';
    sysMsg['content'] = REVISE_SYSTEM_PROMPT;
    messages.push(sysMsg);

    const userMsg: Record<string, Object> = {};
    userMsg['role'] = 'user';
    userMsg['content'] = `当前记录（JSON）：${VisionService.draftsToContext(drafts)}\n\n我的修改要求：${request}`;
    messages.push(userMsg);

    body['messages'] = messages;

    const raw: string = await VisionService.postJson(url, JSON.stringify(body), config.apiKey, true);
    return VisionService.extractOpenAiContent(raw);
  }

  /** 配置合法性检查，提前给出明确提示 */
  static validate(config: AiConfig): void {
    if (config.baseUrl.trim().length === 0) {
      throw new VisionError('还没有填写接口地址，请到「设置」里配置 AI 识别');
    }
    if (config.apiKey.trim().length === 0) {
      throw new VisionError('还没有填写 API Key，请到「设置」里配置 AI 识别');
    }
    if (config.model.trim().length === 0) {
      throw new VisionError('还没有填写模型名，请到「设置」里配置 AI 识别');
    }
  }

  // ---------------------------------------------------------------- 请求构造

  /** OpenAI 兼容：POST {baseUrl}/chat/completions */
  private static async callOpenAiCompatible(config: AiConfig, images: string[], notes: string): Promise<string> {
    const url: string = `${VisionService.trimSlash(config.baseUrl)}/chat/completions`;

    const body: Record<string, Object> = {};
    body['model'] = config.model;
    // 多图会显著增加输入 token，输出上限相应放宽一点
    body['max_tokens'] = images.length > 1 ? 2500 : 1500;

    // 思考模式显式关掉或打开。
    // 不传时由服务端默认值决定——DeepSeek 的默认是「开启且 effort=high」，
    // 思维链按输出 token 计费（约为输入单价的 4 倍），一次识图能贵到 5 倍，
    // 所以这里必须显式下发，不能依赖服务端默认。
    const thinking: Record<string, Object> = {};
    thinking['type'] = config.thinking ? 'enabled' : 'disabled';
    body['thinking'] = thinking;
    if (config.thinking) {
      // 开启时用 low 档：这个任务不需要深度推理，省 token 也快
      body['reasoning_effort'] = 'low';
    } else {
      // 思考模式不支持 temperature，只有关闭时才设置
      body['temperature'] = 0.2;
    }

    const userContent: Record<string, Object>[] = [];
    const textPart: Record<string, Object> = {};
    textPart['type'] = 'text';
    textPart['text'] = VisionService.buildUserText(images.length, notes);
    userContent.push(textPart);

    // 多张图片按顺序附上，模型会当作同一餐的多角度照片
    for (const b64 of images) {
      const imagePart: Record<string, Object> = {};
      imagePart['type'] = 'image_url';
      const inner: Record<string, Object> = {};
      inner['url'] = `data:image/jpeg;base64,${b64}`;
      imagePart['image_url'] = inner;
      userContent.push(imagePart);
    }

    const messages: Record<string, Object>[] = [];
    const sysMsg: Record<string, Object> = {};
    sysMsg['role'] = 'system';
    sysMsg['content'] = SYSTEM_PROMPT;
    messages.push(sysMsg);

    const userMsg: Record<string, Object> = {};
    userMsg['role'] = 'user';
    userMsg['content'] = userContent;
    messages.push(userMsg);

    body['messages'] = messages;

    const raw: string = await VisionService.postJson(url, JSON.stringify(body), config.apiKey, true);
    return VisionService.extractOpenAiContent(raw);
  }

  /**
   * 拼用户那段文字。
   *
   * 多图时明确告诉模型这是同一餐的照片，让它合并同类项而不是当成两餐重复计数；
   * 有用户手写说明时原样附上，并强调以此为准。
   */
  private static buildUserText(imageCount: number, notes: string): string {
    const parts: string[] = [];
    if (imageCount > 1) {
      parts.push(`这是同一餐的 ${imageCount} 张照片，请合并同类项后统一给出结果，不要重复计数。`);
    } else {
      parts.push('请识别这张照片里的食物，并按要求的 JSON 格式返回。');
    }
    const trimmed: string = notes.trim();
    if (trimmed.length > 0) {
      parts.push(`用户补充说明（请以此为准调整份量与判断）：${trimmed}`);
    }
    parts.push('只输出 JSON。');
    return parts.join('\n');
  }

  /** Gemini：POST {baseUrl}/v1beta/models/{model}:generateContent?key=... */
  private static async callGemini(config: AiConfig, images: string[], notes: string): Promise<string> {
    const base: string = VisionService.trimSlash(config.baseUrl);
    // 官方地址已含版本号时不再重复拼接
    const prefix: string = base.includes('/v1beta') || base.includes('/v1alpha') ? base : `${base}/v1beta`;
    const url: string = `${prefix}/models/${config.model}:generateContent`;

    const parts: Record<string, Object>[] = [];
    const textPart: Record<string, Object> = {};
    textPart['text'] = `${SYSTEM_PROMPT}\n${VisionService.buildUserText(images.length, notes)}`;
    parts.push(textPart);

    // 多张图片依次作为 inline_data 附上
    for (const b64 of images) {
      const inline: Record<string, Object> = {};
      inline['mime_type'] = 'image/jpeg';
      inline['data'] = b64;
      const imagePart: Record<string, Object> = {};
      imagePart['inline_data'] = inline;
      parts.push(imagePart);
    }

    const content: Record<string, Object> = {};
    content['parts'] = parts;
    const contents: Record<string, Object>[] = [];
    contents.push(content);

    const genConfig: Record<string, Object> = {};
    genConfig['temperature'] = 0.2;
    genConfig['maxOutputTokens'] = images.length > 1 ? 2500 : 1500;
    genConfig['responseMimeType'] = 'application/json';

    const body: Record<string, Object> = {};
    body['contents'] = contents;
    body['generationConfig'] = genConfig;

    const raw: string = await VisionService.postJson(url, JSON.stringify(body), config.apiKey, false);
    return VisionService.extractGeminiContent(raw);
  }

  // ---------------------------------------------------------------- HTTP

  /**
   * 发一个 JSON POST。
   * @param bearer true 用 Authorization 头（OpenAI 系），false 用 x-goog-api-key 头（Gemini）
   */
  private static async postJson(url: string, payload: string, apiKey: string, bearer: boolean): Promise<string> {
    const request: http.HttpRequest = http.createHttp();

    const headers: Record<string, string> = {};
    headers['Content-Type'] = 'application/json';
    headers['Accept'] = 'application/json';
    if (bearer) {
      headers['Authorization'] = `Bearer ${apiKey}`;
    } else {
      headers['x-goog-api-key'] = apiKey;
    }

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: payload,
      expectDataType: http.HttpDataType.STRING,
      usingCache: false,
      connectTimeout: 15000,
      readTimeout: TIMEOUT_MS
    };

    try {
      const resp: http.HttpResponse = await request.request(url, options);
      const code: number = resp.responseCode;
      const bodyText: string = typeof resp.result === 'string' ? resp.result : '';

      if (code === 200 || code === 201) {
        return bodyText;
      }
      throw new VisionError(VisionService.describeHttpError(code, bodyText));
    } catch (err) {
      if (err instanceof VisionError) {
        throw err;
      }
      const e: Error = err as Error;
      hilog.error(DOMAIN, 'CalorieLite', 'vision request failed: %{public}s', e.message);
      throw new VisionError(VisionService.describeNetworkError(e.message));
    } finally {
      request.destroy();
    }
  }

  /** 把 HTTP 状态码翻译成人话 */
  private static describeHttpError(code: number, body: string): string {
    const detail: string = VisionService.extractApiMessage(body);
    switch (code) {
      case 401:
        return `API Key 无效或已过期（401）${detail}`;
      case 403:
        return `没有权限调用该模型（403）${detail}`;
      case 404:
        return `接口地址或模型名不对（404）${detail}`;
      case 413:
        return '图片太大了，换一张小一点的试试（413）';
      case 429:
        return `请求太频繁或额度用完（429）${detail}`;
      default:
        if (code >= 500) {
          return `服务端暂时不可用（${code}），过会儿再试${detail}`;
        }
        return `请求失败（${code}）${detail}`;
    }
  }

  /** 从错误响应里挖出服务端的提示，能显著加快用户自查 */
  private static extractApiMessage(body: string): string {
    if (body.length === 0) {
      return '';
    }
    const map: JsonMap | null = parseObject(body);
    if (map === null) {
      return '';
    }
    const errObj: Object | undefined = map['error'];
    if (errObj !== undefined && errObj !== null && typeof errObj === 'object') {
      const msg: string = getStr(errObj as JsonMap, 'message', '');
      if (msg.length > 0) {
        return `：${msg}`;
      }
    }
    const msg2: string = getStr(map, 'message', '');
    return msg2.length > 0 ? `：${msg2}` : '';
  }

  /** 网络层异常的友好化 */
  private static describeNetworkError(message: string): string {
    const m: string = message.toLowerCase();
    if (m.includes('timeout') || m.includes('timed out')) {
      return '请求超时了，检查一下网络，或者换个更快的模型';
    }
    if (m.includes('resolve') || m.includes('dns') || m.includes('host')) {
      return '域名解析失败，检查接口地址是否写对，以及当前网络能否访问该服务';
    }
    if (m.includes('refused') || m.includes('connect')) {
      return '连接不上服务器，检查接口地址和网络';
    }
    return `网络请求失败：${message}`;
  }

  // ---------------------------------------------------------------- 响应解析

  /** 从 OpenAI 响应里取 choices[0].message.content */
  private static extractOpenAiContent(raw: string): string {
    const map: JsonMap | null = parseObject(raw);
    if (map === null) {
      throw new VisionError('服务端返回的不是合法 JSON');
    }
    const choices: Object | undefined = map['choices'];
    if (!Array.isArray(choices)) {
      throw new VisionError(VisionService.firstErrorMessage(map, '响应里没有 choices 字段'));
    }
    const arr: Object[] = choices as Object[];
    if (arr.length === 0) {
      throw new VisionError('模型没有返回任何内容');
    }
    const first: JsonMap = arr[0] as JsonMap;
    const message: Object | undefined = first['message'];
    if (message === undefined || message === null || typeof message !== 'object') {
      throw new VisionError('响应结构异常：缺少 message');
    }
    return getStr(message as JsonMap, 'content', '');
  }

  /** 从 Gemini 响应里取 candidates[0].content.parts[0].text */
  private static extractGeminiContent(raw: string): string {
    const map: JsonMap | null = parseObject(raw);
    if (map === null) {
      throw new VisionError('服务端返回的不是合法 JSON');
    }
    const candidates: Object | undefined = map['candidates'];
    if (!Array.isArray(candidates)) {
      throw new VisionError(VisionService.firstErrorMessage(map, '响应里没有 candidates 字段'));
    }
    const arr: Object[] = candidates as Object[];
    if (arr.length === 0) {
      // 被安全策略拦截时 candidates 为空
      const feedback: Object | undefined = map['promptFeedback'];
      if (feedback !== undefined && feedback !== null && typeof feedback === 'object') {
        const reason: string = getStr(feedback as JsonMap, 'blockReason', '');
        if (reason.length > 0) {
          throw new VisionError(`图片被安全策略拦截（${reason}），换一张照片试试`);
        }
      }
      throw new VisionError('模型没有返回任何内容');
    }
    const first: JsonMap = arr[0] as JsonMap;
    const content: Object | undefined = first['content'];
    if (content === undefined || content === null || typeof content !== 'object') {
      const finish: string = getStr(first, 'finishReason', '');
      throw new VisionError(finish.length > 0 ? `模型提前结束（${finish}）` : '响应结构异常：缺少 content');
    }
    const parts: Object | undefined = (content as JsonMap)['parts'];
    if (!Array.isArray(parts)) {
      throw new VisionError('响应结构异常：缺少 parts');
    }
    const partArr: Object[] = parts as Object[];
    let text: string = '';
    for (const p of partArr) {
      if (p !== null && p !== undefined && typeof p === 'object') {
        text += getStr(p as JsonMap, 'text', '');
      }
    }
    return text;
  }

  /** 服务端返回 error.message 时优先展示它 */
  private static firstErrorMessage(map: JsonMap, fallback: string): string {
    const errObj: Object | undefined = map['error'];
    if (errObj !== undefined && errObj !== null && typeof errObj === 'object') {
      const msg: string = getStr(errObj as JsonMap, 'message', '');
      if (msg.length > 0) {
        return msg;
      }
    }
    const msg2: string = getStr(map, 'message', '');
    return msg2.length > 0 ? msg2 : fallback;
  }

  /** 模型有时会把 JSON 包在 ```json 里，这里统一剥掉 */
  private static stripCodeFence(text: string): string {
    let s: string = text.trim();
    if (s.startsWith('```')) {
      const firstBreak: number = s.indexOf('\n');
      if (firstBreak >= 0) {
        s = s.substring(firstBreak + 1);
      }
      const lastFence: number = s.lastIndexOf('```');
      if (lastFence >= 0) {
        s = s.substring(0, lastFence);
      }
      s = s.trim();
    }
    return s;
  }

  /** 从模型输出里抽出 foods 数组 */
  private static parseFoods(content: string): ParsedFood[] {
    const cleaned: string = VisionService.stripCodeFence(content);
    if (cleaned.length === 0) {
      throw new VisionError('模型返回了空内容');
    }

    const map: JsonMap | null = parseObject(cleaned);
    if (map === null) {
      // 尝试截取第一个 { 到最后一个 } 之间的内容
      const start: number = cleaned.indexOf('{');
      const end: number = cleaned.lastIndexOf('}');
      if (start < 0 || end <= start) {
        throw new VisionError('模型返回的内容不是 JSON，换个模型试试');
      }
      const retry: JsonMap | null = parseObject(cleaned.substring(start, end + 1));
      if (retry === null) {
        throw new VisionError('模型返回的内容不是 JSON，换个模型试试');
      }
      return VisionService.readFoods(retry);
    }
    return VisionService.readFoods(map);
  }

  private static readFoods(map: JsonMap): ParsedFood[] {
    const foodsRaw: Object | undefined = map['foods'];
    if (!Array.isArray(foodsRaw)) {
      return [];
    }
    const arr: Object[] = foodsRaw as Object[];
    const out: ParsedFood[] = [];
    for (const el of arr) {
      if (el === null || el === undefined || typeof el !== 'object') {
        continue;
      }
      const f: JsonMap = el as JsonMap;
      const name: string = getStr(f, 'name', '').trim();
      if (name.length === 0) {
        continue;
      }
      out.push(new ParsedFood(
        name,
        getStr(f, 'amount', ''),
        getNum(f, 'grams', 0),
        getNum(f, 'kcal', 0),
        getNum(f, 'protein', 0),
        getNum(f, 'fat', 0),
        getNum(f, 'carb', 0),
        getNum(f, 'confidence', 60),
        getStr(f, 'note', '')
      ));
    }
    return out;
  }

  private static extractSummary(content: string): string {
    const cleaned: string = VisionService.stripCodeFence(content);
    const map: JsonMap | null = parseObject(cleaned);
    if (map === null) {
      return '';
    }
    return getStr(map, 'summary', '');
  }

  // ---------------------------------------------------------------- 结果落地

  /**
   * 把 AI 结果转成可编辑草稿。
   *
   * 热量与三大营养素全部采用模型给的值，不再查内置食物表——
   * 模型能结合画面判断烹饪方式，比按名字查表更贴近真实情况。
   * 克重缺失时按份量描述兜底估一个，保证界面有值可改。
   */
  private static toDrafts(parsed: ParsedFood[]): FoodDraft[] {
    const out: FoodDraft[] = [];
    for (const p of parsed) {
      const grams: number = p.grams > 0 ? Math.round(p.grams) : estimateGrams(p.amount, 150);
      out.push(new FoodDraft(
        p.name,
        grams,
        Math.round(p.kcal),
        round1(p.protein),
        round1(p.fat),
        round1(p.carb),
        VisionService.confidenceLabel(p.confidence),
        FoodSource.AI,
        p.note
      ));
    }
    return out;
  }

  /** 纯文本补问：OpenAI 兼容 */
  private static async textOpenAi(config: AiConfig, prompt: string): Promise<string> {
    const url: string = `${VisionService.trimSlash(config.baseUrl)}/chat/completions`;
    const body: Record<string, Object> = {};
    body['model'] = config.model;
    body['temperature'] = 0.1;
    body['max_tokens'] = 800;

    const messages: Record<string, Object>[] = [];
    const sysMsg: Record<string, Object> = {};
    sysMsg['role'] = 'system';
    sysMsg['content'] = '你是专业营养师，只输出 JSON。';
    messages.push(sysMsg);
    const userMsg: Record<string, Object> = {};
    userMsg['role'] = 'user';
    userMsg['content'] = prompt;
    messages.push(userMsg);
    body['messages'] = messages;

    const raw: string = await VisionService.postJson(url, JSON.stringify(body), config.apiKey, true);
    return VisionService.extractOpenAiContent(raw);
  }

  /** 纯文本补问：Gemini */
  private static async textGemini(config: AiConfig, prompt: string): Promise<string> {
    const base: string = VisionService.trimSlash(config.baseUrl);
    const prefix: string = base.includes('/v1beta') || base.includes('/v1alpha') ? base : `${base}/v1beta`;
    const url: string = `${prefix}/models/${config.model}:generateContent`;

    const parts: Record<string, Object>[] = [];
    const textPart: Record<string, Object> = {};
    textPart['text'] = prompt;
    parts.push(textPart);
    const content: Record<string, Object> = {};
    content['parts'] = parts;
    const contents: Record<string, Object>[] = [];
    contents.push(content);

    const genConfig: Record<string, Object> = {};
    genConfig['temperature'] = 0.1;
    genConfig['maxOutputTokens'] = 800;
    genConfig['responseMimeType'] = 'application/json';

    const body: Record<string, Object> = {};
    body['contents'] = contents;
    body['generationConfig'] = genConfig;

    const raw: string = await VisionService.postJson(url, JSON.stringify(body), config.apiKey, false);
    return VisionService.extractGeminiContent(raw);
  }

  /**
   * 用一次极小的纯文本请求验证配置是否可用。
   *
   * 不发送任何图片，只花几百分之一分钱，让用户能在设置页确认 Key 和模型名没问题。
   * @returns 成功时返回模型的回复片段，失败时抛 VisionError
   */
  static async testConnection(config: AiConfig): Promise<string> {
    VisionService.validate(config);

    const prompt: string = '请只回复两个字：正常';
    let content: string = '';
    try {
      content = config.provider === AiProvider.GEMINI
        ? await VisionService.textGemini(config, prompt)
        : await VisionService.textOpenAi(config, prompt);
    } catch (err) {
      if (err instanceof VisionError) {
        throw err;
      }
      const e: Error = err as Error;
      throw new VisionError(VisionService.describeNetworkError(e.message));
    }

    const trimmed: string = content.trim();
    if (trimmed.length === 0) {
      throw new VisionError('接口有响应但内容为空，可能是模型名不对或该模型不支持该调用方式');
    }
    return trimmed.length > 40 ? `${trimmed.substring(0, 40)}…` : trimmed;
  }

  /** 把 0-100 的置信度归到三档 */
  private static confidenceLabel(score: number): string {
    if (score >= 80) {
      return 'high';
    }
    if (score >= 55) {
      return 'medium';
    }
    return 'low';
  }

  private static trimSlash(url: string): string {
    let s: string = url.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}

/** 保留一位小数，营养值不需要更高精度 */
function round1(v: number): number {
  return Math.round(v * 10) / 10;
}
