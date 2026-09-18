import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/tag_ledger_item.dart';

const String _keyCacheJson = 'tag_ledger_cache_json';
const String _keyFetchDate = 'tag_ledger_fetch_date';

/// ICタグ台帳キャッシュ（tag_id2 → 商品コード・番号）。
/// 案 A': その日の初回起動だけ前回を破棄して全件再取得。成功後に差し替え。
class TagLedgerCache {
  TagLedgerCache._();

  static final TagLedgerCache instance = TagLedgerCache._();

  /// EPC（trim済み）→ (productCode, number)
  final Map<String, _LedgerEntry> _byEpc = {};
  bool _initLoaded = false;

  static String _todayLocal() {
    final n = DateTime.now();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _applyList(Iterable<TagLedgerItem> list) {
    _byEpc.clear();
    for (final e in list) {
      final tagId2 = e.tagId2.trim();
      if (tagId2.isEmpty) continue;
      _byEpc[tagId2] = _LedgerEntry(
        productCode: e.productCode,
        number: e.number,
      );
    }
  }

  void _applyJsonList(List<dynamic> list) {
    _byEpc.clear();
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final tagId2 = (m['tagId2'] as String?)?.trim() ?? '';
      if (tagId2.isEmpty) continue;
      _byEpc[tagId2] = _LedgerEntry(
        productCode: (m['productCode'] as num?)?.toInt(),
        number: (m['number'] as num?)?.toInt(),
      );
    }
  }

  /// 永続キャッシュを読み込みメモリに展開する。空なら assets の tag_ledger.json。
  Future<void> init() async {
    if (_initLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyCacheJson);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        _applyJsonList(list);
      } catch (_) {
        // パース失敗時は空のまま
      }
    }
    if (_byEpc.isEmpty) {
      try {
        final assetStr =
            await rootBundle.loadString('assets/data/tag_ledger.json');
        final list = jsonDecode(assetStr) as List<dynamic>;
        _applyJsonList(list);
      } catch (_) {
        // ファイルなし・パース失敗時はそのまま
      }
    }
    _initLoaded = true;
  }

  /// 取得日が今日でなければ全件再取得して差し替える。
  /// 失敗時は既存データを残し false を返す。kUseApi=false では assets のみ。
  Future<bool> ensureInitialLoaded(ApiClient api) async {
    await init();
    if (!kUseApi) return true;

    final prefs = await SharedPreferences.getInstance();
    final fetchDate = prefs.getString(_keyFetchDate);
    final today = _todayLocal();
    final needsRefresh = fetchDate != today || _byEpc.isEmpty;

    if (!needsRefresh) return true;

    try {
      final list = await api.fetchTagLedger();
      _applyList(list);
      await _persist(fetchDate: today);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist({String? fetchDate}) async {
    final list = _byEpc.entries
        .map((e) => {
              'tagId2': e.key,
              'productCode': e.value.productCode,
              'number': e.value.number,
            })
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCacheJson, jsonEncode(list));
    if (fetchDate != null) {
      await prefs.setString(_keyFetchDate, fetchDate);
    }
  }

  /// EPC で台帳を参照し、商品コード・番号を返す。見つからなければ null。
  TagLedgerEntry? lookup(String epc) {
    final k = epc.trim();
    if (k.isEmpty) return null;
    var e = _byEpc[k];
    if (e == null) {
      final lower = k.toLowerCase();
      for (final entry in _byEpc.entries) {
        if (entry.key.toLowerCase() == lower) {
          e = entry.value;
          break;
        }
      }
    }
    return e == null
        ? null
        : TagLedgerEntry(productCode: e.productCode, number: e.number);
  }

  /// 台帳キャッシュに同一 EPC（大文字小文字無視）があるか。
  bool containsEpc(String epc) => lookup(epc) != null;

  /// 個別 GET 成功時など、1 件をメモリ＋永続に追加／上書きする。
  Future<void> put(String epc, {int? productCode, int? number}) async {
    await init();
    final k = epc.trim();
    if (k.isEmpty) return;
    _byEpc[k] = _LedgerEntry(productCode: productCode, number: number);
    await _persist();
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
