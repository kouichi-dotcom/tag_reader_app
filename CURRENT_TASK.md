# 現在のタスク

v0.9.0 Beta 配布準備。

# 状態

- iOS の staging / prod 環境分離は実装済み。基本の実機確認は完了
- バージョン設定済み。Git の Commit と Push は、在庫確認の戻る操作とあわせて `main` へ反映する
- App Store Connect への登録と TestFlight 配布は未実施。Git タグ `v0.9.0-beta.1` は未作成
- staging の送信制限問題は今回の対象外

# リリース候補

- 名称: v0.9.0 Beta（アプリ画面には Beta と出さない）
- Version: `0.9.0`
- Build Number: `1` を候補とする。App Store Connect での使用有無は未確認のため、使用可能とは断定しない
- 将来の Git タグ: `v0.9.0-beta.1`（未作成）
- 配布: TestFlight。対象は prod（本番 API / 本番 DB）
- 急ぎ来店納品: prod では非表示。staging では表示

# 作業終了後

DEVELOPMENT_LOG.md へ作業結果を記録する。Git タグの作成は、配布 Commit を確定したあとの明示指示まで行わない。
