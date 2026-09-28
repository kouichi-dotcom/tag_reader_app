# iOS Flavor 準備メモ（未検証）

Windows 環境では iOS の Scheme / 署名 / 実機起動は確認できない。
**動作確認済み扱いにはしない。** Mac + Xcode で後日実施する。

## 予定値

| Flavor | Bundle ID | Display Name |
|--------|-----------|--------------|
| prod | `com.ohmiyakouki.tagReaderApp`（現行維持） | タグアプリ |
| staging | `com.ohmiyakouki.tagReaderApp.staging` | タグアプリ（TEST） |

## Dart 側（共通・済）

接続先・更新禁止は `FLAVOR` / `APP_ENV` の dart-define で制御済み。
iOS でも同じ define を渡す:

```bash
flutter run --flavor staging --dart-define=FLAVOR=staging --dart-define=APP_ENV=test
flutter run --flavor prod --dart-define=FLAVOR=prod --dart-define=APP_ENV=prod
```

## Mac でやること（未着手）

1. Xcode に `Debug-staging` / `Release-staging` / `Debug-prod` / `Release-prod` Configuration を追加
2. Scheme `staging` / `prod` を作成
3. Bundle ID / Display Name を上記表どおり設定
4. staging 用アイコン（TEST バッジ）を Asset Catalog に追加
5. 実機で Scheme・署名・起動を確認

現行の単一 Scheme（`Runner`）と Bundle ID `com.ohmiyakouki.tagReaderApp` は本番用として維持する方針。
