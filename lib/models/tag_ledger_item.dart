/// GET /api/products/tag-ledger の 1 件（tag_id2 → 商品コード・番号）
class TagLedgerItem {
  const TagLedgerItem({
    required this.tagId2,
    this.productCode,
    this.number,
  });

  final String tagId2;
  final int? productCode;
  final int? number;

  static TagLedgerItem fromJson(Map<String, dynamic> json) {
    return TagLedgerItem(
      tagId2: (json['tagId2'] as String?)?.trim() ?? '',
      productCode: (json['productCode'] as num?)?.toInt(),
      number: (json['number'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'tagId2': tagId2,
        'productCode': productCode,
        'number': number,
      };
}
