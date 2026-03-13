import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/employee.dart';

const String _keyCacheJson = 'employee_cache_json';
const String _keyLastUpdated = 'employee_cache_last_updated';
const Duration _cacheTtl = Duration(hours: 24);

/// 担当者名のキャッシュ（初回一括取得 + 永続 + メモリ + 不足分オンデマンド取得）
class EmployeeCache {
  EmployeeCache._();

  static final EmployeeCache instance = EmployeeCache._();

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
          final code = (m['employeeCode'] as num?)?.toInt();
          final name = m['employeeName'] as String? ?? '';
          if (code != null) _namesByCode[code.toString()] = name;
        }
      } catch (_) {
        // パース失敗時はメモリのみ空のまま
      }
    }
    _initLoaded = true;
  }

  /// キャッシュが空または TTL 切れなら 1〜101 を一括取得して永続・メモリを更新する。
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
        final list = await api.fetchEmployeesInRange(minCode: 1, maxCode: 101);
        _namesByCode.clear();
        for (final e in list) {
          _namesByCode[e.employeeCode.toString()] = e.employeeName;
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
              'employeeCode': int.tryParse(e.key) ?? 0,
              'employeeName': e.value,
            })
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCacheJson, jsonEncode(list));
    await prefs.setInt(_keyLastUpdated, DateTime.now().millisecondsSinceEpoch);
  }

  /// メモリから担当者名を取得（同期）。コードは文字列で渡す。
  String? getNameFromMemory(String code) {
    final k = code.trim();
    return k.isEmpty ? null : _namesByCode[k];
  }

  /// 担当者名を解決する。メモリ → 永続再読込は行わず API のみ → なければ API でオンデマンド取得してキャッシュ更新。
  Future<String?> resolveName(ApiClient api, String code) async {
    await init();
    final k = code.trim();
    if (k.isEmpty) return null;
    if (_namesByCode.containsKey(k)) return _namesByCode[k];
    final emp = await api.fetchEmployee(code);
    if (emp != null) {
      _namesByCode[emp.employeeCode.toString()] = emp.employeeName;
      await _persist();
      return emp.employeeName;
    }
    return null;
  }
}
