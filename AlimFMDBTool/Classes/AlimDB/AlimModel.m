//
//  AlimModel.m
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/16.
//

#import "AlimModel.h"
#import <YYModel/YYModel.h>
#import "AlimDBMacro.h"
#import <objc/message.h>

#define AlimPropertyKey @"property"
#define AlimAutoIncrementKey @"increment"
#define AlimDataColumnsKey @"dataColumn"

@implementation AlimModel
- (void)setValue:(nullable id)value forUndefinedKey:(NSString *)key {
}

- (nullable id)valueForUndefinedKey:(NSString *)key {
    return nil;
}

#pragma mark - Model

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [self yy_modelEncodeWithCoder:aCoder];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    return [self yy_modelInitWithCoder:aDecoder];
}

- (id)copyWithZone:(NSZone *)zone {
    return [self yy_modelCopy];
}

- (NSUInteger)hash {
    return [self yy_modelHash];
}

- (BOOL)isEqual:(id)object {
    return [self yy_modelIsEqual:object];
}

- (NSString *)description {
    return [self yy_modelDescription];
}


+ (NSString *)jsonValueToString:(id)json {
    return [json yy_modelToJSONString];
}

+ (id)stringToJSON:(NSString *)string {
    if (![string isKindOfClass:[NSString class]] || string.length == 0) {
        return nil;
    }
    return [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
}

+ (uint64_t)convertSecToMSec:(NSTimeInterval)sec {
    return (uint64_t)(sec * 1000.0 + 0.5);
}

+ (NSTimeInterval)convertMSecToSec:(NSNumber *)mSec {
    return [mSec doubleValue] / 1000.0;
}

#pragma mark - YYModel
+ (nullable NSArray<NSString *> *)modelPropertyWhitelist {
    NSMutableDictionary *modelPropertyMap = [self modelPropertyInfoMap];
    NSString *className = NSStringFromClass(self.class);
    if (![modelPropertyMap.allKeys containsObject:className]) {
        [self preparePropertyInfo];
    }
    return modelPropertyMap[className][AlimPropertyKey];
}

+ (NSMutableDictionary<NSString *, NSMutableDictionary*> *)modelPropertyInfoMap {
    static NSMutableDictionary *modelPropertyMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        modelPropertyMap = [NSMutableDictionary dictionary];
    });
    return modelPropertyMap;
}

+ (void)preparePropertyInfo {
    NSMutableDictionary *modelPropertyMap = [self modelPropertyInfoMap];
    NSMutableArray *propertyList = [NSMutableArray array];
    NSMutableArray *incrementList = [NSMutableArray array];
    unsigned int count;
    Class metaClass = object_getClass([self class]);
    Method *classMethods = class_copyMethodList(metaClass, &count);
    for (int i = 0; i < count; i++) {
        Method classMethod = classMethods[i];
        SEL selector = method_getName(classMethod);
        NSString *name = NSStringFromSelector(selector);
        if (![name hasPrefix:ALIMDB_STRING(db_)]) {
            continue;
        }
        name = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self.class, selector);
        if (name) {
            [propertyList addObject:name];
            // auto increment key
            if ([self isAutoIncrementColumn:name]) {
                [incrementList addObject:name];
            }
        }
    }
    NSString *className = NSStringFromClass(self.class);
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[AlimPropertyKey] = propertyList;
    info[AlimAutoIncrementKey] = incrementList;
    modelPropertyMap[className] = info;
}

#pragma mark - Database

+ (NSArray<NSString *> *)columnInfoForTable:(NSString *)table addColumnType:(BOOL)addColumnType {
    YYClassInfo *info = [YYClassInfo classInfoWithClass:self];
    NSMutableArray *list = [NSMutableArray array];
    [info.propertyInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (![self isDBColumn:key]) {
            return;
        }
        if (!addColumnType) {
            [list addObject:key];
            return;
        }
        NSString *sqlType = [self getSqlType:obj.typeEncoding];
        if ([self isUniqueColumn:key]) {
            [list addObject:[NSString stringWithFormat:@"%@ %@ UNIQUE", key, sqlType]];
        } else if ([self isPrimaryKeyColumn:key]) {
            NSString *columnDesc = [NSString stringWithFormat:@"%@ %@ PRIMARY KEY", key, sqlType];
            if ([self isAutoIncrementColumn:key]) {
                columnDesc = [NSString stringWithFormat:@"%@ AUTOINCREMENT", columnDesc];
            }
            [list addObject:columnDesc];
        } else {
            [list addObject:[NSString stringWithFormat:@"%@ %@", key, sqlType]];
        }
    }];
    return [NSArray arrayWithArray:list];
}

+ (NSArray<NSString *> *)indexesForTable:(NSString *)table {
    YYClassInfo *info = [YYClassInfo classInfoWithClass:self];
    return [self indexesInColums:info.propertyInfos.allKeys];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
+ (NSString *)virtualTableTokenize:(NSString *)table {
    SEL sel = NSSelectorFromString(ALIMDB_VIRTUAL_TABLE_TOKENIZE_METHOD);
    if ([self respondsToSelector:sel]) {
        return [self performSelector:sel];
    }
    return nil;
}
#pragma clang diagnostic pop

- (NSDictionary *)columnsAndValues {
    id obj = [self yy_modelToJSONObject];
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dict = [obj mutableCopy];
        NSMutableDictionary *modelPropertyMap = [self.class modelPropertyInfoMap];
        NSString *className = NSStringFromClass(self.class);
        if (![modelPropertyMap.allKeys containsObject:className]) {
            [self.class preparePropertyInfo];
        }
        NSDictionary *modelInfo = modelPropertyMap[className];
        // 自增长字段（只能是integer类型），如果没有设置值，则在插入的时候必须不能赋值（或者null）才能真正实现自增长，否则不起作用
        NSArray *autoIncrements = modelInfo[AlimAutoIncrementKey];
        for (NSString *key in autoIncrements) {
            id value = [self valueForKey:key];
            if ([value isKindOfClass:[NSNumber class]]) {
                if ([value intValue] == 0) {
                    dict[key] = nil;
                }
            }
        }
        // 补充YYModel模型转数据时，会漏掉NSData的问题
        NSArray *dataColums = modelInfo[AlimDataColumnsKey] ?: [self.class dataColums];
        for (NSString *column in dataColums) {
            if (dict[column] == nil) {
                id data = [self valueForKey:column];
                if ([data isKindOfClass:[NSData class]]) {
                    dict[column] = data;
                }
            }
        }
        return dict;
    }
    NSAssert(NO, @"???");
    return @{};
}

#pragma mark - private

+ (NSArray <NSString *>*)dataColums {
    NSMutableDictionary *modelPropertyMap = [self.class modelPropertyInfoMap];
    YYClassInfo *info = [YYClassInfo classInfoWithClass:self];
    NSMutableArray *list = [NSMutableArray array];
    [info.propertyInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (![self isDBColumn:key]) {
            return;
        }
        if ([self isDataType:obj.typeEncoding]) {
            [list addObject:key];
        }
    }];
    NSString *className = NSStringFromClass(self.class);
    modelPropertyMap[className][AlimDataColumnsKey] = list;
    return list;
}

+ (NSArray<NSString *> *)indexesInColums:(NSArray <NSString *>*)colums {
    NSMutableArray *filters = [NSMutableArray array];
    for (NSString *colum in colums) {
        if ([self isIndexeASCColumn:colum]) {
            [filters addObject:[NSString stringWithFormat:@"%@ ASC", colum]];
        } else if ([self isIndexeDESCColumn:colum]) {
            [filters addObject:[NSString stringWithFormat:@"%@ DESC", colum]];
        }
    }
    return filters;
}

+ (BOOL)isDBColumn:(NSString *)column {
    return [self respondsToSelector:NSSelectorFromString(column)];
}

+ (BOOL)isUniqueColumn:(NSString *)column {
    return [self respondsToSelector:NSSelectorFromString(ALIMDB_UNIQUE_STR_METHOD(column))];
}

+ (BOOL)isPrimaryKeyColumn:(NSString *)column {
    return [self respondsToSelector:NSSelectorFromString(ALIMDB_PRIMARY_STR_METHOD(column))];
}

+ (BOOL)isAutoIncrementColumn:(NSString *)column {
    return [self respondsToSelector:NSSelectorFromString(ALIMDB_AUTO_INCREMENT_STR_METHOD(column))];
}

+ (BOOL)isIndexeASCColumn:(NSString *)column {
    return [self respondsToSelector:NSSelectorFromString(ALIMDB_INDEX_ASC_STR_METHOD(column))];
}

+ (BOOL)isIndexeDESCColumn:(NSString *)column {
    return [self respondsToSelector:NSSelectorFromString(ALIMDB_INDEX_DESC_STR_METHOD(column))];
}

+ (BOOL)isDataType:(NSString *)yyType {
    return [yyType containsString:@"Data"];
}

+ (NSString *)getSqlType:(NSString*)type {
    if ([type isEqualToString:@"i"] || [type isEqualToString:@"I"] ||
        [type isEqualToString:@"s"] || [type isEqualToString:@"S"] ||
        [type isEqualToString:@"q"] || [type isEqualToString:@"Q"] ||
        [type isEqualToString:@"b"] || [type isEqualToString:@"B"] ||
        [type isEqualToString:@"c"] || [type isEqualToString:@"C"] ||
        [type isEqualToString:@"l"] || [type isEqualToString:@"L"]) {
        return @"INTEGER";
    } else if ([type isEqualToString:@"f"] || [type isEqualToString:@"F"] ||
               [type isEqualToString:@"d"] || [type isEqualToString:@"D"]) {
        return @"REAL";
    } else if ([self isDataType:type]) {
        return @"BLOB";
    } else {
        return @"TEXT";
    }
}

@end
