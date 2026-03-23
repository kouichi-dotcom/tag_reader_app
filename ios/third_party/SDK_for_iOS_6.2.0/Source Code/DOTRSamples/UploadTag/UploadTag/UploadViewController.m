//
//  UploadViewController.m
//  UploadTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "UploadViewController.h"
#import "TSS_SDK.h"

#define LOG(fmt, ...) NSLog((@"%s [%d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);


static NSString *kTAG_COUNT_TEXT_NONE = @"-";

@interface UploadViewController () <DOTRDelegateProtocol, UITableViewDataSource, UITableViewDelegate, ReaderDelegate>

@property TSS_SDK *reader;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *labelTagCount;
@property NSMutableArray *dataList;
@end

@implementation UploadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _reader = [TSS_SDK shared];
#if TARGET_IPHONE_SIMULATOR
    self.dataList = [NSMutableArray arrayWithObjects:@"(sample)[epcepcepc],COUNT=xx", nil];
#endif
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.reader setDelegate:self];
    
    _labelTagCount.text = kTAG_COUNT_TEXT_NONE;
}

#pragma mark - DOTRDelegateProtocol
// UploadTagDataイベント通知
- (void)onUploadTagData:(NSString *)data {
    LOG(@"%@", data);
    [self insertNewObject:data];
}

- (void)onDisconnected {
    LOG(@"切断しました");
}

- (void)onLinkLost {
    LOG(@"通信が切れました");
}

#pragma mark - Action
// メモリ内データ取得
- (IBAction)btnUploadMemory:(id)sender {
    if ([self.reader isConnect] == NO) {
        LOG(@"リーダー未接続です");
        return;
    }
    
    // 取得結果は onUploadTagData で通知される
    [self.reader uploadMemoryTag];
}

// メモリ内データクリア
- (IBAction)btnClearMemory:(id)sender {
    if ([self.reader isConnect] == NO) {
        LOG(@"リーダー未接続です");
        return;
    }

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"メモリ内データクリア"
                                                                             message:@"リーダー本体メモリの読取り済みタグデータをクリアします"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:@"cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    UIAlertAction *actionOK = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDestructive
                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                         [self.reader clearMemoryTag];
                                                         _labelTagCount.text = kTAG_COUNT_TEXT_NONE;
                                                     }];
    [alertController addAction:actionCancel];
    [alertController addAction:actionOK];
    [self presentViewController:alertController animated:YES completion:nil];
}

// ログ消去（TableViewの表示をクリア）
- (IBAction)btnClearLog:(id)sender {
    [self resetTable:nil];
}

#pragma mark - Table View
- (void)resetTable:(id)sender {
    if (self.dataList) {
        [self.dataList removeAllObjects];
        _labelTagCount.text = kTAG_COUNT_TEXT_NONE;
        [self.tableView reloadData];
    }
}

- (void)insertNewObject:(NSString*)data {
    if (!self.dataList) {
        self.dataList = [[NSMutableArray alloc] init];
        _labelTagCount.text = kTAG_COUNT_TEXT_NONE;
    }
    
    [self.dataList insertObject:data atIndex:0];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    
    _labelTagCount.text = [NSString stringWithFormat:@"%ld", (unsigned long)self.dataList.count];
//    LOG(@">>> count: %ld", self.dataList.count);
}

#pragma mark - UITableViewDataSource
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

    // 取得したデータを EPC, COUNTに分けて表示
    // 文字列形式：[EPC],COUNT=xxx, TYPE=xxx
    NSString *data = self.dataList[indexPath.row];
    NSMutableArray *dataTexts = [NSMutableArray arrayWithArray:[data componentsSeparatedByString:@","]];

    cell.textLabel.text = dataTexts[0]; // epc

    NSMutableString *detail = [NSMutableString new];
    if (dataTexts.count >= 2) {
        [detail appendString:dataTexts[1]]; // count
    }
    if (dataTexts.count >= 3) {
        [detail appendFormat:@" ,%@", dataTexts[2]];    // type
    }

    cell.detailTextLabel.text = detail;

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // セル選択時の処理
}
@end
