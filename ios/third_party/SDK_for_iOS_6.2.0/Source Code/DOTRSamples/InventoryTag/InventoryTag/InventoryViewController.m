//
//  InventoryViewController.m
//  InventoryTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "InventoryViewController.h"
#import "SettingParameter.h"
#import "TSS_SDK.h"

#define LOG(fmt, ...) NSLog((@"%s [%d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface InventoryViewController () <DOTRDelegateProtocol, UITableViewDataSource, UITableViewDelegate, ReaderDelegate>

@property TSS_SDK *reader;
@property (weak, nonatomic) IBOutlet UILabel *labelTriggerState;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property NSMutableArray *dataList;
@end

@implementation InventoryViewController

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

- (void)onTriggerChanged:(BOOL)trigger {
    if (trigger) {
        self.labelTriggerState.text = @"ON";
        SettingParameter *settings = [SettingParameter shared];
        [self.reader inventoryTag:settings.singleTag
                         maskFlag:settings.maskFlag
                          timeout:0];
    }
    else {
        self.labelTriggerState.text = @"OFF";
        [self.reader stop];
    }
}

-(void)onInventoryEPC:(NSString*)epc {
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
    NSString *cellItem = self.dataList[indexPath.row];
    //    cell.textLabel.text = [object description];
    
    // 文字列形式：[tag id],[TIME=xxx],[RSSI=]　TIME, RSSIは設定によっては無し
    NSMutableArray *devidedStr = [NSMutableArray arrayWithArray:[cellItem componentsSeparatedByString:@","]];
    NSString *mainText = devidedStr[0];
    cell.textLabel.text = mainText;
    
    // TIMEがある場合はsubtitleセット前に日時の文字列に変換してすり替え
    NSTimeInterval __block interval = -1.0;
    NSInteger __block indexOfTime = 0;
    // TIME=xxx は NSTimeInterval(double)の値
    [devidedStr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
        if ([obj hasPrefix:@"TIME="]) {
            NSString *valueStr = [obj substringFromIndex:5];    // "TIME="を除く
            interval = [valueStr doubleValue];
            indexOfTime = (NSInteger)idx;
            *stop = YES;
        }
    }];
    if (interval != -1.0) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
#if 0
        // （例）subtitleの TIME= をms -> 日時にすり替えて表示
        devidedStr[indexOfTime] = [NSString stringWithFormat:@"%@", date];
#else
        LOG(@"%@ %@", devidedStr[indexOfTime], date);
#endif
    }
    
    if ([devidedStr count] == 3) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", devidedStr[1], devidedStr[2]];
    }
    else if ([devidedStr count] == 2) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", devidedStr[1]];
    }
    else {
        cell.detailTextLabel.text = nil;
    }
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
