//
//  FMDatabase+FTS5.m
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/29.
//

#import "FMDatabase+FTS5.h"
#import "NSString+Tokenizer.h"

#ifdef SQLITE_HAS_CODEC
#import "sqlite3.h"
#else
#import <sqlite3.h>
#endif

//MARK: - FTS5
static fts5_api * fts5_api_from_db(sqlite3 *db)
{
    fts5_api *pRet = 0;
    sqlite3_stmt *pStmt = 0;

    if (SQLITE_OK == sqlite3_prepare(db, "SELECT fts5(?1)", -1, &pStmt, 0) ) {
#ifdef SQLITE_HAS_CODEC
        sqlite3_bind_pointer(pStmt, 1, (void *)&pRet, "fts5_api_ptr", NULL);
        sqlite3_step(pStmt);
#else
        if (@available(iOS 12.0, *)) {
            sqlite3_bind_pointer(pStmt, 1, (void *)&pRet, "fts5_api_ptr", NULL);
            sqlite3_step(pStmt);
        }
#endif
    }
    sqlite3_finalize(pStmt);
    return pRet;
}

typedef struct Fts5AlimTokenizer Fts5AlimTokenizer;
struct Fts5AlimTokenizer {
    char locale[16];
    uint64_t mask;
    void *clazz;
};

static void alim_fts5_xDelete(Fts5Tokenizer *p)
{
    sqlite3_free(p);
}

static int alim_fts5_xCreate(
    void *pUnused,
    const char **azArg, int nArg,
    Fts5Tokenizer **ppOut
    )
{
    Fts5AlimTokenizer *tok = sqlite3_malloc(sizeof(Fts5AlimTokenizer));
    if (!tok) return SQLITE_NOMEM;

    memset(tok->locale, 0x0, 16);
    tok->mask = 0;

    for (int i = 0; i < MIN(2, nArg); i++) {
        const char *arg = azArg[i];
        uint32_t mask = (uint32_t)atoll(arg);
        if (mask > 0) {
            tok->mask = mask;
        } else {
            strncpy(tok->locale, arg, 15);
        }
    }

    tok->clazz = pUnused;
    *ppOut = (Fts5Tokenizer *)tok;
    return SQLITE_OK;
}

static int alim_fts5_xTokenize(
    Fts5Tokenizer *pTokenizer,
    void *pCtx,
    int iUnused,
    const char *pText, int nText,
    int (*xToken)(void *, int, const char *, int nToken, int iStart, int iEnd)
    )
{
    UNUSED_PARAM(iUnused);
    UNUSED_PARAM(pText);
    if (pText == 0) return SQLITE_OK;

    __block int rc = SQLITE_OK;
    Fts5AlimTokenizer *tok = (Fts5AlimTokenizer *)pTokenizer;
    Class<AlimTokenizerProtocol> clazz = (__bridge Class)(tok->clazz);
    if (!clazz || ![clazz conformsToProtocol:@protocol(AlimTokenizerProtocol)]) {
        return SQLITE_ERROR;
    }
    uint64_t mask = tok->mask;
    if (iUnused & FTS5_TOKENIZE_QUERY) {
        mask = mask | AlimTokenMaskQuery;
    } else if (iUnused & FTS5_TOKENIZE_DOCUMENT) {
        mask = mask & ~AlimTokenMaskQuery;
    }
    
    [clazz enumerate:pText mask:(AlimTokenMask)mask usingBlock:^(AlimToken *tk, BOOL *stop) {
        rc = xToken(pCtx, tk.colocated, tk.word, tk.len, tk.start, tk.end);
        if (rc != SQLITE_OK) *stop = YES;
    }];

    if (rc == SQLITE_DONE) rc = SQLITE_OK;
    return rc;
}

static NSMutableDictionary *tokenizersMap;

@implementation FMDatabase (FTS5)

- (sqlite3 *)db {
    sqlite3 *_db = [self sqliteHandle];
    NSAssert(_db != nil, @"get fmdb's db failed");
    return _db;
}

+ (void)registerTokenizer:(Class<AlimTokenizerProtocol>)tokenizer withKey:(NSString *)key
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tokenizersMap = [NSMutableDictionary dictionary];
    });
    [tokenizersMap setObject:tokenizer forKey:key];
}

- (void)installTokenizerModule
{
    sqlite3 *db = self.db;
    
    if (!db) return;
    if (tokenizersMap.count == 0) return;
    
    fts5_api *pApi = fts5_api_from_db(db);
    if (!pApi) {
        NSAssert(NO, @"fts5 is not supported");
//        LOG_E(kDB, @"fts5 is not supported");
        return;
    }

    [tokenizersMap enumerateKeysAndObjectsUsingBlock:^(NSString *name, Class<AlimTokenizerProtocol> enumerator, BOOL *stop) {
        fts5_tokenizer *tokenizer;
        tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
        tokenizer->xCreate = alim_fts5_xCreate;
        tokenizer->xDelete = alim_fts5_xDelete;
        tokenizer->xTokenize = alim_fts5_xTokenize;

        pApi->xCreateTokenizer(pApi, name.cLangString, (__bridge void *)enumerator, tokenizer, NULL);
    }];
}

@end
