# 開発ログ

Cursorで実施した開発内容を記録する。

---

## 作業記録

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
