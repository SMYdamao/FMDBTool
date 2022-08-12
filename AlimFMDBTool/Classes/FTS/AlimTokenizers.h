//
//  AlimTokenizers.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/29.
//

#import <Foundation/Foundation.h>

//MARK: - defines
#ifndef   UNUSED_PARAM
#define   UNUSED_PARAM(v) (void)(v)
#endif

#ifndef TOKEN_PINYIN_MAX_LENGTH
#define TOKEN_PINYIN_MAX_LENGTH 15
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS (NSUInteger, AlimTokenMask) {
    AlimTokenMaskPinyin       = 1 << 0, ///< placeholder, it will be executed without setting
    AlimTokenMaskAbbreviation = 1 << 1, ///< pinyin abbreviation. not recommended, many invalid results will be found

    AlimTokenMaskAll          = 0xFFFFFF,
    AlimTokenMaskQuery        = 1 << 24, ///< FTS5_TOKENIZE_QUERY, only for query
};

//MARK: - AlimTokenizerName
typedef NSString *AlimTokenizerName NS_EXTENSIBLE_STRING_ENUM;

FOUNDATION_EXPORT AlimTokenizerName const AlimTokenTokenizerApple;
FOUNDATION_EXPORT AlimTokenizerName const AlimTokenTokenizerNatual;
FOUNDATION_EXPORT AlimTokenizerName const AlimTokenTokenizerSequelize;

@interface AlimToken : NSObject <NSCopying>
@property (nonatomic, assign) char *word;
@property (nonatomic, assign) int len;
@property (nonatomic, assign) int start;
@property (nonatomic, assign) int end;
@property (nonatomic, assign) int colocated; ///< -1:full width, 0:original, 1:full pinyin, 2:abbreviation, 3:syllable

@property (nonatomic, copy, readonly) NSString *token;

+ (instancetype)token:(const char *)word len:(int)len start:(int)start end:(int)end;

@end

@protocol AlimTokenizerProtocol <NSObject>

+ (void)enumerate:(const char *)input mask:(AlimTokenMask)mask usingBlock:(void(^)(AlimToken *token, BOOL *stop))block;

@end

@interface AlimAppleTokenizer : NSObject <AlimTokenizerProtocol>

@end

@interface AlimNatualTokenizer : NSObject <AlimTokenizerProtocol>

@end

@interface AlimSequelizeTokenizer : NSObject <AlimTokenizerProtocol>

@end

NS_ASSUME_NONNULL_END
