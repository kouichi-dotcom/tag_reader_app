import 'dart:async';

import 'package:flutter/foundation.dart';

import 'connected_device_storage.dart';
import 'reader_connection_log.dart';
import 'tag_reader_service.dart';

/// アプリ全体で共有するタグリーダー接続フェーズ（Storage とは独立）。
enum ReaderConnectionPhase {
  disconnected,
  connecting,
  connected,
  disconnecting,
  connectFailed,
  linkLost,
}

/// 接続状態の一元管理。画面遷移後もイベントを処理する。
/// 自動接続・自動再接続は行わない。
class ReaderConnectionSession extends ChangeNotifier {
  ReaderConnectionSession._();

  static final ReaderConnectionSession instance = ReaderConnectionSession._();

  final TagReaderService _reader = TagReaderService.instance;

  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _started = false;

  ReaderConnectionPhase _phase = ReaderConnectionPhase.disconnected;
  String? _deviceName;
  String? _deviceAddress;
  String? _lastErrorCode;

  /// 手動切断の `disconnect()` が戻るまで、SDK の切断通知では完了にしない。
  /// 別リーダー切り替えの事前切断では true にしない。
  bool _awaitingManualDisconnectResult = false;

  ReaderConnectionPhase get phase => _phase;
  String? get deviceName => _deviceName;
  String? get deviceAddress => _deviceAddress;
  String? get lastErrorCode => _lastErrorCode;
  bool get awaitsManualDisconnectResult => _awaitingManualDisconnectResult;

  bool get isConnected => _phase == ReaderConnectionPhase.connected;
  bool get isBusy =>
      _phase == ReaderConnectionPhase.connecting ||
      _phase == ReaderConnectionPhase.disconnecting;

  /// アプリ起動時に一度呼ぶ。複数回呼んでも安全。
  void ensureStarted() {
    if (_started || !_reader.supportsNativeRfid) return;
    _started = true;
    _sub = _reader.events.listen(_onEvent);
    unawaited(_syncFromNative());
  }

  Future<void> _syncFromNative() async {
    if (_awaitingManualDisconnectResult) return;
    try {
      final connected = await _reader.isConnected();
      final name = await ConnectedDeviceStorage.getName();
      final id = await ConnectedDeviceStorage.getId();
      if (connected) {
        _phase = ReaderConnectionPhase.connected;
        _deviceName = name;
        _deviceAddress = id;
      } else {
        if (name != null || id != null) {
          await ConnectedDeviceStorage.clear();
        }
        if (_phase == ReaderConnectionPhase.connected ||
            _phase == ReaderConnectionPhase.linkLost) {
          _phase = ReaderConnectionPhase.disconnected;
        }
        _deviceName = null;
        _deviceAddress = null;
      }
      notifyListeners();
    } catch (e) {
      ReaderConnectionLog.write(
        action: 'sync_from_native',
        result: 'error',
        detail: e.toString(),
      );
    }
  }

  void _onEvent(Map<String, dynamic> e) {
    final type = e['type'] as String?;
    switch (type) {
      case 'connected':
        // 接続成功の確定は connect() の戻り／呼び出し側で行う。
        // ここはフェーズが connecting/connected のときだけ補強する。
        if (_phase == ReaderConnectionPhase.connecting ||
            _phase == ReaderConnectionPhase.connected) {
          _phase = ReaderConnectionPhase.connected;
          notifyListeners();
        }
        break;
      case 'disconnected':
        _onLinkEnded(linkLost: false);
        break;
      case 'link_lost':
        _onLinkEnded(linkLost: true);
        break;
      default:
        break;
    }
  }

  void _onLinkEnded({required bool linkLost}) {
    if (_awaitingManualDisconnectResult) {
      ReaderConnectionLog.write(
        action: linkLost ? 'link_lost' : 'disconnected_event',
        result: 'deferred_manual_disconnect',
        deviceHint: ReaderConnectionLog.deviceHintFrom(
          name: _deviceName,
          address: _deviceAddress,
        ),
      );
      return;
    }
    _handleUnexpectedOrExplicitDisconnect(linkLost: linkLost);
  }

  void _handleUnexpectedOrExplicitDisconnect({required bool linkLost}) {
    _awaitingManualDisconnectResult = false;
    final wasConnected = _phase == ReaderConnectionPhase.connected ||
        _phase == ReaderConnectionPhase.disconnecting;
    ReaderConnectionLog.write(
      action: linkLost ? 'link_lost' : 'disconnected_event',
      result: wasConnected ? 'ok' : 'ignored_idle',
      deviceHint: ReaderConnectionLog.deviceHintFrom(
        name: _deviceName,
        address: _deviceAddress,
      ),
    );
    _deviceName = null;
    _deviceAddress = null;
    _phase = linkLost
        ? ReaderConnectionPhase.linkLost
        : ReaderConnectionPhase.disconnected;
    unawaited(ConnectedDeviceStorage.clear());
    notifyListeners();
  }

  void markConnecting({String? name, String? address}) {
    _awaitingManualDisconnectResult = false;
    _phase = ReaderConnectionPhase.connecting;
    _lastErrorCode = null;
    _deviceName = name;
    _deviceAddress = address;
    notifyListeners();
  }

  void markConnected({required String name, required String address}) {
    _awaitingManualDisconnectResult = false;
    _phase = ReaderConnectionPhase.connected;
    _deviceName = name;
    _deviceAddress = address;
    _lastErrorCode = null;
    notifyListeners();
  }

  void markConnectFailed({String? errorCode}) {
    _awaitingManualDisconnectResult = false;
    _phase = ReaderConnectionPhase.connectFailed;
    _lastErrorCode = errorCode;
    _deviceName = null;
    _deviceAddress = null;
    notifyListeners();
  }

  /// [manual] が true のときだけ、SDK の切断通知を完了扱いにしない。
  /// 別リーダーへの切り替え前切断は false（既定）のままにする。
  void markDisconnecting({bool manual = false}) {
    _phase = ReaderConnectionPhase.disconnecting;
    _awaitingManualDisconnectResult = manual;
    notifyListeners();
  }

  void markDisconnected() {
    _awaitingManualDisconnectResult = false;
    _phase = ReaderConnectionPhase.disconnected;
    _deviceName = null;
    _deviceAddress = null;
    _lastErrorCode = null;
    notifyListeners();
  }

  /// 切断要求後も SDK が接続中と返したとき。接続表示のまま再切断できる。
  void markDisconnectKeptConnected() {
    _awaitingManualDisconnectResult = false;
    _lastErrorCode = 'disconnect_incomplete';
    _phase = ReaderConnectionPhase.connected;
    notifyListeners();
  }

  /// 接続中か未接続か判定できないとき。未接続にはせず、接続操作は busy のまま止める。
  void markDisconnectUncertain() {
    _awaitingManualDisconnectResult = false;
    _lastErrorCode = 'disconnect_incomplete';
    if (_phase != ReaderConnectionPhase.disconnecting) {
      _phase = ReaderConnectionPhase.disconnecting;
    }
    notifyListeners();
  }

  @visibleForTesting
  void debugReset() {
    _awaitingManualDisconnectResult = false;
    _phase = ReaderConnectionPhase.disconnected;
    _deviceName = null;
    _deviceAddress = null;
    _lastErrorCode = null;
    notifyListeners();
  }

  @visibleForTesting
  void debugDispatchEvent(Map<String, dynamic> event) {
    _onEvent(event);
  }

  Future<void> refreshFromNative() => _syncFromNative();

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    super.dispose();
  }
}
