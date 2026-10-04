export declare class CacheStore {
    private caches;
    private lruCache;
    private readonly name;
    private readonly pinned;
    private hvigorMemoryThreshold;
    private hvigorEnableMemoryCache;
    private static logger;
    constructor(name: string, lruCache: LRUCache, pinned?: boolean);
    getCache(key: string): any;
    get(key: string): any;
    set(key: string, value: any): CacheStore;
    setCache(key: string, value: any, pinned?: boolean): CacheStore;
    hasCache(key: string): boolean;
    clear(): void;
    delete(key: string): boolean;
    size(): number;
    keys(): IterableIterator<string>;
    /**
     * 将当前CacheStore的缓存数据持久化到文件
     *
     * @param filePath 缓存文件路径
     * @param cacheStoreKeyFilters 可选的过滤器，用于排除特定的key
     */
    persistToFile(filePath: string, cacheStoreKeyFilters?: (cacheStoreKey: string) => boolean): void;
    /**
     * 从文件加载缓存数据到当前CacheStore
     * 只加载文件中不存在的键值对，对于内存中已经有值的直接跳过
     *
     * @param filePath 缓存文件路径
     */
    loadFromFile(filePath: string): void;
    /**
     * 递归提取嵌套的基本类型，数组和对象会被递归展开
     *
     * @param value 待处理的值
     */
    private sanitizeValue;
    /**
     * 判断是否为基本类型
     *
     * @param value 待判断的值
     */
    private isPrimitiveType;
    private completeKey;
    private parseCompleteKey;
}
export interface CacheStoreManagerOption {
    capacity?: number;
    ttl?: number;
}
export declare class CacheStoreManager {
    private cacheStores;
    private readonly lruCache;
    constructor(cacheStoreManagerOption?: CacheStoreManagerOption);
    mount(key: string, pinned?: boolean): CacheStore;
    unmount(key: string): boolean;
    clear(): void;
    size(): number;
    keys(): IterableIterator<string>;
    cacheItemSize(): number;
}
declare class LRUCache {
    private cnt;
    private readonly capacity;
    private key2node;
    private readonly head;
    private readonly tail;
    private readonly ttl;
    constructor(cacheStoreManagerOption?: CacheStoreManagerOption);
    access(key: string): void;
    set(key: string): string | undefined;
    delete(key: string): void;
    private moveToHead;
    private eliminate;
    clear(): void;
    getTTL(): number | undefined;
}
export {};
