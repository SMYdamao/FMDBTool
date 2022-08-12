//
//  AlimModel.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AlimModel : NSObject <NSCoding, NSCopying>

#pragma mark - Model

+ (NSString *)jsonValueToString:(id)json;

+ (id)stringToJSON:(NSString*)string;

+ (uint64_t)convertSecToMSec:(NSTimeInterval)sec;

+ (NSTimeInterval)convertMSecToSec:(NSNumber *)mSec;

#pragma mark - Database

+ (NSArray<NSString *> *)columnInfoForTable:(NSString *)table addColumnType:(BOOL)addColumnType;

/// return 'index ASC' or 'index DESC' list
+ (NSArray<NSString *> *)indexesForTable:(NSString *)table;

+ (NSString *)virtualTableTokenize:(NSString *)table;

- (NSDictionary *)columnsAndValues;

@end

NS_ASSUME_NONNULL_END
