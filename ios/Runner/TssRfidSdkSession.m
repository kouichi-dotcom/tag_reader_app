#import "TssRfidSdkSession.h"
#import "TSS_SDK.h"
#import "DOTR_Util.h"
#import <CoreBluetooth/CoreBluetooth.h>

static NSString *const kKnownDevicesKey = @"tss_rfid_ios_known_devices";
static NSString *const kHiddenAddressesKey = @"tss_rfid_ios_hidden_reader_addresses";
// NOTE:
// EPC のクールダウン（重複通知抑制）は一旦無効化中。
// 復活する場合は、下記定数と onInventoryEPC 内の該当ブロックを戻す。
// static const int64_t kEpcCooldownMs = 30000;

static BOOL TssRfidIsLikelyReaderName(NSString *name) {
  NSString *n = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (n.length == 0) return NO;
  NSArray<NSString *> *prefixes = @[
    @"HQ_UHF_READER", @"TSS91JJ-", @"TSS92JJ-", @"DOTR2100-", @"DOTR2200-",
    @"TSS2100", @"TSS2200", @"DOTR3100", @"DOTR3200", @"TSS3100", @"TSS3200",
    @"R-5000", @"SR7_", @"SR-7", @"SR7-", @"SR7", @"MR20_", @"SR160_", @"BLE SPP",
    @"TSS91JI-", @"TSS92JI-",
  ];
  for (NSString *p in prefixes) {
    if ([n caseInsensitiveCompare:p] == NSOrderedSame || [n hasPrefix:p]) {
      return YES;
    }
  }
  return NO;
}

/// TSS_SDK の API はメインキュー前提のため同期呼び出しに使う。
/// メインスレッドから呼ばれた場合はそのまま実行し、dispatch_sync(main) によるデッドロックを避ける。
static void TssRfidPerformOnMain(void (^block)(void)) {
  if ([NSThread isMainThread]) {
    block();
  } else {
    dispatch_sync(dispatch_get_main_queue(), block);
  }
}

@interface TssRfidSdkSession () <ReaderDelegate>
@property (nonatomic, strong) TSS_SDK *reader;
@property (nonatomic, copy, nullable) void (^emitBlock)(NSDictionary *);
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *epcLastNotifiedAtMs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CBPeripheral *> *discoveredPeripheralsByUuid;
@property (nonatomic, strong, nullable) dispatch_semaphore_t pendingConnectSem;
@property (nonatomic, assign) BOOL connectWaitOutcome;
@property (nonatomic, strong, nullable) NSError *pendingConnectError;
/// 同時に複数 connect が走ると semaphore / delegate が競合するため直列化する
@property (nonatomic, strong) NSLock *connectLock;
/// retrieve が空のとき、短時間スキャンで該当 UUID の周辺端末を待つ（SR-7 等）
@property (nonatomic, copy, nullable) NSString *pendingDiscoverUuid;
@property (nonatomic, strong, nullable) dispatch_semaphore_t pendingDiscoverSem;
@property (nonatomic, strong, nullable) CBPeripheral *pendingDiscoveredPeripheral;
@end

@implementation TssRfidSdkSession

+ (instancetype)shared {
  static TssRfidSdkSession *s;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    s = [[TssRfidSdkSession alloc] init];
  });
  return s;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _reader = [TSS_SDK shared];
    [_reader setDelegate:self];
    _epcLastNotifiedAtMs = [NSMutableDictionary dictionary];
    _discoveredPeripheralsByUuid = [NSMutableDictionary dictionary];
    _connectLock = [[NSLock alloc] init];
  }
  return self;
}

- (void)setEmitHandler:(void (^)(NSDictionary *event))handler {
  self.emitBlock = [handler copy];
}

- (void)emit:(NSDictionary *)event {
  if (self.emitBlock) {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.emitBlock(event);
    });
  }
}

#pragma mark - BLE scan (TSS_SDK)

- (void)startBleScan {
  dispatch_async(dispatch_get_main_queue(), ^{
    // SR-7 等は「直前に検出した CBPeripheral」を connect に使う方が安定する。
    // 毎回クリアすると一覧からの retrieve のみになり失敗率が上がるためマージのみとする。
    [self.reader scan];
  });
}

- (void)stopBleScan {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.reader stopScan];
  });
}

#pragma mark - Connect / inventory / power

/// iOS は CoreBluetooth の仕様で、未スキャンだと retrievePeripheralsWithIdentifiers が空のことがある。
/// ペアリング済み表示は UserDefaults 等で出せても、接続には「一度検出した」peripheral が必要な機種がある（SR-7 等）。
- (nullable CBPeripheral *)waitForPeripheralWithUuidString:(NSString *)uuidString
                                                timeoutSec:(NSTimeInterval)timeoutSec {
  if (uuidString.length == 0) return nil;
  CBPeripheral *cached = self.discoveredPeripheralsByUuid[uuidString];
  if (cached) return cached;

  self.pendingDiscoverUuid = uuidString;
  self.pendingDiscoveredPeripheral = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  self.pendingDiscoverSem = sem;

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.reader stopScan];
    [self.reader scan];
  });

  dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutSec * NSEC_PER_SEC));
  long r = dispatch_semaphore_wait(sem, t);

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.reader stopScan];
  });

  if (r != 0) {
    self.pendingDiscoverSem = nil;
    self.pendingDiscoverUuid = nil;
    self.pendingDiscoveredPeripheral = nil;
    return nil;
  }
  CBPeripheral *out = self.pendingDiscoveredPeripheral;
  self.pendingDiscoveredPeripheral = nil;
  return out;
}

- (BOOL)connectWithName:(NSString *)name
                address:(NSString *)address
               outError:(NSError *__autoreleasing *)outError {
  [self.connectLock lock];
  @try {
    return [self connectWithNameLocked:name address:address outError:outError];
  } @finally {
    [self.connectLock unlock];
  }
}

- (BOOL)connectWithNameLocked:(NSString *)name
                      address:(NSString *)address
                     outError:(NSError *__autoreleasing *)outError {
  if (name.length == 0 || address.length == 0) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:10
                                  userInfo:@{NSLocalizedDescriptionKey: @"端末情報が不正です。一覧から接続し直してください。"}];
    }
    return NO;
  }
  NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:address];
  if (!uuid) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:11
                                  userInfo:@{NSLocalizedDescriptionKey: @"端末の識別子が正しくありません。スキャンで表示された端末から接続してください。"}];
    }
    return NO;
  }
  CBPeripheral *p = self.discoveredPeripheralsByUuid[address];
  if (p == nil) {
    NSArray *rets = [self.reader retrievePeripheralsWithIdentifiers:@[uuid]];
    p = rets.firstObject;
  }
  if (!p) {
    // 手動スキャンなしでも接続できるよう、短時間だけスキャンして同じ UUID を捕捉する
    p = [self waitForPeripheralWithUuidString:address timeoutSec:12.0];
  }
  if (!p) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:12
                                  userInfo:@{
                                    NSLocalizedDescriptionKey:
                                      @"端末が見つかりません。リーダーの電源と距離を確認し、再度お試しください。"
                                  }];
    }
    return NO;
  }

  // retrieve だけだと name が nil のことがあり、SR-7 は initReader に正しい端末名が必要な場合がある。
  // 一覧（Flutter）から渡した name を優先し、あれば advertisement 名で上書き。
  NSString *trimName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *pName = p.name ? [p.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
  NSString *readerName = (pName.length > 0) ? pName : trimName;
  if (readerName.length == 0) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:16
                                  userInfo:@{NSLocalizedDescriptionKey: @"端末名を取得できませんでした。「新しいタグリーダーとペアリング設定」でスキャンし、表示された端末から接続してください。"}];
    }
    return NO;
  }

  // 既に別セッションで接続中だと SR-7 側が接続拒否・不安定になることがあるため一度切る。
  __block BOOL wasConnected = NO;
  TssRfidPerformOnMain(^{
    wasConnected = [self.reader isConnect];
    if (wasConnected) {
      [self.reader disconnect];
    }
  });
  if (wasConnected) {
    // disconnect の実完了は非同期のため、短時間待ってから次の connect（ログの sendBye Timeout 緩和）
    [NSThread sleepForTimeInterval:0.45];
  }

  self.pendingConnectError = nil;
  self.connectWaitOutcome = NO;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  self.pendingConnectSem = sem;

  dispatch_async(dispatch_get_main_queue(), ^{
    // 機種によっては scan 中接続で失敗率が上がるため、接続前に明示停止する。
    [self.reader stopScan];
    // メインで sleep すると UI が固まるため、少し遅らせてから init/connect
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self.reader initReader:readerName];
      if (![self.reader connect:p]) {
        [self finishConnectWithSuccess:NO
                                 error:[NSError errorWithDomain:@"TssRfidSdkSession" code:13
                                                         userInfo:@{NSLocalizedDescriptionKey: @"リーダーへの接続要求に失敗しました。Bluetoothをオンにし、リーダーの電源を確認してから再度お試しください。"}]];
      }
    });
  });

  dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC));
  long result = dispatch_semaphore_wait(sem, timeout);
  if (result != 0) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:14
                                  userInfo:@{NSLocalizedDescriptionKey: @"リーダーからの応答がありません（タイムアウト）。電源・距離を確認し、数秒待ってから再接続してください。"}];
    }
    self.pendingConnectSem = nil;
    return NO;
  }
  if (!self.connectWaitOutcome) {
    if (outError) {
      *outError = self.pendingConnectError ?: [NSError errorWithDomain:@"TssRfidSdkSession" code:15
                                                              userInfo:@{NSLocalizedDescriptionKey: @"接続に失敗しました。他の端末が同じリーダーに接続していないか確認してください。"}];
    }
    self.pendingConnectError = nil;
    return NO;
  }
  self.pendingConnectError = nil;
  return YES;
}

- (void)finishConnectWithSuccess:(BOOL)ok error:(NSError *)err {
  if (self.pendingConnectSem) {
    self.connectWaitOutcome = ok;
    self.pendingConnectError = err;
    dispatch_semaphore_signal(self.pendingConnectSem);
    self.pendingConnectSem = nil;
  }
}

- (BOOL)disconnect {
  __block BOOL ok = YES;
  TssRfidPerformOnMain(^{
    ok = [self.reader disconnect];
  });
  return ok;
}

- (BOOL)isConnected {
  __block BOOL c = NO;
  TssRfidPerformOnMain(^{
    c = [self.reader isConnect];
  });
  return c;
}

- (nullable NSString *)firmwareVersion {
  __block NSString *v = nil;
  TssRfidPerformOnMain(^{
    v = [self.reader getFirmwareVersion];
  });
  return v;
}

- (BOOL)startInventoryDateTime:(BOOL)dateTime
                   radioPower:(BOOL)radioPower
                      channel:(BOOL)channel
                         temp:(BOOL)temp
                        phase:(BOOL)phase
                     noRepeat:(BOOL)noRepeat
                     outError:(NSError *__autoreleasing *)outError {
  (void)channel;
  (void)temp;
  (void)phase;
  __block BOOL ok = NO;
  TssRfidPerformOnMain(^{
    [self.reader setNoRepeat:noRepeat];
    if (!noRepeat) {
      [self.reader clearAccessEPCList];
    }
    [self.reader setInventoryReportMode:dateTime reportRSSI:radioPower];
    ok = [self.reader inventoryTag:NO maskFlag:DOTRMaskFlagNone timeout:0];
  });
  if (!ok && outError) {
    *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:20
                                userInfo:@{NSLocalizedDescriptionKey: @"inventoryTag の開始に失敗"}];
  }
  return ok;
}

- (BOOL)stopInventory {
  __block BOOL ok = YES;
  TssRfidPerformOnMain(^{
    ok = [self.reader stop];
  });
  return ok;
}

- (nullable NSNumber *)radioPower {
  __block NSInteger v = -1;
  TssRfidPerformOnMain(^{
    v = [self.reader getRadioPower];
  });
  return v < 0 ? nil : @(v);
}

- (nullable NSNumber *)maxRadioPower {
  __block NSInteger v = -1;
  TssRfidPerformOnMain(^{
    v = [self.reader getMaxRadioPower];
  });
  return v < 0 ? nil : @(v);
}

- (BOOL)setRadioPowerDecreaseDecibel:(NSInteger)decreaseDecibel
                            outError:(NSError *__autoreleasing *)outError {
  __block BOOL ok = NO;
  TssRfidPerformOnMain(^{
    ok = [self.reader setRadioPower:decreaseDecibel];
  });
  if (!ok && outError) {
    *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:21
                                userInfo:@{NSLocalizedDescriptionKey: @"setRadioPower に失敗"}];
  }
  return ok;
}

- (void)trySetBuzzerMute {
  [self.reader setBuzzerVolume:DOTRBuzzerVolumeMute writeFlashMemory:NO];
}

#pragma mark - Known devices

- (NSSet<NSString *> *)hiddenAddressSet {
  NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:kHiddenAddressesKey];
  if (![arr isKindOfClass:[NSArray class]]) return [NSSet set];
  NSMutableSet *s = [NSMutableSet set];
  for (id o in arr) {
    if ([o isKindOfClass:[NSString class]] && [(NSString *)o length] > 0) {
      [s addObject:o];
    }
  }
  return s;
}

- (NSArray<NSDictionary *> *)mergedKnownBondedStyleDevices {
  NSMutableArray *out = [NSMutableArray array];
  NSMutableSet<NSString *> *seen = [NSMutableSet set];
  NSSet<NSString *> *hidden = [self hiddenAddressSet];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *raw = [defaults arrayForKey:kKnownDevicesKey];
  if ([raw isKindOfClass:[NSArray class]]) {
    for (id item in raw) {
      if (![item isKindOfClass:[NSDictionary class]]) continue;
      NSDictionary *d = (NSDictionary *)item;
      NSString *name = d[@"name"];
      NSString *addr = d[@"address"];
      if (name.length == 0 || addr.length == 0) continue;
      if ([hidden containsObject:addr]) continue;
      if ([seen containsObject:addr]) continue;
      [seen addObject:addr];
      [out addObject:@{@"name": name, @"address": addr}];
    }
  }

  TssRfidPerformOnMain(^{
    NSArray *connected = [self.reader retrieveConnectedPeripherals];
    for (CBPeripheral *p in connected) {
      NSString *addr = [[p identifier] UUIDString];
      if ([hidden containsObject:addr]) continue;
      if ([seen containsObject:addr]) continue;
      [seen addObject:addr];
      NSString *name = p.name ?: @"";
      [out addObject:@{@"name": name, @"address": addr}];
    }
  });

  [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
    return [a[@"name"] compare:b[@"name"]];
  }];
  return [out copy];
}

- (BOOL)removeKnownDeviceWithAddress:(NSString *)address {
  if (address.length == 0) return NO;
  [self.discoveredPeripheralsByUuid removeObjectForKey:address];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *raw = [defaults arrayForKey:kKnownDevicesKey];
  NSMutableArray *next = [NSMutableArray array];
  BOOL foundInKnown = NO;
  if ([raw isKindOfClass:[NSArray class]]) {
    for (id item in raw) {
      if (![item isKindOfClass:[NSDictionary class]]) continue;
      NSString *a = ((NSDictionary *)item)[@"address"];
      if ([a isEqualToString:address]) {
        foundInKnown = YES;
        continue;
      }
      [next addObject:item];
    }
  }
  if (foundInKnown) {
    [defaults setObject:[next copy] forKey:kKnownDevicesKey];
  }

  NSMutableArray *hiddenList = [[defaults arrayForKey:kHiddenAddressesKey] mutableCopy];
  if (!hiddenList) hiddenList = [NSMutableArray array];
  BOOL alreadyHidden = NO;
  for (id o in hiddenList) {
    if ([o isKindOfClass:[NSString class]] && [(NSString *)o isEqualToString:address]) {
      alreadyHidden = YES;
      break;
    }
  }
  if (!alreadyHidden) {
    [hiddenList addObject:address];
    [defaults setObject:[hiddenList copy] forKey:kHiddenAddressesKey];
  }

  [defaults synchronize];
  return foundInKnown || !alreadyHidden;
}

#pragma mark - ReaderDelegate

- (void)didUpdateCentralManagerState {
}

- (void)didDiscoverDevice:(CBPeripheral *)peripheral {
  NSString *name = peripheral.name ?: @"";
  NSString *addr = [[peripheral identifier] UUIDString];
  if (addr.length > 0) {
    self.discoveredPeripheralsByUuid[addr] = peripheral;
  }
  // 接続補助: 名前フィルタ前に UUID 一致で完了（advertisement 名が遅延する機種対策）
  if (self.pendingDiscoverSem != nil && [addr isEqualToString:self.pendingDiscoverUuid]) {
    self.pendingDiscoveredPeripheral = peripheral;
    dispatch_semaphore_t s = self.pendingDiscoverSem;
    self.pendingDiscoverSem = nil;
    self.pendingDiscoverUuid = nil;
    dispatch_semaphore_signal(s);
  }
  if (!TssRfidIsLikelyReaderName(name)) return;
  [self emit:@{@"type": @"ble_device_found", @"name": name, @"address": addr}];
}

- (void)onConnected {
  [self trySetBuzzerMute];
  [self emit:@{@"type": @"connected"}];
  NSString *ver = [self.reader getFirmwareVersion];
  if (ver.length > 0) {
    [self emit:@{@"type": @"firmware", @"version": ver}];
  }
  [self finishConnectWithSuccess:YES error:nil];
}

- (void)onConnectFail {
  [self finishConnectWithSuccess:NO
                           error:[NSError errorWithDomain:@"TssRfidSdkSession" code:30
                                                   userInfo:@{
                                                     NSLocalizedDescriptionKey:
                                                       @"リーダー側で接続を拒否したか、通信に失敗しました。電源・至近距離・他スマホ／PCとの同時接続を確認し、一度スキャンしてから再接続してください。"
                                                   }]];
}

- (void)onConnectFail:(NSString *)message {
  [self finishConnectWithSuccess:NO
                           error:[NSError errorWithDomain:@"TssRfidSdkSession" code:31
                                                   userInfo:@{NSLocalizedDescriptionKey: message ?: @""}]];
}

- (void)onDisconnected {
  [self.epcLastNotifiedAtMs removeAllObjects];
  [self emit:@{@"type": @"disconnected"}];
}

- (void)onDisconnected:(NSString *)message {
  (void)message;
  [self onDisconnected];
}

- (void)onLinkLost {
  [self emit:@{@"type": @"link_lost"}];
}

- (void)onLinkLost:(NSString *)message {
  (void)message;
  [self onLinkLost];
}

- (void)onTriggerChanged:(BOOL)trigger {
  [self emit:@{@"type": @"trigger_changed", @"trigger": @(trigger)}];
}

- (void)onInventoryEPC:(NSString *)epc {
  NSString *trim = [epc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (trim.length == 0) return;

  // NOTE:
  // 一度読み取った EPC を一定時間抑制するクールダウン処理は一旦未実装化。
  // 必要になったらこのブロックを復活させる。
  // int64_t now = (int64_t)([[NSDate date] timeIntervalSince1970] * 1000);
  // NSNumber *last = self.epcLastNotifiedAtMs[trim];
  // if (last != nil && (now - last.longLongValue) < kEpcCooldownMs) {
  //   return;
  // }
  // self.epcLastNotifiedAtMs[trim] = @(now);
  // if (self.epcLastNotifiedAtMs.count > 2048) {
  //   [self.epcLastNotifiedAtMs removeAllObjects];
  // }

  [self emit:@{@"type": @"inventory_epc", @"raw": trim}];
}

- (void)onReadTagData:(NSString *)data epc:(NSString *)epc {
  [self emit:@{@"type": @"read_tag_data", @"data": data ?: @"", @"epc": epc ?: @""}];
}

- (void)onWriteTagData:(NSString *)epc {
  [self emit:@{@"type": @"write_tag_data", @"epc": epc ?: @""}];
}

- (void)onUploadTagData:(NSString *)data {
  [self emit:@{@"type": @"upload_tag_data", @"data": data ?: @""}];
}

- (void)onTagMemoryLocked:(NSString *)epc {
  [self emit:@{@"type": @"tag_memory_locked", @"data": epc ?: @""}];
}

- (void)onBarcodeScan:(NSString *)code {
  [self emit:@{@"type": @"scan_code", @"code": code ?: @""}];
}

- (void)onBarcodeScanTriggerChanged:(BOOL)trigger {
  [self emit:@{@"type": @"scan_trigger_changed", @"trigger": @(trigger)}];
}

@end
