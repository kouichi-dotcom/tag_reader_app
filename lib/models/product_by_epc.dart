/// API の商品取得レスポンス（[ICﾀｸﾞ台帳] + [商品台帳] の商品名付き）
class ProductByEpc {
  const ProductByEpc({
    required this.tagId2,
    this.productCode,
    this.number,
    required this.status,
    required this.productName,
  });

  final String tagId2;
  final int? productCode;
  final int? number;
  final String status;
  final String productName;

  static ProductByEpc fromJson(Map<String, dynamic> json) {
    return ProductByEpc(
      tagId2: json['tagId2'] as String? ?? '',
      productCode: (json['productCode'] as num?)?.toInt(),
      number: (json['number'] as num?)?.toInt(),
      status: json['status'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
    );
  }
}
