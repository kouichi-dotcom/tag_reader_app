# オフライン照合用データ（方法A）

APIが使えない開発段階で、タグリーダー読取時に本番と同じように「商品名」「番号」を表示するためのデータです。

## ファイル

- **tag_ledger.json** … [ICタグ台帳] のスナップショット（tag_id2 → 商品コード・番号）
- **product_catalog.json** … [商品台帳] のスナップショット（商品コード → 商品名）
- **employees.json** … 担当者一覧（担当者コード → 担当者名）。Android では API を使わずこの JSON のみ使用する。

## 形式

### tag_ledger.json

```json
[
  { "tagId2": "EPC文字列", "productCode": 123, "number": 1 },
  ...
]
```

- 本番DBで取得する例:  
  `SELECT [tag_id2], [商品ｺｰﾄﾞ], [番号] FROM [dbo].[ICタグ台帳] WHERE [tag_mode2] != N'廃棄'`  
  を実行し、列を tagId2, productCode, number に対応させてJSONに出力。

### product_catalog.json

```json
[
  { "productCode": 123, "productName": "商品名" },
  ...
]
```

- 本番DBで取得する例:  
  `SELECT [商品コード], [商品名] FROM [dbo].[商品台帳] WHERE [現存する商品] = 1`  
  を実行し、列を productCode, productName に対応させてJSONに出力。

### employees.json

```json
[
  { "employeeCode": 1, "employeeName": "担当者名" },
  ...
]
```

- 本番DBで取得する例:  
  [担当者台帳] から 担当者コード・担当者名 を取得し、employeeCode, employeeName に対応させてJSONに出力。

## プラットフォームの使い分け

- **Android** … API に接続しない。上記3種類の JSON のみを使用する（伝票一覧・送信は利用不可）。
- **Windows など** … API に接続し、伝票一覧・送信・担当者・商品の取得を行う。

## 更新手順

1. 本番DBから上記のデータをエクスポートしてJSONファイルを生成する。
2. このフォルダの `tag_ledger.json`・`product_catalog.json`・`employees.json` を上書きする。
3. アプリを再ビルドして実行する。
