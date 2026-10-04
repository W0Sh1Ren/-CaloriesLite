/**
 * 用于定义匹配compitableSdkVersion的正则表达式，因version演进策略变化，不同阶段格式不一样，正则也有差别
 */
/**
 * 用于老版本匹配的正则表达式，格式：M.S.F(X)
 * eg: 5.1.0(18)
 */
export declare const oldVersionReg: RegExp;
/**
 * 第一版用于点分制版本匹配的正则表达式，格式：M.S.F
 *
 */
export declare const oldDotSeparatedVersion: RegExp;
/**
 * 第二版用于点分制版本匹配的正则表达式，格式：M.S.F
 * 明确从API 26开始支持，每个点分位支持最多两位数字
 * eg: 26.0.0
 */
export declare const newDotSeparatedVersion: RegExp;
