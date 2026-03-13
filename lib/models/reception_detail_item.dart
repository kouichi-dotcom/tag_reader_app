/// 受付明細の1行（API レスポンス）
class ReceptionDetailItem {
  const ReceptionDetailItem({
    this.productCode,
    required this.productName,
    this.quantity,
    required this.unitName,
  });

  final int? productCode;
  final String productName;
  final num? quantity;
  final String unitName;

  static ReceptionDetailItem fromJson(Map<String, dynamic> json) {
    return ReceptionDetailItem(
      productCode: (json['productCode'] as num?)?.toInt(),
      productName: json['productName'] as String? ?? '',
      quantity: json['quantity'] as num?,
      unitName: json['unitName'] as String? ?? '',
    );
  }
}
