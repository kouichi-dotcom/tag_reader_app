import 'package:shared_preferences/shared_preferences.dart';

const String _keyStorageLocation = 'storage_location';

/// 保管場所の名前 → [ICタグ台帳].tag_mode 用の数値（0=非表示, 1=本社, 2=山川, 3=東風平, 4=友寄）
const Map<String, int> storageLocationToCode = {
  '本社': 1,
  '山川': 2,
  '東風平': 3,
  '友寄': 4,
};

/// 保管場所の永続化（SharedPreferences）
/// 担当者コードと同様、一度選択すれば変更するまで保持される。
class StorageLocationStorage {
  StorageLocationStorage._();

  static Future<void> save(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStorageLocation, name);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStorageLocation);
  }

  /// 現在の保管場所名に対応する tag_mode 用数値（1〜4）を返す。未選択・非表示の場合は null。
  static Future<int?> getStorageLocationCode() async {
    final name = await getName();
    if (name == null || name.isEmpty) return null;
    return storageLocationToCode[name];
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStorageLocation);
  }
}
