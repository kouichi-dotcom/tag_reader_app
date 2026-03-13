import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/product_catalog_item.dart';

const String _keyCacheJson = 'product_cache_json';
const String _keyLastUpdated = 'product_cache_last_updated';
const Duration _cacheTtl = Duration(hours: 24);

/// 商品名のキャッシュ（初回一括取得 + 永続 + メモリ + 不足分オンデマンド取得）
class ProductCache {
  ProductCache._();

  static final ProductCache instance = ProductCache._();

  final Map<String, String> _namesByCode = {};
  bool _initLoaded = false;

  /// 永続キャッシュを読み込みメモリに展開する。
  Future<void> init() async {
    if (_initLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyCacheJson);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final code = (m['productCode'] as num?)?.toInt();
          final name = m['productName'] as String? ?? '';
          if (code != null) _namesByCode[code.toString()] = name;
        }
      } catch (_) {
        // パース失敗時はメモリのみ空のまま
      }
    }
    _initLoaded = true;
  }

  /// キャッシュが空または TTL 切れなら現存商品一覧を一括取得して永続・メモリを更新する。
  /// 一括取得を試みて失敗した場合 false、それ以外は true。
  Future<bool> ensureInitialLoaded(ApiClient api) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final lastUpdated = prefs.getInt(_keyLastUpdated);
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired =
        lastUpdated == null || (now - lastUpdated) > _cacheTtl.inMilliseconds;

    if (_namesByCode.isEmpty || expired) {
      try {
        final list = await api.fetchProductCatalog();
        _namesByCode.clear();
        for (final e in list) {
          _namesByCode[e.productCode.toString()] = e.productName;
        }
        await _persist();
        return true;
      } catch (_) {
        // 失敗時は既存キャッシュのまま（空なら空）。オンデマンドで補える
        return false;
      }
    }
    return true;
  }

  Future<void> _persist() async {
    final list = _namesByCode.entries
        .map((e) => {
              'productCode': int.tryParse(e.key) ?? 0,
              'productName': e.value,
            })
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCacheJson, jsonEncode(list));
    await prefs.setInt(_keyLastUpdated, DateTime.now().millisecondsSinceEpoch);
  }

  /// メモリから商品名を取得（同期）。コードは文字列で渡す。
  String? getNameFromMemory(String code) {
    final k = code.trim();
    return k.isEmpty ? null : _namesByCode[k];
  }

  /// 商品名を解決する。メモリにあれば返す。無ければ API でオンデマンド取得してキャッシュ更新。
  Future<String?> resolveName(ApiClient api, String code) async {
    await init();
    final k = code.trim();
    if (k.isEmpty) return null;
    if (_namesByCode.containsKey(k)) return _namesByCode[k];
    final codeInt = int.tryParse(k);
    if (codeInt == null) return null;
    final item = await api.fetchProductByCode(codeInt);
    if (item != null) {
      _namesByCode[item.productCode.toString()] = item.productName;
      await _persist();
      return item.productName;
    }
    return null;
  }
}
