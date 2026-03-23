#import "TssRfidNativeBridge.h"
#import "TssRfidSdkSession.h"

static NSString *const kKnownDevicesKey = @"tss_rfid_ios_known_devices";
static void (^sEventCallback)(NSDictionary *event);

@implementation TssRfidNativeBridge

+ (void)setEventSinkCallback:(void (^)(NSDictionary *event))callback {
  sEventCallback = [callback copy];
  [[TssRfidSdkSession shared] setEmitHandler:sEventCallback];
}

+ (void)startBleScan {
  [[TssRfidSdkSession shared] startBleScan];
}

+ (void)stopBleScan {
  [[TssRfidSdkSession shared] stopBleScan];
}

+ (BOOL)connectWithName:(NSString *)name
                address:(NSString *)address
               outError:(NSError *__autoreleasing *)outError {
  return [[TssRfidSdkSession shared] connectWithName:name address:address outError:outError];
}

+ (BOOL)disconnect {
  return [[TssRfidSdkSession shared] disconnect];
}

+ (BOOL)isConnected {
  return [[TssRfidSdkSession shared] isConnected];
}

+ (nullable NSString *)firmwareVersion {
  return [[TssRfidSdkSession shared] firmwareVersion];
}

+ (BOOL)startInventoryDateTime:(BOOL)dateTime
                   radioPower:(BOOL)radioPower
                      channel:(BOOL)channel
                         temp:(BOOL)temp
                        phase:(BOOL)phase
                     noRepeat:(BOOL)noRepeat
                       outError:(NSError *__autoreleasing *)outError {
  return [[TssRfidSdkSession shared] startInventoryDateTime:dateTime
                                                 radioPower:radioPower
                                                    channel:channel
                                                       temp:temp
                                                      phase:phase
                                                   noRepeat:noRepeat
                                                   outError:outError];
}

+ (BOOL)stopInventory {
  return [[TssRfidSdkSession shared] stopInventory];
}

+ (nullable NSNumber *)radioPower {
  return [[TssRfidSdkSession shared] radioPower];
}

+ (nullable NSNumber *)maxRadioPower {
  return [[TssRfidSdkSession shared] maxRadioPower];
}

+ (BOOL)setRadioPowerDecreaseDecibel:(NSInteger)decreaseDecibel
                            outError:(NSError *__autoreleasing *)outError {
  return [[TssRfidSdkSession shared] setRadioPowerDecreaseDecibel:decreaseDecibel outError:outError];
}

+ (NSArray<NSDictionary *> *)knownBondedStyleDevices {
  return [[TssRfidSdkSession shared] mergedKnownBondedStyleDevices];
}

+ (void)rememberDeviceName:(NSString *)name address:(NSString *)address {
  if (name.length == 0 || address.length == 0) {
    return;
  }
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *raw = [[defaults arrayForKey:kKnownDevicesKey] mutableCopy];
  if (!raw) {
    raw = [NSMutableArray array];
  }
  NSMutableSet *addrs = [NSMutableSet set];
  for (id item in raw) {
    if ([item isKindOfClass:[NSDictionary class]]) {
      NSString *a = ((NSDictionary *)item)[@"address"];
      if (a.length > 0) {
        [addrs addObject:a];
      }
    }
  }
  if (![addrs containsObject:address]) {
    [raw addObject:@{@"name": name, @"address": address}];
    [defaults setObject:[raw copy] forKey:kKnownDevicesKey];
    [defaults synchronize];
  }
}

+ (void)clearKnownDevices {
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kKnownDevicesKey];
}

@end
