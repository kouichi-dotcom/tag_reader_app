//
//  PowerViewController.m
//  ConfigReader
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "PowerViewController.h"
#import "TSS_SDK.h"

@interface PowerViewController ()
@property TSS_SDK *reader;
@property (weak, nonatomic) IBOutlet UISlider *sliderRadioPower;
@property (weak, nonatomic) IBOutlet UISlider *sliderAutoOffTime;
@property (weak, nonatomic) IBOutlet UILabel *labelRadioPowerMax;
@property (weak, nonatomic) IBOutlet UILabel *labelRadioPowerCurrent;
@property (weak, nonatomic) IBOutlet UILabel *labelRadioPower;
@property (weak, nonatomic) IBOutlet UILabel *labelAutoOffTime;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoOffWriteFlash;
@end

@implementation PowerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _reader = [TSS_SDK shared];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
//    [self.reader setDelegate:self];

    NSInteger maxRadioPower = [self.reader getMaxRadioPower];
    self.sliderRadioPower.maximumValue = maxRadioPower;
    self.labelRadioPowerMax.text = [NSString stringWithFormat:@"%ld dBm", (long)maxRadioPower];
    
    NSInteger currentRadioPower = [self.reader getRadioPower];
    self.labelRadioPowerCurrent.text = [NSString stringWithFormat:@"%ld dBm", (long)currentRadioPower];

    NSInteger currentDecreasedDecibel = maxRadioPower - currentRadioPower;
    self.sliderRadioPower.value = (float)currentDecreasedDecibel;
    self.labelRadioPower.text = [NSString stringWithFormat:@"%ld dBm", (long)currentDecreasedDecibel * -1];
    
    NSInteger powerOffDelay = [self.reader getPowerOffDelay];
    self.sliderAutoOffTime.value = (float)powerOffDelay;
    self.labelAutoOffTime.text = [NSString stringWithFormat:@"%ld sec", (long)powerOffDelay];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 * ※電波強度変更時のご注意※
 * setRadioPowerメソッドでは、DOTRリーダーの電波強度を最小0dBmから
 * 設定可能ですが、これは必ずしも0dBmでの正常な読み取りや書き込み
 * 動作を保証するものではありません。
 *
 * DOTRリーダーのハードウェア仕様上、読み取り、書き込みの正常動作を
 * 保証する電波強度は、[最大値 - 20dBm]以上となっています。
 *
 * 電波強度を20dBmを超えて減衰させる場合、機器やタグ、周辺環境に
 * よって、正常に読み取り、書き込みの電波が照射できない可能性が
 * あることをご了承ください。
 *
 * リファレンスマニュアルのsetRadioPowerメソッドに関する説明も
 * 併せてご確認ください。
 */
- (IBAction)onRadioPowerChanged:(UISlider *)sender {
    NSInteger decreaseDecibell = (NSInteger)sender.value;
    [self.reader setRadioPower:decreaseDecibell];
    self.labelRadioPower.text = [NSString stringWithFormat:@"%ld dBm", (long)decreaseDecibell * -1];
    
    NSInteger currentRadioPower = [self.reader getRadioPower];
    self.labelRadioPowerCurrent.text = [NSString stringWithFormat:@"%ld dBm", (long)currentRadioPower];
}

- (IBAction)onAutoOffTimeChanged:(UISlider *)sender {
    NSInteger time = (NSInteger)sender.value;
    self.labelAutoOffTime.text = [NSString stringWithFormat:@"%ld sec", (long)time];

    [self.reader setPowerOffDelay:time writeFlashMemory:self.switchAutoOffWriteFlash.on];
}

- (IBAction)btnTestStart:(id)sender {
    // 動作テストのためInventory実行
    [self.reader inventoryTag:NO maskFlag:DOTRMaskFlagNone timeout:0];
}
- (IBAction)btnTestStop:(id)sender {
    [self.reader stop];
}
@end
