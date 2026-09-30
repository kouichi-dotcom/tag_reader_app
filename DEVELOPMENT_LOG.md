# 開発ログ

Cursorで実施した開発内容を記録する。

---

## 作業記録

### 2026-09-29 — API通信エラーのユーザー向け表示を改善

- **目的**: 利用者画面から技術詳細（SocketException / ClientException / URL 等）を除去し、日本語の案内に統一。開発時のみ Debug Console に詳細を残す
- **追加**
  - `lib/api/api_exception.dart` … `ApiException`（statusCode / apiName / debugMessage）
  - `lib/utils/api_error_presenter.dart` … ユーザー文言マップ + `logApiError`（`kDebugMode` 時のみ）
- **変更**
  - `lib/api/api_client.dart` … HTTP 失敗は `ApiException`。Timeout 文言から URL 言及を削除。常時 `print`（フル URL）を削除
  - `lib/widgets/app_notification.dart` … 任意 `title`、`showAppApiError`
  - 画面: `slip_list_screen` / `slip_link_screen` / `tag_list_screen` / `employee_code_screen` / `inventory_units_screen` / `zaicon_inventory_body` / `tag_id_product_link_screen` / `tag_id_reset_screen`
  - `zaicon_inventory_body` の `API: $kApiBaseUrl` 表示を削除
  - `CURRENT_TASK.md` を本タスク内容に更新
- **判定**: TimeoutException / ネットワーク系 / HTTP 400・401・403・404・409・5xx / 業務日本語ガード / その他
- **対象外**: BLE スキャン・電波強度・タグ読取ストリーム等の API 以外エラー
- **確認**: `dart analyze`（変更ファイル）で error なし。実機の切断・HTTP 異常系は未実施
- **Git**: 未コミット（明示依頼まで待機）

### 2026-09-28 — product-updates トランザクション検証（DB一時トリガー）

- **方法**: テストDB `OOMIYADB` に特定EPC向け `tag_table4` INSERT 失敗トリガーを一時作成（APIコード変更なし）
- **対象 EPC**: `e2008319190f010913308ec7`（元 status=`貸出中`）
- **結果 VERDICT=PASS**
  - トリガーON時 POST → **HTTP 500**
  - GET/DB の status は更新前のまま、`tag_table4` 件数も不変（2→2）
  - トリガー削除確認（ABSENT）
  - 削除後 POST → 200、その後元 status へ復元成功
- **本番**: API/DB/設定とも未接触
- SQL: `scripts/tmp-create-txn-fail-trigger.sql` / `tmp-drop-txn-fail-trigger.sql`（削除済み確認済み）

### 2026-09-28 — staging Android 更新フローテスト（着手・ブロック報告）

- **環境**: staging アプリ起動中（`com.ohmiyakouki.tagreaderapp.staging`）、staging API `readOnly=false` / `databaseKind=Local`
- **ブロック**
  1. 実機がロック画面のまま（PIN/生体が必要）。adb からの操作不可
  2. Android では `supportsNativeRfid=true` のため「テスト: ランダムに1件読み取り」非表示 → 実タグ＋リーダー接続が必須
- **未実施**: 確認項目 1〜10 の実機操作（端末解除待ち）
- **コード確認のみ**: 送信中は `_isSending` で連打ガード。失敗時は `送信エラー:` 通知のみ（成功トーストは出さない）
- **本番**: 未接触

### 2026-09-28 — product-updates の status 入力検証を強化（staging のみ）

- **原因**: `JsonElement.ToString()` フォールバックで非 string を受付、`NVarChar(30)` パラメータで無言切捨て
- **対応**: string のみ・必須・trim 後最大30文字。UPDATE+INSERT を同一トランザクション化
- **ホワイトリスト**: 正式な更新用一覧なしのため未導入（在庫用 `AllowedInventoryTagModes` は表示フィルタのみ）
- **デプロイ**: staging のみ（本番 App Service / 読取設定は未変更）
- **staging 検証**: 数値/配列/bool/object/null/空/31文字 → 400（DB 未変更）。30文字・通常文字列 → 200。復元 OK

### 2026-09-28 — staging 更新系テスト（product-updates）

- **対象**: Azure staging のみ（本番制限は未変更）
- **スクリプト**: `TagReaderApi/scripts/test-product-updates-staging.ps1`（新規のみ。API/Flutter 本体は変更なし）
- **ゲート**: BaseUrl 完全一致 + `readOnly=false` + `databaseKind!=Production`（実測: Local）
- **固定 EPC**: `e2000017690c0041141088bc`（更新前 status=`廃棄` → 終了後に復元確認済み）
- **結果**: PASS=13 / FAIL=0 / OBSERVE=8
- **想定外・観測（コード修正なし）**
  - `status` 数値 → 文字列 `"123"` として 200 更新
  - `status` 配列 → 文字列 `["OK"]` として 200 更新
  - 31/51 文字 status → 200 だが **30 文字に無言切捨て**（`tag_mode2` NVarChar(30)）
  - C1（TimeoutSec=1）は応答が間に合い 200（切断未発生）。C2 はクライアント取消・DB 未更新で整合
- **詳細 JSON**: `TagReaderApi/scripts/test-product-updates-staging-last-result.json`
- **未実施**: link-tags / tag-ledger（別タスク）

### 2026-09-28 — 本番読取版を基準として固定

- **目的**: 現行の本番（読取専用）を Git / Azure 設定 / デプロイルールで基準化する
- **アプリ側**
  - Flavor 分離（staging / prod）、本番 URL・更新禁止、起動・デプロイルール整備をコミット
  - Git タグ `prod-readonly`（注釈: 本番読取版）
- **API 側**
  - `ReadOnlyMiddleware`、デプロイ先 `-Target staging|prod`（prod は `-ConfirmProduction` 必須）
  - `docs/本番読取版_基準設定.md` に Azure 設定を記録
  - Git タグ `prod-readonly`
- **Azure 本番の確認値**: `environment=Production` / `databaseKind=Production` / `readOnly=true`（`API_READ_ONLY=true`, `Database__ReadOnly=true`）
- **注意**: Push は未実施（明示依頼があるまで）
