//
//  SettingParameter.m
//  ReadTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "TSS_SDK.h"
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
        _accessParam = [[DOTRTagAccessParameter alloc] initWithParameter:1
                                                              memoryBank:DOTRMemoryBankEPC
                                                              wordOffset:0
                                                                password:0];
    }
    
    return self;
}

@end
