/*
 * DOTR-SDK for iOS
 * DOTR-900Ji, DOTR-2000, DOTR-3000
 *
 * (C)  2015 Tohoku Systems Support Co., Ltd. All rights reserved.
 *
 * この製品は、日本国著作権法および国際条約により保護されています。
 * この製品の全部または一部を無断で複製したり、無断で複製物を頒布すると、
 * 著作権の侵害となりますのでご注意ください。
 */

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#pragma mark - ENUM
/**
 * リーダーのビープ音量定義
 */
typedef NS_ENUM(NSInteger, DOTRBuzzerVolume){
    /**
     *  ビープ音を鳴らしません
     */
    DOTRBuzzerVolumeMute    = 0,
    /**
     *  音量：小でビープ音を鳴らします
     */
    DOTRBuzzerVolumeLow     = 1,
    /**
     *  音量：大でビープ音を鳴らします
     */
    DOTRBuzzerVolumeHigh    = 2,
    /**
     *  getBuzzerVolumeメソッドでの情報取得に失敗した場合に返されます
     *  setBuzzerVolumeメソッドの引数として指定しないでください
     */
    DOTRBuzzerVolumeUnknown = -1
};

/**
 * リーダーのバイブレーション定義
 */
typedef NS_ENUM(NSInteger, DOTRVibrator){
    /**
     *  バイブレーションをOFFにします
     */
    DOTRVibratorOff    = 0,
    /**
     *  バイブレーションをONにします
     */
    DOTRVibratorOn     = 1,
    /**
     *  getVibratorメソッドでの情報取得に失敗した場合に返されます
     *  setVibratorメソッドの引数として指定しないでください
     */
    DOTRVibratorUnknown = -1
};

/**
 *  タグのアクセス対象メモリを定義
 */
typedef NS_ENUM(NSInteger, DOTRMemoryBank){
    /**
     * タグ内の予約領域を示します
     */
    DOTRMemoryBankRESERVED = 0,
    /**
     * タグ内のEPC領域を示します
     */
    DOTRMemoryBankEPC      = 1,
    /**
     * タグ内のTID領域を示します
     */
    DOTRMemoryBankTID      = 2,
    /**
     * タグ内のUSER領域を示します
     */
    DOTRMemoryBankUSER     = 3
};

/**
 *  リーダーが出力する電波のチャネルを定義
 */
typedef NS_ENUM(NSUInteger, DOTRChannel){
    /**
     *  すべてのチャネルを使用します
     */
    DOTRChannelALL  = -1,
    
    /**
     *  Ch5(916.8MHz)を使用します
     */
    DOTRChannel05   = 5,
    /**
     *  Ch11(918.0MHz)を使用します
     */
    DOTRChannel11   = 11,
    /**
     *  Ch17(919.2MHz)を使用します
     */
    DOTRChannel17   = 17,
    /**
     *  Ch23(920.4MHz)を使用します
     */
    DOTRChannel23   = 23,
    /**
     *  Ch24(920.6MHz)を使用します
     */
    DOTRChannel24   = 24,
    /**
     *  Ch25(920.8MHz)を使用します
     */
    DOTRChannel25   = 25,
    /**
     *  Ch26(921.0MHz)を使用します
     */
    DOTRChannel26   = 26,
    /**
     *  Ch27(921.2MHz)を使用します
     */
    DOTRChannel27   = 27,
    /**
     *  Ch28(921.4MHz)を使用します
     */
    DOTRChannel28   = 28,
    /**
     *  Ch29(921.6MHz)を使用します
     */
    DOTRChannel29   = 29,
    /**
     *  Ch30(921.8MHz)を使用します
     */
    DOTRChannel30   = 30,
    /**
     *  Ch31(922.0MHz)を使用します
     */
    DOTRChannel31   = 31,
    /**
     *  Ch32(922.2MHz)を使用します
     */
    DOTRChannel32   = 32,
    /**
     *  Ch33(922.4MHz)を使用します
     */
    DOTRChannel33   = 33,
    /**
     *  Ch34(922.6MHz)を使用します
     */
    DOTRChannel34   = 34,
    /**
     *  Ch35(922.8MHz)を使用します
     */
    DOTRChannel35   = 35,
    /**
     *  Ch36(923.0MHz)を使用します
     */
    DOTRChannel36   = 36,
    /**
     *  Ch37(923.2MHz)を使用します
     */
    DOTRChannel37   = 37,
    /**
     *  Ch38(923.4MHz)を使用します
     */
    DOTRChannel38   = 38,

    /**
     *  getChannelメソッドでの情報取得に失敗した場合に返されます
     *  setChannelメソッドの引数として指定しないでください
     */
    DOTRChannelNone = 0
};

/**
 *  タグへのアクセス時に使用するセッション
 *  (各セッションの動作についてはリファレンスマニュアルを参照ください）
 */
typedef NS_ENUM(NSUInteger, DOTRSession){
    /**
     *  セッション0を使用してタグへアクセスします
     */
    DOTRSession0 = 0,
    /**
     *  セッション1を使用してタグへアクセスします
     */
    DOTRSession1 = 1,
    /**
     *  セッション2を使用してタグへアクセスします
     */
    DOTRSession2 = 2,
    /**
     *  セッション3を使用してタグへアクセスします
     */
    DOTRSession3 = 3,
    /**
     *  getSessionメソッドでの情報取得に失敗した時に返される値です
     *  setSessionメソッドの引数として指定しないでください
     */
    DOTRSessionNotSet = 999
};

/**
 *  リーダーがアクセス対象とするタグのフラグ状態(inventory flag)
 */
typedef NS_ENUM(NSUInteger, DOTRTagAccessFlag){
    /**
     *  flagA状態のタグのみアクセスします
     */
    DOTRTagAccessFlagA = 0,
    /**
     *  flagB状態のタグのみアクセスします
     *  他のリーダーがアクセスしたタグにアクセスしたい場合などに使用します
     */
    DOTRTagAccessFlagB = 1,
    /**
     *  flag状態に関わらず、タグへのアクセスを行ないます
     *  これにより、タグへのアクセスパフォーマンスが向上します
     *  電源 ON 時のデフォルト設定です
     */
    DOTRTagAccessFlagAandB = 2,
    /**
     *  getTagAccessFlagメソッドでの情報取得に失敗したときに返される値です
     *  setTagAccessFlagメソッドの引数として指定しないでください
     */
    DOTRTagAccessFlagNotSet = 999
};

/**
 *  タグのアクセス方法を定義
 */
typedef NS_ENUM(NSUInteger, DOTRMaskFlag){
    /**
     *  すべてのタグにアクセスします
     */
    DOTRMaskFlagNone         = 0,
    /**
     *  指定されているマスク情報に一致しないタグのみアクセスします
     */
    DOTRMaskFlagUnSelectMask = 2,
    /**
     *  指定されているマスク情報に一致するタグのみアクセスします
     */
    DOTRMaskFlagSelectMask   = 3,
};


@protocol DOTRDelegateProtocol;
@class DOTRTagLockPattern;
@class DOTRTagAccessParameter;

#pragma mark - DOTR Interface
/**
 *  @class DOTR_Utilクラス
 */
@interface DOTR_Util : NSObject

@property (nonatomic, weak) id<DOTRDelegateProtocol> delegate;
@property (readonly, getter=isCentralManagerReady) BOOL centralManagerReady;

/**
 *  インスタンスを取得する
 *
 *  @return 生成＆初期化済みオブジェクト
 *
 *  各種通知を取得するにはプロパティの delegate へ
 *  デリゲートオブジェクトを設定してください
 */
+ (DOTR_Util *)shared;

/**
 *  インスタンスを取得する（デリゲート同時に指定）
 *
 *  @param delegate 通知を受けるデリゲートを設定
 *
 *  @return 生成＆初期化済みオブジェクト
 */
+ (DOTR_Util *)sharedWithDelegate:(id<DOTRDelegateProtocol>)delegate;

#pragma mark - DOTRリーダーの検索・接続・切断
/**
 *  既知のデバイスを取得する
 *
 *  CoreBluetooth > retrievePeripheralsWithIdentifiers: に準拠します
 *
 *  @param identifiers 検索対象ペリフェラルのIdentifierのリスト
 *
 *  @return 既知のデバイス(CBPeripheral)のリスト
 */
- (NSArray *)retrievePeripheralsWithIdentifiers:(NSArray *)identifiers;

/**
 *  システムへ接続済みのデバイスを取得する
 *
 *  retrieveConnectedPeripheralsWithServices:serviceUUIDs:
 *  をDOTRデバイスに対して呼び出した結果を返します。
 *
 *  @return 接続済みデバイス(CBPeripheral)のリスト
 */
- (NSArray *)retrieveConnectedPeripherals;

/**
 *  DOTRデバイスをスキャンする
 *
 *  接続対象デバイスのスキャンを開始します
 *  スキャン結果は didDiscoverDevice: で通知されます
 *
 *  @warning スキャン動作は自動停止やタイムアウトしないため、
 *  アプリが終了・中断される場合は必ず stopScan を呼んでください
 */
- (void)scan;

/**
 *  デバイスのスキャンを停止する
 */
- (void)stopScan;

/**
 *  デバイスへの接続
 *
 *  DOTRデバイスへ接続し、通信確立処理を行います
 *  実行結果は onConnect, onConnectFail, onDisconnected で通知されます
 *
 *  @param peripheral 接続対象のデバイス
 */
- (BOOL)connect:(CBPeripheral *)peripheral;

/**
 *  接続中デバイスの切断
 *
 *  デバイス切断します
 *  結果は onDisconnected で通知されます
 *  アプリケーションの終了時は、確実にリーダーとの接続を解除するようにしてください
 *
 *  @return
 *      YES :接続解除要求成功
 *      NO  :接続解除要求失敗
 */
- (BOOL)disconnect;

/**
 *  デバイスの接続有無
 *
 *  @return YES:接続あり, NO:接続無し
 */

- (BOOL)isConnect;

#pragma mark - DOTRリーダー操作：設定・設定値取得

/**
 *  同一タグの二度読みを禁止するかどうかの設定内容を取得する
 *
 *  @return
 *      YES :同一EPCタグをアクセスしたときにイベントを発生しない
 *      NO  :同一EPCタグのアクセスしたときにイベントを発生する
 */
- (BOOL)isNoRepeat;

/**
 *  同一タグの二度読みを禁止するかどうかの設定内容を設定する
 *
 *  @param repeat
 *      YES :同一EPCタグをアクセスしたときにイベントを発生しない
 *      NO  :同一EPCタグのアクセスしたときにイベントを発生する
 */
- (void)setNoRepeat:(BOOL)repeat;

/**
 *  リーダーが接続、切断、タグへのアクセスなどを行なった際に発生させるブザー音量を設定します
 *
 *  @param volume 設定するブザー音量
 *  @param write  YES:設定値をリーダーのフラッシュメモリ内に書きこむ
 *
 * @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
- (BOOL)setBuzzerVolume:(DOTRBuzzerVolume)volume writeFlashMemory:(BOOL)write;

/**
 *  リーダーのブザー音量を取得します
 *  @return リーダーブザー音量    取得に失敗した場合は DOTRBuzzerVolumeUnknown
 */
- (DOTRBuzzerVolume)getBuzzerVolume;

/**
*  リーダーへバイブレーターのON/OFFを設定します
*
*  @param vibrator 設定するバイブレーターのON/OFF
*  @param write  YES:設定値をリーダーのフラッシュメモリ内に書きこむ
*
* @return
*      YES :正常終了した場合
*      NO  :正常終了しなかった場合
*/
- (BOOL)setVibrator:(DOTRVibrator)vibrator writeFlashMemory:(BOOL)write;

/**
 *  リーダーのバイブレーターON/OFFを取得します
 *  @return リーダーのバイブレーター    取得に失敗した場合は DOTRVibratorUnknown
 */
- (DOTRVibrator)getVibrator;

/**
 *  無操作状態で、リーダーが自動的に電源をOFFにするまでの時間を設定する
 *
 *  @param waitSec 自動電源ＯＦＦまでの秒数  （０～７２００（２時間））まで設定可能
 *  @param write YES:設定値をリーダーのフラッシュメモリ内に書きこむ
 *
 *  @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 *
 *  @warning DOTR-2000/DOTR-3000シリーズでは使用できません
 *
 */
- (BOOL)setPowerOffDelay:(NSInteger)waitSec  writeFlashMemory:(BOOL)write;
- (BOOL)setPowerOffDelay:(NSInteger)waitSec  writeFlushMemory:(BOOL)write __attribute__ ((deprecated));

/**
 *  無操作状態で、リーダーが自動的に電源をOFFにするまでの時間を取得する
 *
 *  @return リーダーが自動電源ＯＦＦされるまでの秒数     取得に失敗した場合は－１
 *
 *  @warning DOTR-2000/DOTR-3000シリーズでは使用できません
 *
 */
- (NSInteger)getPowerOffDelay;

/**
 *  リーダーの現在の電波出力強度を設定する
 *
 *  @param decreaseDecibel 電波出力を最大値からどれだけ減衰させるかを 1dBm 単位で指定
 *
 *  @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
- (BOOL)setRadioPower:(NSInteger)decreaseDecibel;

/**
 *  リーダーの現在の電波出力強度を取得する
 *
 *  @return リーダーの電波出力強度（ｄＢｍ）取得に失敗した場合は－１
 */
- (NSInteger)getRadioPower;

/**
 *  リーダーが出力する電波のチャネルを設定する
 *
 *  リーダーが出力する電波のチャネルを設定します
 *  本メソッドで変更された出力チャネルの設定は、リーダーの電源を入れなおすことでリセットされます
 *  DOTRChannel 列挙型の詳細については、 リファレンスマニュアルを参照してください
 *
 * @param channels 出力するチャネル番号   ON にするチャネルをDOTRChannelのリストで指定する
 *
 * @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
- (BOOL)setRadioChannel:(NSArray *)channels;

/**
 *  リーダーが出力する電波のチャネルを取得する
 *
 *  @return リーダーが出力する電波チャネル
 */
- (NSArray *)getRadioChannel;

/**
 *  タグへアクセスする際のQ値を設定する
 *
 *  タグへのアクセス時に使用する Q 値を設定します
 *  Q 値はタグを読み取る際の衝突回避(Anti-Collision)のために使用され、
 *  qValue の値が大きいほど、大量のタグを衝突なく読み取ることができます
 *  (対応するタグの枚数は 2^qValue で表され、最大は 2^15 = 32768 枚 となります)
 *
 *  なお、本メソッドで設定した Q 値は、リーダーとの接続を解除するとデフォルト値の 5(2^5 = 32 枚)に 戻ります
 *  接続の都度、本メソッドにて設定をお願いします
 *
 *  @param qValue タグへのアクセス時に使用する Q 値(0~15)
 *
 *  @return 正常終了した場合は YES
 */
- (BOOL)setQValue:(NSInteger)qValue;

/**
 *  タグへアクセスする際の Q 値を取得する
 *
 *  リーダーがタグへアクセスする際の Q 値を取得します
 *  Q 値の意味と役割については、setQValue メソッドを参照ください
 *
 *  @returnタグへアクセスする際の Q 値    取得に失敗した場合は-1
 */
- (NSInteger)getQValue;

/**
 *  タグへのアクセスする際のセッション情報を設定する
 *
 *  @param session タグへのアクセス時に使用するセッション情報
 *
 *  @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
- (BOOL)setSession:(DOTRSession)session;

/**
 *  タグへのアクセスする際のセッション情報を取得する
 *
 *  @return タグへアクセスする際のセッション情報取得に失敗した場合は DOTRSessionNotSet
 */
- (DOTRSession)getSession;

/**
 *  アクセス対象とするタグのフラグを設定する
 *
 *  タグが持つフラグ状態(inventory flag)を元に、どのフラグ状態のタグをアクセス対象にするかを変更します
 *  flag に設定できる値とその意味については、リファレンスマニュアルを参照してください
 *
 *  @param accessFlag アクセス対象とするタグのフラグ状態
 *
 *  @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 *
 *  @warning 本メソッドで設定した値は、リーダーの電源を入れ直すと
 *  デフォルト値(FlagA, FlagB両方のタグを読み取る)に戻りますのでご注意ください
 */
- (BOOL)setTagAccessFlag:(DOTRTagAccessFlag)accessFlag;

/**
 *  アクセス対象とするタグのフラグを取得します
 *
 *  リーダーがアクセス対象とするタグのフラグ状態を取得します
 *  取得される EnTagAccessFlag 列挙体の値とその意味については、リファレンスマニュアルを参照ください
 *
 *  @return アクセス対象とするタグのフラグ状態取得に失敗した場合は DOTRTagAccessFlagNotSet
 */
- (DOTRTagAccessFlag)getTagAccessFlag;

/**
 *  リーダーの電波照射間隔を設定する
 *  （電波休止時間は内部で自動設定されます）
 *
 *  @param onTime 電波照射時間（４０～４００ミリ秒）
 *
 *  @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
- (BOOL)setTxCycle:(NSInteger)onTime;

/**
 *  リーダーの電波照射時間を取得する
 *
 *  @return リーダーの電波照射時間（ミリ秒）    取得に失敗した場合は、－１
 */
- (NSInteger)getTxCycle;


/**
 * 2020.06.03 M.Yatsu
 * リーダーのLinkProfile値を設定する
 *
 * @param index 設定するLinkProfileのindex値（１～２）
 *
 * @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
-(BOOL)setLinkProfile:(NSInteger)index;


/**
 * 2020.06.03 M.Yatsu
 * リーダーのLinkProfile値を取得する
 *
 * @return リーダーのLinkProfile index値（１～２）　　取得に失敗した場合は、－１
 */
-(NSInteger)getLinkProfile;



/**
 *  リーダーのファームウェアバージョンを取得する
 *
 *  @return リーダーのファームウェアバージョン
 */
- (NSString *)getFirmwareVersion;


/**
 *  リーダーの電波出力強度の最大値を取得する
 *
 *  @return リーダーの最大電波出力強度（dBm）  取得に失敗した場合は－１
 */
- (NSInteger)getMaxRadioPower;

/**
 *  リーダーのバッテリー残量（％単位）を取得する
 *
 *  @return リーダーバッテリー残量（％単位）    取得に失敗した場合は－１
 */
- (NSInteger)getBatteryLevel;

/**
 *  inventoryTagメソッドでの読み取り時に、タグ読取り時間やタグからの受信電波強度を取得するかどうかを設定する
 *
 *  inventoryTagメソッドを使用してタグ読取りを行った際、タグを読み取った時間とタグからの受信電波強度を取得するかどうかを設定できます
 *  なお、リーダーの電源を入れ直すと初期設定(共に取得しない)になりますのでご注意ください
 *  reportTime 引数、reportRSSI 引数を YES にした場合、inventoryEPC イベントで取得される EPC データに 情報が付加されます
 *  詳細については onInventoryEPC イベントの項を参照ください
 *
 *  @param reportTime タグ読取り時間（ＧＭＴ）を取得するかどうか
 *  @param reportRSSI タグからの受信電波強度（ＲＳＳＩ値）を取得するかどうか
 *
 *  @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
- (BOOL)setInventoryReportMode:(BOOL)reportTime reportRSSI:(BOOL)reportRSSI;

/**
 *  デバッグモードでの実行を行なうかどうかを設定する
 *
 *  デバッグモードでの実行を行なうかどうかを設定します  デフォルトは NO(非デバッグモード)です
 *  モードの変更は、connectメソッドでリーダーとの接続を行う前に行なってください
 *  isDebugMode パラメータを YES にしてこのメソッドを実行することで、アプリケーションのデバッグ時に処理を中断しても、
 *  リーダーの接続が切れないようになります
 *
 *  @param debug デバッグモードでの実行を行なうかどうか
 *
 *  @return 正常終了した場合は YES
 *
 *  @warning: デバッグモード中は、リーダーを Bluetooth 範囲外に移動させた場合に onLinkLost イベントが発生しな くなります
 *  (Bluetooth 範囲内で、リーダーの電源を OFF にした場合は onLinkLost が発生します)
 *  アプリケーションの開発終了時には NO に戻してください
 *
 *  @warning DOTR-2000/DOTR-3000シリーズでは使用できません
 *
 */
- (BOOL)setDebugMode:(BOOL)debug;

/**
 *  リーダーの設定を初期状態に戻す
 *
 *  @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
- (BOOL)setDefaultParameter;

#pragma mark - DOTRリーダー操作：タグ読み取り
/**
 *  EPCメモリ一括読取りを行なう
 *
 *  @param singleTag YES:一枚のタグ読取りが完了したら読取りを終了
 *  @param maskFlag  読取り対象タグの制限方法
 *  @param timeout   読取り処理のタイムアウト時間（ミリ秒）    ０の場合はタイムアウト無し
 *
 *  @return
 *      YES :読取が正常に開始された場合
 *      NO  :読取が正常に開始されなかった場合
 */
- (BOOL)inventoryTag:(BOOL)singleTag maskFlag:(DOTRMaskFlag)maskFlag timeout:(int)timeout;

/**
 *  メモリ領域を指定してタグを読み取る
 *
 *  @param accessParam タグへのアクセス方法（対象メモリ、オフセット、データ長など）
 *  @param singleTag YES:一枚のタグ読取りが完了したら読取りを終了
 *  @param maskFlag 読取り対象タグの制限方法
 *  @param timeout 読取り処理のタイムアウト時間（ミリ秒）   ０の場合はタイムアウト無し
 *
 *  @return
 *      YES :読取が正常に開始された場合
 *      NO  :読取が正常に開始されなかった場合
 */
- (BOOL)readTag:(DOTRTagAccessParameter *)accessParam singleTag:(BOOL)singleTag maskFlag:(DOTRMaskFlag)maskFlag timeout:(int)timeout;

#pragma mark - DOTRリーダー：タグ書き込み
/**
 *  メモリ領域を指定してタグを書き込む
 *
 *  @param accessParam タグへのアクセス方法（対象メモリ、オフセット、データ長など）
 *  @param writeData タグに書き込むデータ  １６進数形式の文字列で指定
 *  @param singleTag YES:一枚のタグ書き込みが完了したら書き込みを終了
 *  @param maskFlag 書き込み対象タグの制限方法
 *  @param timeout 書き込み処理のタイムアウト時間（ミリ秒）  ０の場合はタイムアウト無し
 *
 *  @return
 *      YES :書き込みが正常に開始された場合
 *      NO  :書き込みが正常に開始されなかった場合
 */
- (BOOL)writeTag:(DOTRTagAccessParameter *)accessParam writeData:(NSString *)writeData singleTag:(BOOL)singleTag maskFlag:(DOTRMaskFlag)maskFlag timeout:(int)timeout;

/**
 *  タグのメモリ領域をロック／アンロックします
 *
 *  @param lockFlags ロック／アンロックの対象メモリとロック／アンロック方法 (メンバは DOTRTagLockPattern を参照)
 *  @param password  ロック／アンロック処理に必要なパスワード
 *  @param singleTag YESの場合、一枚のタグをロック／アンロックしたら処理を終了
 *  @param maskFlag  ロック／アンロック対象タグの制限方法
 *  @param timeout   ロック／アンロック処理のタイムアウト時間（ミリ秒）   0の場合はタイムアウト無し
 *
 *  @return ロック／アンロック処理が正常に開始された場合はYES
 */
- (BOOL)lockTagMemory:(DOTRTagLockPattern *)lockFlags password:(long)password singleTag:(BOOL)singleTag maskFlag:(DOTRMaskFlag)maskFlag timeout:(int)timeout;

/**
 *  アクセス対象のタグを制限するマスク情報を設定する
 *
 *  @param memoryBank マスク対象のメモリ領域
 *  @param maskOffset マスクパターンを適用する、メモリ領域のオフセット（ビット）
 *  @param maskBits マスクパターンのビット数
 *  @param maskPattern マスクパターンの１６進数形式の文字列
 *
 *  @return
 *      YES :設定が正常に行なわれた場合
 *      NO  :設定が正常に行なわれなかった場合
 */
- (BOOL)setTagAccessMask:(DOTRMemoryBank)memoryBank maskOffset:(int)maskOffset maskBits:(int)maskBits maskPattern:(NSString *)maskPattern;

#pragma mark - DOTRリーダー：バーコード読取り
/**
 *  バーコードスキャナの読み取りを開始する
 *
 *  @warning DOTR-900シリーズでは使用できません
 *
 */
- (BOOL)startBarcodeScan;

/**
 *  バーコードスキャナの読取を停止する
 *
 *  @warning DOTR-900シリーズでは使用できません
 *
 */
- (BOOL)stopBarcodeScan;

#pragma mark - DOTRリーダー：その他
/**
 *  リーダーのメモリ内に格納されたタグの情報を取得する
 *
 * @return
 * YES :正常終了した場合
 * NO  :正常終了しなかった場合
 */
- (BOOL)uploadMemoryTag;

/**
 *  リーダーのメモリ内に格納されたタグの情報をクリアする
 *
 *  @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
- (BOOL)clearMemoryTag;

/**
 *  現在までに読み取られたタグの情報をクリアする
 */
- (void)clearAccessEPCList;

/**
 *  DOTRへストップコマンドを送信する
 *
 *  @return
 *      YES :正常終了した場合
 *      NO  :正常終了しなかった場合
 */
- (BOOL)stop;

- (NSString*)getMacAddress;

@end

#pragma mark - DOTRTagLockPattern
/**
 *  ロック・ロック解除の設定値
 */
typedef NS_ENUM(NSInteger, DOTRTagLockFlags){
    /**
     *  設定変更しない
     */
    DOTRTagLockFlagNoChange = 0,
    /**
     *  ロック解除する
     */
    DOTRTagLockFlagUnLock,
    /**
     *  ロックする
     */
    DOTRTagLockFlagLock,
};

@interface DOTRTagLockPattern : NSObject
/**
 *  タグのロック・ロック解除する対象の設定
 *  初期値： DOTRTagLockFlagsNoChange（設定変更しない）
 */
@property DOTRTagLockFlags EPC;               // EPCメモリ
@property DOTRTagLockFlags TID;               // TIDメモリ
@property DOTRTagLockFlags USER;              // USERメモリ
@property DOTRTagLockFlags AccessPassword;    // RESERVEDメモリのAccess Password部分
@property DOTRTagLockFlags KillPassword;      // RESERVEDメモリのKill Password部分
@end

#pragma mark - TagAccessParameter
@interface DOTRTagAccessParameter : NSObject

/**
 *  アクセス対象のメモリ領域
 *  初期値：DOTRMemoryBankEPC
 */
@property DOTRMemoryBank memoryBank;

/**
 *  アクセス対象のオフセット位置(ワード単位)
 */
@property int wordOffset;

/**
 *  アクセスするワード数
 */
@property int wordCount;

/**
 *  範囲は0~4294967295L、パスワードが設定されていない場合は0を設定
 */
@property unsigned int password;

- (id)initWithParameter:(int)wordCount
             memoryBank:(DOTRMemoryBank)memoryBank
             wordOffset:(int)wordOffset
               password:(unsigned int)password;
@end

#pragma mark - DOTRDelegateProtocol
/**
 *  @protocol DOTRDelegateProtocol
 *
 * リーダーとの接続状態、動作状態変化の通知
 */
@protocol DOTRDelegateProtocol <NSObject>
@optional
/**
 *  Bluetooth利用可否の状態変化通知
 *
 *  isCentralManagerReadyの値が変化した場合に呼ばれます
 *  isCentralManagerReady:NOの場合はBluetooth動作が不可となります
 *  動作不可の場合にはリーダーへ接続しないようにしてください
 */
- (void)didUpdateCentralManagerState;

/**
 *  発見したデバイスの通知
 *
 *  スキャンの結果、接続対象の候補として発見したデバイスを通知します
 *
 *  @param peripheral        発見したペリフェラル（デバイス）
 */
- (void)didDiscoverDevice:(CBPeripheral *)peripheral;

/**
 *  DOTRデバイスへの接続成功通知
 */
- (void)onConnected;

/**
 *  DOTRデバイスへの接続失敗通知
 *
 *  @param message 付加情報情報（デバッグ用途のテキスト情報）
 *
 */
- (void)onConnectFail;
- (void)onConnectFail:(NSString *)message;

/**
 *  DOTRデバイスの切断完了通知
 *
 *  disconnectメソッドによってリーダーとの接続が解除された場合に呼ばれます
 *  アプリケーションの終了時は、確実にリーダーとの接続を解除するようにしてください
 *
 *  @param message 付加情報情報（デバッグ用途のテキスト情報）
 *
 */
- (void)onDisconnected;
- (void)onDisconnected:(NSString *)message;

/**
 *  通信断通知
 *
 *  リーダーとの接続後、リーダーの電源が OFF になったり、
 *  リーダーが Bluetooth の通信エリア外に移動したりしたことによってリンク切れとなった場合に呼ばれます
 *
 *  @param message 付加情報情報（デバッグ用途のテキスト情報）
 *
 */
- (void)onLinkLost;
- (void)onLinkLost:(NSString *)message;

/**
 *  トリガ状態変化通知
 *
 *  リーダーとの接続後にリーダーのトリガが押された、もしくは離された場合に発生し、
 *  引数にトリガのON/OFF 状態が返されます
 *  このイベントを使用することで、トリガを押している間だけタグの読取りや書込みを行う、
 *  といった制御が可能です
 *
 *  @param trigger トリガの ON/OFF 状態  YES でトリガ ON
 */
- (void)onTriggerChanged:(BOOL)trigger;

/**
 *  InventoryEPCイベント通知
 *
 *  inventoryTagメソッドにより、タグの EPC データを読み取った際に発生します
 *  なお、EPC データは PC(Protocol Control)領域および UII(Unique Item Identifier)領域を
 *  連結した文字列で、バイナリデータが 16 進数形式の文字列として返されます
 *
 *  setInventoryReportMode: でタグの読取り時間、およびタグからの受信電波強度 (RSSI 値)を
 *  取得する設定を行った場合、取得される EPC データに文字列が付加されます
 *
 *  データ文字列に付加されるTIME の値は NSTimeInterval値の文字列で、
 *  timeIntervalSince1970 = 1970/01/01(GMT)からの経過秒数です
 *
 *  @param epc 読み取ったタグの EPC データ
 */
- (void)onInventoryEPC:(NSString *)epc;

/**
 *  ReadTagDataイベント通知
 *
 *  readTagメソッドによってタグのデータを読み取った場合に発生し、
 *  読み取ったデータと、読み取りを行ったタグのEPCデータが返されます
 *
 *  @param data 読み取ったデータ
 *  @param epc 読み取ったタグの EPC デ ータ
  */
- (void)onReadTagData: (NSString *)data epc: (NSString *)epc;

/**
 *  WriteTagDataイベント通知
 *
 *  writeTagメソッドによってタグへデータを書き込んだ場合に発生し、
 *  書き込みが行なわれたタグの EPCデータが返されます
 *
 *  @param epc 書き込みが行なわれたタグの EPC データ
 */
- (void)onWriteTagData: (NSString *)epc;

/**
 *  UploadTagDataイベント通知
 *
 *  uploadTagDataメソッドにより、非接続時または Bluetooth 圏外での読取りで
 *  リーダーのメモリ内に格納されたタグの情報を取得した際に発生します
 *
 *  @param data リーダーのメモリ内に格納されたタグの情報
 */
- (void)onUploadTagData: (NSString *)data;

/**
 *  TagMemoryLockedイベント通知
 *
 *  lockTagMemoryメソッドによってタグのメモリ領域がロック/アンロックされた場合に発生し、
 *  ロック/アンロックを行なった対象タグの EPC データが返されます
 *
 *  @param epc メモリロック/アンロックが行なわれたタグの EPC データ
 */
- (void)onTagMemoryLocked: (NSString *)epc;


/**
 *  onBarcodeScanイベント通知
 *
 *  startBarcodeScan()メソッドによってリーダーのバーコードスキャナが動作開始した後、
 *  バーコードが読み取られた場合に発生します。
 *
 *  @param code バーコードスキャナで読み取られたバーコードのデータ
 *
 *  @warning DOTR-900シリーズでは使用できません
 *
 */
- (void)onBarcodeScan:(NSString *)code;

/**
 *  onBarcodeScanTriggerChangedイベント通知
 *
 *  リーダーとの接続後にリーダーのバーコードボタンが押された、もしくは離された場合に発生し、
 *  引数にトリガのON/OFF 状態が返されます
 *  このイベントを使用することで、トリガを押している間だけバーコードの読取りを行う制御が可能です
 *
 *  @param trigger トリガの ON/OFF 状態  YES でトリガ ON
 *
 *  @warning DOTR-900シリーズでは使用できません
 *
 */
- (void)onBarcodeScanTriggerChanged:(BOOL)trigger;
@end

