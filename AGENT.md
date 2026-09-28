# プロジェクト概要

社内で使用する ICタグリーダー業務アプリ。

ICタグの読取・更新、伝票との紐付け、在庫確認などを行う Flutter アプリ。
商品情報との紐付けも主要な用途のひとつ。

## 対象

- Android（RFID 実機の主戦場）
- Windows（開発・UI / API 疎通の主戦場）
- iOS（コード・SDK ブリッジあり。Flavor 分離は未検証）
- 社内利用
- 利用人数：約 20～50 人

# リポジトリ構成

| 役割 | パス |
|------|------|
| アプリ（本リポジトリ） | `C:\dev\tag_reader_app` |
| API | `C:\dev\TagReaderApi` |

起動・デプロイの手順は `.cursor/rules/startup.mdc` および `docs/起動コマンド一覧.md` に従う。
ユーザーが起動を依頼したら、説明だけで終わらせず実際に起動する。

# システム構成

```
Flutter（Android / Windows / iOS）
        │ HTTPS（local 時は http://localhost:5262）
        ▼
Azure App Service（staging / prod）
  ASP.NET Core Web API（TagReaderApi）
        │ Key Vault（接続文字列等）
        │ Hybrid Connection
        ▼
社内 SQL Server（クラウドへ移行しない）
```

アーキテクチャの正本: `TagReaderApi/docs/本番アーキテクチャ方針.md`

# 環境・Flavor（必須）

接続先は `FLAVOR`（または明示 `APP_ENV=local`）のみで決まる。
未指定や不一致ではエラー画面で止まり、**本番 URL へフォールバックしない**。

| 環境 | 指定の要点 | 接続先 |
|------|------------|--------|
| テスト（標準） | `staging` + `APP_ENV=test` | Azure テスト API |
| 本番（明示時のみ） | `prod` + `APP_ENV=prod` | Azure 本番 API |
| ローカル | `APP_ENV=local` | `http://localhost:5262` |

- URL 定数の場所: `lib/config/api_config.dart`（推測・手書き換えしない）
- **prod Flavor ではアプリ側で更新を常時禁止**
- API 側にも `API_READ_ONLY` / `Database:ReadOnly` がある

# 認証の現状

- API に JWT / API Key 等の認証は未実装
- アプリは担当者コード入力で作業者を識別（ログインではない）
- 「認証方式変更」は明確な指示がない限り行わない

# 開発方針

- Flutter を使用する
- Android / Windows / iOS で動く設計を維持する（日常検証は Android・Windows 中心）
- 業務アプリなので、見た目より操作ミス防止を優先する
- 操作はできるだけ少ない手順にする
- ボタン名称は曖昧な表現を避ける
- エラー内容は利用者が理解できる日本語にする
- 既存機能を勝手に削除しない
- 大規模な構造変更は勝手に行わない
- 不明点がある場合は推測で大きな変更を行わない
- 既存 API が使える場合はそれを使う（仕様変更は指示があるまでしない）

# コーディングルール

- 既存コードの構造を優先する
- 同じ処理を重複して書かない
- API 通信処理と画面処理を可能な限り分離する
- 定数化できるものは定数化する
- エラー処理を省略しない
- null 安全を考慮する
- デバッグ用コードを本番コードに残さない

# 作業ルール

作業開始前に必ず以下を確認する。

1. `AGENT.md`（本ファイル）
2. `PROJECT_PLAN.md`（目的・構成・フェーズ）
3. `CURRENT_TASK.md`
4. 関係する既存コード・docs（機能仕様・API 一覧など）

作業終了後は `DEVELOPMENT_LOG.md` に結果を記録する。
Git の操作（コミット / Push 等）は `GIT_WORKFLOW.md` に従う。
**コミット・Push はユーザーが明示したときのみ行う。**

# 参照ドキュメント（必要時）

| 内容 | 場所 |
|------|------|
| 機能概要 | `docs/アプリ機能説明_AIプレゼン用.md` |
| ICタグ読取・更新 | `docs/ICタグ読取・更新.md` |
| 起動コマンド | `docs/起動コマンド一覧.md` |
| Git 運用 | `GIT_WORKFLOW.md` |
| API エンドポイント | `TagReaderApi/docs/APIエンドポイント一覧.md` |
| 本番アーキテクチャ | `TagReaderApi/docs/本番アーキテクチャ方針.md` |
| 本番読取版の基準設定 | `TagReaderApi/docs/本番読取版_基準設定.md`（Git タグ `prod-readonly`） |

# 禁止事項

以下は明確な指示がない限り行わない。

- DB 構造変更
- API 仕様変更
- パッケージの大量追加
- Flutter バージョン変更
- Android SDK 設定変更
- iOS 設定変更
- 認証方式変更
- Azure 設定変更（App Service / Hybrid Connection / Key Vault 等）
- 既存機能削除
- `api_config.dart` の Azure URL を推測で書き換えること

# 作業終了時

以下を報告する。

- 変更したファイル
- 変更内容
- 動作確認内容
- 残っている問題
- 次に確認すべき事項
