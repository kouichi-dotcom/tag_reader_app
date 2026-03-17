import 'dart:convert';

import 'package:flutter/services.dart';

/// ICタグ台帳のスナップショット（tag_id2 → 商品コード・番号）。
/// assets/data/tag_ledger.json を読み込み、APIが使えない開発時も照合可能にする。
class TagLedgerCache {
  TagLedgerCache._();

  static final TagLedgerCache instance = TagLedgerCache._();

  /// EPC（trim済み）→ (productCode, number)
  final Map<String, _LedgerEntry> _byEpc = {};
  bool _initLoaded = false;

  /// assets の tag_ledger.json を読み込む。
  Future<void> init() async {
    if (_initLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/tag_ledger.json');
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _byEpc.clear();
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final tagId2 = (m['tagId2'] as String?)?.trim() ?? '';
        if (tagId2.isEmpty) continue;
        final productCode = (m['productCode'] as num?)?.toInt();
        final number = (m['number'] as num?)?.toInt();
        _byEpc[tagId2] = _LedgerEntry(productCode: productCode, number: number);
      }
    } catch (_) {
      // ファイルなし・パース失敗時は空のまま
    }
    _initLoaded = true;
  }

  /// EPC で台帳を参照し、商品コード・番号を返す。見つからなければ null。
  TagLedgerEntry? lookup(String epc) {
    final k = epc.trim();
    final e = k.isEmpty ? null : _byEpc[k];
    return e == null ? null : TagLedgerEntry(productCode: e.productCode, number: e.number);
  }
}

/// 台帳1件（商品コード・番号のみ。商品名は商品台帳で別途取得）
class TagLedgerEntry {
  const TagLedgerEntry({this.productCode, this.number});
  final int? productCode;
  final int? number;
}

class _LedgerEntry {
  _LedgerEntry({this.productCode, this.number});
  final int? productCode;
  final int? number;
}
