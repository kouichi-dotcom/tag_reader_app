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

## 3. Xcode での SDK リンク（実装時）

SDK の種類（`.xcframework` / `.framework` 等）に応じて、**Runner ターゲット**へ以下を実施します（詳細はベンダー同梱の手順書・サンプルを参照）。

- Framework の埋め込み（Embed）
- 必要な **Build Settings** / **Bridging Header**
- **Info.plist**（Bluetooth 等の利用目的文言・権限）

## 4. Flutter との連携

Android の `MainActivity.kt` と同様、**Method Channel** 等で Dart ↔ ネイティブを接続します。iOS 側は `AppDelegate.swift` または別クラスに実装を追加します。

## 5. ビルド例

```bash
flutter build ios
```

実機では Xcode で署名チームを選び、`Runner` を実機向けに Run します。

## ライセンス・取り扱い

- SDK の利用条件は **ベンダー利用規約**に従います。
- 本手順は「社内・許可された関係者のみがアクセスできるリポジトリ」での管理を想定しています。
