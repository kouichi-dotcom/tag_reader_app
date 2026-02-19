import 'package:shared_preferences/shared_preferences.dart';

const String _keyDeviceId = 'connected_device_id';
const String _keyDeviceName = 'connected_device_name';

/// 接続中タグリーダー情報の永続化（SharedPreferences）
class ConnectedDeviceStorage {
  ConnectedDeviceStorage._();

  static Future<void> save(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, id);
    await prefs.setString(_keyDeviceName, name);
  }

  static Future<String?> getId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceName);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyDeviceName);
  }
}
