# 案2：全スマホに tag_id2＋商品コード＋番号をキャッシュ — 詳細

## 1. 案2の概要

| 項目 | 内容 |
|------|------|
| **内容** | 約6,000件の「tag_id2・商品コード・番号」を全端末で保持する。読取時はキャッシュ参照のみでAPIを呼ばない（初回DLまたは更新時のみAPI）。 |
| **開発難易度** | 低〜中 |
| **実現可能性** | 高 |
| **データ量の目安** | 約6,000件 ×（EPC 約24文字＋商品コード・番号）→ JSON で **300KB〜500KB 程度** |

### 必要な変更（まとめ）

1. **API**
   - [ICタグ台帳] から `tag_id2`, `商品コード`, `番号` を一括返すエンドポイント（例: `GET /api/products/tag-ledger`、`WHERE tag_mode2 != '廃棄'`）
   - キャッシュ更新の要否判定用に、台帳の「バージョン」だけを返す軽量エンドポイント（例: `GET /api/products/tag-ledger/version`）
2. **アプリ**
   - EPC → 商品コード・番号 のキャッシュ（EpcLookupCache 等）：メモリ ＋ 永続化（SharedPreferences 等）
   - 起動時・「更新」実行時にバージョンAPIを呼び、ローカルと異なるときだけ全件取得してキャッシュを上書き
   - tag_list_screen の読取処理で `fetchProduct(epc)` の代わりにキャッシュから取得

### メリット・デメリット

- **メリット:** 読取時にDBアクセスなし。通信不可でも照合可能。既存の ProductCache と同様のパターンで実装しやすい。
- **デメリット:** 台帳の更新（新規タグ・廃棄・紐付け変更・リユース等）があった場合、端末キャッシュの更新が必要。そのため「バージョンで変更を検知し、変わったときだけ全件DL」する仕組みを入れる。

---

## 2. 変更検知：バージョン／最終更新日の考え方

- 台帳の変更（tag_id2 と 商品コード・番号 の組み合わせの変更）は**滅多にないが、たまに発生する**（例: 商品は壊れたがICタグをリユースする場合）。
- **「6,000件を毎日1件ずつ照合する」必要はない。**
- サーバ側で「台帳のバージョン」を**1つだけ**持ち、アプリはその値だけを取得して端末に保存した値と比較する。違う場合だけ全件取得する。

---

## 3. DB側で「台帳が更新されたらバージョンを更新する」具体的な実現方法

いずれも **「台帳（tag_id2・商品コード・番号の組み合わせ）が変わるいかなる操作の結果、バージョンが必ず更新される」** ことを保証する必要がある。

### 方式1：バージョン用テーブル ＋ トリガー（推奨）

**概要:** [ICタグ台帳] に対する INSERT / UPDATE / DELETE が発生したときに、**トリガー**でバージョン用テーブルの値を更新する。アプリや手動SQLなど、**どの経路で台帳が更新されても**必ずバージョンが上がる。

**手順:**

1. **バージョン用テーブルを1つ用意する（1行だけ保持）**

   ```sql
   -- 例: バージョン番号で管理
   CREATE TABLE [dbo].[TagLedgerVersion] (
       [id] INT NOT NULL PRIMARY KEY DEFAULT 1,
       [version] BIGINT NOT NULL DEFAULT 0,
       CONSTRAINT CK_TagLedgerVersion_SingleRow CHECK (id = 1)
   );
   INSERT INTO [dbo].[TagLedgerVersion] ([id], [version]) VALUES (1, 0);
   ```

   または、日時で管理する場合:

   ```sql
   CREATE TABLE [dbo].[TagLedgerVersion] (
       [id] INT NOT NULL PRIMARY KEY DEFAULT 1,
       [updated_at] DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
       CONSTRAINT CK_TagLedgerVersion_SingleRow CHECK (id = 1)
   );
   INSERT INTO [dbo].[TagLedgerVersion] ([id], [updated_at]) VALUES (1, SYSDATETIME());
   ```

2. **[ICタグ台帳] に AFTER INSERT, UPDATE, DELETE のトリガーを張る**

   ```sql
   CREATE OR ALTER TRIGGER [dbo].[tr_ICタグ台帳_UpdateVersion]
   ON [dbo].[ICタグ台帳]
   AFTER INSERT, UPDATE, DELETE
   AS
   BEGIN
       SET NOCOUNT ON;
       UPDATE [dbo].[TagLedgerVersion] SET [version] = [version] + 1 WHERE [id] = 1;
       -- 日時で管理する場合: UPDATE [dbo].[TagLedgerVersion] SET [updated_at] = SYSDATETIME() WHERE [id] = 1;
   END;
   ```

**ポイント:**

- 台帳を更新するのが「自社のAPI」「他システム」「手動SQL」「バッチ」のどれであっても、トリガーが必ず実行される。
- トリガー内の処理は短い（1行のUPDATEのみ）ので、パフォーマンス影響は小さい。
- 運用で「台帳だけ触る」ことがある場合でも、バージョンを取りこぼさない。

---

### 方式2：アプリケーション側で「台帳更新とバージョン更新」を同一トランザクションで実行

**概要:** 台帳を更新する処理を**すべてAPI（または決まったアプリケーション）に集約**し、その処理の最後に「バージョン用テーブルを更新する」を同じトランザクションで行う。

**手順:**

1. 方式1と同様に `TagLedgerVersion` テーブルを用意する。
2. 台帳を変更するすべての処理で、次のようにする。
   - トランザクション開始
   - [ICタグ台帳] の INSERT / UPDATE / DELETE
   - `UPDATE [dbo].[TagLedgerVersion] SET [version] = [version] + 1 WHERE [id] = 1`
   - コミット

**メリット:** トリガーを使わないため、トリガー運用を避けたい場合に使える。

**デメリット:**

- 台帳を更新する**すべての経路**（別システム・手動SQL・SSMSでの修正など）で、必ずバージョン更新を行わないと不整合になる。
- 取りこぼしを防ぐには「台帳は必ずこのAPI経由でしか更新しない」という運用規約が必要。

---

### 方式3：[ICタグ台帳] の `updated_at` を「バージョン」の代わりに使う

**概要:** [ICタグ台帳] に `updated_at`（またはそれに類する更新日時）列があり、**すべての更新でその列が必ず更新される**前提で、その最大値を「バージョン」として返す。

**手順:**

1. [ICタグ台帳] に `updated_at DATETIME2` のような列がある（なければ追加）。
2. 台帳の行が更新されるときに必ず `updated_at = SYSDATETIME()` になるようにする。
   - **方法A:** [ICタグ台帳] に AFTER UPDATE トリガーを張り、`updated_at` を `SYSDATIME()` に更新する。
   - **方法B:** 台帳を更新するアプリケーション側で、常に `updated_at` を明示的に設定する（かつ、他経路で台帳を触らない運用）。
3. API で「バージョン」を返すとき、次のようなクエリの結果を返す。

   ```sql
   SELECT MAX([updated_at]) AS [version] FROM [dbo].[ICタグ台帳] WHERE [tag_mode2] != N'廃棄';
   ```

   （廃棄除く有効な台帳の「いちばん新しい更新日時」が変われば「台帳が変わった」とみなす。）

**メリット:** 専用のバージョン用テーブルが不要。既存の `updated_at` を活用できる。

**注意点:**

- INSERT 時にも `updated_at` を設定する必要がある（新規行の `updated_at` がMAXに含まれるようにする）。
- 台帳を触る**すべての経路**で `updated_at` が更新されることを保証する必要がある。トリガーで一括して更新するのが確実。

---

### 方式の比較と推奨

| 方式 | 実現方法 | 取りこぼしリスク | 推奨度 |
|------|----------|------------------|--------|
| **方式1: トリガー** | バージョン用テーブル ＋ [ICタグ台帳] の AFTER INSERT/UPDATE/DELETE トリガー | 低（どの経路で更新してもバージョンが上がる） | ◎ 推奨 |
| **方式2: アプリで更新** | 台帳更新処理の最後に必ずバージョン更新を同じトランザクションで実行 | 中（他経路で台帳を触ると取りこぼす） | △ 更新経路がAPIのみに限定できる場合のみ |
| **方式3: MAX(updated_at)** | 台帳に updated_at を必ず更新する仕組みを用意し、MAX をバージョンとして返す | 低（トリガーで updated_at を更新する場合） | ○ 既存の updated_at を活かしたい場合 |

**推奨:** どの経路で台帳が更新されるかが不明確な場合は **方式1（バージョン用テーブル ＋ トリガー）** が確実。既存テーブルに `updated_at` があり、トリガーで更新する運用ができるなら方式3も選択肢。

---

## 4. API の役割（案2でのイメージ）

- **`GET /api/products/tag-ledger/version`**  
  - 上記の「バージョン」（方式1なら `TagLedgerVersion.version` または `updated_at`、方式3なら `MAX(updated_at)`）を返すだけの軽量API。  
  - 例: `{ "version": 123 }` または `{ "updatedAt": "2025-03-10T12:00:00Z" }`

- **`GET /api/products/tag-ledger`**  
  - [ICタグ台帳] から `tag_id2`, `商品コード`, `番号` を一括取得（`tag_mode2 != '廃棄'`）。  
  - アプリは「バージョンがローカルと違う」ときだけこのAPIを呼び、キャッシュを全件で上書きする。

---

## 5. アプリの動き（案2でのイメージ）

1. **起動時（または「キャッシュを更新」実行時）**
   - `GET /api/products/tag-ledger/version` を呼ぶ。
   - 返ってきたバージョンと、端末に保存しているバージョンを比較。
2. **同じ場合**
   - 何もしない（既存キャッシュをそのまま利用）。
3. **違う場合**
   - `GET /api/products/tag-ledger` で全件取得し、永続化とメモリキャッシュを上書き。
   - 取得したバージョンを端末に保存。

これにより、「毎日すべての組み合わせを確認する」処理は不要になる。
