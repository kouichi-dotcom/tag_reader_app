# 開発ログ

Cursorで実施した開発内容を記録する。

---

## 作業記録

### 2026-10-23 — ホームと下部タブを main へ反映（STEP 11-A）

- **目的**: Windows で行った UI 変更を、iOS の staging / prod 分離と `0.9.0+1` を維持したまま GitHub の `main` へ反映する
- **UI**: 下部5タブ（ホーム / ICタグ更新 / 伝票 / 在庫 / 履歴）。ホームは Bluetooth 接続状況と設定メニュー。急ぎ来店納品は有効な環境だけ伝票タブに表示。EPC読取テストの画面と入口は削除
- **本体ボタン**: ICタグ更新タブが見えている間、伝票のタグ紐付け画面、急ぎ来店納品の読取画面だけ受け付ける。タブを離れると購読を外し、読取中なら止める
- **維持**: Bundle ID、Team ID `3MMGLB2435`、Scheme、FLAVOR、APP_ENV、バージョン `0.9.0+1`、API、DB。prod の急ぎ来店納品は非表示のまま
- **変更ファイル**: `home_screen.dart`、`slip_load_screen.dart`、`tag_list_screen.dart`、`settings_screen.dart`、`hardware_trigger_settings_screen.dart`、`urgent_store_delivery_screen.dart`、`zaicon_main_shell.dart`、`epc_test_screen.dart`（削除）、`test/home_navigation_test.dart`、`test/urgent_store_delivery_visibility_test.dart`、`CURRENT_TASK.md`、`DEVELOPMENT_LOG.md`
- **対象外**: `pubspec.lock`。Windows SDK による characters / matcher / material_color_utilities / test_api の差分だけなので未コミット
- **検証**: `flutter pub get` 成功。`flutter test` は 45 件成功。`flutter analyze` は既存の info 10 件と warning 2 件のみで、今回の新規指摘は無い。`git diff --check` に空白エラーは無い
- **次回**: Mac で Build Number を `2` にして TestFlight Build 2 を作る。このコミットではバージョンを変えない。既存の Build 1 は維持する

### 2026-10-22 — ホームと下部固定タブ

- **目的**: 主要画面をホーム / ICタグ更新 / 伝票 / 在庫 / 履歴の5タブにし、ホームは接続状況と設定メニューにする
- **タブ**: `NavigationBar` と `IndexedStack`。未表示タブは作らず、一度開いた画面は破棄しない。詳細画面は従来の push で開き、戻るとタブに戻る
- **ホーム**: Bluetooth接続状況（接続済み / 未接続、リーダー名、ファームウェアが取れたときだけ FW）。タップで既存の接続画面。設定は出力、担当者、保管場所、読み取りボタン動作、タグ設定の順
- **表示名**: 「読み取りボタン動作設定」は画面タイトルとメニュー名のみ。保存キーと設定値は未変更
- **維持**: 読取・書込、接続・切断の内部処理、API、接続先、バージョン `0.9.0+1`
- **急ぎ来店納品**: ホームからは外し、有効な環境だけ伝票タブに表示する。判定フラグは未変更
- **EPC読取テスト**: 画面と設定メニューの入口を削除。他機能の読取処理は残している
- **本体ボタン**: ICタグ更新タブが見えていない間は購読を外し、読取中なら止める。伝票のタグ紐付け画面は、その画面を開いている間だけ受け付ける。急ぎ来店納品は読取画面を離れて伝票選択に進む間は止める
- **バッテリー**: アプリに残量を取る既存処理がないため表示しない
- **在庫**: タブの起点にはホームへ戻るボタンを出さない。商品一覧からカテゴリー一覧へ戻る動きは維持
- **検証**: `flutter analyze` は既存の info 10件と warning 2件のみで、今回の新規指摘は無い。`flutter test` は 45件成功
- **未実施**: 実機の見た目確認、コミット / Push。`pubspec.lock` の SDK 差分は未コミットのまま

### 2026-10-22 — 在庫確認の戻る操作をカテゴリー一覧へ

- **目的**: カテゴリーを開いたあと、画面端スワイプや戻るでホームまで戻ってしまうのをやめ、カテゴリー一覧へ戻す
- **原因**: カテゴリー選択は同じ画面の表示切替だけで、端末の戻るは在庫確認の画面ごと閉じていた
- **変更**: カテゴリー・全表示・検索結果を別画面 `inventory_category_products_screen` で開く。戻る操作はこの画面だけを閉じる。カテゴリー一覧でもう一度戻るとホーム
- **維持**: 商品を開いたあとの戻るは商品一覧。在庫の取得 API は変更していない
- **未実施**: 実機でのスワイプ確認

### 2026-10-22 — v0.9.0 Beta のバージョン設定と開発管理（STEP 6）

- **目的**: 社員向け初回 TestFlight 候補の Version / Build Number を `0.9.0+1` に揃え、リリース計画と Git の版管理ルールを残す
- **変更前**: `pubspec.yaml` は `1.0.0+1`。アプリの `Info.plist` は `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)`。アプリ本体の各構成は `CURRENT_PROJECT_VERSION = $(FLUTTER_BUILD_NUMBER)` で、`MARKETING_VERSION` は無い
- **変更**: `pubspec.yaml` のみ `version: 0.9.0+1`。`Info.plist` へ番号は書いていない。表示名とアイコン、Feature Flag、Bundle ID、Team ID は未変更
- **連動**: ビルド時の `Generated.xcconfig` が `FLUTTER_BUILD_NAME=0.9.0` / `FLUTTER_BUILD_NUMBER=1`。Android は `versionName = flutter.versionName` / `versionCode = flutter.versionCode` のため同じ番号に連動する。Android 固有のファイルは変えていない
- **対象外の番号**: RunnerTests は `MARKETING_VERSION = 1.0` / `CURRENT_PROJECT_VERSION = 1`（テスト用）。`AppFrameworkInfo.plist` は Flutter フレームワーク側の `1.0`。いずれも配布アプリの Version ではないため未変更
- **Git**: 既存タグは `prod-readonly` のみ。`v0.9.0-beta.1` は未作成。HEAD は `a4df237`（未コミット変更あり）
- **App Store Connect**: ローカルに Archive、ipa、アップロードログは無く、アップロード履歴は未確認。Build Number `1` が使用可能とは断定していない
- **検証**: `flutter pub get` 成功。`flutter test` は 39 件成功（iOS prod で急ぎ来店納品を出さないテストを含む）。`flutter analyze` は既存の info 10 件と warning 2 件のみで、今回の新規指摘は無い
- **iOS prod**: 署名なし Release は成功。成果物は Version `0.9.0`、Build `1`、Bundle ID `jp.co.ohmiyakouki.tagreader`、表示名 `Tag Reader App`。`DART_DEFINES` は `FLAVOR=prod` / `APP_ENV=prod`
- **staging（静的）**: Release-staging の Version / Build は prod と同じ `0.9.0` / `1`。Bundle ID は `jp.co.ohmiyakouki.tagreader.staging`。`DART_DEFINES` は `FLAVOR=staging` / `APP_ENV=test`。表示名は「タグリーダー DEV」
- **Git**: 在庫確認の戻る操作とあわせ、この記録を含む Commit で `main` へ反映する。タグ `v0.9.0-beta.1` は未作成
- **未実施**: 実機インストール、署名済み Archive、TestFlight、App Store Connect の変更

### 2026-10-21 — iOS prod の Bundle ID を会社登録済み ID に変更（STEP 5-D）

- **目的**: prod の Bundle ID を `jp.co.ohmiyakouki.tagreader` に合わせる
- **変更**: `project.pbxproj` の Debug-prod / Profile-prod / Release-prod の3構成だけ
- **維持**: staging は `jp.co.ohmiyakouki.tagreader.staging`。Team は `3MMGLB2435`。prod の `DART_DEFINES` は `FLAVOR=prod` / `APP_ENV=prod`
- **Runner**: 今回は未変更。Bundle ID は `jp.co.ohmiyakouki.tagreader.staging`（旧 `com.ohmiyakouki.tagReaderApp` ではない）。Flavor は固定していない
- **検証**: 署名なし prod Release は成功。成果物の Bundle ID は新 ID、表示名は Tag Reader App、`DART_DEFINES` は prod。急ぎ来店納品の既存テスト6件は成功
- **未実施**: 実機インストール、Provisioning Profile 作成、Commit / Push

### 2026-10-20 — iOS staging の Bundle ID を会社登録済み ID に変更（STEP 5-C）

- **目的**: staging の Bundle ID を Apple Developer 登録済みの `jp.co.ohmiyakouki.tagreader.staging` に合わせる
- **変更**: `project.pbxproj` の Debug-staging / Profile-staging / Release-staging の3構成だけ
- **維持**: prod と Runner は `com.ohmiyakouki.tagReaderApp`、Team は全構成 `3MMGLB2435`、`DART_DEFINES` は `FLAVOR=staging` / `APP_ENV=test`
- **検証**: `xcodebuild -showBuildSettings` で3系統の Bundle ID と Team を確認。署名なしの staging Release ビルドは成功。成果物の Bundle ID は新 ID、表示名は「タグリーダー DEV」、`DART_DEFINES` は staging / test
- **未実施**: 実機インストール、Provisioning Profile 作成、Commit / Push

### 2026-10-20 — iOS 署名チームを会社用 Team ID に統一（STEP 5-B）

- **目的**: Runner / staging / prod の署名チームを会社用 `3MMGLB2435`（OMIYA KOKI, Y.K.）に揃える
- **変更**: `ios/Runner.xcodeproj/project.pbxproj` の `DEVELOPMENT_TEAM` 18箇所。Runner と RunnerTests の Debug / Profile / Release および staging・prod の各3構成
- **維持**: Bundle ID、Automatic（RunnerTests は明示、本体は従来どおりプロファイル手動固定なし）、`DART_DEFINES`、Feature Flag、Android
- **検証**: `xcodebuild -list` で Scheme `prod` / `Runner` / `staging` を確認。9構成×2ターゲットの `DEVELOPMENT_TEAM` は `3MMGLB2435`。アプリ用プロジェクト内に旧 Team ID は残っていない
- **署名の手元資料**: 会社用 Apple Development 証明書はある。会社用 Provisioning Profile はローカルに無い。証明書と Profile は新規作成していない
- **未実施**: 実機インストール、Portal 登録、Commit / Push

### 2026-10-20 — iOS prod で急ぎ来店納品を非表示（STEP 4）

- **目的**: iOS の prod だけ急ぎ来店納品を出さず、直接開くことも止める
- **判定**: `enableUrgentStoreDelivery`。環境が不正なら不可。iOS かつ prod なら不可。それ以外の有効な環境（iOS staging、Android）は可
- **画面**: ホームから外す。共通ルートと急ぎ来店納品の各画面は案内を出して作業画面を開かない
- **維持**: 通常の納品・返却・交換、Android、API の環境切替、更新禁止フラグ
- **検証**: フラグの単体テストと画面テストを含む `flutter test` は成功。`flutter analyze` は既存の info 10件と warning 2件のみ。署名なしの `staging` / `prod` Release ビルドは成功し、それぞれの `DART_DEFINES` は維持
- **未実施**: 実機インストール、Commit / Push、STEP 3 の DB 照合

### 2026-10-20 — iOS prod Flavor（STEP 1）

- **目的**: iOS に prod Scheme と Debug-prod / Profile-prod / Release-prod を追加し、実行時の API を `FLAVOR=prod` / `APP_ENV=prod` に固定する
- **維持**: Bundle ID `com.ohmiyakouki.tagReaderApp`、Team `G5335GZVS2`、既存 Debug / Profile / Release、Runner Scheme、prod API の判定、Android
- **受け渡し**: prod 用 xcconfig が `Generated.xcconfig` のあとで `DART_DEFINES` を上書きする。Xcode の Run Script がこの値を Flutter の `--DartDefines` に渡す
- **未実施**: 急ぎ来店納品の変更、実機インストール、Commit / Push

### 2026-10-20 — iOS staging Flavor（STEP 2）

- **目的**: 同じ iPhone に別アプリとして入る staging Scheme を追加する
- **追加**: Debug-staging / Profile-staging / Release-staging、Scheme `staging`、Bundle ID `com.ohmiyakouki.tagReaderApp.staging`、表示名「タグリーダー DEV」
- **環境**: `FLAVOR=staging` と `APP_ENV=test` を xcconfig の `DART_DEFINES` で固定。prod の定義は維持
- **表示名**: `Info.plist` は `$(APP_DISPLAY_NAME)`。Runner は `Tag Reader App`、prod も同じ、staging だけ別名称
- **対象外**: Android、業務機能、急ぎ来店納品、アイコン、実機インストール、Commit / Push

### 2026-10-20 — iPhone 切断中UIをSDK切断の前に表示する

- **目的**: 切断中 Widget は build されるが、TSS SDK の `disconnect` がメインスレッドを約3秒占有し、画面に出ない
- **変更**: 手動切断で、既存の `endOfFrame` のあと iOS だけ次の1フレームを待つ。上限は 50ms。来なければ打ち切って切断は続ける
- **対象外**: Android の追加待ち、セッション、ネイティブ SDK、接続処理、8秒タイムアウト
- **ログ**: `disconnect_ui_present_wait` の start / ok / timeout / unmounted
- **未実施**: ビルド、テスト、実機確認

### 2026-10-20 — iPhone 切断中UIの時刻診断ログ

- **目的**: 切断から未接続まで 3〜4 秒あるのに「切断中…」が出ない原因を、時刻で分ける
- **追加**: `device_connection_screen.dart` に `[ReaderBT]` の診断行のみ。切断処理・表示・待機時間は変えていない
- **記録**: フラグ設定、`endOfFrame` の ok / timeout、`stopInventory` と `disconnect()` の開始・終了、切断中の最初の `build`
- **未実施**: ビルド、テスト、実機でのログ取得

### 2026-10-19 — Android 切断中ローディング（Dart）

- **目的**: 切断ボタン直後に接続中と同じローディングを出し、`disconnect()` 完了まで連続操作を止める
- **画面**: 手動切断だけ `endOfFrame` のあとで `stopInventory` / `disconnect`。切断中は青背景・スピナー・「切断中…」。接続・切断・削除と削除スワイプを無効化
- **セッション**: 手動切断中の `disconnected` / `link_lost` では完了にせず、保存も消さない。切り替え前の切断と、意図しない通信切断は従来どおり
- **失敗時**: まだ接続中なら接続表示のまま再切断可。未接続なら未接続表示。判定不能なら未接続とせず接続操作は止めたまま、切断の再試行は可能
- **テスト**: ボタンタップで切断完了を保留する Widget テストと、セッションのイベント保留テストを追加。`kReleaseMode` の import 不足を修正し、当該2ファイルは `flutter test` 成功（5件）。ビルド・実機起動は未実施
- **対象外**: Android / iOS ネイティブ、接続タイムアウト、通常の接続処理
- **Git**: 未コミット

### 2026-10-15 — Bluetooth 接続安定化・エラー表示改善

- **目的**: R-5000 共有時の接続不安定を軽減（自動接続は追加しない）
- **Android**: `connect()` は DOTR 同期完了型と確認のうえ、タイムアウト(20s)・`isConnect` 再確認・切断完了待ち・処理直列化・遅延 `onConnected` 無視
- **iOS**: 切断完了待ち、Known を成功後保存、BT OFF（`isCentralManagerReady`）、世代番号で遅延コールバック無視
- **Dart**: `ReaderConnectionSession`（画面横断の状態）、`ReaderConnectionLog`（端末内診断）、エラー文言見直し、接続画面 dispose でスキャンのみ停止（接続維持）
- **テスト**: `test/connect_error_messages_test.dart` 成功。実機は `docs/Bluetooth接続_実機確認手順.md`
- **Git**: 未コミット（急ぎ来店納品の未コミット変更は触っていない）

### 2026-10-08 — 急ぎ来店納品 UI（統合画面＋伝票選択〜確認〜送信）

- **目的**: 伝票なしで先にタグ読取 → 当日未処理から複数選択 → 伝票選択 → 再確認 → 送信、の操作イメージ（API/DB 未接続）
- **ホーム**: 「急ぎ来店納品」＋補足＋未処理 N点（メモリ上の当日件数）
- **画面**
  - `urgent_store_delivery_screen` … 接続状態・本日未処理一覧・チェック選択・「伝票を選択」
  - `urgent_store_delivery_slip_select_screen` … ダミー伝票一覧 →「確認へ進む」
  - `urgent_store_delivery_confirm_screen` … 伝票＋商品の再確認 →「送信」（仮）→ 統合画面へ戻る
- **セッション**: `UrgentStoreDeliverySession`（アプリ内メモリ。送信後は選択商品を一覧から除去）
- **削除**: 旧読取完了／未処理一覧／詳細の分離画面
- **Git**: 未コミット

### 2026-10-08 — 急ぎ来店納品 UI（初期版・画面分離） ※上記で置き換え

- 読取／完了／未処理一覧を分離した初版。統合フローへ再設計。

### 2026-10-07 — 保管場所設定: 手動 / GPS自動判定の切替

- **画面**: `storage_location_screen` を 4 ボタン廃止 → 現在の保管場所表示 + SegmentedButton（GPS/手動）+ 手動時のみドロップダウン
- **保持**: `StorageLocationStorage` に mode / 手動選択 / DB直近コード（SharedPreferences）
- **タグ更新**: 手動時は GPS なしで選択コードを `storage_location` 送信。GPS時は既存判定のまま
- **設定字幕**: 「手動 / GPS自動判定の設定」
- **Git**: 未コミット

### 2026-10-07 — GPS による保管場所判定（完成: 実座標 + tag_mode 不使用の確定）

- **目的**: タグ更新時に GPS で拠点を判定し、`ICタグ台帳.保管場所コード` と異なるときだけ確認して更新する
- **確定方針**: 保管場所は必ず `[保管場所コード]`。`tag_mode` / `tag_mode2` は保管場所に使わない（ステータス等の本来用途のみ）
- **DB（TagReaderApi）**
  - `scripts/sql/add-ic-tag-ledger-storage-location-code.sql` … `[保管場所コード] int NULL` を安全追加
  - 値: 1=本社, 2=山川, 3=東風平, 4=友寄
- **API**
  - `ProductUpdatesController` … `storage_location` → `[保管場所コード]` のみ更新（`tag_mode` へは書かない）
  - `ProductsController` / `ProductResponse` … `storageLocationCode` 取得
- **アプリ**
  - `StorageLocationCatalog` に4拠点の実座標を設定
  - `StorageLocationGpsService`（200m・5分キャッシュ）、確認ダイアログ、`tag_list_screen` 送信フロー
  - 手動保管場所選択はホーム表示用（DB 更新は GPS 確認後のみ）
- **テスト**: `test/storage_location_gps_test.dart`（実座標判定・距離・5分キャッシュ）
- **Git**: 未コミット（明示依頼まで待機）

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
