import 'package:shared_preferences/shared_preferences.dart';

import 'connected_device_storage.dart';
import 'reader_family.dart';

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

  static const double timedSecondsMin = 0.1;
  static const double timedSecondsMax = 10.0;
  static const double timedSecondsDefault = 1.5;
  static const double timedSecondsStep = 0.1;

  /// 0.1 秒刻みに丸める（スライダー・ステッパー共通）
  static double snapToStep(double seconds) {
    final steps = ((seconds - timedSecondsMin) / timedSecondsStep).round();
    return (timedSecondsMin + steps * timedSecondsStep)
        .clamp(timedSecondsMin, timedSecondsMax);
  }

  /// 表示用（整数秒なら小数なし、それ以外は 1 桁）
  static String formatTimedSeconds(double seconds) {
    final snapped = snapToStep(seconds);
    if ((snapped * 10).round() % 10 == 0) {
      return snapped.toInt().toString();
    }
    return snapped.toStringAsFixed(1);
  }

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

  static Future<double> getTimedSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    // getInt/getDouble は型が違うと例外になるため、生の値で判定する。
    // 現行は double、旧バージョンは int の可能性がある。
    final raw = prefs.get(_keyTimedSeconds);
    if (raw is double) {
      return snapToStep(raw.clamp(timedSecondsMin, timedSecondsMax));
    }
    if (raw is int) {
      final v = snapToStep(raw.toDouble().clamp(timedSecondsMin, timedSecondsMax));
      await prefs.setDouble(_keyTimedSeconds, v);
      return v;
    }
    return timedSecondsDefault;
  }

  static Future<void> saveTimedSeconds(double seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTimedSeconds, snapToStep(seconds));
  }

  /// 接続中が SR-7 かつ長押し式が保存されている場合、切替式へ強制変更する。
  /// 変更を行ったとき true を返す。
  static Future<bool> forceToggleIfSr7AndHold() async {
    final currentMode = await getMode();
    if (currentMode != HardwareTriggerMode.hold) return false;

    final connectedName = await ConnectedDeviceStorage.getName();
    final family = detectReaderFamilyFromName(connectedName);
    if (family != ReaderFamily.sr7) return false;

    await saveMode(HardwareTriggerMode.toggle);
    return true;
  }

  /// ICタグ一覧などのヒント1行（実機トリガー用）
  static String describeForTagList(HardwareTriggerMode mode, double timedSeconds) {
    switch (mode) {
      case HardwareTriggerMode.toggle:
        return 'リーダー本体トリガー: 1回押しで読取ON、もう1回でOFF';
      case HardwareTriggerMode.hold:
        return 'リーダー本体トリガー: 押している間だけ読取';
      case HardwareTriggerMode.timed:
        return 'リーダー本体トリガー: 押すと読取開始、約${formatTimedSeconds(timedSeconds)}秒で自動停止（再押下で延長）';
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
