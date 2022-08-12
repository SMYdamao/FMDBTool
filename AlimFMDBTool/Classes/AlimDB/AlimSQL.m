//
//  AlimSQL.m
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/16.
//

#import "AlimSQL.h"
#import "AlimModel.h"
#import <FMDB/FMDB.h>
#import <YYModel/YYModel.h>

NSString * const kSQLErrorReporterComponent = @"kSQLErrorReporterComponent";
NSString * const AlimSQLNULL = @"";
NSString * const AlimSQLSpace = @" ";
NSString * const AlimSQLALLColumns = @"*";
NSString * const AlimSQLArrayJoined = @", ";

NSString * SQLValue(id value) {
    NSString *valueStr = @"NULL";
    Class cs = [value class];
    if ([cs isSubclassOfClass:[NSString class]]) {
        valueStr = [(NSString *)value stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        valueStr = [NSString stringWithFormat:@"'%@'", valueStr];
    } else if ([cs isSubclassOfClass:[NSNumber class]]) {
        valueStr = [NSString stringWithFormat:@"%@", value];
    }
    return valueStr;
}

@interface AlimSQL ()

@property (nonatomic, assign) AlimSQLMethod method;

@property (nonatomic, strong) NSString *table;

@property (nonatomic, strong) NSArray<NSString *> *columns;

@property (nonatomic, assign) AlimSQLContent content;

@property (nonatomic, strong) AlimModel *model;

@property (nonatomic, strong) NSDictionary *value;

@property (nonatomic, strong) NSDictionary<NSString *, id> *updateValue;

@property (nonatomic, strong) NSString *updateString;

@property (nonatomic, strong) NSNumber *limit;

@property (nonatomic, strong) NSNumber *offset;

@property (nonatomic, strong) NSString *sortSQLString;

@property (nonatomic, strong) AlimSort *sort;

@property (nonatomic, strong) AlimCondition *condition;

@property (nonatomic, strong) AlimSelectCondition *selectCondition;

@property (nonatomic, copy) NSString *customSQLString;

@property (nonatomic) BOOL notReplace;

@property (nonatomic) BOOL distinct;

@end

@implementation AlimSQL

+ (instancetype)maker {    
    return [[self alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        _notReplace = NO;
        _distinct = NO;
    }
    return self;
}

- (NSString *)string {

    switch (self.method) {
        case AlimSQLMethodInsert: return [self makeInsertSQL];
        case AlimSQLMethodDelete: return [self makeDeleteSQL];
        case AlimSQLMethodUpdate: return [self makeUpdateSQL];
        case AlimSQLMethodSelect: return [self makeSelectSQL];
        case AlimSQLMethodDrop: return [self makeDropSQL];
        case AlimSQLMethodCustom: return self.customSQLString;
        default: return self.AlimIllegalSQL;
    }
}

#pragma mark - Make

- (NSString *)makeInsertSQL {
    if ([self isIllegalInsert]) {
        return self.AlimIllegalSQL;
    }
    return [NSString stringWithFormat:@"INSERT OR %@ INTO %@ (%@) VALUES (%@)", self.notReplace ? @"IGNORE" : @"REPLACE" ,self.table, [self makeInsertColumns], [self makeInsertValuesPlaceholder]];
}

- (NSString *)makeDeleteSQL {
    if ([self isIllegalDelete]) {
        return self.AlimIllegalSQL;
    }
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ ", self.table];
    sql = [sql stringByAppendingString:[self makeConditions]];
    return sql;
}

- (NSString *)makeUpdateSQL {
    if ([self isIllegalUpdate]) {
        return self.AlimIllegalSQL;
    }
    if (self.updateValue.count) {
        return [NSString stringWithFormat:@"UPDATE %@ SET %@ %@", self.table, [self makeChanges], [self makeConditions]];
    }
    if (self.updateString.length) {
        return [NSString stringWithFormat:@"UPDATE %@ SET %@ %@", self.table, self.updateString, [self makeConditions]];
    }
    NSAssert(NO, @"no change value.");
    return self.AlimIllegalSQL;
}

- (NSString *)makeSelectSQL {
    if ([self isIllegalSelect]) {
        return self.AlimIllegalSQL;
    }
    NSMutableArray *list = [NSMutableArray array];
    if (self.selectCondition) {
        [list addObject:[NSString stringWithFormat:@"SELECT %@ FROM %@", [self.selectCondition makeConditions], self.table]];
    } else {
        [list addObject:[NSString stringWithFormat:@"SELECT %@ %@ FROM %@", self.distinct ? @"DISTINCT" : @"", [self makeColumns], self.table]];
    }
    [list addObject:[self makeConditions]];
    [list addObject:[self makeSort]];
    [list addObject:[self makeLimitOffset]];
    return [list componentsJoinedByString:AlimSQLSpace];
}

- (NSString *)makeDropSQL {
    if ([self isIllegalTable]) {
        return self.AlimIllegalSQL;
    }
    return [NSString stringWithFormat:@"DROP TABLE %@", self.table];
}

- (NSString *)makeInsertColumns {
    return [[self.value allKeys] componentsJoinedByString:AlimSQLArrayJoined];
}

- (NSString *)makeInsertValuesPlaceholder {
    return [AlimSQL valuesPlaceholder:self.value.count];
}

- (NSArray *)makeInsertValues {
    return [self.value allValues];
}

- (NSString *)makeChanges {
    @autoreleasepool {
        NSArray<NSString *> *changeKeys = [self.updateValue allKeys];
        NSMutableArray *tmp = [NSMutableArray array];
        for (NSString *change in changeKeys) {
            id value = self.updateValue[change];
            if (value != nil) {
                [tmp addObject:[NSString stringWithFormat:@"%@ = %@", change, SQLValue(value)]];
            }
        }
        return [tmp componentsJoinedByString:AlimSQLArrayJoined];
    }
}

- (NSString *)makeConditions {
    if (self.condition == nil) return AlimSQLNULL;
    return [self.condition makeConditions];
}

- (NSString *)makeColumns {
    return self.columns.count == 0 ? AlimSQLALLColumns : [self.columns componentsJoinedByString:AlimSQLArrayJoined];
}

- (NSString *)makeSort {
    return self.sort == nil ? AlimSQLNULL : [self.sort makeSort];
}

- (NSString *)makeLimitOffset {
    if (self.limit == nil) {
        return AlimSQLNULL;
    }
    NSString *limit = [NSString stringWithFormat:@"LIMIT %lu", (unsigned long)[self.limit unsignedIntegerValue]];
    NSString *offset = self.offset == nil ? AlimSQLNULL : [NSString stringWithFormat:@" OFFSET %lu", (unsigned long)[self.offset unsignedIntegerValue]];
    return [limit stringByAppendingString:offset];
}

#pragma mark - Illegal

- (NSString *)AlimIllegalSQL {
    NSAssert(NO, @"");
    return AlimSQLNULL;
}

- (BOOL)isIllegalInsert {
    if ([self isIllegalTable]) return YES;
    if ([self isIllegalInsertValue]) return YES;
    return NO;
}

- (BOOL)isIllegalDelete {
    if ([self isIllegalTable]) return YES;
    return NO;
}

- (BOOL)isIllegalUpdate {
    if ([self isIllegalTable]) return YES;
    return NO;
}

- (BOOL)isIllegalSelect {
    if ([self isIllegalTable]) return YES;
    return NO;
}

- (BOOL)isIllegalTable {
    return self.table.length == 0;
}

- (BOOL)isIllegalInsertValue {
    if (self.value.count == 0) {
        self.value = [self.model yy_modelToJSONObject];
    }
    return self.value.count == 0;
}

#pragma mark - Method

- (AlimSQL *(^)(NSString *string))zCustomSQLString {
    return ^AlimSQL * (NSString *string) {
        self.method = AlimSQLMethodCustom;
        self.customSQLString = string;
        return self;
    };
}

- (AlimSQL *)zInsert {
    self.method = AlimSQLMethodInsert;
    return self;
}

- (AlimSQL *(^)(BOOL))zNotReplace {
    return ^AlimSQL * (BOOL notReplace) {
        self.notReplace = notReplace;
        return self;
    };
}

- (AlimSQL * _Nonnull (^)(BOOL))zDistinct {
    return ^AlimSQL * (BOOL distinct) {
        self.distinct = distinct;
        return self;
    };
}

- (AlimSQL *)zSelect {
    self.method = AlimSQLMethodSelect;
    return self;
}

- (AlimSQL *)zUpdate {
    self.method = AlimSQLMethodUpdate;
    return self;
}

- (AlimSQL *)zDelete {
    self.method = AlimSQLMethodDelete;
    return self;
}

- (AlimSQL *)zDrop {
    self.method = AlimSQLMethodDrop;
    return self;
}

- (AlimSQL *(^)(NSString *table))zTable {
    return ^AlimSQL * (NSString *table) {
        self.table = table;
        return self;
    };
}

#pragma mark - Word

- (AlimSQL *)zInto {
    return self;
}

- (AlimSQL *)zSet {
    return self;
}

- (AlimSQL *)zFrom {
    return self;
}


#pragma mark - Model Content

- (AlimSQL *(^)(AlimModel *model))zModel {
    return ^AlimSQL * (AlimModel *model) {
        self.model = model;
        self.value = [self.model yy_modelToJSONObject];
        self.content = AlimSQLContentModel;
        return self;
    };
}

- (AlimSQL *(^)(AlimModel *model, NSArray<NSString *> *changeKeys))zUpdateModel {
    return ^AlimSQL * (AlimModel *model, NSArray<NSString *> *changeKeys) {
        @autoreleasepool {
            NSDictionary *json = [model yy_modelToJSONObject];
            NSMutableDictionary *realChanges = [NSMutableDictionary dictionary];
            for (NSString *key in changeKeys) {
                realChanges[key] = json[key];
            }
            self.updateValue = [NSDictionary dictionaryWithDictionary:realChanges];
            self.content = AlimSQLContentModel;
            return self;
        }
    };
}

- (AlimSQL *(^)(NSString * updateString))zUpdateString {
    return ^AlimSQL * (NSString * updateString) {
        self.updateString = updateString;
        self.content = AlimSQLContentModel;
        return self;
    };
}

#pragma mark - Content

- (AlimSQL *)zALL {
    self.columns = nil;
    return self;
}

- (AlimSQL *(^)(NSArray<NSString *> *columns))zColumns {
    return ^AlimSQL * (NSArray<NSString *> *columns) {
        self.columns = columns;
        return self;
    };
}

- (AlimSQL *(^)(NSString *string))zCustomContent {
    return ^AlimSQL * (NSString *string) {
        self.columns = @[string];
        return self;
    };
}

- (AlimSQL *(^)(NSDictionary *value))zValue {
    return ^AlimSQL * (NSDictionary *value) {
        self.model = nil;
        self.value = value;
        self.content = AlimSQLContentOther;
        return self;
    };
}

- (AlimSQL *(^)(NSDictionary *updateValue))zUpdateValue {
    return ^AlimSQL * (NSDictionary *updateValue) {
        self.updateValue = updateValue;
        self.content = AlimSQLContentOther;
        return self;
    };
}

#pragma mark - Condition

- (AlimSQL * (^)(AlimCondition * where ))zWhere {
    return ^AlimSQL * (AlimCondition *where) {
        self.condition = where;
        return self;
    };
}

- (AlimSQL *)zOneReturn {
    self.limit = @(1);
    return self;
}

- (AlimSQL *(^)(NSNumber *limit))zLimit {
    return ^AlimSQL * (NSNumber *limit) {
        self.limit = limit;
        return self;
    };
}

- (AlimSQL *(^)(NSNumber *offset))zOffset {
    return ^AlimSQL * (NSNumber *offset) {
        self.offset = offset;
        return self;
    };
}

#pragma mark - Sort

- (AlimSQL * _Nonnull (^)(AlimSort * _Nonnull))zSort {
    return ^AlimSQL * (AlimSort *sort) {
        self.sort = sort;
        return self;
    };
}

#pragma mark - SelectCondition

- (AlimSQL * _Nonnull (^)(AlimSelectCondition * _Nonnull))zSelectCondition {
    return ^AlimSQL * (AlimSelectCondition *selectCond) {
        self.selectCondition = selectCond;
        return self;
    };
}

#pragma mark - Other

+ (NSString *)valuesPlaceholder:(NSInteger)count {
    static NSDictionary *valuesReplace = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary *temp = [NSMutableDictionary dictionary];
        NSMutableArray *list = [NSMutableArray array];
        for (NSInteger index = 1; index < 100; index++) {
            [list addObject:@"?"];
            [temp setObject:[list componentsJoinedByString:@", "] forKey:@(index)];
        }
        valuesReplace = [NSDictionary dictionaryWithDictionary:temp];
    });
    return [valuesReplace objectForKey:@(count)];
}

@end

@implementation AlimSort

+ (AlimSort *)maker {
    return [[self alloc] init];
}

- (AlimSort *(^)(NSArray<NSString *> *columns))zAsc {
    return ^AlimSort * (NSArray<NSString *> *columns) {
        return self.zSort(columns, @"ASC");
    };
}

- (AlimSort *(^)(NSArray<NSString *> *columns))zDesc {
    return ^AlimSort * (NSArray<NSString *> *columns) {
        return self.zSort(columns, @"DESC");
    };
}

- (AlimSort *(^)(NSArray<NSString *> *columns, NSString *sort))zSort {
    return ^AlimSort * (NSArray<NSString *> *columns, NSString *sort) {
        NSArray *cols = self.sorts[sort];
        if (cols) {
            self.sorts[sort] = [cols arrayByAddingObjectsFromArray:columns];
        } else {
            self.sorts[sort] = columns;
        }
        return self;
    };
}

- (NSString *)makeSort {
    if (_sorts.count == 0) {
        return @"";
    }
    __block NSMutableString *sortStr = [NSMutableString stringWithString:@"ORDER BY "];
    [self.sorts enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSArray<NSString *> * _Nonnull obj, BOOL * _Nonnull stop) {
        NSMutableArray *list = [NSMutableArray array];
        for (NSString *column in obj) {
            [list addObject:[column stringByAppendingString:[NSString stringWithFormat:@" %@", key]]];
        }
        [sortStr appendFormat:@"%@ ", [list componentsJoinedByString:AlimSQLArrayJoined]];
    }];
    return sortStr;
}

- (NSMutableDictionary<NSString *,NSArray<NSString *> *> *)sorts {
    if (!_sorts) {
        _sorts = [NSMutableDictionary dictionary];
    }
    return _sorts;
}

@end

@implementation AlimCondition

+ (AlimCondition *)maker {
    return [[self alloc] init];
}

- (AlimCondition *)zAnd {
    NSString *theCond = @"AND";
    if (![self canAddCondition:theCond]) {
        return self;
    }
    [self.conditions addObject:theCond];
    return self;
}

- (AlimCondition *)zOr {
    NSString *theCond = @"OR";
    if (![self canAddCondition:theCond]) {
        return self;
    }
    [self.conditions addObject:theCond];
    return self;
}

- (AlimCondition *)zOpenParen {
    [self.conditions addObject:@"("];
    return self;
}

- (AlimCondition *)zCloseParen {
    [self.conditions addObject:@")"];
    return self;
}

- (AlimCondition *)zResetCondition {
    [self.conditions removeAllObjects];
    return self;
}

- (AlimCondition *(^)(NSString *column, id value))zIs {
    return ^AlimCondition * (NSString *column, id value) {
        return self.zCondition(column, @"IS", value);
    };
}

- (AlimCondition *(^)(NSString *column, id value))zEqual {
    return ^AlimCondition * (NSString *column, id value) {
        return self.zCondition(column, @"=", value);
    };
}

- (AlimCondition * _Nonnull (^)(NSString * _Nonnull, NSArray * _Nonnull))zEquals {
    return ^AlimCondition * (NSString *column, NSArray *values) {
        [self zOpenParen];
        for (NSInteger idx = 0; idx < values.count; idx++) {
            id value = values[idx];
            self.zCondition(column, @"=", value);
            if (idx != values.count-1) {
                [self zOr];
            }
        }
        [self zCloseParen];
        return self;
    };
}

- (AlimCondition *(^)(NSString *column, id value))zNotEqual {
    return ^AlimCondition * (NSString *column, id value) {
        return self.zCondition(column, @"!=", value);
    };
}

- (AlimCondition * _Nonnull (^)(NSString * _Nonnull, NSArray * _Nonnull))zNotEquals {
    return ^AlimCondition * (NSString *column, NSArray *values) {
        for (NSInteger idx = 0; idx < values.count; idx++) {
            id value = values[idx];
            self.zCondition(column, @"!=", value);
            if (idx != values.count-1) {
                [self zAnd];
            }
        }
        return self;
    };
}

- (AlimCondition * _Nonnull (^)(NSString * _Nonnull))zIsNull {
    return ^AlimCondition * (NSString *column) {
        [self.conditions addObject:[NSString stringWithFormat:@"%@ IS NULL", column]];
        return self;
    };
}

- (AlimCondition * _Nonnull (^)(NSString * _Nonnull))zNotNull {
    return ^AlimCondition * (NSString *column) {
        [self.conditions addObject:[NSString stringWithFormat:@"%@ IS NOT NULL", column]];
        return self;
    };
}

- (AlimCondition *(^)(NSString *column, id value))zLike {
    return ^AlimCondition * (NSString *column, id value) {
        return self.zCondition(column, @"LIKE", value);
    };
}

- (AlimCondition *(^)(NSString *column, NSArray *values))zIn {
    return ^AlimCondition * (NSString *column, NSArray *values) {
        [self makeInOrNotInCondition:YES column:column valus:values];
        return self;
    };
}

- (AlimCondition * _Nonnull (^)(NSString * _Nonnull, NSArray * _Nonnull))zNotIn {
    return ^AlimCondition * (NSString *column, NSArray *values) {
        [self makeInOrNotInCondition:NO column:column valus:values];
        return self;
    };
}

- (AlimCondition *(^)(NSString *column, id value))zLess {
    return ^AlimCondition * (NSString *column, id value) {
        return self.zCondition(column, @"<", value);
    };
}

- (AlimCondition *(^)(NSString *column, id value))zLessEqual {
    return ^AlimCondition * (NSString *column, id value) {
        return self.zCondition(column, @"<=", value);
    };
}

- (AlimCondition *(^)(NSString *column, id value))zGreater {
    return ^AlimCondition * (NSString *column, id value) {
        return self.zCondition(column, @">", value);
    };
}

- (AlimCondition *(^)(NSString *column, id value))zGreaterEqual {
    return ^AlimCondition * (NSString *column, id value) {
        return self.zCondition(column, @">=", value);
    };
}

- (AlimCondition * _Nonnull (^)(NSString * _Nonnull, id _Nonnull))zMatch {
    return ^AlimCondition * (NSString *column, id value) {
        return self.zCondition(column, @"MATCH", value);
    };
}

- (AlimCondition * _Nonnull (^)(NSString * _Nonnull, NSString * _Nonnull))zMax {
    return ^AlimCondition * (NSString *column, NSString * table) {
        [self.conditions addObject:[NSString stringWithFormat:@"%@ = (SELECT MAX(%@) from %@)", column, column, table]];
        return self;
    };
}

- (AlimCondition * _Nonnull (^)(NSString * _Nonnull, NSString * _Nonnull))zMin {
    return ^AlimCondition * (NSString *column, NSString * table) {
        [self.conditions addObject:[NSString stringWithFormat:@"%@ = (SELECT MIN(%@) from %@)", column, column, table]];
        return self;
    };
}

- (AlimCondition *(^)(NSString *column, NSString *center, id value))zCondition {
    return ^AlimCondition * (NSString *column, NSString *center, id value) {
        [self.conditions addObject:[NSString stringWithFormat:@"%@ %@ %@", column, center, SQLValue(value)]];
        return self;
    };
}

- (NSString *)makeConditions {
    // 合法性检查
    [self syntaxValidityCheck];
    
    if (self.conditions.count == 0) return AlimSQLNULL;
    NSString *conditions = [self.conditions componentsJoinedByString:AlimSQLSpace];
    return [NSString stringWithFormat:@"WHERE %@", conditions];
}

#pragma mark - Other

- (BOOL)canAddCondition:(NSString *)theCond {
    NSString *lastCond = self.conditions.lastObject;
    if (self.conditions.count == 0 || [lastCond isEqual:@"AND"] || [lastCond isEqualToString:@"OR"] || [lastCond isEqualToString:@"("]) {
//        LOG_E(kDB, @"should not add duplicate condition '%@', because last condition is %@", theCond, lastCond.isNumber ? lastCond : @"empty");
        return NO;
    }
    return YES;
}

- (void)syntaxValidityCheck {
    if (self.conditions.count == 0) {
        return;
    }
    
    NSString *lastCond = self.conditions.lastObject;
    if ([lastCond isEqual:@"AND"] || [lastCond isEqual:@"OR"] || [lastCond isEqualToString:@"("]) {
//        LOG_I(kDB, @"remove last condition: %@, because is not effective", lastCond);
        [self.conditions removeLastObject];
    }
    
    NSString *firstCond = self.conditions.firstObject;
    if ([firstCond isEqual:@"AND"] || [firstCond isEqual:@"OR"]) {
//        LOG_I(kDB, @"remove first condition: %@, because is not effective", firstCond);
        [self.conditions removeObjectAtIndex:0];
    }
}

- (void)makeInOrNotInCondition:(BOOL)isIn column:(NSString *)column valus:(NSArray *)values {
    NSMutableString *string = [NSMutableString stringWithFormat:@"( "];
    [values enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [string appendString:SQLValue(obj)];
        if (idx != values.count - 1) { // not last object
            [string appendString:@", "];
        }
    }];
    [string appendString:@" )"];
    [self.conditions addObject:[NSString stringWithFormat:@"%@ %@ %@", column, isIn ? @"IN" : @"NOT IN", string]];
}

- (NSMutableArray *)conditions {
    if (_conditions == nil) {
        _conditions = [NSMutableArray array];
    }
    return _conditions;
}

@end

@implementation AlimSelectCondition

+ (AlimSelectCondition *)maker {
    return [[self alloc] init];
}

- (AlimSelectCondition * _Nonnull (^)(NSString * _Nonnull))zMax {
    return ^AlimSelectCondition * (NSString *column) {
        self.zMaxDistinct(column, NO);
        return self;
    };
}

- (AlimSelectCondition * _Nonnull (^)(NSString * _Nonnull, BOOL))zMaxDistinct {
    return ^AlimSelectCondition * (NSString *column, BOOL distinct) {
        [self.conditions addObject:[NSString stringWithFormat:@"MAX(%@ %@)", distinct ? @"DISTINCT" : @"", column]];
        return self;
    };
}

- (AlimSelectCondition * _Nonnull (^)(NSString * _Nonnull))zMin {
    return ^AlimSelectCondition * (NSString *column) {
        self.zMinDistinct(column, NO);
        return self;
    };
}

- (AlimSelectCondition * _Nonnull (^)(NSString * _Nonnull, BOOL))zMinDistinct {
    return ^AlimSelectCondition * (NSString *column, BOOL distinct) {
        [self.conditions addObject:[NSString stringWithFormat:@"MIN(%@ %@)", distinct ? @"DISTINCT" : @"", column]];
        return self;
    };
}

- (AlimSelectCondition * _Nonnull (^)(void))zCount {
    return ^AlimSelectCondition * (void) {
        [self.conditions addObject:@"COUNT(*)"];
        return self;
    };
}

- (AlimSelectCondition * _Nonnull (^)(NSString * _Nonnull, BOOL))zCountColumn {
    return ^AlimSelectCondition * (NSString *column, BOOL distinct) {
        [self.conditions addObject:[NSString stringWithFormat:@"COUNT(%@%@)", distinct ? @"DISTINCT " : @"", column]];
        return self;
    };
}

- (NSString *)makeConditions {
    if (self.conditions.count == 0) return AlimSQLNULL;
    return [self.conditions componentsJoinedByString:AlimSQLSpace];;
}

- (NSMutableArray *)conditions {
    if (_conditions == nil) {
        _conditions = [NSMutableArray array];
    }
    return _conditions;
}

@end
