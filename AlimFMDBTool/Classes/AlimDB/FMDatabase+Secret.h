//
//  FMDatabase+Secret.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/15.
//

#import <FMDB/FMDB.h>

NS_ASSUME_NONNULL_BEGIN

@interface FMDatabase (Secret)

@property (nonatomic, strong) NSData *dbKey;

@property (nonatomic, copy) NSString *identifier;

@end

NS_ASSUME_NONNULL_END
