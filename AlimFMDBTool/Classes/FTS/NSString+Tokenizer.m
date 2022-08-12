//
//  NSString+Tokenizer.m
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/30.
//

#import "NSString+Tokenizer.h"

@implementation NSString (Tokenizer)

+ (instancetype)ocStringWithCString:(const char *)cString
{
    NSString *str = [NSString stringWithUTF8String:cString];
    if (str) return str;
    str = [NSString stringWithCString:cString encoding:NSASCIIStringEncoding];
    if (str) return str;
    return @"";
}

- (const char *)cLangString
{
    const char *str = self.UTF8String;
    if (str) return str;
    str = [self cStringUsingEncoding:NSASCIIStringEncoding];
    if (str) return str;
    return "";
}

@end
