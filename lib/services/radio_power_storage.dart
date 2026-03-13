import 'package:shared_preferences/shared_preferences.dart';

const String _keyDecreaseDecibel = 'radio_power_decrease_decibel';

/// 電波出力の減衰量（decreaseDecibel）の永続化（SharedPreferences）
/// 未保存時は 0（最大出力）を返す
class RadioPowerStorage {
  RadioPowerStorage._();

  static Future<int> getDecreaseDecibel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDecreaseDecibel) ?? 0;
  }

  static Future<void> saveDecreaseDecibel(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDecreaseDecibel, value);
  }
}
