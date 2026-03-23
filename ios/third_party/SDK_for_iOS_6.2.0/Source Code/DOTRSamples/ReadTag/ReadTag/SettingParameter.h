//
//  SettingParameter.h
//  ReadTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DOTRTagAccessParameter;

@interface SettingParameter : NSObject

@property DOTRTagAccessParameter *accessParam;

+ (SettingParameter*)shared;

@end
