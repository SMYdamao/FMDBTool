//
//  FMResultSet+Result.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/4/15.
//

#import <FMDB/FMDB.h>

NS_ASSUME_NONNULL_BEGIN

@interface FMResultSet (Result)

- (NSDictionary*)safeResultDictionary;

@end

NS_ASSUME_NONNULL_END
