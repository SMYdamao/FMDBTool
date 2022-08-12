//
//  AlimDB+Operate.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/17.
//

#import "AlimDB.h"

NS_ASSUME_NONNULL_BEGIN

@class AlimModel, AlimSQL, AlimCondition, AlimSort, AlimSelectCondition;

@interface AlimDB (Operate)

#pragma mark - Insert

/// If there is an object in the DB, it will be ignored.
/// Otherwise, the object will be inserted into the DB
- (BOOL)insertObject:(AlimModel *)object
                 into:(NSString *)table;

/// If there is an object in the DB, it will be ignored.
/// Otherwise, the object will be inserted into the DB
- (BOOL)insertObjects:(NSArray<AlimModel *> *)objects
                 into:(NSString *)table;

/// If there is an object in the DB, replace it.
/// Otherwise, insert the object into the DB
- (BOOL)insertOrReplaceObject:(AlimModel *)object
                          into:(NSString *)table;

/// If there is an object in the DB, replace it.
/// Otherwise, insert the object into the DB
- (BOOL)insertOrReplaceObjects:(NSArray<AlimModel *> *)objects
                          into:(NSString *)table;

#pragma mark - Delete

- (BOOL)deleteAllObjectsFromTable:(NSString *)table;

- (BOOL)deleteObjectsFromTable:(NSString *)table
                         where:(AlimCondition * _Nullable)condition;

#pragma mark - Update

- (BOOL)updateRowsInTable:(NSString *)table
             onProperty:(NSString *)property
                  withValue:(id)value
                    where:(AlimCondition *)condition;

- (BOOL)updateRowsInTable:(NSString *)table
             onProperties:(NSArray<NSString *> *)propertyList
                  withValues:(NSArray *)values
                    where:(AlimCondition *)condition;

#pragma mark - Query

- (NSArray<__kindof AlimModel *> *)getAllObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table;

- (NSArray<__kindof AlimModel *> *)getAllObjectsOnResults:(NSArray<NSString *> *)resultList
                                                withClass:(Class)cls
                                             fromTable:(NSString *)table;

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table
                                               where:(AlimCondition * _Nullable)condition;

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table
                                             orderBy:(AlimSort * _Nullable)orderBy;

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table
                                               where:(AlimCondition * _Nullable)condition
                                             orderBy:(AlimSort * _Nullable)orderBy;

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table
                                             orderBy:(AlimSort * _Nullable)orderBy
                                               limit:(int)limit;

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table
                                               where:(AlimCondition * _Nullable)condition
                                             orderBy:(AlimSort * _Nullable)orderBy
                                               limit:(int)limit;

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table
                                               limit:(int)limit;

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table
                                               where:(AlimCondition * _Nullable)condition
                                               limit:(int)limit
                                              offset:(int)offset;

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table
                                               where:(AlimCondition *)condition
                                               limit:(int)limit
                                              offset:(int)offset
                                            RWSerial:(BOOL)isSerial;

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls
                                           fromTable:(NSString *)table
                                               where:(AlimCondition * _Nullable)condition
                                             orderBy:(AlimSort * _Nullable)orderBy
                                               limit:(int)limit
                                              offset:(int)offset
                                            RWSerial:(BOOL)isSerial;

- (__kindof AlimModel *)getOneObjectOfClass:(Class)cls
                                 fromTable:(NSString *)table
                                     where:(AlimCondition * _Nullable)condition;

- (__kindof AlimModel *)getOneObjectOfClass:(Class)cls
                                 fromTable:(NSString *)table
                                     where:(AlimCondition * _Nullable)condition
                                    orderBy:(AlimSort * _Nullable)orderBy
                                   RWSerial:(BOOL)isSerial;

- (NSArray *)getOneColumnOnResult:(NSString *)result
                        fromTable:(NSString *)table;

- (NSArray *)getOneColumnOnResult:(NSString *)result
                             fromTable:(NSString *)table
                            where:(AlimCondition * _Nullable)condition;

- (NSArray *)getOneDistinctColumnOnResult:(NSString *)result
                             fromTable:(NSString *)table
                            where:(AlimCondition * _Nullable)condition;

- (NSArray *)getOneColumnOnResult:(NSString *)result
                             fromTable:(NSString *)table
                            where:(AlimCondition * _Nullable)condition
                          orderBy:(AlimSort * _Nullable)orderBy;

- (NSArray *)getOneColumnOnResult:(NSString *)result
                             fromTable:(NSString *)table
                            where:(AlimCondition * _Nullable)condition
                            limit:(int)limit
                           offset:(int)offset;

- (NSArray *)getOneColumnOnResult:(NSString *)result
                             fromTable:(NSString *)table
                            where:(AlimCondition * _Nullable)condition
                          orderBy:(AlimSort * _Nullable)orderBy
                            limit:(int)limit
                           offset:(int)offset;

- (id)getOneValueOnResult:(NSString *)result
                fromTable:(NSString *)table
                    where:(AlimCondition * _Nullable)condition
                 RWSerial:(BOOL)isSerial;

- (id)getOneValueOnCondition:(AlimSelectCondition *)selectCond
                   fromTable:(NSString *)table;

- (id)getOneValueOnCondition:(AlimSelectCondition *)selectCond
                   fromTable:(NSString *)table
                       where:(AlimCondition * _Nullable)condition
                    RWSerial:(BOOL)isSerial;

- (BOOL)alterTable:(NSString *)tableName;

@end

NS_ASSUME_NONNULL_END
