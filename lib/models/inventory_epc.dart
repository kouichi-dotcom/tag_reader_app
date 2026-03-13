class InventoryEpc {
  const InventoryEpc({
    required this.epcPcUii,
    required this.attrs,
  });

  /// SDKの onInventoryEPC で届く先頭フィールド（PC+UII）
  final String epcPcUii;

  /// `TIME=...` などの付加情報
  final Map<String, String> attrs;

  /// PC（先頭2バイト=4hex）。存在しない/短い場合は null。
  String? get pcHex => epcPcUii.length >= 4 ? epcPcUii.substring(0, 4) : null;

  /// UII（PCの後ろ）。存在しない/短い場合は null。
  String? get uiiHex => epcPcUii.length > 4 ? epcPcUii.substring(4) : null;

  /// 便宜上、DB照合や一覧表示に使うEPC候補（基本はUII優先）。
  ///
  /// - SDKの例では先頭フィールドが「PC+UII」になるため、DB側がUIIのみ保持している場合に一致させやすい。
  /// - 実機/DB定義により PC込みを使う場合は `epcPcUii` を利用する。
  String get epcForLookup => uiiHex ?? epcPcUii;

  int? get timeMs => int.tryParse(attrs['TIME'] ?? '');
  double? get rssi => double.tryParse(attrs['RSSI'] ?? '');
  int? get channel => int.tryParse(attrs['CH'] ?? '');
  int? get temp => int.tryParse(attrs['TEMP'] ?? '');
  int? get phase => int.tryParse(attrs['PH'] ?? '');

  static InventoryEpc parse(String raw) {
    final parts = raw.split(',').where((e) => e.trim().isNotEmpty).toList();
    final epcPcUii = parts.isNotEmpty ? parts.first.trim() : raw.trim();
    final attrs = <String, String>{};
    for (final p in parts.skip(1)) {
      final idx = p.indexOf('=');
      if (idx <= 0) continue;
      final k = p.substring(0, idx).trim();
      final v = p.substring(idx + 1).trim();
      if (k.isNotEmpty) attrs[k] = v;
    }
    return InventoryEpc(epcPcUii: epcPcUii, attrs: attrs);
  }
}

