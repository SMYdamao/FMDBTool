//
//  NSString+Tokenizer.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Tokenizer)

/// using utf8 or ascii encoding to generate objc string
+ (instancetype)ocStringWithCString:(const char *)cString;

/// using utf8 or ascii encoding to generate c string
- (const char *)cLangString;

@end

NS_ASSUME_NONNULL_END
