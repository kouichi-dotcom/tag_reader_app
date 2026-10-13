import 'package:shared_preferences/shared_preferences.dart';

import '../models/storage_location_mode.dart';
import 'storage_location_catalog.dart';

const String _keyManualLocation = 'storage_location';
const String _keyMode = 'storage_location_mode';
const String _keyLastDbCode = 'storage_location_last_db_code';

/// 保管場所名 → コード（カタログと同期）
Map<String, int> get storageLocationToCode => {
      for (final loc in StorageLocationCatalog.all) loc.name: loc.code,
    };

/// 保管場所設定の永続化（SharedPreferences）
///
/// - [mode]: GPS自動判定 / 手動（未保存時は GPS）
/// - 手動選択名: 次回タグ更新時に送る保管場所（DB そのものではない）
/// - [lastDbStorageLocationCode]: API 経由で観測・更新した直近の `保管場所コード`
class StorageLocationStorage {
  StorageLocationStorage._();

  /// 設定方法。未保存時は [StorageLocationMode.gpsAuto]。
  static Future<StorageLocationMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageLocationModeX.fromPrefs(prefs.getString(_keyMode));
  }

  static Future<void> saveMode(StorageLocationMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode.prefsValue);
  }

  /// 手動モードで選んだ保管場所名（再起動後も保持）。
  static Future<void> save(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyManualLocation, name);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyManualLocation);
  }

  /// 手動選択に対応するコード（1〜4）。未選択時は null。
  static Future<int?> getStorageLocationCode() async {
    final name = await getName();
    return StorageLocationCatalog.byName(name)?.code;
  }

  /// API で得た / タグ更新で書き込んだ直近の [ICタグ台帳].[保管場所コード]。
  /// 画面の「現在の保管場所」表示用（手動選択値とは別）。
  static Future<int?> getLastDbStorageLocationCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastDbCode);
  }

  static Future<String?> getLastDbStorageLocationName() async {
    final code = await getLastDbStorageLocationCode();
    if (code == null) return null;
    return StorageLocationCatalog.displayName(code);
  }

  /// DB 上の保管場所コードをアプリが知ったときに呼ぶ（取得・更新成功時）。
  static Future<void> rememberDbStorageLocationCode(int? code) async {
    if (code == null || code < 1 || code > 4) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastDbCode, code);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyManualLocation);
    await prefs.remove(_keyMode);
    await prefs.remove(_keyLastDbCode);
  }
}
