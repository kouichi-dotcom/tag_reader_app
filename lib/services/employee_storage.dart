import 'package:shared_preferences/shared_preferences.dart';

const String _keyEmployeeCode = 'employee_code';
const String _keyEmployeeName = 'employee_name';

/// 従業員コード・氏名の永続化（SharedPreferences）
class EmployeeStorage {
  EmployeeStorage._();

  static Future<void> save(String code, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmployeeCode, code);
    await prefs.setString(_keyEmployeeName, name);
  }

  static Future<String?> getCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmployeeCode);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmployeeName);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmployeeCode);
    await prefs.remove(_keyEmployeeName);
  }
}
