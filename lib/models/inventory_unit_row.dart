/// GET /api/products/inventory/units の1行（個体）
class InventoryUnitRow {
  InventoryUnitRow({
    required this.number,
    required this.tagMode2,
    required this.manufacturer,
    required this.modelType,
    required this.remarks,
    this.acquisitionDateYmd,
  });

  final int? number;
  final String tagMode2;
  final String manufacturer;
  final String modelType;
  final String remarks;
  final String? acquisitionDateYmd;

  factory InventoryUnitRow.fromJson(Map<String, dynamic> json) {
    return InventoryUnitRow(
      number: _readInt(json['number']),
      tagMode2: json['tagMode2']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString() ?? '',
      modelType: json['modelType']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
      acquisitionDateYmd: json['acquisitionDateYmd']?.toString(),
    );
  }

  static int? _readInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  /// tag_mode2 を在庫一覧に表示してよい値か（OK／ＯＫ／在庫／清掃中／整備中）。表記ゆれ除去後に判定。
  static bool isAllowedTagMode2ForInventory(String raw) {
    const allowed = {'OK', 'ＯＫ', '在庫', '清掃中', '整備中'};
    return allowed.contains(normalizeTagMode2ForInventory(raw));
  }

  /// 集計用のステータスキー（ok / cleaning / maintenance / storage）。未対応は null。
  static String? inventoryStatusKey(String raw) {
    switch (normalizeTagMode2ForInventory(raw)) {
      case 'OK':
      case 'ＯＫ':
        return 'ok';
      case '清掃中':
        return 'cleaning';
      case '整備中':
        return 'maintenance';
      case '在庫':
        return 'storage';
      default:
        return null;
    }
  }

  static String normalizeTagMode2ForInventory(String s) {
    var t = s.trim();
    for (final ch in ['\u3000', '\uFEFF', '\u200B']) {
      t = t.replaceAll(ch, '');
    }
    return t.trim();
  }
}
