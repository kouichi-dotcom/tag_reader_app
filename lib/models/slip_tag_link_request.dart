/// 用件「交換」時の link_mode 値（API / tag_table3.tag_mode と同一）。
class SlipTagLinkMode {
  static const exchangeDelivery = '交換納品';
  static const exchangeReturn = '交換返品';

  SlipTagLinkMode._();
}

/// POST /api/reception-slips/{receptionNo}/link-tags のリクエスト。
class SlipTagLinkRequest {
  final String? userId;
  /// 用件「交換」のとき必須（[SlipTagLinkMode.exchangeDelivery] / [SlipTagLinkMode.exchangeReturn]）。
  final String? linkMode;
  final List<SlipTagLinkItem> items;

  const SlipTagLinkRequest({
    this.userId,
    this.linkMode,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        if (userId != null) 'user_id': userId,
        if (linkMode != null && linkMode!.isNotEmpty) 'link_mode': linkMode,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class SlipTagLinkItem {
  final String epc;
  final String? productCode;

  const SlipTagLinkItem({
    required this.epc,
    this.productCode,
  });

  Map<String, dynamic> toJson() => {
        'epc': epc,
        if (productCode != null && productCode!.isNotEmpty)
          'product_code': productCode,
      };
}

/// POST /api/reception-slips/{receptionNo}/link-tags のレスポンス。
class SlipTagLinkResult {
  final String receptionNo;
  final int linked;
  final List<String> warnings;

  const SlipTagLinkResult({
    required this.receptionNo,
    required this.linked,
    this.warnings = const [],
  });

  factory SlipTagLinkResult.fromJson(Map<String, dynamic> json) {
    final warningsRaw = json['warnings'];
    return SlipTagLinkResult(
      receptionNo: json['receptionNo']?.toString() ?? '',
      linked: (json['linked'] as num?)?.toInt() ?? 0,
      warnings: warningsRaw is List
          ? warningsRaw.map((e) => e.toString()).toList()
          : const [],
    );
  }
}
