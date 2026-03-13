/// [商品台帳] の商品コード・商品名（一括・1件取得用）
class ProductCatalogItem {
  const ProductCatalogItem({
    required this.productCode,
    required this.productName,
  });

  final int productCode;
  final String productName;

  static ProductCatalogItem fromJson(Map<String, dynamic> json) {
    return ProductCatalogItem(
      productCode: (json['productCode'] as num?)?.toInt() ?? 0,
      productName: json['productName'] as String? ?? '',
    );
  }
}
