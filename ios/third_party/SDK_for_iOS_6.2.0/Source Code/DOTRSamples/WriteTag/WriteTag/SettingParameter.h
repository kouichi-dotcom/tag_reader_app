//
//  SettingParameter.h
//  WriteTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSS_SDK.h"

@interface SettingParameter : NSObject

@property DOTRTagAccessParameter *accessParam;
@property NSString* writeData;

+ (SettingParameter*)shared;

@end
