//
//  SettingParameter.m
//  InventoryTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "SettingParameter.h"

@implementation SettingParameter

+ (SettingParameter*)shared;
{
    static dispatch_once_t pred;
    static SettingParameter *obj = nil;
    dispatch_once(&pred,^{
        obj = [[SettingParameter alloc] init];
    });
    
    return obj;
}

- (id)init
{
    self = [super init];
    
    if (self) {
        _maskFlag = DOTRMaskFlagNone;
        _maskData = @"";
        _maskTargetMemory = DOTRMemoryBankEPC;
    }
    
    return self;
}

@end
