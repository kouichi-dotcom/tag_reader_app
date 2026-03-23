#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// TSS iOS SDK（TSS_SDK）のシングルトンラッパー。ReaderDelegate でイベントを emit へ転送する。
@interface TssRfidSdkSession : NSObject

+ (instancetype)shared;

/// Flutter EventChannel へ渡すブリッジ（TssRfidNativeBridge から設定）
- (void)setEmitHandler:(void (^)(NSDictionary *event))handler;

- (void)startBleScan;
- (void)stopBleScan;

- (BOOL)connectWithName:(NSString *)name
                address:(NSString *)address
               outError:(NSError *_Nullable *_Nullable)outError;

- (BOOL)disconnect;
- (BOOL)isConnected;
- (nullable NSString *)firmwareVersion;

- (BOOL)startInventoryDateTime:(BOOL)dateTime
                   radioPower:(BOOL)radioPower
                      channel:(BOOL)channel
                         temp:(BOOL)temp
                        phase:(BOOL)phase
                     noRepeat:(BOOL)noRepeat
                     outError:(NSError *_Nullable *_Nullable)outError;

- (BOOL)stopInventory;

- (nullable NSNumber *)radioPower;
- (nullable NSNumber *)maxRadioPower;

- (BOOL)setRadioPowerDecreaseDecibel:(NSInteger)decreaseDecibel
                            outError:(NSError *_Nullable *_Nullable)outError;

/// UserDefaults + retrieveConnectedPeripherals をマージした bonded 風一覧
- (NSArray<NSDictionary *> *)mergedKnownBondedStyleDevices;

@end

NS_ASSUME_NONNULL_END
