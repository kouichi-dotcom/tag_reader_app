//
//  DeviceViewController.m
//  UploadTag
//
//  Copyright (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
//

#import "DeviceViewController.h"
#import "TSS_SDK.h"

#define LOG(fmt, ...) NSLog((@"%s [%d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface DeviceViewController () <DOTRDelegateProtocol, UITableViewDataSource, UITableViewDelegate, ReaderDelegate>
@property TSS_SDK *reader;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property NSMutableArray *peripheralList;
@property BOOL isReady;
@property BOOL isScaning;
@property (weak, nonatomic) IBOutlet UIButton *buttonScan;
@property NSTimer *timerForScan;
@end

@implementation DeviceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _reader = [TSS_SDK shared];
    
    [_reader setDebugMode:YES];
    
#if TARGET_IPHONE_SIMULATOR
    if (self.peripheralList == nil) {
        self.peripheralList = [NSMutableArray arrayWithObjects:@"sample", nil];
    }
#endif
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.reader setDelegate:self];
    
    [self setScanButtonText:@"Scan"];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self stopScanTimer];
    if (self.isScaning) {
        [self.reader stopScan];
        self.isScaning = NO;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void)setScanButtonText:(NSString *)text {
    [self.buttonScan setTitle:text forState:UIControlStateNormal];
}

- (IBAction)onScan:(id)sender {
#if TARGET_IPHONE_SIMULATOR
    LOG(@"シミュレータでは実行できません");
#else
    // stopScan
    if (self.isScaning) {
        [self.reader stopScan];
        [self stopScanTimer];
        self.isScaning = NO;
        [self setScanButtonText:@"Scan"];
    }
    // startScan
    else {
        // スキャンしなおすのでクリア
        if (self.peripheralList) {
            [self.peripheralList removeAllObjects];
            [self.tableView reloadData];
        }
        if ([self.reader isConnect]) {
            [self.reader disconnect];
        }
        if (self.isReady) {
            [self.reader scan];
            [self startScanTimer];
            self.isScaning = YES;
            [self setScanButtonText:@"Stop"];
        }
    }
#endif
}

/**
 * ＜scanメソッド使用せずにデバイスを取得するサンプル＞
 *  scan結果得られたCBPeripheralオブジェクトをNSUserDefault等で保持しておき、
 *  retrievePeripheralsWithIdentifiers: へ渡すことでscan済のデバイス取得が可能
 */
- (IBAction)onGetKnownDevices:(id)sender {
#if TARGET_IPHONE_SIMULATOR
    LOG(@"シミュレータでは実行できません");
#else
    // ここでは簡易的な確認のため、アプリ起動中に得たscan結果をそのまま使う
    if ((self.peripheralList == nil)
        || (self.peripheralList.count == 0)) {
        return;
    }
    
    NSMutableArray *backupPeripherals = [NSMutableArray arrayWithArray:self.peripheralList];
    // 結果をわかるようにするためscan結果は一旦削除
    [self.peripheralList removeAllObjects];
    [self.tableView reloadData];

    NSMutableArray *identifiers = [NSMutableArray array];
    for (CBPeripheral *peripheral in backupPeripherals) {
        [identifiers addObject:peripheral.identifier];
    }
    
    NSArray *knownPeripherals = [self.reader retrievePeripheralsWithIdentifiers:identifiers];
    if (knownPeripherals.count > 0) {
        for (CBPeripheral *peripheral in knownPeripherals) {
            [self insertNewObject:peripheral];
        }
    }
#endif
}

/**
 * ＜scanメソッド使用せずにデバイスを取得するサンプル＞
 *  システムへ既に接続済みのデバイスがある場合はCBPeripheralのリストとして返される
 */
- (IBAction)onGetConnectedDevices:(id)sender {
#if TARGET_IPHONE_SIMULATOR
    LOG(@"シミュレータでは実行できません");
#else
    NSArray *connectedPeripherals = [self.reader retrieveConnectedPeripherals];
    if (connectedPeripherals.count > 0) {
        // 結果をわかるようにするためscan結果は一旦削除
        [self.peripheralList removeAllObjects];
        [self.tableView reloadData];

        // リストに接続候補として表示させる
        for (CBPeripheral *peripheral in connectedPeripherals) {
            [self insertNewObject:peripheral];
        }
    }
#endif
}

-(void)startScanTimer {
    self.timerForScan = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                         target:self
                                                       selector:@selector(onScan:)
                                                       userInfo:nil
                                                        repeats:NO];
}

-(void)stopScanTimer {
    if ([self.timerForScan isValid]) {
        [self.timerForScan invalidate];
        self.timerForScan = nil;
    }
}


# pragma mark - Delegate / DOTR_Util
// Bluetooth利用可否の状態変化通知
- (void)didUpdateCentralManagerState {
    self.isReady = [self.reader isCentralManagerReady];
}

// 発見したデバイスの通知
- (void)didDiscoverDevice:(CBPeripheral *)peripheral {
    [self insertNewObject:peripheral];
}

// DOTRデバイスへの接続成功通知
- (void)onConnected {
    LOG(@"接続しました");
    // チェックマーク更新のためリロード
    [self.tableView reloadData];
}

// DOTRデバイスへの接続失敗通知
- (void)onConnectFail {
    LOG(@"接続失敗");
    // チェックマーク更新のためリロード
    [self.tableView reloadData];
}

- (void)onConnectFail:(NSString *)message
{
    LOG(@"接続失敗");
    // チェックマーク更新のためリロード
    [self.tableView reloadData];
}

// DOTRデバイスの切断完了通知
- (void)onDisconnected {
    LOG(@"切断しました");
    // チェックマーク更新のためリロード
    [self.tableView reloadData];
}

-(void)onDisconnected:(NSString *)message
{
    [self.tableView reloadData];
}

// 通信断通知
- (void)onLinkLost {
    LOG(@"通信が切れました");
    // 切断通知と分けて処理が必要あれば記述
    [self.tableView reloadData];
}

- (void)onLinkLost:(NSString *)message
{
    LOG(@"通信が切れました");
    // 切断通知と分けて処理が必要あれば記述
    [self.tableView reloadData];
}

#pragma mark - Delegate / Table View
- (void)insertNewObject:(id)sender {
    if (!self.peripheralList) {
        self.peripheralList = [[NSMutableArray alloc] init];
    }
    
    CBPeripheral *newPeripheral = sender;
    // SDK側で(CoreBluetoothに対して）重複したデバイスの検出・通知は行わない設定としているが、一応ここでも同じのが来たらスキップ
    if ([self.peripheralList containsObject:newPeripheral] == YES) {
        return;
    }
    
    [self.peripheralList insertObject:newPeripheral atIndex:0];
    
    [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.peripheralList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
#if TARGET_IPHONE_SIMULATOR
    cell.textLabel.text = self.peripheralList[indexPath.row];
    cell.detailTextLabel.text =  @"(UUID)";
#else
    CBPeripheral *cellItem = self.peripheralList[indexPath.row];
    //    cell.textLabel.text = [object description];
    cell.textLabel.text = [cellItem name];
    cell.detailTextLabel.text =  [[cellItem identifier] UUIDString];
    
    // 「接続済み」の場合にチェックマークを表示
    if ([cellItem state] == CBPeripheralStateConnected) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
#endif
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
#if TARGET_IPHONE_SIMULATOR
    LOG(@"シミュレータでは実行できません");
#else
    // スキャン中の場合はスキャン停止
    if (self.isScaning) {
        [self.reader stopScan];
        [self stopScanTimer];
        self.isScaning = NO;
        [self setScanButtonText:@"Scan"];
    }
    
    if ([self.reader isConnect] == NO) {
        CBPeripheral *cellItem = self.peripheralList[indexPath.row];
        [self.reader initReader:cellItem.name];
        // 接続中でない場合は接続
        if ([self.reader connect:self.peripheralList[indexPath.row]] == NO) {
            // 必要あれば：接続要求が失敗した場合の処理
        }
    }
    else {
        // 接続中の場合は切断
        [self.reader disconnect];
    }
#endif
}
@end
