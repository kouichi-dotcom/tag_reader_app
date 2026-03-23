//
//  BuzzerViewController.m
//  ConfigReader
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "BuzzerViewController.h"
#import "TSS_SDK.h"

@interface BuzzerViewController() <DOTRDelegateProtocol, ReaderDelegate>
@property TSS_SDK *reader;
@property BOOL isReady;
@property (weak, nonatomic) IBOutlet UISlider *sliderBattery;
@property (weak, nonatomic) IBOutlet UILabel *labelBattery;
@property (weak, nonatomic) IBOutlet UILabel *labelBuzzer;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentBuzzer;
@property (weak, nonatomic) IBOutlet UISwitch *switchSaveFlash;
@property (weak, nonatomic) IBOutlet UILabel *labelFirmware;
@end

@implementation BuzzerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _reader = [TSS_SDK shared];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.reader setDelegate:self];
    self.isReady = self.reader.isCentralManagerReady;
    
    [self refleshBatteryValue];
    [self refleshBuzzerValue];
    
    self.labelFirmware.text = [self.reader getFirmwareVersion];
}

#pragma mark - Action
- (void)refleshBatteryValue
{
    NSInteger batt = [self.reader getBatteryLevel];
    self.sliderBattery.value = (float)batt;
    self.labelBattery.text = [NSString stringWithFormat:@"%ld", (long)batt];
}

- (void)refleshBuzzerValue
{
    DOTRBuzzerVolume buzz = [self.reader getBuzzerVolume];
    
    if (buzz == DOTRBuzzerVolumeUnknown) {
        self.labelBuzzer.text = @"unknown";
    }
    else {
        self.labelBuzzer.text = @"";
    }
    
    self.segmentBuzzer.selectedSegmentIndex = buzz; // Unknown:-1の場合はそのまま設定することでのUISegmentedConrol非選択状態
}

- (IBAction)selectedBuzzer:(UISegmentedControl *)sender
{
    DOTRBuzzerVolume vol = [self.segmentBuzzer selectedSegmentIndex];
    BOOL save = self.switchSaveFlash.isOn;
    [self.reader setBuzzerVolume:vol writeFlashMemory:save];

    // 設定した値が反映されたことの確認
    [self refleshBuzzerValue];
}


#pragma mark - DOTRDelegateProtocol
- (void)didUpdateCentralManagerState
{
    self.isReady = self.reader.isCentralManagerReady;
}

- (void)onDisconnected
{
    // 切断時の処理
}

- (void)onLinkLost
{
    // 通信断通知時の処理
}

@end
