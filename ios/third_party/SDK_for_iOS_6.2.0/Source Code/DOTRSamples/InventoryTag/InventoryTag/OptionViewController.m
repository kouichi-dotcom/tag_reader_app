//
//  OptionViewController.m
//  InventoryTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "OptionViewController.h"
#import "SettingParameter.h"
#import "TSS_SDK.h"

@interface OptionViewController () <UITextFieldDelegate>
@property TSS_SDK *reader;
@property SettingParameter *settings;
@property (weak, nonatomic) IBOutlet UILabel *labelMemoryBank;
@property (weak, nonatomic) IBOutlet UITextField *textFieldOffset;
@property (weak, nonatomic) IBOutlet UITextField *textFieldLength;
@property (weak, nonatomic) IBOutlet UITextField *textFieldMaskData;
@property (weak, nonatomic) IBOutlet UISwitch *swMaskEnable;
@property (weak, nonatomic) IBOutlet UISwitch *swRepeat;
@property (weak, nonatomic) IBOutlet UISwitch *swTime;
@property (weak, nonatomic) IBOutlet UISwitch *swRSSI;
@end

@implementation OptionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _reader   = [TSS_SDK shared];
    _settings = [SettingParameter shared];
    
    _textFieldOffset.delegate   = self;
    _textFieldLength.delegate   = self;
    _textFieldMaskData.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ([self isMaskOn]) {
        self.swMaskEnable.on = YES;
    }
    else {
        self.swMaskEnable.on = NO;
    }
    
    _textFieldOffset.text = [NSString stringWithFormat:@"%ld", (long)self.settings.maskOffset];
    _textFieldLength.text = [NSString stringWithFormat:@"%ld", (long)self.settings.maskLength];
    _textFieldMaskData.text = self.settings.maskData;
    
    switch (self.settings.maskTargetMemory) {
        case DOTRMemoryBankRESERVED:
            _labelMemoryBank.text = @"RESERVED";
            break;
        case DOTRMemoryBankEPC:
            _labelMemoryBank.text = @"EPC";
            break;
        case DOTRMemoryBankTID:
            _labelMemoryBank.text = @"TID";
            break;
        case DOTRMemoryBankUSER:
            _labelMemoryBank.text = @"USER";
            break;
        default:
            _labelMemoryBank.text = @"";
            break;
    }
    
    self.swRepeat.on = [self.reader isNoRepeat];
}

- (void)viewWillDisappear:(BOOL)animated {
    BOOL isOk = [self.reader setTagAccessMask:self.settings.maskTargetMemory
                                   maskOffset:self.settings.maskOffset
                                     maskBits:self.settings.maskLength
                                  maskPattern:self.settings.maskData];
    if (isOk == NO) {
        NSLog(@"Fail: mask setting");
    }
}

#pragma mark - Action
- (IBAction)btnMemoryBank:(id)sender {
    // アラートで選択させる
    UIAlertController * ac =
    [UIAlertController alertControllerWithTitle:@"MemoryBank"
                                        message:@"Message"
                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    [ac addAction:[UIAlertAction actionWithTitle:@"RESERVED"
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                             [self.settings setMaskTargetMemory:DOTRMemoryBankRESERVED];
                                             self.labelMemoryBank.text = @"RESERVED";
                                         }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"EPC"
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                             [self.settings setMaskTargetMemory:DOTRMemoryBankEPC];
                                             self.labelMemoryBank.text = @"EPC";
                                         }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"TID"
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                             [self.settings setMaskTargetMemory:DOTRMemoryBankTID];
                                             self.labelMemoryBank.text = @"TID";
                                         }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"USER"
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                             [self.settings setMaskTargetMemory:DOTRMemoryBankUSER];
                                             self.labelMemoryBank.text = @"USER";
                                         }]];
    
    [self presentViewController:ac animated:YES completion:nil];
}

- (IBAction)onSwitchSettingEnable:(UISwitch *)sender {
    [self setMaskOn:sender.on];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // tagはstoryboardで設定した値
    switch (textField.tag) {
        case 0: // Offset
            self.settings.maskOffset = (int)[textField.text integerValue];
            break;
        case 1: // Length
            self.settings.maskLength = (int)[textField.text integerValue];
            break;
        case 2: // MaskData
            self.settings.maskData = [NSString stringWithString:textField.text];
            break;
        default:
            break;
    }
    
    // キーボード消す
    [textField resignFirstResponder];
    return YES;
}

- (IBAction)onSwitchRepeat:(UISwitch*)sender {
    [self.reader setNoRepeat:sender.on];
}

- (IBAction)onSwitchTimeRSSI:(UISwitch*)sender {
    BOOL isOk = [self.reader setInventoryReportMode:self.swTime.on reportRSSI:self.swRSSI.on];
    if (isOk == NO) {
        NSLog(@"Fail: setInventoryReportMode");
    }
}

#pragma mark - Utility
// スイッチのOn, Offをマスク設定に変換
- (void)setMaskOn:(BOOL)on {
    if (on) {
        self.settings.maskFlag = DOTRMaskFlagSelectMask;
    }
    else {
        self.settings.maskFlag = DOTRMaskFlagNone;
    }
}

- (BOOL)isMaskOn {
    if (self.settings.maskFlag == DOTRMaskFlagSelectMask) {
        return YES;
    }
    return NO;
}
@end
