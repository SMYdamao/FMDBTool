//
//  AlimDB.m
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/15.
//

#import "AlimDB.h"
#import <FMDB/FMDB.h>
#import "FMDatabase+Secret.h"
#import "FMDatabase+FTS5.h"
#import "AlimTokenizers.h"
#import "AlimDBToolDefine.h"
#import "NSString+DBTool.h"

#ifdef SQLITE_HAS_CODEC
#import "sqlite3.h"
#else
#import <sqlite3.h>
#endif

NSString * const AlimTableSeparated = @"_";

#define dispatch_queue_current_equal(queue)\
(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(queue))

#define dispatch_queue_sync_safe(queue, block)\
if (dispatch_queue_current_equal(queue)) {\
block();\
} else {\
dispatch_sync(queue, block);\
}

#define dispatch_barrier_sync_safe(queue, block)\
if (dispatch_queue_current_equal(queue)) {\
    block();\
} else {\
    dispatch_barrier_sync(queue, block);\
}

#define AlimDBMaxReadDBCount 3

@interface AlimDB ()

@property (nonatomic, copy) NSString *name;

@property (nonatomic, copy) NSString *uid;

@property (nonatomic, strong) NSData *key;

@property (nonatomic, strong) FMDatabase *db;

@property (nonatomic, strong) NSOrderedSet<NSString *> *allTables;

@property (nonatomic, strong) NSOrderedSet<NSString *> *virtualTables;

@property (nonatomic, assign) BOOL encrypted;

@property (nonatomic, strong) NSString *path;

@property (nonatomic, assign) NSInteger gateCount;

@property (nonatomic, strong) dispatch_queue_t operationQueue;

@property (nonatomic, assign) BOOL openFastWriteMode;

#pragma mark - readDB property

@property (nonatomic, copy) NSString *readDBLock;

@property (nonatomic, strong) NSMutableDictionary<NSString*, FMDatabase*> *readDBPool;

@property (nonatomic, strong) NSMutableArray<NSString *> *usingReadDBPool;

@property (nonatomic, strong) NSMutableDictionary<NSString*, dispatch_queue_t> *readDBQueuePool;

#ifdef DEBUG
@property (nonatomic) NSTimeInterval beginTransactionTime;
#endif

@end

@implementation AlimDB

- (instancetype)initWithRootPath:(NSString *)rootPath {
    return [self initWithRootPath:rootPath name:[self.class defaultName] uid:nil key:nil];
}

- (instancetype)initWithRootPath:(NSString *)rootPath uid:(NSString *)uid {
    return [self initWithRootPath:rootPath name:[self.class defaultName] uid:uid key:nil];
}

- (instancetype)initWithRootPath:(NSString *)rootPath uid:(NSString *)uid key:(NSData *)key {
    return [self initWithRootPath:rootPath name:[self.class defaultName] uid:uid key:key];
}

- (instancetype)initWithRootPath:(NSString *)rootPath name:(NSString *)name uid:(NSString *)uid key:(NSData *)key {
    if (name.length == 0 ||
        ([self.class isUserDB] && (key == nil || !uid.isNotEmpty))) {
        NSAssert(NO, @"error db key or uid.");
        return nil;
    }
    if (self = [super init]) {
        _name = name;
        _key = key;
        _uid = uid;
        [self setupWithRootPath:rootPath name:name uid:uid key:key];
    }
    return self;
}

- (void)setupWithRootPath:(NSString *)rootPath name:(NSString *)name uid:(NSString * _Nullable)uid key:(NSData *)key {
    self.encrypted = NO;
    self.readDBLock = [NSUUID UUID].UUIDString;
    self.readDBPool = [NSMutableDictionary dictionary];
    self.readDBQueuePool = [NSMutableDictionary dictionary];
    self.usingReadDBPool = [NSMutableArray array];
    NSString *path = rootPath;
    if ([self.class isUserDB]) {
        self.encrypted = YES;
        path = [path stringByAppendingPathComponent:uid];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    path = [[path stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"sqlite"];
    self.path = path;
//    LOG_D(kDB, @"%@ path: %@", NSStringFromClass(self.class), path);
    [self setupSqliteMode];
    [self installTokenizer];
    [self resetAllDB];
    [self setupDBWithPath:path retryCount:3];
    [self setupSomethingIfNeed];
}

- (void)setupSqliteMode {
    sqlite3_config(SQLITE_CONFIG_MULTITHREAD);
}

- (void)resetAllDB {
    [self.readDBPool removeAllObjects];
    self.db = [self createDB];
}

- (FMDatabase *)createDB {
    FMDatabase *db = [FMDatabase databaseWithPath:self.path];
    db.dbKey = self.encrypted ? self.key : nil;
    [self setupDB:db];
    return db;
}

- (void)setupDB:(FMDatabase *)db {
    db.shouldCacheStatements = YES;
#ifdef DEBUG
    db.crashOnErrors = YES;
    db.traceExecution = NO;
#endif
}

- (void)asyncInQueue:(void(^)(void))block {
    dispatch_async(self.operationQueue, block);
}

- (void)syncInQueue:(void(^)(void))block {
    dispatch_queue_sync_safe(self.operationQueue, block);
}

- (void)syncBarryInQueue:(void(^)(void))block {
    dispatch_barrier_sync_safe(self.operationQueue, block);
}

- (void)dealloc {
    [self.db close];
    self.db = nil;
    for (FMDatabase *readDB in self.readDBPool.allValues) {
        [readDB close];
    }
    self.readDBPool = nil;
//    LOG_I(kDB, @"db dealloc");
}

#pragma mark - Database

- (BOOL)openIfNeed {
    BOOL installTk = !self.db.isOpen;
    self.gateCount = self.gateCount + 1;
    BOOL result = [self.db open];
    if (installTk) {
        [self.db installTokenizerModule];
    }
    NSAssert(result, @"open error");
    return result;
}

- (BOOL)beginTransaction {
#ifdef DEBUG
    self.beginTransactionTime = CACurrentMediaTime();
#endif
    BOOL result = [self.db beginDeferredTransaction];
    NSAssert(result, @"beginTransaction error");
    if (!result) {
//        LOG_E(kDB, @"beginTransaction error, the transaction current status is: %@", self.db.isInTransaction ? @"opened" : @"closed");
    }
    return result;
}

- (BOOL)rollbackTransaction {
#ifdef DEBUG
    NSTimeInterval deltaTime = CACurrentMediaTime() - self.beginTransactionTime;
    if (deltaTime > 0.1) {
//        LOG_I(kDB, @"❗️❗️❗️sql cost time: %@", @(deltaTime));
    }
#endif
    BOOL result = [self.db rollback];
    NSAssert(result, @"rollback error");
    if (!result) {
//        LOG_E(kDB, @"rollback error, the transaction current status is: %@", self.db.isInTransaction ? @"opened" : @"closed");
    }
    return result;
}

- (BOOL)commitTransaction {
#ifdef DEBUG
    NSTimeInterval deltaTime = CACurrentMediaTime() - self.beginTransactionTime;
    if (deltaTime > 0.1) {
//        LOG_I(kDB, @"❗️❗️❗️sql cost time: %@", @(deltaTime));
    }
#endif
    BOOL result = [self.db commit];
    NSAssert(result, @"commit error");
    if (!result) {
//        LOG_E(kDB, @"commit error, the transaction current status is: %@", self.db.isInTransaction ? @"opened" : @"closed");
    }
    return result;
}

- (BOOL)closeIfNeed {
    self.gateCount = self.gateCount - 1;
    return [self close];
}

- (BOOL)close {
    BOOL result = YES;
    if (self.gateCount == 0) {
        if (self.openFastWriteMode) {
            [self.db clearCachedStatements];
        } else {
            result = [self.db close];
            NSAssert(result, @"close error");
            if (!result) {
//                LOG_E(kDB, @"close error");
            }
        }
    }
    return result;
}

- (BOOL)checkAndCloseDB {
    @weakify(self);
    __block BOOL result = YES;
    [self syncBarryInQueue:^{
        @strongify(self);
        if (self.gateCount == 0 && self.db.isOpen) {
            result = [self.db close];
            NSAssert(result, @"close error");
            if (!result) {
//                LOG_E(kDB, @"close db error");
            }
#if DEBUG
//            LOG_I(kDB, @"allCount： close db %@", result ? @"success" : @"error");
#endif
        }
    }];
    return result;
}

- (BOOL)deleteDB {
    return [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
}

- (void)setupDBWithPath:(NSString *)path retryCount:(NSInteger)retryCount {
    [self openIfNeed];
    
    // Verify whether the database is normal
    FMResultSet *result = [self.db executeQuery:@"PRAGMA journal_mode = WAL"];
    if (result == nil) {
//        LOG_E(kDB, @"setup db at path: %@ ERROR", path);
        [self closeIfNeed];
        [self openIfNeed];
        result = [self.db executeQuery:@"PRAGMA journal_mode = WAL"];
    }
    
    [result close];
    
    if (!result) {
        [self closeIfNeed];
        if (retryCount > 0) {
            [self setupDBWithPath:path retryCount:retryCount-1];
        } else {
//            LOG_E(kDB, @"finally setup db at path: %@ ERROR, delete it!", path);
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            @weakify(self)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @strongify(self)
                [self resetAllDB];
                [self setupDBWithPath:path retryCount:0];
            });
        }
        return;
    } else {
//        LOG_I(kDB, @"setup db at path: %@ SUCCESS", path);
    }
    
    NSAssert(result != nil, @"setup db at path: %@ ERROR", path);
    
    if ([self synchronousOff]) {
        result = [self.db executeQuery:@"PRAGMA synchronous = OFF"];
        [result close];
    }
    
    [self loadVirtualTables];
    [self fetchAllTableNames];
    [self createTablesIfNeed:[NSSet setWithArray:[self.class tables]]];
    [self createTablesIfNeed:[NSSet setWithArray:[self.class virtualTables]]];
    
    [self closeIfNeed];
}

- (void)fetchAllTableNames {
    [self openIfNeed];
    NSMutableArray *alltables = [NSMutableArray array];
    FMResultSet *result = [self.db executeQuery:@"SELECT name FROM sqlite_master WHERE TYPE = 'table' ORDER BY name DESC"];
    while (result.next) {
        NSString *tableName = [result stringForColumn:@"name"];
        if (![tableName isEqualToString:@"sqlite_sequence"]) {
            [alltables addObject:tableName];
        }
    }
    [result close];
    self.allTables = [NSOrderedSet orderedSetWithArray:alltables];
    [self closeIfNeed];
}

- (void)loadVirtualTables {
    NSArray *virtualTables = [self.class virtualTables] ? : @[];
    self.virtualTables = [NSOrderedSet orderedSetWithArray:virtualTables];
}

- (BOOL)isTableExist:(NSString *)table {
    return [self.allTables containsObject:table];
}

- (BOOL)isVirtualTable:(NSString *)table {
    return [self.virtualTables containsObject:table];
}

- (BOOL)canUseReadDBToQuery {
    return self.readDBPool.count > 0;
}

- (BOOL)createTablesIfNeed:(NSSet<NSString *> *)tables {
    NSMutableArray *createList = [NSMutableArray array];
    NSMutableArray *updateList = [NSMutableArray array];
    NSArray *tmp = [tables allObjects];
    for (NSString *table in tmp) {
        if ([self isTableExist:table]) {
            [updateList addObject:table];
        } else {
            [createList addObject:table];
        }
    }
    // update table colums
    if (updateList.count > 0) {
        [self openIfNeed];
        for ( NSString *table in updateList ) {
            [self addNewColumnsIfNeededForTable:table];
        }
        [self closeIfNeed];
    }
    // create new table
    if (createList.count > 0) {
        [self openIfNeed];
        BOOL result = YES;
        @try {
            for (NSString *table in createList) {
                if ([self isVirtualTable:table]) {
                    [self createVirtualTable:table];
                } else {
                    [self createStorageTable:table];
                }
            }
        } @catch (NSException *exception) {
            result = NO;
        } @finally {
            [self fetchAllTableNames];
        }
        [self closeIfNeed];
        return result;
    }
    return YES;
}

- (void)createStorageTable:(NSString *)table {
    NSArray<NSString *> *columns = [self.class columnInfoForTable:table addColumnType:YES];
    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@)", table, [columns componentsJoinedByString:@", "]];
    [self.db executeUpdate:sql];
    
    NSArray<NSString *> *indexs = [self.class indexesForTable:table];
    for (NSString *index in indexs) {
        NSArray *indexComps = [index componentsSeparatedByString:@" "];
        if (indexComps.count == 2) {
            NSString *indexName = indexComps.firstObject;
            NSString *indexType = indexComps.lastObject;
            sql = [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@_%@_Index ON %@ (%@ %@)", table, indexName, table, indexName, indexType];
            [self.db executeUpdate:sql];
        }
    }
}

- (void)createVirtualTable:(NSString *)table {
    NSString *tokenName = [self.class virtualTableTokenize:table];
    if (tokenName == nil || tokenName.length == 0) {
        tokenName = AlimTokenTokenizerSequelize;
    }
    NSArray<NSString *> *columns = [self.class columnInfoForTable:table addColumnType:NO];
    NSString *sql = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE IF NOT EXISTS %@ USING fts5(%@, tokenize='%@')", table, [columns componentsJoinedByString:@", "], tokenName];
    [self.db executeUpdate:sql];
}

- (void)openDBFastWriteMode {
    self.openFastWriteMode = YES;
}

- (void)closeDBFastWriteMode {
    self.openFastWriteMode = NO;
    [self checkAndCloseDB];
}

- (void)installTokenizer {
    [FMDatabase registerTokenizer:AlimAppleTokenizer.class withKey:AlimTokenTokenizerApple];
    [FMDatabase registerTokenizer:AlimNatualTokenizer.class withKey:AlimTokenTokenizerNatual];
    [FMDatabase registerTokenizer:AlimSequelizeTokenizer.class withKey:AlimTokenTokenizerSequelize];
}

- (void)addNewColumnsIfNeededForTable:(NSString *)table {
    NSArray<NSString *> *columns = [self.class columnInfoForTable:table addColumnType:![self isVirtualTable:table]];
    for ( NSString *column in columns ) {
        if (![self.db columnExists:[column componentsSeparatedByString:@" "].firstObject inTableWithName:table]) {
            @try {
                NSString *alertStr = [NSString stringWithFormat:@"ALTER TABLE %@ ADD %@",table, column];
                BOOL worked = [self.db executeUpdate:alertStr];
                if (worked){
//                    LOG_I(kDB, @"insert new column '%@' success!", column);
                } else {
//                    LOG_E(kDB, @"insert new column '%@' failed", column);
                }
            } @catch (NSException *exception) {
//                LOG_E(kDB, @"insert new column '%@' failed", column);
            } @finally {
            }
        }
    }
}

+ (NSString *)virtualTableTokenize:(NSString *)table {
    Class modelClass = [self modelClassForTable:table];
    if ([modelClass respondsToSelector:@selector(virtualTableTokenize:)]) {
        return [modelClass virtualTableTokenize:table];
    }
    return nil;
}

+ (NSArray<NSString *> *)columnInfoForTable:(NSString *)table addColumnType:(BOOL)addColumnType  {
    Class modelClass = [self modelClassForTable:table];
    if ([modelClass respondsToSelector:@selector(columnInfoForTable:addColumnType:)]) {
        return [modelClass columnInfoForTable:table addColumnType:addColumnType];
    }
    return nil;
}

/// return 'index ASC' or 'index DESC' list
+ (NSArray<NSString *> *)indexesForTable:(NSString *)table {
    Class modelClass = [self modelClassForTable:table];
    if ([modelClass respondsToSelector:@selector(indexesForTable:)]) {
        return [modelClass indexesForTable:table];
    }
    return nil;
}

#pragma mark - Query action

- (void)asyncExecuteAction:(void (^)())action completion:(void (^)(BOOL))completion {
    [self asyncExecuteAction:action completion:completion usedTransaction:NO];
}

- (void)asyncExecuteTransactionAction:(void (^)())action completion:(void (^)(BOOL))completion {
    [self asyncExecuteAction:action completion:completion usedTransaction:YES];
}

- (void)asyncExecuteAction:(void (^)())action completion:(void (^)(BOOL))completion usedTransaction:(BOOL)usedTransaction {
    @weakify(self);
    [self asyncInQueue:^{
        @strongify(self);
        [self syncExecuteAction:action completion:completion usedTransaction:usedTransaction];
    }];
}

- (void)syncExecuteAction:(void (^)())action completion:(void (^)(BOOL))completion {
    [self syncExecuteAction:action completion:completion usedTransaction:NO];
}

- (void)syncExecuteTransactionAction:(void (^)())action completion:(void (^)(BOOL))completion {
    [self syncExecuteAction:action completion:completion usedTransaction:YES];
}

- (void)syncExecuteAction:(void (^)())action completion:(void (^)(BOOL))completion usedTransaction:(BOOL)usedTransaction {
    @weakify(self);
    [self syncBarryInQueue:^{
        @strongify(self);
        [self openIfNeed];
        if (usedTransaction) {
            [self beginTransaction];
        }
        BOOL result = YES;
        @try {
            action();
        } @catch (NSException *exception) {
            result = NO;
            if (usedTransaction) {
                [self rollbackTransaction];
            }
        } @finally {
            if (result && usedTransaction) {
                [self commitTransaction];
            }
            if (completion) {
                completion(result);
            }
        }
        [self closeIfNeed];
    }];
}

- (void)syncExecuteQuery:(FMDatabase *)readDB action:(void (^)())action completion:(void (^)(BOOL))completion {
    if (self.db == readDB) {
        [self syncExecuteAction:action completion:completion];
        return;
    }
#if DEBUG
    NSAssert(!dispatch_queue_current_equal(self.operationQueue), @"read db should not be nesting used");
#endif
    @weakify(self);
    [self syncInQueue:^{
        @strongify(self);
        dispatch_queue_t readQueue = self.readDBQueuePool[readDB.identifier];
        dispatch_sync(readQueue, ^{
            if (!readDB.isOpen) {
                [readDB openWithFlags:SQLITE_OPEN_READONLY];
                [readDB installTokenizerModule];
            }
            BOOL result = YES;
            @try {
                action();
            } @catch (NSException *exception) {
                result = NO;
            } @finally {
                if (completion) {
                    completion(result);
                }
            }
            [readDB clearCachedStatements];
            [self returnReadDB:readDB];
        });
    }];
}


#pragma mark - overwrite

+ (Class)modelClassForTable:(NSString *)table {
    
    return nil;
}

- (void)setupSomethingIfNeed {
    
}

- (BOOL)synchronousOff {
    return NO;
}

+ (BOOL)isUserDB {
    [self doesNotRecognizeSelector:_cmd];
    return YES;
}

+ (NSString *)defaultName {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (NSArray<NSString *> *)tables {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (NSArray<NSString *> *)virtualTables {
    return nil;
}

#pragma mark - readDB

#pragma mark - get&set
- (dispatch_queue_t)operationQueue {
    if (!_operationQueue) {
        _operationQueue = dispatch_queue_create("ai.superim.db_operation", DISPATCH_QUEUE_CONCURRENT);
    }
    return _operationQueue;
}

- (void)returnReadDB:(FMDatabase *)db {
    if (db.identifier == nil) {
        return;
    }
    @synchronized (self.readDBLock) {
        NSInteger removeIdx = [self.usingReadDBPool indexOfObject:db.identifier];
        if (removeIdx >= 0 && self.usingReadDBPool.count > removeIdx) {
            [self.usingReadDBPool removeObjectAtIndex:removeIdx];
        }
    }
}

- (FMDatabase *)readDBSerial:(BOOL)isSerial {
    if ((self.db.isInTransaction && dispatch_queue_current_equal(self.operationQueue)) || isSerial) {
        // 说明是在开启一个写入事务的同时又执行了查询，这时候必须得是同一个db，否则读取的数据不准确
        // 因为可能再执行事务的时候删除、更新或插入了一条消息，但此时进行读取的时候，若db不一样（不是同一个连接），那么读取的数据就是错误的了。
        return self.db;
    }
    __block FMDatabase *db;
    @synchronized (self.readDBLock) {
        if (self.usingReadDBPool.count < self.readDBPool.count) {
            [self.readDBPool enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, FMDatabase * _Nonnull obj, BOOL * _Nonnull stop) {
                if (![self.usingReadDBPool containsObject:key]) {
                    db = obj;
                    [self.usingReadDBPool addObject:key];
                    *stop = YES;
                }
            }];
        } else if (self.readDBPool.count < AlimDBMaxReadDBCount) {
            NSString *readDBKey = [NSString stringWithFormat:@"%ld", self.readDBPool.count];
            db = [self createDB];
            db.identifier = readDBKey;
            dispatch_queue_t queue = dispatch_queue_create([NSString stringWithFormat:@"ai.superim.read_db_%@", readDBKey].UTF8String, DISPATCH_QUEUE_SERIAL);
            self.readDBPool[readDBKey] = db;
            self.readDBQueuePool[readDBKey] = queue;
            [self.usingReadDBPool addObject:readDBKey];
        } else {
            // Reuse readDB
            NSString *readDBKey = [NSString stringWithFormat:@"%ld", (self.usingReadDBPool.count%AlimDBMaxReadDBCount)];
            db = [self.readDBPool objectForKey:readDBKey];
            [self.usingReadDBPool addObject:readDBKey];
//            LOG_I(kDB, @"readDB: 重复使用：%@", readDBKey);
        }
    }
    return db;
}

@end
