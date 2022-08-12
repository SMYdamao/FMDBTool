//
//  AlimDBMacro.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/17.
//

#ifndef AlimDBMacro_h
#define AlimDBMacro_h

#define ALIMDB_METHOD_NAME(prefix, sufix) prefix##_##sufix
#define ALIMDB_STRING(x) @#x

#define ALIMDB_PROPERTY(propertyName) +(NSString *)propertyName;

#define ALIMDB_SYNTHESIZE(propertyName)                                         \
+(NSString *)propertyName                                                       \
{                                                                               \
    return ALIMDB_STRING(propertyName);                                         \
}                                                                               \
+(NSString *)ALIMDB_METHOD_NAME(db_, propertyName)              \
{                                                                               \
    return ALIMDB_STRING(propertyName);                                         \
}

#define ALIMDB_PRIMARY_STR_METHOD(str) [NSString stringWithFormat:@"PRIMARY_%@", str]
#define ALIMDB_PRIMARY(popertyName)                                             \
+(void)ALIMDB_METHOD_NAME(PRIMARY,popertyName) {}

#define ALIMDB_AUTO_INCREMENT_STR_METHOD(str) [NSString stringWithFormat:@"AUTOINC_%@", str]
#define ALIMDB_PRIMARY_AUTO_INCREMENT(popertyName)                              \
ALIMDB_PRIMARY(popertyName)                                                     \
+(void)ALIMDB_METHOD_NAME(AUTOINC,popertyName) {}

#define ALIMDB_INDEX_ASC_STR_METHOD(str) [NSString stringWithFormat:@"INDEX_ASC_%@", str]
#define ALIMDB_INDEX_ASC(popertyName)                                               \
+(void)ALIMDB_METHOD_NAME(INDEX_ASC,popertyName) {}

#define ALIMDB_INDEX_DESC_STR_METHOD(str) [NSString stringWithFormat:@"INDEX_DESC_%@", str]
#define ALIMDB_INDEX_DESC(popertyName)                                               \
+(void)ALIMDB_METHOD_NAME(INDEX_DESC,popertyName) {}

#define ALIMDB_UNIQUE_STR_METHOD(str) [NSString stringWithFormat:@"UNIQUE_%@", str]
#define ALIMDB_UNIQUE(popertyName)                                              \
+(void)ALIMDB_METHOD_NAME(UNIQUE,popertyName) {}

#define ALIMDB_VIRTUAL_TABLE_TOKENIZE_METHOD @"alimdb_table_tokenize"
#define ALIMDB_VIRTUAL_TABLE_TOKENIZE(tokenName)                                    \
+(NSString *)alimdb_table_tokenize {                                          \
    return tokenName;                                                \
}

#endif /* AlimDBMacro_h */
