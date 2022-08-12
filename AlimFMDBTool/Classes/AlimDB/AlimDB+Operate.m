//
//  AlimDB+Operate.m
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/17.
//

#import "AlimDB+Operate.h"
#import "AlimModel.h"
#import "AlimSQL.h"
#import <FMDB/FMDB.h>
#import <YYModel/YYModel.h>
#import "FMResultSet+Result.h"
#import "NSString+DBTool.h"

#if DEBUG
#define ENABLE_LOGDB 0
#endif

@implementation AlimDB (Operate)

#pragma mark - insert

- (BOOL)insertObject:(AlimModel *)object into:(NSString *)table {
    return [self insertObjects:@[object] into:table];
}

- (BOOL)insertObjects:(NSArray<AlimModel *> *)objects into:(NSString *)table {
    return [self insertObjects:objects into:table notReplace:YES];
}

- (BOOL)insertOrReplaceObject:(AlimModel *)object into:(NSString *)table {
    return [self insertOrReplaceObjects:@[object] into:table];
}

- (BOOL)insertOrReplaceObjects:(NSArray<AlimModel *> *)objects into:(NSString *)table {
    return [self insertObjects:objects into:table notReplace:NO];
}

- (BOOL)insertObjects:(NSArray<AlimModel *> *)objects into:(NSString *)table notReplace:(BOOL)notReplace {
    NSMutableArray *values = [NSMutableArray array];
    for (AlimModel *model in objects) {
        @autoreleasepool {
            [values addObject:[model columnsAndValues]];
        }
    }
    return [self insertVaules:values into:table notReplace:notReplace];
}

- (BOOL)insertVaules:(NSArray<NSDictionary *> *)vaules into:(NSString *)table notReplace:(BOOL)notReplace  {
    NSAssert(table.length != 0, @"");
    if (vaules.count == 0) {
        return YES;
    }
    if (!table.isNotEmpty) {
        NSAssert(NO, @"");
        return NO;
    }
    if (![self isTableExist:table]) {
//        LOG_E(kDB, @"table not exist. table: %@", table);
        NSAssert(NO, @"???");
        return NO;
    }
    AlimSQL *sql = AlimSQLMaker.zInsert.zNotReplace(notReplace).zInto.zTable(table);
    __block BOOL result = YES;
    [self syncExecuteAction:^{
        for (NSDictionary *json in vaules) {
            @autoreleasepool {
                [self run:sql.zValue(json)];
            }
        }
    } completion:^(BOOL finished) {
        result = finished;
        if (!finished) {
//            LOG_E(kDB, @"insert db error : %@", sql.string);
        }
    } usedTransaction:(!self.db.isInTransaction && vaules.count>1)];
    return result;
}

#pragma mark - Delete

- (BOOL)deleteAllObjectsFromTable:(NSString *)table {
    return [self deleteObjectsFromTable:table where:nil];
}

- (BOOL)deleteObjectsFromTable:(NSString *)table where:(AlimCondition * _Nullable)condition {
    if (!table.isNotEmpty) {
        NSAssert(NO, @"???");
        return NO;
    }
    if (![self isTableExist:table]) {
//        LOG_E(kDB, @"table not exist. table: %@", table);
        NSAssert(NO, @"???");
        return NO;
    }
    AlimSQL *sql = AlimSQLMaker.zDelete.zTable(table).zWhere(condition);
    __block BOOL result = YES;
    [self syncExecuteAction:^{
        [self run:sql];
    } completion:^(BOOL finished) {
        result = finished;
        if (!finished) {
//            LOG_E(kDB, @"delete db item error : %@", sql.string);
        }
    } usedTransaction:!self.db.isInTransaction];
    return result;
}

#pragma mark - Update

- (BOOL)updateRowsInTable:(NSString *)table onProperty:(nonnull NSString *)property withValue:(nonnull id)value where:(nonnull AlimCondition *)condition {
    if (!property.isNotEmpty || value == nil) {
        NSAssert(NO, @"???");
        return NO;
    }
    return [self updateRowsInTable:table onProperties:@[property] withValues:@[value] where:condition];
}

- (BOOL)updateRowsInTable:(NSString *)table onProperties:(NSArray<NSString *> *)propertyList withValues:(NSArray *)values where:(AlimCondition *)condition {
    if (propertyList.count != values.count) {
        NSAssert(NO, @"???");
        return NO;
    }
    if (![self isTableExist:table]) {
//        LOG_E(kDB, @"table not exist. table: %@", table);
        NSAssert(NO, @"???");
        return NO;
    }
    AlimSQL *sql = AlimSQLMaker.zUpdate.zTable(table);
    NSMutableDictionary *updateValue = [NSMutableDictionary dictionary];
    for (NSInteger index = 0 ; index < propertyList.count; index++) {
        NSString *property = propertyList[index];
        id value = values[index];
        updateValue[property] = value;
    }
    sql.zUpdateValue(updateValue).zWhere(condition);
    __block BOOL result = YES;
    [self syncExecuteAction:^{
        [self run:sql];
    } completion:^(BOOL finished) {
        result = finished;
        if (!finished) {
//            LOG_E(kDB, @"update db error : %@", sql.string);
        }
    } usedTransaction:!self.db.isInTransaction];
    return result;
}

#pragma mark - alter

- (BOOL)alterTable:(NSString *)tableName {
    NSString *delSql = [NSString stringWithFormat:@"delete from %@", tableName];
    AlimSQL *(^delBlock) (NSString *string) = AlimSQLMaker.zCustomSQLString;
    AlimSQL *delCusSql = delBlock(delSql);

    NSString *alterSql = [NSString stringWithFormat:@"alter table %@ AUTOINCREMENT=1", tableName];
    AlimSQL *(^alterBlock) (NSString *string) = AlimSQLMaker.zCustomSQLString;
    AlimSQL *alterCusSQL = alterBlock(alterSql);
    __block BOOL result = NO;
    [self syncExecuteAction:^{
        [self run:delCusSql];
        [self run:alterCusSQL];
    } completion:^(BOOL finished) {
        result = finished;
        if (!finished) {
//            LOG_E(kDB, @"del db error : %@", delCusSql.string);
//            LOG_E(kDB, @"alter db error : %@", alterCusSQL.string);
        }
    }];
    return result;
}

#pragma mark - Query

- (NSArray<__kindof AlimModel *> *)getAllObjectsOfClass:(Class)cls fromTable:(NSString *)table {
    return [self getObjectsOfClass:cls fromTable:table where:nil];
}

- (NSArray<__kindof AlimModel *> *)getAllObjectsOnResults:(NSArray<NSString *> *)resultList withClass:(Class)cls fromTable:(NSString *)table {
    NSArray *reslutObjList = [self getColumnsOnResults:resultList fromTable:table where:nil orderBy:nil limit:-1 offset:-1 distinct:NO RWSerial:NO];
    return [NSArray yy_modelArrayWithClass:cls json:reslutObjList];
}

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls fromTable:(NSString *)table where:(AlimCondition *)condition {
    return [self getObjectsOfClass:cls fromTable:table where:condition orderBy:nil];
}

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls fromTable:(NSString *)table orderBy:(AlimSort *)orderBy {
    return [self getObjectsOfClass:cls fromTable:table where:nil orderBy:orderBy];
}

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls fromTable:(NSString *)table where:(AlimCondition *)condition orderBy:(AlimSort *)orderBy {
    return [self getObjectsOfClass:cls fromTable:table where:condition orderBy:orderBy limit:-1];
}

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls fromTable:(NSString *)table limit:(int)limit {
    return [self getObjectsOfClass:cls fromTable:table where:nil orderBy:nil limit:-1];
}

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls fromTable:(NSString *)table orderBy:(AlimSort *)orderBy limit:(int)limit {
    return [self getObjectsOfClass:cls fromTable:table where:nil orderBy:orderBy limit:limit];
}

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls fromTable:(NSString *)table where:(AlimCondition *)condition orderBy:(AlimSort *)orderBy limit:(int)limit {
    return [self getObjectsOfClass:cls fromTable:table where:condition orderBy:orderBy limit:limit offset:-1 RWSerial:NO];
}

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls fromTable:(NSString *)table where:(AlimCondition *)condition limit:(int)limit offset:(int)offset {
    return [self getObjectsOfClass:cls fromTable:table where:condition orderBy:nil limit:limit offset:offset RWSerial:NO];
}

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls fromTable:(NSString *)table where:(AlimCondition *)condition limit:(int)limit offset:(int)offset RWSerial:(BOOL)isSerial {
    return [self getObjectsOfClass:cls fromTable:table where:condition orderBy:nil limit:limit offset:offset RWSerial:isSerial];
}

- (NSArray<__kindof AlimModel *> *)getObjectsOfClass:(Class)cls fromTable:(NSString *)table where:(AlimCondition *)condition orderBy:(AlimSort *)orderBy limit:(int)limit offset:(int)offset RWSerial:(BOOL)isSerial {
    if (!table.isNotEmpty || cls == nil) {
        NSAssert(NO, @"???");
        return @[];
    }
    if (![self isTableExist:table]) {
//        LOG_E(kDB, @"table not exist. table: %@", table);
        NSAssert(NO, @"???");
        return @[];
    }
    AlimSQL *sql = AlimSQLMaker.zSelect.zFrom.zTable(table).zWhere(condition).zSort(orderBy);
    if (limit >= 0) {
        sql.zLimit(@(limit));
    }
    if (offset >= 0) {
        sql.zOffset(@(offset));
    }
    __block NSArray *list = nil;
    FMDatabase *readDB = [self readDBSerial:isSerial];
    [self syncExecuteQuery:readDB action:^{
        list = [self runModelQuery:sql modelClass:cls readDB:readDB];
    } completion:^(BOOL finished) {
        if (!finished) {
//            LOG_E(kDB, @"query db error : %@", sql.string);
        }
    }];
    return list;
}

- (__kindof AlimModel *)getOneObjectOfClass:(Class)cls fromTable:(NSString *)table where:(AlimCondition *)condition {
    return [self getOneObjectOfClass:cls fromTable:table where:condition orderBy:nil RWSerial:NO];
}

- (__kindof AlimModel *)getOneObjectOfClass:(Class)cls fromTable:(NSString *)table where:(AlimCondition *)condition orderBy:(AlimSort *)orderBy RWSerial:(BOOL)isSerial {
    if (!table.isNotEmpty) {
        NSAssert(NO, @"???");
        return nil;
    }
    if (![self isTableExist:table]) {
//        LOG_E(kDB, @"table not exist. table: %@", table);
        NSAssert(NO, @"???");
        return nil;
    }
    AlimSQL *sql = AlimSQLMaker.zSelect.zFrom.zTable(table).zWhere(condition).zSort(orderBy).zOneReturn;
    __block AlimModel *model = nil;
    FMDatabase *readDB = [self readDBSerial:isSerial];
    [self syncExecuteQuery:readDB action:^{
        model = [self runModelQuery:sql modelClass:cls readDB:readDB].firstObject;
    } completion:^(BOOL finished) {
        if (!finished) {
//            LOG_E(kDB, @"query db error : %@", sql.string);
        }
    }];
    return model;
}

- (NSArray *)getOneDistinctColumnOnResult:(NSString *)result fromTable:(NSString *)table where:(AlimCondition *)condition {
    return [self getOneColumnOnResult:result fromTable:table where:condition orderBy:nil limit:-1 offset:-1 distinct:YES RWSerial:NO];
}

- (NSArray *)getOneColumnOnResult:(NSString *)result fromTable:(NSString *)table {
    return [self getOneColumnOnResult:result fromTable:table where:nil];
}

- (NSArray *)getOneColumnOnResult:(NSString *)result fromTable:(NSString *)table where:(AlimCondition *)condition {
    return [self getOneColumnOnResult:result fromTable:table where:condition orderBy:nil];
}

- (NSArray *)getOneColumnOnResult:(NSString *)result fromTable:(NSString *)table where:(AlimCondition *)condition orderBy:(AlimSort *)orderBy {
    return [self getOneColumnOnResult:result fromTable:table where:condition orderBy:orderBy limit:-1 offset:-1];
}

- (NSArray *)getOneColumnOnResult:(NSString *)result fromTable:(NSString *)table where:(AlimCondition *)condition limit:(int)limit offset:(int)offset {
    return [self getOneColumnOnResult:result fromTable:table where:condition orderBy:nil limit:limit offset:offset];
}

- (NSArray *)getOneColumnOnResult:(NSString *)result fromTable:(NSString *)table where:(AlimCondition *)condition orderBy:(AlimSort *)orderBy limit:(int)limit offset:(int)offset {
    return [self getOneColumnOnResult:result fromTable:table where:condition orderBy:orderBy limit:limit offset:offset distinct:NO RWSerial:NO];
}

- (NSArray *)getOneColumnOnResult:(NSString *)result fromTable:(NSString *)table where:(AlimCondition *)condition orderBy:(AlimSort *)orderBy limit:(int)limit offset:(int)offset distinct:(BOOL)distinct RWSerial:(BOOL)isSerial {
    if (!table.isNotEmpty || !result.isNotEmpty) {
        NSAssert(NO, @"???");
        return @[];
    }
    if (![self isTableExist:table]) {
//        LOG_E(kDB, @"table not exist. table: %@", table);
        NSAssert(NO, @"???");
        return @[];
    }
    NSMutableArray *list = [NSMutableArray array];
    NSArray *resultsList = [self getColumnsOnResults:@[result] fromTable:table where:condition orderBy:orderBy limit:limit offset:offset distinct:distinct RWSerial:isSerial];
    for (NSDictionary *resObj in resultsList) {
        id obj = resObj[result];
        if (obj) {
            [list addObject:obj];
        }
    }
    return list;
}

- (NSArray<NSDictionary *> *)getColumnsOnResults:(NSArray<NSString *> *)results fromTable:(NSString *)table where:(AlimCondition *)condition orderBy:(AlimSort *)orderBy limit:(int)limit offset:(int)offset distinct:(BOOL)distinct RWSerial:(BOOL)isSerial {
    if (!table.isNotEmpty || results.count == 0) {
        NSAssert(NO, @"???");
        return @[];
    }
    if (![self isTableExist:table]) {
//        LOG_E(kDB, @"table not exist. table: %@", table);
        NSAssert(NO, @"???");
        return @[];
    }
    AlimSQL *sql = AlimSQLMaker.zSelect.zDistinct(distinct).zColumns(results).zFrom.zTable(table).zWhere(condition).zSort(orderBy);
    if (limit >= 0) {
        sql.zLimit(@(limit));
    }
    if (offset >= 0) {
        sql.zOffset(@(offset));
    }
    __block NSArray *list = nil;
    FMDatabase *readDB = [self readDBSerial:isSerial];
    [self syncExecuteQuery:readDB action:^{
        list = [self runQuery:sql readDB:readDB];
    } completion:^(BOOL finished) {
        if (!finished) {
//            LOG_E(kDB, @"query db error : %@", sql.string);
        }
    }];
    return list;
}

- (id)getOneValueOnResult:(NSString *)result fromTable:(NSString *)table where:(AlimCondition *)condition RWSerial:(BOOL)isSerial {
    if (!table.isNotEmpty || !result.isNotEmpty) {
        NSAssert(NO, @"???");
        return nil;
    }
    if (![self isTableExist:table]) {
//        LOG_E(kDB, @"table not exist. table: %@", table);
        NSAssert(NO, @"???");
        return nil;
    }
    AlimSQL *sql = AlimSQLMaker.zSelect.zColumns(@[result]).zFrom.zTable(table).zWhere(condition).zOneReturn;
    __block id columnObj = nil;
    FMDatabase *readDB = [self readDBSerial:isSerial];
    [self syncExecuteQuery:readDB action:^{
        NSDictionary *firstObj = [self runQuery:sql readDB:readDB].firstObject;
        columnObj = firstObj[result];
    } completion:^(BOOL finished) {
        if (!finished) {
//            LOG_E(kDB, @"query db error : %@", sql.string);
        }
    }];
    return columnObj;
}

- (id)getOneValueOnCondition:(AlimSelectCondition *)selectCond fromTable:(NSString *)table {
    return [self getOneValueOnCondition:selectCond fromTable:table where:nil RWSerial:NO];
}

- (id)getOneValueOnCondition:(AlimSelectCondition *)selectCond fromTable:(NSString *)table where:(AlimCondition * _Nullable)condition RWSerial:(BOOL)isSerial {
    if (!table.isNotEmpty || selectCond == nil) {
        NSAssert(NO, @"???");
        return nil;
    }
    if (![self isTableExist:table]) {
//        LOG_E(kDB, @"table not exist. table: %@", table);
        NSAssert(NO, @"???");
        return nil;
    }
    AlimSQL *sql = AlimSQLMaker.zSelect.zSelectCondition(selectCond).zFrom.zTable(table).zWhere(condition).zOneReturn;
    __block id resultObj = nil;
    FMDatabase *readDB = [self readDBSerial:isSerial];
    [self syncExecuteQuery:readDB action:^{
        NSDictionary * resultDict = [self runQuery:sql readDB:readDB].firstObject;
        resultObj = resultDict.allValues.firstObject;
    } completion:^(BOOL finished) {
        if (!finished) {
//            LOG_E(kDB, @"query db error : %@", sql.string);
        }
    }];
    return resultObj;
}

#pragma mark - Run

- (BOOL)run:(AlimSQL *)sql {
    if (sql.method == AlimSQLMethodNone || sql.method == AlimSQLMethodSelect) {
        NSAssert(NO, @"");
        return NO;
    }
    NSString *sqlStr = sql.string;
    if (!sqlStr.isNotEmpty) {
        return NO;
    } else if (sql.method == AlimSQLMethodInsert) {
#if ENABLE_LOGDB
        NSString *tmpString = sql.string;
        for (id value in [sql makeInsertValues]) {
            NSRange range = [tmpString rangeOfString:@"?"];
            tmpString = [tmpString stringByReplacingCharactersInRange:range withString:[NSString stringWithFormat:@"%@", value]];
        }
//        LOG_I(kDB, @"sql execute: %@", tmpString);
#endif
        return [self.db executeUpdate:sqlStr withArgumentsInArray:[sql makeInsertValues]];
    } else {
#if ENABLE_LOGDB
//    LOG_I(kDB, @"sql execute: %@", sqlStr);
#endif
    return [self.db executeUpdate:sqlStr];
    }
}

- (NSArray<NSMutableDictionary *> *)runQuery:(AlimSQL *)sql readDB:(FMDatabase *)readDB {
    if (!(sql.method == AlimSQLMethodSelect
          || sql.method == AlimSQLMethodCustom)) {
        return nil;
    }
    NSMutableArray *list = [NSMutableArray array];
    NSString *query = sql.string;
#if ENABLE_LOGDB
//    LOG_I(kDB, @"sql execute: %@", sql.string);
#endif
#if DEBUG
    NSTimeInterval beginTransactionTime = CACurrentMediaTime();
#endif
    FMResultSet *resultSet = [readDB executeQuery:query];
    while ([resultSet next]) {
        NSDictionary *value = [resultSet safeResultDictionary];
        if (value != nil) {
            [list addObject:value];
        }
    }
    
#if DEBUG
    NSTimeInterval deltaTime = CACurrentMediaTime() - beginTransactionTime;
    if (deltaTime > 0.1) {
//        LOG_I(kDB, @"❗️❗️❗️sql cost time: %@, sql： %@", @(deltaTime), sql.string);
    }
#endif
    
    [resultSet close];
    return [NSArray arrayWithArray:list];
}

- (NSArray<__kindof AlimModel *> *)runModelQuery:(AlimSQL *)sql modelClass:(Class)modelClass readDB:(FMDatabase *)readDB {
    NSAssert([modelClass isSubclassOfClass:[AlimModel class]], @"");
    return [NSArray yy_modelArrayWithClass:modelClass json:[self runQuery:sql readDB:readDB]];
}

@end
