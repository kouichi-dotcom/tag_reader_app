//
//  TSS_SDK.h
//  TSS_SDK
//
//  Created by Yoshiaki Endo on 2021/04/16.
//  Copyright © 2021 TOHOKU SYSTEMS SUPPORT. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DOTR_Util.h"

@protocol ReaderDelegate;

@interface TSS_SDK : NSObject

@property (nonatomic, weak) id<ReaderDelegate> delegate;
//@property (readonly, getter=isCentralManagerReady) BOOL centralManagerReady;
@property (readonly) BOOL isCentralManagerReady;

- (void)initReader:(NSString *)deviceName;

/**
 *  インスタンスを取得する
 *
 *  @return 生成＆初期化済みオブジェクト
 *
 *  各種通知を取得するにはプロパティの delegate へ
 *  デリゲートオブジェクトを設定してください
 */
+ (TSS_SDK *)shared;

/**
 *  インスタンスを取得する（デリゲート同時に指定）
 *
 *  @param delegate 通知を受けるデリゲートを設定
 *
 *  @return 生成＆初期化済みオブジェクト
 */
+ (TSS_SDK *)sharedWithDelegate:(id<ReaderDelegate>)delegate;

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
- (BOOL)setPowerOffDelay:(NSInteger)waitSec writeFlushMemory:(BOOL)write __attribute__ ((deprecated));
- (BOOL)setPowerOffDelay:(NSInteger)waitSec writeFlashMemory:(BOOL)write;

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
- (BOOL)setLinkProfile:(NSInteger)index;


/**
 * 2020.06.03 M.Yatsu
 * リーダーのLinkProfile値を取得する
 *
 * @return リーダーのLinkProfile index値（１～２）　　取得に失敗した場合は、－１
 */
- (NSInteger)getLinkProfile;



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

#pragma mark - ReaderDelegate
@protocol ReaderDelegate <NSObject>
@optional

- (void)didUpdateCentralManagerState;
- (void)didDiscoverDevice:(CBPeripheral *)peripheral;
- (void)onConnected;
- (void)onConnectFail;
- (void)onConnectFail:(NSString *)message;
- (void)onDisconnected;
- (void)onDisconnected:(NSString *)message;
- (void)onLinkLost;
- (void)onLinkLost:(NSString *)message;
- (void)onTriggerChanged:(BOOL)trigger;
- (void)onInventoryEPC:(NSString *)epc;
- (void)onReadTagData: (NSString *)data epc: (NSString *)epc;
- (void)onWriteTagData: (NSString *)epc;
- (void)onUploadTagData: (NSString *)data;
- (void)onTagMemoryLocked: (NSString *)epc;
- (void)onBarcodeScan:(NSString *)code;
- (void)onBarcodeScanTriggerChanged:(BOOL)trigger;
@end
