//
//  SettingParameter.m
//  WriteTag
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
        _accessParam = [[DOTRTagAccessParameter alloc] initWithParameter:0  // 書き込みデータ長さを word 単位で指定(1word = 2byte)
                                                              memoryBank:DOTRMemoryBankEPC
                                                              wordOffset:2  // EPC領域は先頭2word分は書き込み不可 (CRC領域:1word + PC領域:1word)
                                                                password:0];
        _writeData = @"";
    }
    
    return self;
}

@end
