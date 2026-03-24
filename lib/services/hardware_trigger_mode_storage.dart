import 'package:shared_preferences/shared_preferences.dart';

const String _keyMode = 'hardware_trigger_mode';
const String _keyTimedSeconds = 'hardware_trigger_timed_seconds';

/// タグリーダー本体の読み取りボタン（triggerStream）の解釈モード
enum HardwareTriggerMode {
  /// 押下のたびに読取の ON/OFF を切り替え
  toggle,

  /// 押している間だけ読取
  hold,

  /// 押下で読取開始し、一定秒後に自動停止（読取中の再押下で秒数を延長）
  timed,
}

extension HardwareTriggerModeLabel on HardwareTriggerMode {
  String get label {
    switch (this) {
      case HardwareTriggerMode.toggle:
        return '切替式';
      case HardwareTriggerMode.hold:
        return '長押し式';
      case HardwareTriggerMode.timed:
        return '時間式';
    }
  }
}

/// 本体トリガーモードの永続化（SharedPreferences）
class HardwareTriggerModeStorage {
  HardwareTriggerModeStorage._();

  static const int timedSecondsMin = 1;
  static const int timedSecondsMax = 60;
  static const int timedSecondsDefault = 5;

  static Future<HardwareTriggerMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyMode);
    if (v == null) return HardwareTriggerMode.toggle;
    for (final e in HardwareTriggerMode.values) {
      if (e.name == v) return e;
    }
    return HardwareTriggerMode.toggle;
  }

  static Future<void> saveMode(HardwareTriggerMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode.name);
  }

  static Future<int> getTimedSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_keyTimedSeconds);
    if (v == null) return timedSecondsDefault;
    return v.clamp(timedSecondsMin, timedSecondsMax);
  }

  static Future<void> saveTimedSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyTimedSeconds,
      seconds.clamp(timedSecondsMin, timedSecondsMax),
    );
  }

  /// ICタグ一覧などのヒント1行（実機トリガー用）
  static String describeForTagList(HardwareTriggerMode mode, int timedSeconds) {
    switch (mode) {
      case HardwareTriggerMode.toggle:
        return 'リーダー本体トリガー: 1回押しで読取ON、もう1回でOFF';
      case HardwareTriggerMode.hold:
        return 'リーダー本体トリガー: 押している間だけ読取';
      case HardwareTriggerMode.timed:
        return 'リーダー本体トリガー: 押すと読取開始、約$timedSeconds秒で自動停止（再押下で延長）';
    }
  }

  /// 空一覧の補足（実機）
  static String describeEmptyStateHint(HardwareTriggerMode mode) {
    switch (mode) {
      case HardwareTriggerMode.toggle:
        return '読取開始ボタンまたはリーダー本体トリガー（切替式）で読み取れます';
      case HardwareTriggerMode.hold:
        return '読取開始ボタンまたはリーダー本体トリガー（長押し）で読み取れます';
      case HardwareTriggerMode.timed:
        return '読取開始ボタンまたはリーダー本体トリガー（時間式）で読み取れます';
    }
  }
}
