# tag_reader_app

大宮タグリーダーアプリ（Flutter）。ICタグの読取・更新、伝票一覧、担当者コード入力などを提供するデスクトップ/モバイルアプリ。

## 主な機能

- **タグリーダー接続** … 接続デバイス設定
- **ICタグ読取・更新** … タグ一覧表示・ステータス変更・[ICタグ台帳]／[tag_table4] への送信（完成形）
- **伝票一覧** … 受付台帳API 連携
- **担当者コード入力** … 担当者コード・氏名の保存
- **電波強度設定（Android実機）** … 接続中タグリーダーのRF出力(dBm)を変更

## ドキュメント

- [ICタグ読取・更新 機能仕様書](docs/ICタグ読取・更新.md) … 画面・操作・DB連携・テスト機能の最新仕様
- [API設計](docs/API設計.md) … 商品取得・ランダム取得・商品更新API の仕様
- [iOS開発セットアップ](docs/iOS開発セットアップ.md) … Mac/Xcode・CocoaPods・TSS iOS SDK 配置・ビルド手順

## 技術スタック

- Flutter（Windows / その他プラットフォーム）
- バックエンド: TagReaderApi（.NET / SQL Server）

## セットアップ

```bash
flutter pub get
flutter run -d windows   # または対象デバイス
```

API のベース URL は `lib/config/api_config.dart` の `kApiBaseUrl` で指定。

## Android（実機タグリーダー接続）セットアップ

このアプリは TSS の Android SDK（`TSS_SDK.aar` と `libDeviceAPI.so`）を **ローカル配置**して動かします（バイナリはリポジトリに含めません）。

### 1) SDKファイルの配置

PowerShellで以下を実行します。

```powershell
cd C:\dev\tag_reader_app
.\tools\setup_tss_sdk.ps1
```

配置先:

- `android/app/libs/TSS_SDK.aar`
- `android/app/src/main/jniLibs/<arch>/*.so`

### 2) 端末側の事前準備（推奨）

- Androidの設定で、タグリーダー（Bluetooth）を **事前にペアリング**しておく
- 初回起動時にBluetooth権限の許可を求められたら許可する

### 3) アプリでの確認手順（最短）

- メイン → **「タグリーダー接続」** → **「スキャン」**（ペアリング済み一覧） → 対象デバイスを **「接続」**
- メイン → **「ICタグ読取・更新」** → **「読取開始」**（EPCが追加されること）
- メイン → **「タグ情報表示」** → **「読取開始」**（RSSI/CH/TEMP/PH 等が表示されること）

## iOS（iPhone 向けビルド・TSS SDK 配置）

- **Mac + Xcode** が必要です。詳細は [iOS開発セットアップ](docs/iOS開発セットアップ.md) を参照。
- **CocoaPods**: `cd ios && pod install`（`ios/Podfile` あり）
- **TSS iOS SDK（SDK_for_iOS_6.2.0）** は `ios/third_party/SDK_for_iOS_6.2.0/` に配置します。共有フォルダからコピーする場合:

```powershell
cd C:\dev\tag_reader_app
.\tools\setup_ios_sdk.ps1
```

SDK をリポジトリに含める場合は、配置後に `git add ios/third_party/SDK_for_iOS_6.2.0` でコミットしてください（容量が大きい場合は Git LFS を検討）。  
**Xcode でのフレームワークリンク・Flutter ネイティブ連携**は Android 同様、別途実装が必要です。

## Getting Started（Flutter）

This project is a starting point for a Flutter application.

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/).
