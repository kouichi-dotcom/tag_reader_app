//
//  SettingParameter.h
//  InventoryTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSS_SDK.h"

@interface SettingParameter : NSObject

@property BOOL singleTag;
@property DOTRMaskFlag maskFlag;
@property DOTRMemoryBank maskTargetMemory;
@property int maskOffset;
@property int maskLength;
@property NSString* maskData;

+ (SettingParameter*)shared;

@end
