//
//  FMDatabase+FTS5.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/29.
//

#import <FMDB/FMDB.h>
#import "AlimTokenizers.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct sqlite3 sqlite3;

@interface FMDatabase (FTS5)

/// register tokenizer, only fts5 is supported
+ (void)registerTokenizer:(Class<AlimTokenizerProtocol>)tokenizer withKey:(NSString *)key;

- (void)installTokenizerModule;

@end

NS_ASSUME_NONNULL_END
