# サードパーティ（TSS iOS SDK）

ベンダー提供の **SDK_for_iOS_6.2.0** を、この配下に配置します（チーム内 Git 管理用）。

## 配置先

- `ios/third_party/SDK_for_iOS_6.2.0/` … 配布パッケージの内容をそのまま（またはベンダー推奨構成で）置く

## コピー方法

リポジトリ直下で:

```powershell
.\tools\setup_ios_sdk.ps1
```

共有フォルダ以外からコピーする場合:

```powershell
.\tools\setup_ios_sdk.ps1 -SourceRoot "D:\path\to\SDK_for_iOS_6.2.0"
```

コピー後、Xcode プロジェクトへフレームワークをリンクする作業が **別途必要**です（`docs/iOS開発セットアップ.md`）。

## ライセンス

配布・再配布の可否は **ベンダー利用規約**に従ってください。本リポジトリへのコミットは **社内・許可された関係者のみがアクセスできる前提**で行ってください。
