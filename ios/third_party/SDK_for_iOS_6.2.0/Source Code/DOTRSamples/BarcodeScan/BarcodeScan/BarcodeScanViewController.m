//
//  BarcodeScanViewController.m
//  BarcodeScan
//
//  Copyright (C)  2017 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import <TSS_SDK.h>
#import "BarcodeScanViewController.h"

#define LOG(fmt, ...) NSLog((@"%s [%d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface BarcodeScanViewController () <DOTRDelegateProtocol, UITableViewDataSource, UITableViewDelegate, ReaderDelegate>
@property TSS_SDK *reader;
@property (weak, nonatomic) IBOutlet UILabel *labelTriggerState;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property NSMutableArray *dataList;
@end

@implementation BarcodeScanViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _reader = [TSS_SDK shared];
    self.labelTriggerState.text = nil;
#if TARGET_IPHONE_SIMULATOR
    self.dataList = [NSMutableArray arrayWithObjects:@"sample", nil];
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

-(void)onBarcodeScanTriggerChanged:(BOOL)trigger {
    if (trigger) {
        self.labelTriggerState.text = @"ON";
        [self.reader startBarcodeScan];
    }
    else {
        self.labelTriggerState.text = @"OFF";
        [self.reader stopBarcodeScan];
    }
}

- (void)onBarcodeScan:(NSString *)code {
    LOG(@"%@", code);
    [self insertNewObject:code];
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
        [self.tableView reloadData];
    }
}

- (void)insertNewObject:(NSString*)data {
    if (!self.dataList) {
        self.dataList = [[NSMutableArray alloc] init];
    }
    
    [self.dataList insertObject:data atIndex:0];
    
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
#if TARGET_IPHONE_SIMULATOR
    cell.textLabel.text = self.dataList[indexPath.row];
#else
    cell.textLabel.text = self.dataList[indexPath.row];
#endif  // TARGET_IPHONE_SIMULATOR
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // セル選択時の処理（必要に応じて）
}
@end

