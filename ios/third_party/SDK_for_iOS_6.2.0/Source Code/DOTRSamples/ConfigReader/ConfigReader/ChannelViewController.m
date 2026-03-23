//
//  ChannelViewController.m
//  ConfigReader
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

// --------------------------------------------------
// DOTRChannel は DOTRChannel38 まで定義していますが、
// 本画面のコーディング例としては DOTRChannel05 ~ DOTRChannel25 に絞って扱います
// --------------------------------------------------

#import "ChannelViewController.h"
#import "TSS_SDK.h"

@interface ChannelViewController ()
@property TSS_SDK *reader;
@property (strong, nonatomic) IBOutletCollection(UISwitch) NSArray *swichChannels;
@property (weak, nonatomic) IBOutlet UIButton *buttonSet;
@end

@implementation ChannelViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _reader = [TSS_SDK shared];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 通知に対応した処理を行う場合はDelegateを設定し、対応するメソッドを実装
//    [self.reader setDelegate:self];

    // 現在の設定値を取得
    NSArray *channels = [self.reader getRadioChannel];
    NSLog(@"channels:%@", channels);

    // 画面のSWへON, OFF状態を反映
    for (UISwitch *sw in self.swichChannels) {
        sw.on = NO;
        for (NSNumber *channel in channels) {
            if ([channel isEqualToNumber:[NSNumber numberWithInteger:sw.tag]]) {
                sw.on = YES;
                break;
            }
        }
    }
    
    [self setSetButtonEnable];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onSwitchChanged:(UISwitch *)sender {
    [self setSetButtonEnable];
}

- (IBAction)onSetChannel:(id)sender {
    // ONされたChを渡す（Storyboard上で各SWのtagをDOTRChannelに対応させている）
    NSMutableArray *channelList = [NSMutableArray array];
    [self.swichChannels enumerateObjectsUsingBlock:^(UISwitch *sw, NSUInteger idx, BOOL *stop) {
        NSLog(@"%lu: tag:%ld val:%ld", (unsigned long)idx, (long)sw.tag,(long)sw.on);
        if (sw.on) {
            [channelList addObject:[NSNumber numberWithInteger:sw.tag]];
        }
    }];
    
    BOOL ret = [self.reader setRadioChannel:channelList];
    NSLog(@"ret:%ld channelList:%@", (long)ret, channelList);
}

// "全部OFF"の場合はSet不可とする
- (void)setSetButtonEnable {
    BOOL existON = NO;
    
    for (UISwitch *sw in self.swichChannels) {
        if (sw.on) {
            existON = YES;
            break;
        }
    }

    self.buttonSet.enabled = existON;
}
@end
