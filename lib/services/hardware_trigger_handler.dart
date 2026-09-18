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
  double _timedSeconds = HardwareTriggerModeStorage.timedSecondsDefault;

  /// 押下→離しの順序を崩さないよう、トリガー処理を直列化する。
  Future<void> _queue = Future<void>.value();

  /// SharedPreferences を読み、リスナを張り直す。
  Future<void> attach(TagReaderService reader) async {
    await cancelSubscriptionOnly();
    await reloadSettings();
    _sub = reader.triggerStream.listen(_onTrigger);
  }

  /// 設定画面から戻った直後など、モード／秒数だけ再読込する。
  Future<void> reloadSettings() async {
    await HardwareTriggerModeStorage.forceToggleIfSr7AndHold();
    _mode = await HardwareTriggerModeStorage.getMode();
    _timedSeconds = await HardwareTriggerModeStorage.getTimedSeconds();
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
    _queue = Future<void>.value();
  }

  void _onTrigger(bool pressed) {
    // トリガー毎に prefs を await しない（長押しの押下/離しレース防止）
    _queue = _queue.then((_) => _handleTrigger(pressed));
  }

  Future<void> _handleTrigger(bool pressed) async {
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

        _timedStopTimer = Timer(
          Duration(milliseconds: (_timedSeconds * 1000).round()),
          () async {
          if (mounted() && isReading()) {
            await onStop();
          }
        });
        return;
    }
  }
}
