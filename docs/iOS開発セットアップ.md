# iOS 開発セットアップ（iPhone 向けビルド）

## 前提

- **macOS** と **Xcode**（App Store からインストール）
- **Apple Developer** アカウント（実機配布・TestFlight 用）
- 本プロジェクトは **Flutter**。リポジトリを clone したら `flutter pub get`

## 1. CocoaPods（必須）

Flutter の iOS ビルドでは `ios/Podfile` に基づき **CocoaPods** が使われます。

```bash
cd ios
pod install
cd ..
```

初回のみ、または依存変更後に実行します。

## 2. TSS iOS SDK の配置

ベンダー提供の **SDK_for_iOS_6.2.0** を、次のディレクトリに配置します。

- `ios/third_party/SDK_for_iOS_6.2.0/`

Windows から共有フォルダを参照できる場合、リポジトリ直下で:

```powershell
.\tools\setup_ios_sdk.ps1
```

別の場所からコピーする場合:

```powershell
.\tools\setup_ios_sdk.ps1 -SourceRoot "D:\path\to\SDK_for_iOS_6.2.0"
```

### Git に含める場合

SDK をチームで Git 管理する場合、配置後に追加コミットします。

```bash
git add ios/third_party/SDK_for_iOS_6.2.0
git commit -m "Add TSS iOS SDK 6.2.0 vendor files"
```

バイナリが大きい場合は **Git LFS** の利用を検討してください。

## 3. Xcode での SDK リンク（静的ライブラリ）

**Runner** ターゲットに、ベンダー同梱の **`libTSS_SDK.a`** をリンクします。`project.pbxproj` では次を満たすよう設定済みです（変更時は Xcode の **Build Settings** で確認してください）。

| 設定 | 値（例） |
|------|----------|
| **Link Binary With Libraries** | `third_party/SDK_for_iOS_6.2.0/Library/DOTR_IOS/libTSS_SDK.a` |
| **LIBRARY_SEARCH_PATHS** | `$(PROJECT_DIR)/third_party/SDK_for_iOS_6.2.0/Library/DOTR_IOS` |
| **HEADER_SEARCH_PATHS** | 上記 SDK ルートに加え、`.../Library/DOTR_IOS/Headers`（`#import "TSS_SDK.h"` 用） |
| **OTHER_LDFLAGS** | `$(inherited)` と **`-ObjC`**（カテゴリ等の未解決シンボル対策） |

サンプルは `third_party/.../Source Code/DOTRSamples/InventoryTag/` を参照。

- **Bridging Header** … `Runner-Bridging-Header.h`（必要に応じて）
- **Info.plist** … Bluetooth 等の利用目的文言・権限（`NSBluetoothAlwaysUsageDescription` 等）

## 4. Flutter との連携（実装済み）

Android の `MainActivity.kt` と同じ名前で、次を登録しています。

| 名前 | 役割 |
|------|------|
| `tss_rfid/method` | `MethodChannel`（接続・在庫・電波強度など） |
| `tss_rfid/events` | `EventChannel`（`inventory_epc`、`ble_device_found` 等） |

- `ios/Runner/TssRfidPlugin.swift` … チャネル登録・Flutter からの呼び出し
- `ios/Runner/TssRfidNativeBridge.m` + **`TssRfidSdkSession.m`** … `TSS_SDK` / `ReaderDelegate` へのブリッジ（**静的リンク済み**）

### Android との API 差分（在庫レポート）

Android の `setInventoryReportMode` は複数フラグがありますが、**iOS の `TSS_SDK` は引数が異なります**。実装では Dart 側の `dateTime` / `radioPower` を iOS の **`setInventoryReportMode:reportTime:reportRSSI:`** にマップしています。**`channel` / `temp` / `phase`** は iOS API に無いため、無視（ベストエフォート）です。

### BLE スキャンは TSS_SDK に統一

別の `CBCentralManager` で見つけた端末と、SDK の `connect:` が必ず整合するとは限らないため、**`ble_device_found` は `[TSS_SDK scan]` / `didDiscoverDevice:` 経路**に統一しています（`startBleScan` → `TssRfidSdkSession`）。接続は **`retrievePeripheralsWithIdentifiers:`** で UUID から `CBPeripheral` を復元してから `connect:` します。先にスキャンで端末を検出してから接続してください。

**接続の非同期**: `connect:` は即時 `BOOL` ですが実接続完了はデリゲートです。ブリッジ側で `onConnected` / `onConnectFail` を短時間待ってから FW 取得等に進みます（Flutter が `connect` 直後に `getFirmwareVersion` を呼んでも破綻しないよう配慮）。

アドレスは iOS では **UUID 文字列**です。

## 5. トラブルシュート

- **リンクエラー（Undefined symbols / ObjC カテゴリ）** … `OTHER_LDFLAGS` に `-ObjC` が入っているか、`LIBRARY_SEARCH_PATHS` に `libTSS_SDK.a` のディレクトリがあるか確認してください。
- **Bluetooth を許可してもスキャンが始まらない** … `Info.plist` の `NSBluetoothAlwaysUsageDescription` を確認し、設定アプリで Bluetooth をオンにしてください。
- **接続できない・UUID が見つからない** … 一度 **SDK のスキャン**で端末を検出してから接続してください。別経路の `CBPeripheral` だけでは不整合になる場合があります。
- **SR-7 だけ不安定・R-5000 は安定** … iOS の `retrievePeripheralsWithIdentifiers` だけだと `CBPeripheral` が古い／名前が空の状態になり、`initReader:` に必要な端末名とズレて `onConnectFail` になりやすいです。アプリ側では **スキャンで検出した端末をキャッシュ**し、**接続前に既存セッションがあれば切断して短い待機**するよう調整しています。それでも失敗する場合は、リーダー電源・距離、**他スマホ／PC との同時接続**、直前の切断直後の再接続を避けて再試行してください。
- **ペアリング済みなのに SR-7 だけ「先にスキャン」が必要だった** … 「ペアリング済み」表示はアプリ内保存＋一部 `retrieve` 由来ですが、**CoreBluetooth は機種によって `retrieve` が空のまま**になり、**実際の `connect:` には周辺スキャンで一度検出した `CBPeripheral` が要る**ことがあります。R-5000 は OS が既に周辺として認識しており `retrieve` が効きやすい一方、SR-7 はそうならない場合があります。接続処理内で **`retrieve` が空なら短時間の自動スキャン**して同じ UUID を捕捉してから接続するよう補っています。
- **実機から PC 上の TagReaderApi を叩く** … `localhost` は使えません。PC の LAN IP と `http://0.0.0.0:5262` 待受など（`README` / `api_config` のコメント参照）。

## 6. ビルド例

```bash
cd ios && pod install && cd ..
flutter build ios --no-codesign   # CI や署名なし確認用
flutter build ios                 # 実機配布・署名あり
```

実機では Xcode で署名チームを選び、`Runner` を実機向けに Run します。

### 実機での確認手順（目安）

1. アプリ起動 → BLE スキャンでリーダーが `ble_device_found` に出ること
2. 接続 → FW バージョン取得
3. 在庫開始 → `inventory_epc` が流れること
4. 電波強度の取得・変更（リーダー仕様に依存）

## ライセンス・取り扱い

- SDK の利用条件は **ベンダー利用規約**に従います。
- 本手順は「社内・許可された関係者のみがアクセスできるリポジトリ」での管理を想定しています。
