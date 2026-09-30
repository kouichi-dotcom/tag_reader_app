# 現在のタスク

API通信エラーのユーザー向け表示を改善する。

# 目的

業務アプリの利用者に、技術的な例外情報（SocketException、API URL など）を見せず、
分かりやすい日本語で「何が起きたか」「どうすればよいか」を伝える。

開発時は Debug Console に詳細を残し、調査できるようにする。

# 実装内容

1. `ApiException` と共通のエラー変換・ログ（`api_error_presenter`）を追加する
2. `ApiClient` の失敗時 throw から status/body/URL の埋め込みをやめる
3. 画面の catch で `$e` / `e.toString()` / API URL を表示しないようにする
4. 開発時のみ `kDebugMode` + `debugPrint` で詳細を出す

# 注意事項

- 独自エラーコード（NET-001 等）は作らない
- HTTP 時はステータスコードで分類する
- 正常系の API 処理・戻り値は変えない
- BLE 等 API 以外の `$e` 表示は今回の対象外
- コミット / Push は明示依頼があるまで行わない

# 完了条件

- ユーザー画面に Exception / URL / hostname / errno が出ない
- 接続不能・タイムアウト・HTTP 別の日本語メッセージが出る
- Debug Console（開発時）に API 論理名・StatusCode 等が出る
- 本番相当（`kDebugMode == false`）では詳細ログが出ない

# 作業終了後

DEVELOPMENT_LOG.md へ作業結果を記録する。
