//
//  FMResultSet+Result.m
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/4/15.
//

#import "FMResultSet+Result.h"

#ifdef SQLITE_HAS_CODEC
#import "sqlite3.h"
#else
#import <sqlite3.h>
#endif

@implementation FMResultSet (Result)

- (NSDictionary*)safeResultDictionary {
    
    NSUInteger num_cols = (NSUInteger)sqlite3_data_count([self.statement statement]);
    
    if (num_cols > 0) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:num_cols];
        
        int columnCount = sqlite3_column_count([self.statement statement]);
        
        int columnIdx = 0;
        for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
            
            NSString *columnName = [NSString stringWithUTF8String:sqlite3_column_name([self.statement statement], columnIdx)];
            id objectValue = [self objectForColumnIndex:columnIdx];
            if (![objectValue isKindOfClass:[NSNull class]]) {
                [dict setObject:objectValue forKey:columnName];
            }
        }
        
        return dict;
    }
    else {
//        LOG_E(kDB, @"Warning: There seem to be no columns in this set.");
    }
    
    return nil;
}

@end
