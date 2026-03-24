#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// TSS iOS SDK への薄いブリッジ（Android MainActivity の TssRfidUtill 相当）。
/// SDK を Xcode にリンクし、TssRfidNativeBridge.m 内の HAS_TSS_IOS_SDK 分岐を実装すると実機 RFID が動作します。
/// SDK 未配置時はスタブ（接続・在庫・電波強度は失敗）ですが、BLE スキャンは Swift 側で動作します。
@interface TssRfidNativeBridge : NSObject

+ (void)setEventSinkCallback:(void (^)(NSDictionary *event))callback;

/// TSS_SDK の scan / stopScan（ble_device_found は ReaderDelegate 経由）
+ (void)startBleScan;
+ (void)stopBleScan;

+ (BOOL)connectWithName:(NSString *)name
                address:(NSString *)address
               outError:(NSError *_Nullable *_Nullable)outError;

+ (BOOL)disconnect;

+ (BOOL)isConnected;

+ (nullable NSString *)firmwareVersion;

+ (BOOL)startInventoryDateTime:(BOOL)dateTime
                   radioPower:(BOOL)radioPower
                      channel:(BOOL)channel
                         temp:(BOOL)temp
                        phase:(BOOL)phase
                     noRepeat:(BOOL)noRepeat
                       outError:(NSError *_Nullable *_Nullable)outError;

+ (BOOL)stopInventory;

+ (nullable NSNumber *)radioPower;

+ (nullable NSNumber *)maxRadioPower;

+ (BOOL)setRadioPowerDecreaseDecibel:(NSInteger)decreaseDecibel
                            outError:(NSError *_Nullable *_Nullable)outError;

/// Android の bonded 相当: UserDefaults に保存した過去接続デバイス（iOS は MAC が取れないため UUID 文字列を address として渡す）
+ (NSArray<NSDictionary *> *)knownBondedStyleDevices;

+ (void)rememberDeviceName:(NSString *)name address:(NSString *)address;

+ (void)clearKnownDevices;

/// UserDefaults から 1 台削除（ペアリング済み一覧のスワイプ削除）
+ (BOOL)removeKnownDeviceWithAddress:(NSString *)address;

@end

NS_ASSUME_NONNULL_END
