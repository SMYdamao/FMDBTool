//
//  AlimTokenizers.m
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/29.
//

#import "AlimTokenizers.h"
#import "NSString+Tokenizer.h"
#import <NaturalLanguage/NaturalLanguage.h>

//MARK: - AlimTokenizerName
AlimTokenizerName const AlimTokenTokenizerApple = @"apple";
AlimTokenizerName const AlimTokenTokenizerNatual = @"natual";
AlimTokenizerName const AlimTokenTokenizerSequelize = @"sequelize";

//MARK: - Token
@implementation AlimToken
@synthesize token = _token;
+ (instancetype)token:(const char *)word len:(int)len start:(int)start end:(int)end
{
    AlimToken *tk = [AlimToken new];
    char *temp = (char *)malloc(len + 1);
    memcpy(temp, word, len);
    temp[len] = '\0';
    tk.word = temp;
    tk.start = start;
    tk.len = len;
    tk.end = end;
    return tk;
}

- (NSString *)token
{
    if (!_token) {
        _token = _word ? [NSString stringWithUTF8String:_word] : nil;
    }
    return _token;
}

- (BOOL)isEqual:(id)object
{
    return object != nil && [object isKindOfClass:AlimToken.class] && [(AlimToken *)object hash] == self.hash;
}

- (NSUInteger)hash
{
    return self.token.hash ^ @(_start).hash ^ @(_len).hash ^ @(_end).hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%2i-%2i|%2i|%i|0x%09lx]: %@ ", _start, _end, _len, (int)_colocated, (unsigned long)self.hash, self.token];
}

- (void)dealloc
{
    free(_word);
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    AlimToken *token = [[[self class] allocWithZone:zone] init];
    char *temp = (char *)malloc(_len + 1);
    memcpy(temp, _word, _len);
    temp[_len] = '\0';
    token.word = temp;
    token.start = _start;
    token.end = _end;
    token.len = _len;
    return token;
}

+ (NSArray<AlimToken *> *)sortedTokens:(NSArray<AlimToken *> *)tokens
{
    return [tokens sortedArrayUsingComparator:^NSComparisonResult (AlimToken *tk1, AlimToken *tk2) {
        uint64_t h1 = ((uint64_t)tk1.start) << 32 | ((uint64_t)tk1.end) | ((uint64_t)tk1.len);
        uint64_t h2 = ((uint64_t)tk2.start) << 32 | ((uint64_t)tk2.end) | ((uint64_t)tk2.len);
        return h1 == h2 ? strcmp(tk1.word, tk2.word) : (h1 < h2 ? NSOrderedAscending : NSOrderedDescending);
    }];
}

@end

//MARK: - Tokenizer -
@implementation AlimAppleTokenizer

+ (void)enumerate:(const char *)input mask:(AlimTokenMask)mask usingBlock:(void (^)(AlimToken * _Nonnull, BOOL * _Nonnull))block {
    if (!block) {
        return;
    }
    
    NSString *source = [NSString stringWithUTF8String:input];

    CFRange range = CFRangeMake(0, source.length);
    CFLocaleRef locale = CFLocaleCopyCurrent(); //need CFRelease!

    // create tokenizer
    CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (CFStringRef)source, range, kCFStringTokenizerUnitWordBoundary, locale);

    //token status
    CFStringTokenizerTokenType tokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer, 0);

    BOOL stop = NO;
    NSInteger offset = 0;
    while (tokenType != kCFStringTokenizerTokenNone && !stop) {
        @autoreleasepool {
            // get current range
            range = CFStringTokenizerGetCurrentTokenRange(tokenizer);
            CFIndex maxBufferSize = CFStringGetMaximumSizeForEncoding(range.length, kCFStringEncodingUTF8);
            unichar buffer[maxBufferSize];
            NSUInteger used;
            BOOL success = [source getBytes:buffer maxLength:maxBufferSize usedLength:&used encoding:NSUTF8StringEncoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(range.location, range.length) remainingRange:NULL];
            NSString *byteString = [[NSString alloc] initWithBytes:&buffer
                                                            length:used
                                                          encoding:NSUTF8StringEncoding].lowercaseString;
            if (success) {
                AlimToken *token = [AlimToken token:byteString.UTF8String len:(int)used start:(int)offset end:(int)(offset+used)];
                offset += used;
                // get next token
                tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
                block(token, &stop);
            } else {
                stop = YES;
            }
        }
    }

    // release
    if (locale != NULL) CFRelease(locale);
    if (tokenizer) CFRelease(tokenizer);
}

@end

@implementation AlimNatualTokenizer

+ (void)enumerate:(const char *)input mask:(AlimTokenMask)mask usingBlock:(void (^)(AlimToken * _Nonnull, BOOL * _Nonnull))block {
    if (!block) {
        return;
    }
    if (@available(iOS 12.0, *)) {
        NSString *source = [NSString stringWithUTF8String:input];
        NLTokenizer *tokenizer = [[NLTokenizer alloc] initWithUnit:NLTokenUnitWord];
        tokenizer.string = source;

        NSRange range = NSMakeRange(0, tokenizer.string.length);
        [tokenizer enumerateTokensInRange:range usingBlock:^(NSRange tokenRange, NLTokenizerAttributes flags, BOOL *stop) {
            @autoreleasepool {
                NSString *tk = [tokenizer.string substringWithRange:tokenRange];
                const char *pre = [tokenizer.string substringToIndex:tokenRange.location].cLangString;
                const char *tokenStr = tk.cLangString;
                int start = (int)strlen(pre);
                int len   = (int)strlen(tokenStr);
                int end   = (int)(start + len);
                AlimToken *token = [AlimToken token:tk.lowercaseString.UTF8String len:len start:start end:end];
                block(token, stop);
                if (*stop) return;
            }
        }];
    }
}

@end

@implementation AlimSequelizeTokenizer

+ (void)enumerate:(const char *)input mask:(AlimTokenMask)mask usingBlock:(void (^)(AlimToken * _Nonnull, BOOL * _Nonnull))block {
    if (!block) {
        return;
    }
    
    UNUSED_PARAM(mask);
    if (input == NULL) return;
    u_long nText = strlen(input);
    if (nText == 0) return;

    BOOL stop = NO;
    BOOL isquery = mask & AlimTokenMaskQuery;
    if (isquery) {
        NSString *source = [NSString ocStringWithCString:input];
        if ([source hasPrefix:@" "]) {
            source = [source substringFromIndex:1];
            NSArray *strings = [source componentsSeparatedByString:@" "];
            int loc = 0;
            for (NSString *string in strings) {
                int len = (int)string.length;
                AlimToken *token = [AlimToken token:string.lowercaseString.UTF8String len:len start:loc end:loc + len];
                loc += len;
                block(token, &stop);
                if (stop) {
                    break;
                }
            }
            return;
        }
    }

    uint8_t *buff = (uint8_t *)malloc(nText);
    memcpy(buff, input, nText);

    int idx = 0;
    int length = 0;
    while (idx < nText && !stop) {
        if (buff[idx] < 0xC0) {
            length = 1;
        } else if (buff[idx] < 0xE0) {
            length = 2;
        } else if (buff[idx] < 0xF0) {
            length = 3;
        } else if (buff[idx] < 0xF8) {
            length = 4;
        } else if (buff[idx] < 0xFC) {
            length = 5;
        } else {
            //length = 6;
            NSAssert(NO, @"wrong utf-8 text");
            break;
        }

        uint8_t *word = (uint8_t *)malloc(6);
        memcpy(word, buff + idx, length);
        int wordlen = length;

        // full width to half width
        if (length == 3 && word[0] == 0xEF) {
            unichar uni = ((unichar)(word[0] & 0xF) << 12) | ((unichar)(word[1] & 0x3F) << 6) | (unichar)(word[2] & 0x3F);
            if (uni >= 0xFF01 && uni <= 0xFF5E) {
                word[0] = uni - 0xFEE0;
                word[1] = '\0';
                wordlen = 1;
            } else if (uni >= 0xFFE0 && uni <= 0xFFE5) {
                switch (uni) {
                    case 0xFFE0: word[1] = 0xa2; break;
                    case 0xFFE1: word[1] = 0xa3; break;
                    case 0xFFE2: word[1] = 0xac; break;
                    case 0xFFE3: word[1] = 0xaf; break;
                    case 0xFFE4: word[1] = 0xa6; break;
                    case 0xFFE5: word[1] = 0xa5; break;
                    default: break;
                }
                word[0] = 0xc2;
                word[2] = '\0';
                wordlen = 2;
            } else if (uni == 0x3000) {
                word[0] = 0x20;
                word[1] = '\0';
                wordlen = 1;
            }
        }

        // upper case to lower case
        if (wordlen == 1 && word[0] > 64 && word[0] < 91) {
            word[0] += 32;
        }
        
        NSString *byteString = [[NSString alloc] initWithBytes:&word
                                                        length:wordlen
                                                      encoding:NSUTF8StringEncoding].lowercaseString;
        AlimToken *token = [AlimToken token:byteString.UTF8String len:wordlen start:idx end:idx + length];
        idx += length;
        free(word);
        block(token, &stop);
    }
    free(buff);
    return;
}

@end
