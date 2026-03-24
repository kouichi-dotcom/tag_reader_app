import 'dart:async';

import 'hardware_trigger_mode_storage.dart';
import 'tag_reader_service.dart';

/// 本体トリガー（triggerStream）を [HardwareTriggerMode] に従って解釈する。
/// アプリ内の「読取開始／停止」ボタンは別途トグルでよく、停止時は [notifyStoppedByAppButton] を呼ぶこと。
class HardwareTriggerHandler {
  HardwareTriggerHandler({
    required this.onStart,
    required this.onStop,
    required this.isReading,
    required this.mounted,
  });

  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final bool Function() isReading;
  final bool Function() mounted;

  StreamSubscription<bool>? _sub;
  Timer? _timedStopTimer;

  HardwareTriggerMode _mode = HardwareTriggerMode.toggle;
  int _timedSeconds = HardwareTriggerModeStorage.timedSecondsDefault;

  /// SharedPreferences を読み、リスナを張り直す。
  Future<void> attach(TagReaderService reader) async {
    await cancelSubscriptionOnly();
    _mode = await HardwareTriggerModeStorage.getMode();
    _timedSeconds = await HardwareTriggerModeStorage.getTimedSeconds();
    _sub = reader.triggerStream.listen(_onTrigger);
  }

  /// 時間式の自動停止タイマーのみキャンセル（アプリの停止ボタンから読取を止めたときに呼ぶ）
  void notifyStoppedByAppButton() {
    _timedStopTimer?.cancel();
    _timedStopTimer = null;
  }

  /// サブスクとタイマーを破棄（画面 dispose）
  Future<void> cancelSubscriptionOnly() async {
    await _sub?.cancel();
    _sub = null;
    _timedStopTimer?.cancel();
    _timedStopTimer = null;
  }

  Future<void> _onTrigger(bool pressed) async {
    if (!mounted()) return;

    switch (_mode) {
      case HardwareTriggerMode.toggle:
        if (!pressed) return;
        if (isReading()) {
          await onStop();
        } else {
          await onStart();
        }
        return;

      case HardwareTriggerMode.hold:
        if (pressed) {
          if (!isReading()) await onStart();
        } else {
          if (isReading()) await onStop();
        }
        return;

      case HardwareTriggerMode.timed:
        if (!pressed) return;
        _timedStopTimer?.cancel();
        _timedStopTimer = null;

        if (!isReading()) {
          await onStart();
        }
        if (!mounted() || !isReading()) return;

        _timedStopTimer = Timer(Duration(seconds: _timedSeconds), () async {
          if (mounted() && isReading()) {
            await onStop();
          }
        });
        return;
    }
  }
}
