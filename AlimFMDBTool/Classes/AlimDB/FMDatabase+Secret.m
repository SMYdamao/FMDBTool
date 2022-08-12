//
//  FMDatabase+Secret.m
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/15.
//

#import "FMDatabase+Secret.h"
#import <objc/runtime.h>

static inline NSArray<NSString *> *encryptSettings() {
    NSMutableArray<NSString *> *list = [NSMutableArray array];
    [list addObject:@"PRAGMA cipher_page_size = 1024;"];
    [list addObject:@"PRAGMA kdf_iter = 1000;"];
    [list addObject:@"PRAGMA cipher_hmac_algorithm = HMAC_SHA256;"];
    [list addObject:@"PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA256;"];
    return [list copy];
}

@implementation FMDatabase (Secret)

+ (void)load {
    Method orOpen = class_getInstanceMethod([FMDatabase class], @selector(open));
    Method swOpen = class_getInstanceMethod([FMDatabase class], @selector(al_open));
    method_exchangeImplementations(orOpen, swOpen);
    Method orOpenFlag = class_getInstanceMethod([FMDatabase class], @selector(openWithFlags:vfs:));
    Method swOpenFlag = class_getInstanceMethod([FMDatabase class], @selector(al_openWithFlags:vfs:));
    method_exchangeImplementations(orOpenFlag, swOpenFlag);
}

- (BOOL)al_open {
    if (self.sqliteHandle) {
        return YES;
    }
    BOOL result = [self al_open];
    if (result && self.dbKey != nil) {
        encryptConfig(self);
    }
    return result;
}

- (BOOL)al_openWithFlags:(int)flags vfs:(NSString *)vfsName {
    if (self.sqliteHandle) {
        return YES;
    }
    BOOL result = [self al_openWithFlags:flags vfs:vfsName];
    if (result && self.dbKey != nil) {
        encryptConfig(self);
    }
    return result;
}

static inline void encryptConfig(FMDatabase *db) {
    NSString *key = [[NSString alloc] initWithData:db.dbKey encoding:NSUTF8StringEncoding];
    FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"PRAGMA key = '%@';", key]];
    [result close];
    NSArray<NSString *> *settings = encryptSettings();
    for (NSString *sql in settings) {
        result = [db executeQuery:sql];
        [result close];
    }
}

#pragma mark - Property

- (NSData *)dbKey {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setDbKey:(NSData *)dbKey {
    objc_setAssociatedObject(self, @selector(dbKey), dbKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)identifier {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setIdentifier:(NSString *)identifier {
    objc_setAssociatedObject(self, @selector(identifier), identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
