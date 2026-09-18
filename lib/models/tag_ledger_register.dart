/// POST /api/products/tag-ledger のリクエスト
class TagLedgerRegisterRequest {
  const TagLedgerRegisterRequest({
    required this.epc,
    required this.productCode,
    this.number,
    this.autoNumber = false,
    this.userId,
    this.userName,
  });

  final String epc;
  final int productCode;
  final int? number;
  final bool autoNumber;
  final String? userId;
  final String? userName;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'epc': epc,
      'product_code': productCode,
      'auto_number': autoNumber,
      'user_id': userId,
      'user_name': userName,
    };
    if (!autoNumber && number != null) map['number'] = number;
    return map;
  }
}

/// POST /api/products/tag-ledger のレスポンス
class TagLedgerRegisterResult {
  const TagLedgerRegisterResult({
    required this.tagId2,
    required this.productCode,
    required this.number,
    required this.tagMode2,
  });

  final String tagId2;
  final int productCode;
  final int number;
  final String tagMode2;

  factory TagLedgerRegisterResult.fromJson(Map<String, dynamic> json) {
    return TagLedgerRegisterResult(
      tagId2: (json['tagId2'] as String?)?.trim() ?? '',
      productCode: (json['productCode'] as num).toInt(),
      number: (json['number'] as num).toInt(),
      tagMode2: (json['tagMode2'] as String?)?.trim() ?? '登録',
    );
  }
}
