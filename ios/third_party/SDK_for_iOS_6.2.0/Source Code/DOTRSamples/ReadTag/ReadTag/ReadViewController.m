//
//  InventoryViewController.m
//  ReadTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "ReadViewController.h"
#import "SettingParameter.h"
#import "TSS_SDK.h"

#define LOG(fmt, ...) NSLog((@"%s [%d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface ReadViewController () <DOTRDelegateProtocol, UITableViewDataSource, UITableViewDelegate, ReaderDelegate>

@property TSS_SDK *reader;
@property (weak, nonatomic) IBOutlet UILabel *labelTriggerState;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property NSMutableArray *dataList;
@property NSMutableArray *epcList;
@end

@implementation ReadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _reader = [TSS_SDK shared];
    self.labelTriggerState.text = nil;
#if TARGET_IPHONE_SIMULATOR
    self.dataList = [NSMutableArray arrayWithObjects:@"sample", nil];
    self.epcList = [NSMutableArray arrayWithObjects:@"sample", nil];
#endif
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.reader setDelegate:self];
}

#pragma mark - DOTRDelegateProtocol
-(void)onDisconnected {
    // 切断時の処理を記述
}

- (void)onTriggerChanged:(BOOL)trigger {
    if (trigger) {
        self.labelTriggerState.text = @"ON";
        SettingParameter *settings = [SettingParameter shared];
        [self.reader readTag:settings.accessParam
                   singleTag:NO
                    maskFlag:DOTRMaskFlagNone
                     timeout:0];
    }
    else {
        self.labelTriggerState.text = @"OFF";
        [self.reader stop];
    }
}

- (void)onReadTagData: (NSString *)data epc: (NSString *)epc {
    LOG(@"data:%@ epc:%@", data, epc);
    [self insertNewObject:data epc:epc];
}

#pragma mark - Action
- (IBAction)btnReset:(id)sender {
    [self.reader clearAccessEPCList];
    [self resetTable:nil];
}

#pragma mark - Table View
- (void)resetTable:(id)sender {
    if (self.dataList) {
        [self.dataList removeAllObjects];
        [self.epcList removeAllObjects];
        [self.tableView reloadData];
    }
}

- (void)insertNewObject:(NSString*)data epc:(NSString*)epc{
    
    if (!self.dataList) {
        self.dataList = [[NSMutableArray alloc] init];
    }
    if (!self.epcList) {
        self.epcList = [[NSMutableArray alloc] init];
    }

    if (data) {
        [self.dataList insertObject:data atIndex:0];
    }
    // errorの場合 -> data無し、epcにエラー
    else if (data == nil
             && ([epc containsString:@"err"] || [epc containsString:@"ERR"])) {
        [self.dataList insertObject:@"(err)" atIndex:0];
    }
    else {
        ;
    }

    if (epc) {
        [self.epcList insertObject:epc atIndex:0];
    }
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    cell.textLabel.text = self.dataList[indexPath.row];
    if ([self.epcList count] > 0) {
        cell.detailTextLabel.text = self.epcList[indexPath.row];
    }
    else {
        cell.detailTextLabel.text = @"";
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // セル選択時の処理（必要に応じて）
}
@end
