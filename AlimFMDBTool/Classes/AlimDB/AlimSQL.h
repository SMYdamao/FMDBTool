//
//  AlimSQL.h
//  AlimDataCenter
//
//  Created by 生茂元 on 2022/3/16.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AlimSQLMethod) {
    AlimSQLMethodNone = 0,
    AlimSQLMethodInsert,
    AlimSQLMethodSelect,
    AlimSQLMethodUpdate,
    AlimSQLMethodDelete,
    AlimSQLMethodDrop,
    AlimSQLMethodCustom,
};

typedef NS_ENUM(NSInteger, AlimSQLContent) {
    AlimSQLContentNone = 0,
    AlimSQLContentModel,
    AlimSQLContentOther,
};

@class AlimModel;
@class FMDatabase;
@class AlimCondition;
@class AlimSort;
@class AlimSelectCondition;

NS_ASSUME_NONNULL_BEGIN

#define AlimSQLMaker [AlimSQL maker]

@interface AlimSQL : NSObject

@property (nonatomic, readonly) AlimSQLMethod method;

@property (nonatomic, readonly) NSString *table;

@property (nonatomic, readonly) AlimSQLContent content;

@property (nonatomic, readonly) AlimModel *model;

@property (nonatomic, readonly) NSDictionary *value;

+ (AlimSQL *)maker;

- (NSString *)string;

- (NSArray *)makeInsertValues;

#pragma mark - Method

@property (readonly, nonatomic, copy) AlimSQL *(^zCustomSQLString)(NSString *string);

@property (readonly, nonatomic, copy) AlimSQL *(^zNotReplace)(BOOL notReplace);

@property (readonly, nonatomic, copy) AlimSQL *(^zDistinct)(BOOL distinct);

- (AlimSQL *)zInsert;

- (AlimSQL *)zSelect;

- (AlimSQL *)zUpdate;

- (AlimSQL *)zDelete;

- (AlimSQL *)zDrop;

@property (readonly, nonatomic, copy) AlimSQL *(^zTable)(NSString *);

#pragma mark - Word

- (AlimSQL *)zInto;

- (AlimSQL *)zSet;

- (AlimSQL *)zFrom;

#pragma mark - Model Content

@property (readonly, nonatomic, copy) AlimSQL *(^zModel)(AlimModel *);

@property (readonly, nonatomic, copy) AlimSQL *(^zUpdateModel)(AlimModel *, NSArray<NSString *> *);

@property (readonly, nonatomic, copy) AlimSQL *(^zUpdateString)(NSString * updateString);

#pragma mark - Other Content

- (AlimSQL *)zALL;

@property (readonly, nonatomic, copy) AlimSQL *(^zColumns)(NSArray<NSString *> *);

@property (readonly, nonatomic, copy) AlimSQL *(^zCustomContent)(NSString *string);

@property (readonly, nonatomic, copy) AlimSQL *(^zValue)(NSDictionary *);

@property (readonly, nonatomic, copy) AlimSQL *(^zUpdateValue)(NSDictionary *);

#pragma mark - Condition

- (AlimSQL *)zOneReturn;

@property (readonly, nonatomic, copy) AlimSQL *(^zWhere)(AlimCondition *);

@property (readonly, nonatomic, copy) AlimSQL *(^zLimit)(NSNumber *);

@property (readonly, nonatomic, copy) AlimSQL *(^zOffset)(NSNumber *);

#pragma mark - Sort

@property (readonly, nonatomic, copy) AlimSQL *(^zSort)(AlimSort *);

#pragma mark - SelectCondition

@property (readonly, nonatomic, copy) AlimSQL *(^zSelectCondition)(AlimSelectCondition *);

@end


/*********************   AlimSort   ****************/

#define AlimSortMaker [AlimSort maker]

@interface AlimSort : NSObject

@property (nonatomic, strong) NSMutableDictionary<NSString*,NSArray<NSString*>*> *sorts;

@property (readonly, nonatomic, copy) AlimSort *(^zAsc)(NSArray<NSString *> *);

@property (readonly, nonatomic, copy) AlimSort *(^zDesc)(NSArray<NSString *> *);

+ (AlimSort *)maker;

- (NSString *)makeSort;

@end


/*********************   AlimCondition   ****************/


#define AlimCondMaker [AlimCondition maker]

@interface AlimCondition : NSObject

@property (nonatomic, strong) NSMutableArray<NSString *> *conditions;

+ (AlimCondition *)maker;

- (AlimCondition *)zAnd;

- (AlimCondition *)zOr;

- (AlimCondition *)zOpenParen;

- (AlimCondition *)zCloseParen;

- (AlimCondition *)zResetCondition;

@property (readonly, nonatomic, copy) AlimCondition *(^zIs)(NSString *, id);

@property (readonly, nonatomic, copy) AlimCondition *(^zEqual)(NSString *, id);

@property (readonly, nonatomic, copy) AlimCondition *(^zEquals)(NSString *, NSArray *);

@property (readonly, nonatomic, copy) AlimCondition *(^zNotEqual)(NSString *, id);

@property (readonly, nonatomic, copy) AlimCondition *(^zNotEquals)(NSString *, NSArray *);

@property (readonly, nonatomic, copy) AlimCondition *(^zIsNull)(NSString *);

@property (readonly, nonatomic, copy) AlimCondition *(^zNotNull)(NSString *);

@property (readonly, nonatomic, copy) AlimCondition *(^zLike)(NSString *, id);

@property (readonly, nonatomic, copy) AlimCondition *(^zIn)(NSString *column, NSArray *values);

@property (readonly, nonatomic, copy) AlimCondition *(^zNotIn)(NSString *column, NSArray *values);

@property (readonly, nonatomic, copy) AlimCondition *(^zLess)(NSString *, id);

@property (readonly, nonatomic, copy) AlimCondition *(^zLessEqual)(NSString *, id);

@property (readonly, nonatomic, copy) AlimCondition *(^zGreater)(NSString *, id);

@property (readonly, nonatomic, copy) AlimCondition *(^zGreaterEqual)(NSString *, id);

@property (readonly, nonatomic, copy) AlimCondition *(^zMatch)(NSString *, id);

@property (readonly, nonatomic, copy) AlimCondition *(^zMax)(NSString *column, NSString *table);

@property (readonly, nonatomic, copy) AlimCondition *(^zMin)(NSString *column, NSString *table);

@property (readonly, nonatomic, copy) AlimCondition *(^zCondition)(NSString *column, NSString *center, id value);

- (NSString *)makeConditions;

@end

/*********************   AlimSelectCondition   ****************/

#define AlimSelectMaker [AlimSelectCondition maker]

@interface AlimSelectCondition : NSObject

@property (nonatomic, strong) NSMutableArray<NSString *> *conditions;

+ (AlimSelectCondition *)maker;

@property (readonly, nonatomic, copy) AlimSelectCondition *(^zMax)(NSString * column);

@property (readonly, nonatomic, copy) AlimSelectCondition *(^zMaxDistinct)(NSString * column, BOOL distinct);

@property (readonly, nonatomic, copy) AlimSelectCondition *(^zMin)(NSString * column);

@property (readonly, nonatomic, copy) AlimSelectCondition *(^zMinDistinct)(NSString * column, BOOL distinct);

@property (readonly, nonatomic, copy) AlimSelectCondition *(^zCount)(void);

@property (readonly, nonatomic, copy) AlimSelectCondition *(^zCountColumn)(NSString *column, BOOL distinct);

- (NSString *)makeConditions;

@end

NS_ASSUME_NONNULL_END
