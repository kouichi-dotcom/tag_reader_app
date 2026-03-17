import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
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
  /// 永続が空の場合は assets/data/product_catalog.json を読み込み（APIが使えない開発時用）。
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
    // 永続が空なら assets の商品台帳を読み込む（開発時・オフライン用）
    if (_namesByCode.isEmpty) {
      try {
        final assetStr = await rootBundle.loadString('assets/data/product_catalog.json');
        final list = jsonDecode(assetStr) as List<dynamic>;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final code = (m['productCode'] as num?)?.toInt();
          final name = m['productName'] as String? ?? '';
          if (code != null) _namesByCode[code.toString()] = name;
        }
      } catch (_) {
        // ファイルなし・パース失敗時はそのまま
      }
    }
    _initLoaded = true;
  }

  /// キャッシュが空または TTL 切れなら現存商品一覧を一括取得して永続・メモリを更新する。
  /// Android（kUseApi=false）では API を呼ばず、init() で読み込んだ JSON のみ使用する。
  Future<bool> ensureInitialLoaded(ApiClient api) async {
    await init();
    if (!kUseApi) return true; // Android: API 呼び出しなし
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

  /// 商品名を解決する。メモリにあれば返す。Android では API を呼ばず JSON のみ。
  Future<String?> resolveName(ApiClient api, String code) async {
    await init();
    final k = code.trim();
    if (k.isEmpty) return null;
    if (_namesByCode.containsKey(k)) return _namesByCode[k];
    if (!kUseApi) return null; // Android: API 呼び出しなし
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
