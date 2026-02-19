// 商品情報（API 設計に基づく型）
// 参照: docs/API設計.md

/// 商品マスタ／商品情報取得 API のレスポンス用モデル
class Product {
  final String productId;
  final String name;
  // 在庫・ステータス・メモ等は業務に合わせて追加
  // final int? stockQuantity;
  // final String? status;
  // final String? memo;

  const Product({
    required this.productId,
    required this.name,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['product_id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
      };
}
