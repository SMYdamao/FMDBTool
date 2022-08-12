//
//  AlimDB.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FMDatabase;

@interface AlimDB : NSObject

@property (nonatomic, copy, readonly) NSString *name;

@property (nonatomic, copy, readonly) NSString *uid;

@property (nonatomic, strong, readonly) NSData *key;

@property (nonatomic, strong, readonly) FMDatabase *db;

@property (nonatomic, strong, readonly) FMDatabase *readDB;

@property (nonatomic, strong, readonly) NSOrderedSet<NSString *> *allTables;

// init with defualt name, must not be user db
- (instancetype)initWithRootPath:(NSString *)rootPath;

// init with defualt name
- (instancetype)initWithRootPath:(NSString *)rootPath uid:(NSString *)uid;

// init with defualt name
- (instancetype)initWithRootPath:(NSString *)rootPath uid:(NSString *)uid key:(NSData *)key;

// if is user db key and uid must be not nil, if not is user db ignore key and uid
- (instancetype)initWithRootPath:(NSString *)rootPath name:(NSString *)name uid:(NSString * _Nullable )uid key:( NSData * _Nullable )key;

#pragma mark - Database

- (BOOL)beginTransaction;

- (BOOL)commitTransaction;

- (BOOL)rollbackTransaction;

- (BOOL)deleteDB;

- (BOOL)isTableExist:(NSString *)table;

- (BOOL)isVirtualTable:(NSString *)table;

- (BOOL)canUseReadDBToQuery;

- (void)openDBFastWriteMode;

- (void)closeDBFastWriteMode;

#pragma mark - action

/// thread safe, run on write queue, with transaction
- (void)asyncExecuteTransactionAction:(void(^)(void))action
                completion:(void (^ )(BOOL finished))completion;

/// thread safe, run on write queue, not use transaction
- (void)asyncExecuteAction:(void(^)(void))action
                completion:(void (^ )(BOOL finished))completion;

/// thread safe, run on write queue, can select use transaction
- (void)asyncExecuteAction:(void (^)(void))action
                completion:(void (^)(BOOL))completion
           usedTransaction:(BOOL)usedTransaction;

///thread safe, with transaction
- (void)syncExecuteTransactionAction:(void(^)(void))action
               completion:(void (^)(BOOL finished))completion;

/// thread safe, not use transaction
- (void)syncExecuteAction:(void(^)(void))action
               completion:(void (^)(BOOL finished))completion;

/// thread safe, can select use transaction
- (void)syncExecuteAction:(void (^)(void))action
               completion:(void (^)(BOOL))completion
          usedTransaction:(BOOL)usedTransaction;

/// thread safe, used query db
- (void)syncExecuteQuery:(FMDatabase *)readDB
                  action:(void (^)(void))action
              completion:(void (^)(BOOL))completion;

#pragma mark - Overwrite

+ (Class)modelClassForTable:(NSString *)table;

- (void)setupSomethingIfNeed NS_REQUIRES_SUPER;   //option

- (void)fetchAllTableNames NS_REQUIRES_SUPER;   //option

+ (BOOL)isUserDB;

// use by initWithVuid:
+ (NSString *)defaultName;

/// storage tables
+ (NSArray<NSString *> *)tables;

/// virtual tables
+ (NSArray<NSString *> *)virtualTables;

- (BOOL)synchronousOff;

- (FMDatabase *)readDBSerial:(BOOL)isSerial;

@end

NS_ASSUME_NONNULL_END
