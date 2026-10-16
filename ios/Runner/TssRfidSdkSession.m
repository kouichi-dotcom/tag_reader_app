#import "TssRfidSdkSession.h"
#import "TSS_SDK.h"
#import "DOTR_Util.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <os/log.h>

static NSString *const kKnownDevicesKey = @"tss_rfid_ios_known_devices";
static NSString *const kHiddenAddressesKey = @"tss_rfid_ios_hidden_reader_addresses";
// NOTE:
// EPC のクールダウン（重複通知抑制）は一旦無効化中。
// 復活する場合は、下記定数と onInventoryEPC 内の該当ブロックを戻す。
// static const int64_t kEpcCooldownMs = 30000;

/// 診断ログ専用。接続処理の順序・SDK 呼び出しを変えないこと。
static NSString *TssRfidAddrTail(NSString *address) {
  NSString *a = [address stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (a.length == 0) return @"";
  if (a.length <= 5) return a;
  return [a substringFromIndex:a.length - 5];
}

static NSString *TssRfidPeripheralStateName(CBPeripheralState state) {
  switch (state) {
    case CBPeripheralStateDisconnected: return @"disconnected";
    case CBPeripheralStateConnecting: return @"connecting";
    case CBPeripheralStateConnected: return @"connected";
    case CBPeripheralStateDisconnecting: return @"disconnecting";
    default: return [NSString stringWithFormat:@"unknown(%ld)", (long)state];
  }
}

// EventChannel 経由で Flutter コンソールへも流すための弱参照（ログ専用）
static __weak TssRfidSdkSession *sBtLogSession;

// TssRfidBtLog から emit を呼ぶための前方宣言（実装は @implementation 内）
@interface TssRfidSdkSession (BtDiagEmit)
- (void)emit:(NSDictionary *)event;
@end

static void TssRfidBtLog(NSString *event, NSString *detail) {
  // NSISO8601DateFormatter はスレッドセーフではないため都度生成。ログ専用で接続をブロックしない。
  NSISO8601DateFormatter *fmt = [[NSISO8601DateFormatter alloc] init];
  fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime |
                      NSISO8601DateFormatWithFractionalSeconds;
  NSString *iso = [fmt stringFromDate:[NSDate date]] ?: @"";
  NSString *thr = [NSThread isMainThread] ? @"main" : @"bg";
  NSString *line = detail.length > 0
      ? [NSString stringWithFormat:@"[ReaderBT-iOS] %@ | thr=%@ | %@ | %@", iso, thr, event, detail]
      : [NSString stringWithFormat:@"[ReaderBT-iOS] %@ | thr=%@ | %@", iso, thr, event];
  // Flutter run / Xcode のいずれでも拾えるよう NSLog + stderr + os_log に出す（処理は待たない）
  NSLog(@"%@", line);
  fprintf(stderr, "%s\n", line.UTF8String);
  fflush(stderr);
  os_log(OS_LOG_DEFAULT, "%{public}s", line.UTF8String);
  // UI / 接続ロジックは変更せず、診断行だけ EventChannel へ（Plugin で print）
  TssRfidSdkSession *session = sBtLogSession;
  if (session != nil) {
    [session emit:@{@"type": @"bt_diag", @"line": line}];
  }
}

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
@property (nonatomic, assign) NSInteger connectGeneration;
@property (nonatomic, assign) NSInteger activeConnectGeneration;
/// 切断完了待ち
@property (nonatomic, strong, nullable) dispatch_semaphore_t pendingDisconnectSem;
@property (nonatomic, assign) BOOL disconnectWaitOutcome;
/// 同時に複数 connect/disconnect が走ると semaphore / delegate が競合するため直列化する
@property (nonatomic, strong) NSLock *connectLock;
@property (nonatomic, assign) BOOL isDisconnecting;
/// retrieve が空のとき、短時間スキャンで該当 UUID の周辺端末を待つ（SR-7 等）
@property (nonatomic, copy, nullable) NSString *pendingDiscoverUuid;
@property (nonatomic, strong, nullable) dispatch_semaphore_t pendingDiscoverSem;
@property (nonatomic, strong, nullable) CBPeripheral *pendingDiscoveredPeripheral;

/// 削除済み（非表示化）端末は、名前判定で ble_device_found を捨てないためのキャッシュ
@property (nonatomic, strong) NSSet<NSString *> *scanHiddenSet;

- (void)emit:(NSDictionary *)event;
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
    // 調査用の一時設定。公式サンプルと同様、connect 前に有効化する。本番適用しない。
    [_reader setDebugMode:NO];
    _epcLastNotifiedAtMs = [NSMutableDictionary dictionary];
    _discoveredPeripheralsByUuid = [NSMutableDictionary dictionary];
    _connectLock = [[NSLock alloc] init];
    _scanHiddenSet = [NSSet set];
    _connectGeneration = 0;
    _activeConnectGeneration = 0;
    _isDisconnecting = NO;
    sBtLogSession = self;
  }
  return self;
}

- (BOOL)isBluetoothPoweredOn {
  __block BOOL ready = YES;
  TssRfidPerformOnMain(^{
    // TSS_SDK: isCentralManagerReady == NO のとき Bluetooth 利用不可
    ready = [self.reader isCentralManagerReady];
  });
  return ready;
}

/// disconnect 要求後、onDisconnected または isConnect==NO を待つ
- (BOOL)waitUntilDisconnectedLockedWithTimeoutSec:(NSTimeInterval)timeoutSec {
  __block BOOL already = NO;
  TssRfidPerformOnMain(^{
    already = ![self.reader isConnect];
  });
  if (already) return YES;

  self.disconnectWaitOutcome = NO;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  self.pendingDisconnectSem = sem;

  dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutSec * NSEC_PER_SEC));
  long r = dispatch_semaphore_wait(sem, t);
  self.pendingDisconnectSem = nil;
  if (r == 0 && self.disconnectWaitOutcome) {
    return YES;
  }
  __block BOOL still = YES;
  TssRfidPerformOnMain(^{
    still = [self.reader isConnect];
  });
  return !still;
}

- (void)finishDisconnectWait {
  if (self.pendingDisconnectSem) {
    self.disconnectWaitOutcome = YES;
    dispatch_semaphore_signal(self.pendingDisconnectSem);
    self.pendingDisconnectSem = nil;
  }
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
  self.scanHiddenSet = [self hiddenAddressSet];
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
  TssRfidBtLog(@"connect_lock_acquire",
               [NSString stringWithFormat:@"device=%@(…%@)",
                                          name ?: @"",
                                          TssRfidAddrTail(address)]);
  [self.connectLock lock];
  @try {
    BOOL ok = [self connectWithNameLocked:name address:address outError:outError];
    TssRfidBtLog(@"connect_lock_release",
                 [NSString stringWithFormat:@"ok=%d flutterErrorCode=%ld",
                                            ok ? 1 : 0,
                                            (long)(outError && *outError ? (*outError).code : 0)]);
    return ok;
  } @finally {
    [self.connectLock unlock];
  }
}

- (BOOL)connectWithNameLocked:(NSString *)name
                      address:(NSString *)address
                     outError:(NSError *__autoreleasing *)outError {
  TssRfidBtLog(@"connect_start",
               [NSString stringWithFormat:@"name=%@ addrTail=…%@ readerInit=%@ activeGen=%ld",
                                          name ?: @"",
                                          TssRfidAddrTail(address),
                                          self.reader != nil ? @"yes" : @"no",
                                          (long)self.activeConnectGeneration]);
  if (name.length == 0 || address.length == 0) {
    TssRfidBtLog(@"connect_reject", @"reason=empty_name_or_address code=10");
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:10
                                  userInfo:@{NSLocalizedDescriptionKey: @"端末情報が不正です。一覧から接続し直してください。"}];
    }
    return NO;
  }
  NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:address];
  if (!uuid) {
    TssRfidBtLog(@"connect_reject", @"reason=invalid_uuid code=11");
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:11
                                  userInfo:@{NSLocalizedDescriptionKey: @"端末の識別子が正しくありません。スキャンで表示された端末から接続してください。"}];
    }
    return NO;
  }
  NSString *peripheralSource = @"none";
  BOOL fromRecentScan = NO;
  CBPeripheral *p = self.discoveredPeripheralsByUuid[address];
  if (p != nil) {
    peripheralSource = @"cache";
    fromRecentScan = YES;
    TssRfidBtLog(@"peripheral_resolve",
                 [NSString stringWithFormat:@"source=cache fromScan=1 state=%@ pName=%@",
                                            TssRfidPeripheralStateName(p.state),
                                            p.name ?: @""]);
  }
  if (p == nil) {
    NSArray *rets = [self.reader retrievePeripheralsWithIdentifiers:@[uuid]];
    p = rets.firstObject;
    if (p != nil) {
      peripheralSource = @"retrieve";
      fromRecentScan = NO;
      TssRfidBtLog(@"peripheral_resolve",
                   [NSString stringWithFormat:@"source=retrieve fromScan=0 state=%@ pName=%@",
                                              TssRfidPeripheralStateName(p.state),
                                              p.name ?: @""]);
    }
  }
  if (!p) {
    // 手動スキャンなしでも接続できるよう、短時間だけスキャンして同じ UUID を捕捉する
    TssRfidBtLog(@"peripheral_scan_wait_start",
                 [NSString stringWithFormat:@"addrTail=…%@ timeoutSec=12", TssRfidAddrTail(address)]);
    p = [self waitForPeripheralWithUuidString:address timeoutSec:12.0];
    if (p != nil) {
      peripheralSource = @"scan";
      fromRecentScan = YES;
      TssRfidBtLog(@"peripheral_resolve",
                   [NSString stringWithFormat:@"source=scan fromScan=1 state=%@ pName=%@",
                                              TssRfidPeripheralStateName(p.state),
                                              p.name ?: @""]);
    } else {
      TssRfidBtLog(@"peripheral_scan_wait_timeout",
                   [NSString stringWithFormat:@"addrTail=…%@", TssRfidAddrTail(address)]);
    }
  }
  if (!p) {
    TssRfidBtLog(@"connect_reject",
                 [NSString stringWithFormat:@"reason=not_found source=%@ code=12", peripheralSource]);
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:12
                                  userInfo:@{
                                    NSLocalizedDescriptionKey:
                                      @"タグリーダーが見つかりません。電源と通信範囲を確認してください。"
                                  }];
    }
    return NO;
  }

  // retrieve だけだと name が nil のことがあり、SR-7 は initReader に正しい端末名が必要な場合がある。
  // 一覧（Flutter）から渡した name を優先し、あれば advertisement 名で上書き。
  NSString *trimName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *pName = p.name ? [p.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
  NSString *readerName = (pName.length > 0) ? pName : trimName;
  TssRfidBtLog(@"peripheral_ready",
               [NSString stringWithFormat:@"source=%@ fromScan=%d state=%@ readerName=%@ flutterName=%@",
                                          peripheralSource,
                                          fromRecentScan ? 1 : 0,
                                          TssRfidPeripheralStateName(p.state),
                                          readerName ?: @"",
                                          trimName ?: @""]);
  if (readerName.length == 0) {
    TssRfidBtLog(@"connect_reject", @"reason=empty_reader_name code=16");
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:16
                                  userInfo:@{NSLocalizedDescriptionKey: @"端末名を取得できませんでした。「新しいタグリーダーとペアリング設定」でスキャンし、表示された端末から接続してください。"}];
    }
    return NO;
  }

  if (![self isBluetoothPoweredOn]) {
    TssRfidBtLog(@"connect_reject", @"reason=bluetooth_off code=17");
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:17
                                  userInfo:@{NSLocalizedDescriptionKey: @"BluetoothがOFFです。スマホのBluetoothをONにしてください。"}];
    }
    return NO;
  }

  // 既に接続中なら完了待ち付きで切断（固定 sleep のみに依存しない）
  __block BOOL wasConnected = NO;
  TssRfidPerformOnMain(^{
    wasConnected = [self.reader isConnect];
    if (wasConnected) {
      TssRfidBtLog(@"pre_connect_disconnect", @"wasConnected=1 calling_disconnect");
      [self.reader disconnect];
    } else {
      TssRfidBtLog(@"pre_connect_disconnect", @"wasConnected=0 skip");
    }
  });
  if (wasConnected) {
    (void)[self waitUntilDisconnectedLockedWithTimeoutSec:8.0];
    TssRfidBtLog(@"pre_connect_disconnect_wait_done", @"timeoutSec=8");
  }

  self.connectGeneration += 1;
  NSInteger gen = self.connectGeneration;
  self.activeConnectGeneration = gen;
  self.pendingConnectError = nil;
  self.connectWaitOutcome = NO;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  self.pendingConnectSem = sem;
  TssRfidBtLog(@"connect_generation",
               [NSString stringWithFormat:@"gen=%ld pendingConnectSem=1", (long)gen]);

  dispatch_async(dispatch_get_main_queue(), ^{
    // 機種によっては scan 中接続で失敗率が上がるため、接続前に明示停止する。
    TssRfidBtLog(@"sdk_stop_scan",
                 [NSString stringWithFormat:@"gen=%ld", (long)gen]);
    [self.reader stopScan];
    // メインで sleep すると UI が固まるため、少し遅らせてから init/connect
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      if (self.activeConnectGeneration != gen) {
        TssRfidBtLog(@"sdk_connect_aborted_stale_gen",
                     [NSString stringWithFormat:@"expectedGen=%ld activeGen=%ld",
                                                (long)gen,
                                                (long)self.activeConnectGeneration]);
        return;
      }
      TssRfidBtLog(@"sdk_init_reader",
                   [NSString stringWithFormat:@"gen=%ld readerName=%@", (long)gen, readerName ?: @""]);
      [self.reader initReader:readerName];
      TssRfidBtLog(@"sdk_connect_call_start",
                   [NSString stringWithFormat:@"gen=%ld pState=%@ pName=%@",
                                              (long)gen,
                                              TssRfidPeripheralStateName(p.state),
                                              p.name ?: @""]);
      BOOL connectRequested = [self.reader connect:p];
      TssRfidBtLog(@"sdk_connect_return",
                   [NSString stringWithFormat:@"gen=%ld connectReturn=%d",
                                              (long)gen,
                                              connectRequested ? 1 : 0]);
      if (!connectRequested) {
        [self finishConnectWithSuccess:NO
                                 generation:gen
                                     error:[NSError errorWithDomain:@"TssRfidSdkSession" code:13
                                                             userInfo:@{NSLocalizedDescriptionKey: @"リーダーへの接続要求に失敗しました。Bluetoothをオンにし、リーダーの電源を確認してから再度お試しください。"}]];
      }
    });
  });

  TssRfidBtLog(@"semaphore_wait_start",
               [NSString stringWithFormat:@"gen=%ld timeoutSec=20 pendingConnectSem=1", (long)gen]);
  dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC));
  long result = dispatch_semaphore_wait(sem, timeout);
  if (result != 0) {
    TssRfidBtLog(@"semaphore_wait_timeout",
                 [NSString stringWithFormat:@"gen=%ld reason=timeout", (long)gen]);
    // タイムアウト後の遅延 onConnected を無効化
    self.activeConnectGeneration = -1;
    self.pendingConnectSem = nil;
    TssRfidBtLog(@"timeout_disconnect_call", @"calling_sdk_disconnect");
    TssRfidPerformOnMain(^{
      [self.reader disconnect];
    });
    (void)[self waitUntilDisconnectedLockedWithTimeoutSec:3.0];
    TssRfidBtLog(@"flutter_result", @"ok=0 code=14 connect_timeout");
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:14
                                  userInfo:@{NSLocalizedDescriptionKey: @"接続が完了しませんでした。タグリーダーの電源と他の端末の接続状況を確認してください。"}];
    }
    return NO;
  }
  TssRfidBtLog(@"semaphore_wait_done",
               [NSString stringWithFormat:@"gen=%ld reason=signaled outcome=%d errCode=%ld",
                                          (long)gen,
                                          self.connectWaitOutcome ? 1 : 0,
                                          (long)(self.pendingConnectError ? self.pendingConnectError.code : 0)]);
  if (!self.connectWaitOutcome) {
    NSInteger errCode = self.pendingConnectError ? self.pendingConnectError.code : 15;
    TssRfidBtLog(@"flutter_result",
                 [NSString stringWithFormat:@"ok=0 code=%ld connect_failed", (long)errCode]);
    if (outError) {
      *outError = self.pendingConnectError ?: [NSError errorWithDomain:@"TssRfidSdkSession" code:15
                                                              userInfo:@{NSLocalizedDescriptionKey: @"タグリーダーに接続できませんでした。もう一度お試しください。"}];
    }
    self.pendingConnectError = nil;
    return NO;
  }
  self.pendingConnectError = nil;
  TssRfidBtLog(@"flutter_result", @"ok=1");
  return YES;
}

- (void)finishConnectWithSuccess:(BOOL)ok error:(NSError *)err {
  [self finishConnectWithSuccess:ok generation:self.activeConnectGeneration error:err];
}

- (void)finishConnectWithSuccess:(BOOL)ok generation:(NSInteger)generation error:(NSError *)err {
  if (generation != self.activeConnectGeneration) {
    TssRfidBtLog(@"semaphore_signal_ignored_stale",
                 [NSString stringWithFormat:@"ok=%d gen=%ld activeGen=%ld",
                                            ok ? 1 : 0,
                                            (long)generation,
                                            (long)self.activeConnectGeneration]);
    return;
  }
  if (self.pendingConnectSem) {
    self.connectWaitOutcome = ok;
    self.pendingConnectError = err;
    TssRfidBtLog(@"semaphore_signal",
                 [NSString stringWithFormat:@"ok=%d gen=%ld errCode=%ld msg=%@",
                                            ok ? 1 : 0,
                                            (long)generation,
                                            (long)(err ? err.code : 0),
                                            err.localizedDescription ?: @""]);
    dispatch_semaphore_signal(self.pendingConnectSem);
    self.pendingConnectSem = nil;
  } else {
    TssRfidBtLog(@"semaphore_signal_no_pending",
                 [NSString stringWithFormat:@"ok=%d gen=%ld", ok ? 1 : 0, (long)generation]);
  }
}

- (BOOL)disconnect {
  return [self disconnectWithError:nil];
}

- (BOOL)disconnectWithError:(NSError *__autoreleasing *)outError {
  TssRfidBtLog(@"disconnect_lock_acquire",
               [NSString stringWithFormat:@"activeGen=%ld pendingConnectSem=%d",
                                          (long)self.activeConnectGeneration,
                                          self.pendingConnectSem != nil ? 1 : 0]);
  [self.connectLock lock];
  @try {
    if (self.isDisconnecting) {
      TssRfidBtLog(@"disconnect_reject", @"reason=already_disconnecting code=40");
      if (outError) {
        *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:40
                                    userInfo:@{NSLocalizedDescriptionKey: @"現在、切断処理中です。"}];
      }
      return NO;
    }
    self.isDisconnecting = YES;
    // 進行中の接続待ちを無効化
    self.activeConnectGeneration = -1;
    if (self.pendingConnectSem) {
      self.connectWaitOutcome = NO;
      self.pendingConnectError = [NSError errorWithDomain:@"TssRfidSdkSession" code:41
                                                userInfo:@{NSLocalizedDescriptionKey: @"切断処理のため接続を中止しました。"}];
      TssRfidBtLog(@"disconnect_cancel_pending_connect", @"signaling_pendingConnectSem code=41");
      dispatch_semaphore_signal(self.pendingConnectSem);
      self.pendingConnectSem = nil;
    }

    __block BOOL already = NO;
    TssRfidPerformOnMain(^{
      already = ![self.reader isConnect];
      if (!already) {
        TssRfidBtLog(@"disconnect_sdk_call", @"stop+disconnect");
        [self.reader stop];
        [self.reader disconnect];
      } else {
        TssRfidBtLog(@"disconnect_sdk_call", @"already_disconnected skip");
      }
    });
    if (already) {
      self.isDisconnecting = NO;
      TssRfidBtLog(@"disconnect_done", @"ok=1 already=1");
      return YES;
    }
    BOOL confirmed = [self waitUntilDisconnectedLockedWithTimeoutSec:8.0];
    self.isDisconnecting = NO;
    if (!confirmed) {
      TssRfidBtLog(@"disconnect_done", @"ok=0 code=42 incomplete");
      if (outError) {
        *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:42
                                    userInfo:@{NSLocalizedDescriptionKey: @"切断の完了を確認できませんでした。"}];
      }
      return NO;
    }
    TssRfidBtLog(@"disconnect_done", @"ok=1 confirmed=1");
    return YES;
  } @finally {
    self.isDisconnecting = NO;
    [self.connectLock unlock];
    TssRfidBtLog(@"disconnect_lock_release", @"");
  }
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
    // 読取セッション開始のたびにクリア。noRepeat=YES でも前回の EPC が残ると再通知されない。
    [self.reader clearAccessEPCList];
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

- (BOOL)writeEpcWithCurrentEpc:(NSString *)currentEpc
                        newEpc:(NSString *)newEpc
                      outError:(NSError *__autoreleasing *)outError {
  NSString *cur = [[currentEpc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
  NSString *nxt = [[newEpc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
  if (cur.length == 0 || nxt.length == 0) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:30
                                  userInfo:@{NSLocalizedDescriptionKey: @"currentEpc / newEpc が空です"}];
    }
    return NO;
  }
  if (nxt.length % 4 != 0) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:31
                                  userInfo:@{NSLocalizedDescriptionKey: @"newEpc の桁数が不正です"}];
    }
    return NO;
  }

  __block BOOL ok = NO;
  TssRfidPerformOnMain(^{
    [self.reader stop];
    [NSThread sleepForTimeInterval:0.15];
    [self.reader clearAccessEPCList];
    [self.reader setQValue:0];

    // 前回マスクをクリア（公式サンプルはマスクなし書込み）
    [self.reader setTagAccessMask:DOTRMemoryBankEPC
                       maskOffset:0
                         maskBits:0
                      maskPattern:@"0000"];

    DOTRTagAccessParameter *param =
        [[DOTRTagAccessParameter alloc] initWithParameter:(int)(nxt.length / 4)
                                               memoryBank:DOTRMemoryBankEPC
                                               wordOffset:2
                                                 password:0];
    // timeout=0: 成功か stop まで継続 / singleTag=YES: 1枚で終了
    ok = [self.reader writeTag:param
                     writeData:nxt
                     singleTag:YES
                      maskFlag:DOTRMaskFlagNone
                       timeout:0];
    [self emit:@{
      @"type": @"write_tag_started",
      @"ok": @(ok),
      @"newEpc": nxt ?: @"",
    }];
  });
  if (!ok && outError) {
    *outError = [NSError errorWithDomain:@"TssRfidSdkSession" code:32
                                userInfo:@{NSLocalizedDescriptionKey: @"writeTag の開始に失敗"}];
    [self emit:@{@"type": @"write_tag_failed", @"message": @"writeTag failed"}];
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
  BOOL isHidden = [self.scanHiddenSet containsObject:addr];
  if (!TssRfidIsLikelyReaderName(name) && !isHidden) return;
  [self emit:@{@"type": @"ble_device_found", @"name": name, @"address": addr}];
}

- (void)onConnected {
  TssRfidBtLog(@"onConnected",
               [NSString stringWithFormat:@"activeGen=%ld pendingConnectSem=%d",
                                          (long)self.activeConnectGeneration,
                                          self.pendingConnectSem != nil ? 1 : 0]);
  if (self.activeConnectGeneration < 0) {
    // タイムアウト後の遅延コールバック: 成功扱いしない
    TssRfidBtLog(@"onConnected_ignored_stale", @"activeGen<0 after_timeout");
    return;
  }
  [self trySetBuzzerMute];
  [self emit:@{@"type": @"connected"}];
  NSString *ver = [self.reader getFirmwareVersion];
  if (ver.length > 0) {
    [self emit:@{@"type": @"firmware", @"version": ver}];
  }
  TssRfidBtLog(@"onConnected_before_finish",
               [NSString stringWithFormat:@"fwLen=%lu pendingConnectSem=%d",
                                          (unsigned long)(ver.length),
                                          self.pendingConnectSem != nil ? 1 : 0]);
  [self finishConnectWithSuccess:YES generation:self.activeConnectGeneration error:nil];
}

- (void)onConnectFail {
  TssRfidBtLog(@"onConnectFail",
               [NSString stringWithFormat:@"activeGen=%ld pendingConnectSem=%d message=(none)",
                                          (long)self.activeConnectGeneration,
                                          self.pendingConnectSem != nil ? 1 : 0]);
  [self finishConnectWithSuccess:NO
                      generation:self.activeConnectGeneration
                           error:[NSError errorWithDomain:@"TssRfidSdkSession" code:30
                                                   userInfo:@{
                                                     NSLocalizedDescriptionKey:
                                                       @"タグリーダーに接続できませんでした。もう一度お試しください。"
                                                   }]];
}

- (void)onConnectFail:(NSString *)message {
  NSString *msg = message.length > 0
                      ? message
                      : @"タグリーダーに接続できませんでした。もう一度お試しください。";
  TssRfidBtLog(@"onConnectFail",
               [NSString stringWithFormat:@"activeGen=%ld pendingConnectSem=%d message=%@",
                                          (long)self.activeConnectGeneration,
                                          self.pendingConnectSem != nil ? 1 : 0,
                                          msg]);
  [self finishConnectWithSuccess:NO
                      generation:self.activeConnectGeneration
                           error:[NSError errorWithDomain:@"TssRfidSdkSession" code:31
                                                   userInfo:@{NSLocalizedDescriptionKey: msg}]];
}

- (void)onDisconnected {
  TssRfidBtLog(@"onDisconnected",
               [NSString stringWithFormat:@"activeGen=%ld pendingConnectSem=%d pendingDisconnectSem=%d message=(none)",
                                          (long)self.activeConnectGeneration,
                                          self.pendingConnectSem != nil ? 1 : 0,
                                          self.pendingDisconnectSem != nil ? 1 : 0]);
  [self.epcLastNotifiedAtMs removeAllObjects];
  [self finishDisconnectWait];
  [self emit:@{@"type": @"disconnected"}];
}

- (void)onDisconnected:(NSString *)message {
  TssRfidBtLog(@"onDisconnected",
               [NSString stringWithFormat:@"activeGen=%ld pendingConnectSem=%d pendingDisconnectSem=%d message=%@",
                                          (long)self.activeConnectGeneration,
                                          self.pendingConnectSem != nil ? 1 : 0,
                                          self.pendingDisconnectSem != nil ? 1 : 0,
                                          message ?: @""]);
  [self.epcLastNotifiedAtMs removeAllObjects];
  [self finishDisconnectWait];
  [self emit:@{@"type": @"disconnected"}];
}

- (void)onLinkLost {
  TssRfidBtLog(@"onLinkLost",
               [NSString stringWithFormat:@"activeGen=%ld pendingConnectSem=%d pendingDisconnectSem=%d message=(none)",
                                          (long)self.activeConnectGeneration,
                                          self.pendingConnectSem != nil ? 1 : 0,
                                          self.pendingDisconnectSem != nil ? 1 : 0]);
  [self finishDisconnectWait];
  [self emit:@{@"type": @"link_lost"}];
}

- (void)onLinkLost:(NSString *)message {
  TssRfidBtLog(@"onLinkLost",
               [NSString stringWithFormat:@"activeGen=%ld pendingConnectSem=%d pendingDisconnectSem=%d message=%@",
                                          (long)self.activeConnectGeneration,
                                          self.pendingConnectSem != nil ? 1 : 0,
                                          self.pendingDisconnectSem != nil ? 1 : 0,
                                          message ?: @""]);
  [self finishDisconnectWait];
  [self emit:@{@"type": @"link_lost"}];
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
