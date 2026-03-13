# API 設計（tag_reader_app 連携）

TagReaderApi のうち、ICタグ読取・更新機能で利用するエンドポイントの仕様。

---

## 商品取得（EPC 指定）

- **GET** `/api/products?epc={epc}`

### 説明

EPC（tag_id2）をキーに [ICタグ台帳] と [商品台帳] から商品情報を取得。商品名は [商品台帳] を JOIN して取得。

### クエリパラメータ

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| epc | string | ○ | タグID（tag_id2 と一致させる文字列） |

### レスポンス（200）

JSON オブジェクト:

| プロパティ | 型 | 説明 |
|------------|-----|------|
| tag_id2 | string | EPC |
| product_code | int? | 商品コード |
| number | int? | 番号 |
| status | string | ステータス（tag_mode2） |
| product_name | string | 商品名 |

### エラー

- 400: epc 未指定
- 404: 該当する tag_id2 が存在しない

---

## ランダム取得（テスト用）

- **GET** `/api/products/random?count={count}`

### 説明

[ICタグ台帳] からランダムに N 件取得し、[商品台帳] の商品名を JOIN して返す。タグリーダーがない環境での「読み取りシミュレート」用。

### クエリパラメータ

| パラメータ | 型 | 必須 | 既定 | 説明 |
|-----------|-----|------|------|------|
| count | int | - | 5 | 取得件数。1～50。範囲外は 5 に補正 |

### レスポンス（200）

上記と同じ形式のオブジェクトの配列。

---

## 商品データ更新（ステータス送信）

- **POST** `/api/product-updates`

### 説明

変更した商品データ（主にステータス）を送信し、[ICタグ台帳] の `tag_mode2` と `updated` を更新。あわせて [tag_table4] に更新ログを1件挿入する。

### リクエスト Body（JSON）

| プロパティ | 型 | 必須 | 説明 |
|------------|-----|------|------|
| epc | string | ○ | タグID（tag_id2） |
| read_at | string | ○ | 読み取り日時（ISO 8601 等）。API ではログ用 |
| changes | object | ○ | 変更内容。`status` キーでステータス文字列を渡す |
| user_id | string | - | 担当者コード（従業員コード）。整数に変換できれば tag_table4.s_code に記録 |
| product_id | string | - | 未使用可 |
| device_id | string | - | 未使用可 |

例:

```json
{
  "epc": "e2000017690c003116706a0f",
  "read_at": "2026-02-24 16:00:00",
  "changes": { "status": "修理中" },
  "user_id": "123"
}
```

### 処理内容

1. ** [ICタグ台帳]** を更新  
   - `WHERE LTRIM(RTRIM([tag_id2])) = @epc`  
   - `SET [tag_mode2] = @status`  
   - `SET [updated] = CONVERT(DATETIME, CONVERT(VARCHAR(19), GETDATE(), 120), 120)`（秒単位）

2. **[tag_table4]** に1行 INSERT  
   - read_time: サーバー現在時刻（秒単位）  
   - tag_id2: epc  
   - tag_mode: 送信した status  
   - s_code: user_id を int にした値（不可なら NULL）  
   - 受付番号: 0, mark: 0, complete: 1, Remarks: NULL

### レスポンス

- **200:** `{ "updated": 1, "logRecorded": true }`
- **400:** epc 未指定、または changes.status 未指定
- **404:** 該当する tag_id2 が存在しない

### エラー時（4xx）

404 時は `message`, `receivedEpc`, `receivedEpcLength` などを含む JSON が返る場合あり。
