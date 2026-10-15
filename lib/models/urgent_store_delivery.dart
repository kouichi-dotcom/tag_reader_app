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

  /// 表示用「2026/10/15 08:15」
  String get readTimeLabel {
    final y = readAt.year.toString();
    final mo = readAt.month.toString().padLeft(2, '0');
    final d = readAt.day.toString().padLeft(2, '0');
    final hh = readAt.hour.toString().padLeft(2, '0');
    final mm = readAt.minute.toString().padLeft(2, '0');
    return '$y/$mo/$d $hh:$mm';
  }
}
