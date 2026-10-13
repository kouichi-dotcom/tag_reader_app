// 急ぎ来店納品の UI 用モデル。
// 現状は画面確認用の仮データ。後から実データ／API に差し替えやすいよう分離している。

/// 本日読み取った未処理商品 1 件
class UrgentReadItem {
  const UrgentReadItem({
    required this.id,
    required this.productName,
    required this.productCode,
    required this.number,
    required this.tagId,
    required this.readAt,
  });

  final String id;
  final String productName;
  final String productCode;

  /// 個体番号（表示用。ゼロ埋め等は呼び出し側で整形してもよい）
  final String number;
  final String tagId;
  final DateTime readAt;

  /// 表示用「08:15」
  String get readTimeLabel {
    final hh = readAt.hour.toString().padLeft(2, '0');
    final mm = readAt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

/// 伝票選択画面用の仮伝票（本実装時は ReceptionSlip 等に差し替え）
class UrgentSlipCandidate {
  const UrgentSlipCandidate({
    required this.id,
    required this.deliveryNo,
    required this.companyName,
    required this.siteName,
  });

  final String id;
  final String deliveryNo;
  final String companyName;
  final String siteName;
}
