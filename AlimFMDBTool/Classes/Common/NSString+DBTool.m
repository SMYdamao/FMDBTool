//
//  NSString+DBTool.m
//  AlimDBTool
//
//  Created by 生茂元 on 2022/8/12.
//


#import "NSString+DBTool.h"

@implementation NSString (DBTool)

- (BOOL)isNotEmpty{
    return (self!=nil && [self length]>0);
}

@end
