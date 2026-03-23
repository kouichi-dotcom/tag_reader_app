//
//  OptionViewController.m
//  ReadTag
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
@property (weak, nonatomic) IBOutlet UISwitch *swRepeat;
@end

@implementation OptionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _reader   = [TSS_SDK shared];
    _settings = [SettingParameter shared];
    
    _textFieldOffset.delegate   = self;
    _textFieldLength.delegate   = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _textFieldOffset.text = [NSString stringWithFormat:@"%ld", (long)self.settings.accessParam.wordOffset];
    _textFieldLength.text = [NSString stringWithFormat:@"%ld", (long)self.settings.accessParam.wordCount];
    
    switch (self.settings.accessParam.memoryBank) {
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
                                             [self.settings.accessParam setMemoryBank:DOTRMemoryBankRESERVED];
                                             self.labelMemoryBank.text = @"RESERVED";
                                         }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"EPC"
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                             [self.settings.accessParam setMemoryBank:DOTRMemoryBankEPC];
                                             self.labelMemoryBank.text = @"EPC";
                                         }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"TID"
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                             [self.settings.accessParam setMemoryBank:DOTRMemoryBankTID];
                                             self.labelMemoryBank.text = @"TID";
                                         }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"USER"
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                             [self.settings.accessParam setMemoryBank:DOTRMemoryBankUSER];
                                             self.labelMemoryBank.text = @"USER";
                                         }]];
    
    [self presentViewController:ac animated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // tagはstoryboardで設定した値
    switch (textField.tag) {
        case 0: // Offset
            self.settings.accessParam.wordOffset = (int)[textField.text integerValue];
            break;
        case 1: // Length
            self.settings.accessParam.wordCount = (int)[textField.text integerValue];
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
@end
