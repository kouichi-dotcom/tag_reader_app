# 現在のタスク

Mac で TestFlight Build 2 の配布準備を行う。

# 状態

- ホームと下部5タブ、ICタグ読取のクリア、更新履歴の商品名表示を `main` へ反映する
- バージョンは `0.9.0+1`。Build Number `2` への更新は Mac の配布準備で別作業
- 既存の TestFlight Build 1 は維持する
- staging / prod の Bundle ID、Team ID、Scheme、FLAVOR、APP_ENV は維持
- Windows の `pubspec.lock`（SDK 由来の4パッケージ）は未コミットのまま残す
- iOS Archive と TestFlight アップロードは未実施

# 作業終了後

DEVELOPMENT_LOG.md へ作業結果を記録する。バージョン変更、タグ作成、Archive、アップロードは明示指示まで行わない。
