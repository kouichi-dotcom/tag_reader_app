//
//  InventoryViewController.m
//  WriteTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "WriteViewController.h"
#import "SettingParameter.h"
#import "TSS_SDK.h"

#define LOG(fmt, ...) NSLog((@"%s [%d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface WriteViewController () <DOTRDelegateProtocol, UITableViewDataSource, UITableViewDelegate, ReaderDelegate>

@property TSS_SDK *reader;
@property (weak, nonatomic) IBOutlet UILabel *labelTriggerState;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property NSInteger powerLevel;
@property NSInteger maxPowerLevel;
@property NSMutableArray *epcList;
@end

@implementation WriteViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _reader = [TSS_SDK shared];
    self.labelTriggerState.text = nil;
#if TARGET_IPHONE_SIMULATOR
    self.epcList = [NSMutableArray arrayWithObjects:@"sample", nil];
#endif
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.reader setDelegate:self];

    // 注意：出力を高くすると意図せず周囲のタグへ書き込みする可能性がありますのでご注意ください。
    // 10dBm程度で試して、うまくいかない場合は少しずつ強くすることをお勧めします
    // 以下は10dBmに設定する場合の例として
    self.powerLevel = self.reader.getRadioPower;
    
    const NSInteger writePowerLevel = 10; // [dBm]
    self.maxPowerLevel = self.reader.getMaxRadioPower;
    if (self.maxPowerLevel < 0) {
        return;
    }
    [self.reader setRadioPower:self.maxPowerLevel - writePowerLevel];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.reader setRadioPower:self.maxPowerLevel - self.powerLevel];   // 元に戻す
    
    [super viewWillDisappear:animated];
}

#pragma mark - DOTRDelegateProtocol
-(void)onDisconnected {
    // 切断時の処理を記述
}

- (void)onTriggerChanged:(BOOL)trigger {
    // トリガを離したら書込みをストップ
    if (trigger) {
        self.labelTriggerState.text = @"ON";
        SettingParameter *settings = [SettingParameter shared];
        [self.reader writeTag:settings.accessParam
                    writeData:settings.writeData
                    singleTag:NO
                     maskFlag:DOTRMaskFlagNone
                      timeout:0];
    }
    else {
        self.labelTriggerState.text = @"OFF";
        [self.reader stop];
    }
}

-(void)onWriteTagData:(NSString*)epc
{
    LOG(@"%@", epc);
    [self insertNewObject:epc];
}

#pragma mark - Action
- (IBAction)btnReset:(id)sender {
    [self.reader clearAccessEPCList];
    [self resetTable:nil];
}

#pragma mark - Table View
- (void)resetTable:(id)sender {
    if (self.epcList) {
        [self.epcList removeAllObjects];
        [self.tableView reloadData];
    }
}

- (void)insertNewObject:(NSString*)data{
    
    if (data == nil) {
        return;
    }
    
    if (!self.epcList) {
        self.epcList = [[NSMutableArray alloc] init];
    }
    
    [self.epcList insertObject:data atIndex:0];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.epcList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    cell.textLabel.text = self.epcList[indexPath.row];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // セル選択時の処理（必要に応じて）
}
@end
