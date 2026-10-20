import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../mocks/mock_data.dart';
import '../services/connected_device_storage.dart';
import '../services/hardware_trigger_mode_storage.dart';
import '../services/reader_connection_log.dart';
import '../services/reader_connection_session.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';
import '../utils/connect_error_messages.dart';
import '../widgets/main_flow_nav_bar.dart';

/// 画面 1: タグリーダー接続（design/screen1-connection-wireframe.html 準拠）
/// スキャン・デバイス一覧・接続・切断
/// 画面破棄時はスキャン停止のみ（Bluetooth 接続は維持）
class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  /// 単体テスト用。Android / iOS およびリリースビルドでは使わない。
  /// 切断ボタンから `disconnect()` 完了を保留できるようにする。
  @visibleForTesting
  static Future<bool> Function()? debugDisconnectOverride;

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen>
    with WidgetsBindingObserver {
  List<MockBleDevice> _bondedDevices = [];
  List<MockBleDevice> _scannedBleDevices = [];
  MockBleDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  /// 切断中表示の最初の build だけ記録する。毎フレームは出さない。
  bool _disconnectUiBuildLogged = false;
  MockBleDevice? _connectingDevice;
  String? _firmwareVersion;

  final _reader = TagReaderService.instance;
  final _session = ReaderConnectionSession.instance;
  StreamSubscription<Map<String, dynamic>>? _sub;
  StreamSubscription<Map<String, dynamic>>? _bleScanSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.ensureStarted();
    _session.addListener(_onSessionChanged);
    _loadSavedConnection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBondedDevices();
    });
    _sub = _reader.events.listen((e) async {
      if (!mounted) return;
      switch (e['type']) {
        case 'connected':
          await _stopScan();
          if (mounted) setState(() {});
          break;
        case 'disconnected':
        case 'link_lost':
          // 手動切断の完了は disconnect() の戻りで決める。通知だけでは解除しない。
          if (_session.awaitsManualDisconnectResult) break;
          final linkLost = e['type'] == 'link_lost';
          final wasDisconnecting = _isDisconnecting;
          setState(() {
            _connectedDevice = null;
            _firmwareVersion = null;
            _isConnecting = false;
            _isDisconnecting = false;
            _connectingDevice = null;
          });
          if (wasDisconnecting) {
            ReaderConnectionLog.write(
              action: 'disconnect_ui_flag',
              result: 'clear_by_event',
              detail: e['type'] as String?,
            );
          }
          if (linkLost && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(linkLostMessageForUser())),
            );
          }
          break;
        case 'firmware':
          final v = e['version'] as String?;
          if (v != null && v.isNotEmpty) setState(() => _firmwareVersion = v);
          break;
      }
    });
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (_isDisconnecting ||
        _session.awaitsManualDisconnectResult ||
        _session.phase == ReaderConnectionPhase.disconnecting) {
      return;
    }
    // Storage ではなくセッション／SDK 実状態を優先して表示を合わせる
    if (!_session.isConnected && _connectedDevice != null) {
      setState(() {
        _connectedDevice = null;
        _firmwareVersion = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onSessionChanged);
    _sub?.cancel();
    _bleScanSub?.cancel();
    // 接続は維持。スキャンと購読のみ解放。
    if (_reader.supportsNativeRfid && _isScanning) {
      unawaited(_reader.stopBleScan());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // バックグラウンド移行では disconnect しない（仕様）
    if (state == AppLifecycleState.resumed && mounted && _reader.supportsNativeRfid) {
      _loadBondedDevices();
      _loadSavedConnection();
      unawaited(_session.refreshFromNative());
    }
  }

  /// ペアリング済み（登録済み）デバイス一覧のみ取得。BLE スキャンは開始しない。
  Future<void> _loadBondedDevices() async {
    if (!mounted) return;
    try {
      if (_reader.supportsNativeRfid) {
        final ok = await _reader.requestBluetoothPermissions();
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(connectFailureMessageForUser(
                PlatformException(code: 'permission_required'),
              ))),
            );
          }
          return;
        }
        if (!mounted) return;
        final bonded = await _reader.getBondedDevices();
        if (!mounted) return;
        setState(() {
          _bondedDevices = bonded
              .map((d) => MockBleDevice(id: d.address, name: d.name))
              .toList();
        });
      } else {
        setState(() {
          _bondedDevices = List.from(mockBleDevices);
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission_required' || e.code == 'bluetooth_off') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(connectFailureMessageForUser(e))),
        );
        if (e.code == 'bluetooth_off') {
          await _promptEnableBluetooth();
        }
      } else {
        debugPrint('getBondedDevices failed: $e');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('getBondedDevices failed: $e');
      }
    }
  }

  Future<void> _promptEnableBluetooth() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('BluetoothがOFFです'),
        content: const Text('BluetoothをONにしてから再度お試しください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSavedConnection() async {
    final id = await ConnectedDeviceStorage.getId();
    final name = await ConnectedDeviceStorage.getName();
    if (!mounted) return;
    if (_reader.supportsNativeRfid) {
      final actuallyConnected = await _reader.isConnected();
      if (!actuallyConnected) {
        if (mounted) {
          setState(() {
            _connectedDevice = null;
            _firmwareVersion = null;
          });
        }
        await ConnectedDeviceStorage.clear();
        return;
      }
      if (id != null && name != null && mounted) {
        setState(() => _connectedDevice = MockBleDevice(id: id, name: name));
      }
      return;
    }
    if (id == null || name == null) return;
    if (mounted) setState(() => _connectedDevice = MockBleDevice(id: id, name: name));
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      if (_reader.supportsNativeRfid) {
        final ok = await _reader.requestBluetoothPermissions();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(connectFailureMessageForUser(
              PlatformException(code: 'permission_required'),
            ))),
          );
          setState(() => _isScanning = false);
          return;
        }
        final bonded = await _reader.getBondedDevices();
        if (!mounted) return;
        setState(() {
          _bondedDevices = bonded
              .map((d) => MockBleDevice(id: d.address, name: d.name))
              .toList();
          _scannedBleDevices = [];
        });
        _bleScanSub?.cancel();
        _bleScanSub = _reader.events
            .where((e) => e['type'] == 'ble_device_found')
            .listen((e) {
          if (!mounted) return;
          final name = (e['name'] as String?) ?? '';
          final address = (e['address'] as String?) ?? '';
          if (address.isEmpty) return;
          final bondedIds = _bondedDevices.map((d) => d.id).toSet();
          if (bondedIds.contains(address)) return;
          setState(() {
            final existing = _scannedBleDevices.any((d) => d.id == address);
            if (!existing) {
              _scannedBleDevices = [
                ..._scannedBleDevices,
                MockBleDevice(id: address, name: name.isNotEmpty ? name : 'Unknown'),
              ];
            }
          });
        });
        await _reader.startBleScan();
      } else {
        setState(() {
          _bondedDevices = List.from(mockBleDevices);
          _scannedBleDevices = List.from(mockScannedBleDevices);
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(connectFailureMessageForUser(e))),
        );
        if (e.code == 'bluetooth_off') {
          await _promptEnableBluetooth();
        }
        setState(() => _isScanning = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('スキャン失敗: $e')),
        );
        setState(() => _isScanning = false);
      }
    } finally {
      if (mounted && !_reader.supportsNativeRfid) setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    if (_reader.supportsNativeRfid) {
      await _reader.stopBleScan();
      _bleScanSub?.cancel();
      _bleScanSub = null;
    }
    if (mounted) setState(() => _isScanning = false);
  }

  bool get _buttonsLocked => _isConnecting || _isDisconnecting || _session.isBusy;

  /// 切断の再試行は、処理中と接続処理中だけ止める。判定不能で busy のときは再度切断できる。
  bool get _disconnectLocked =>
      _isDisconnecting ||
      _isConnecting ||
      _session.phase == ReaderConnectionPhase.connecting;

  Future<void> _connect(MockBleDevice device) async {
    if (!_reader.supportsNativeRfid) {
      setState(() => _connectedDevice = device);
      ConnectedDeviceStorage.save(device.id, device.name);
      return;
    }

    if (_buttonsLocked) {
      final code = _isDisconnecting ||
              _session.phase == ReaderConnectionPhase.disconnecting
          ? 'disconnect_in_progress'
          : 'connect_in_progress';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(connectFailureMessageForUser(
              PlatformException(code: code),
            )),
          ),
        );
      }
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectingDevice = device;
    });
    _session.markConnecting(name: device.name, address: device.id);
    await SchedulerBinding.instance.endOfFrame;

    final hint = ReaderConnectionLog.deviceHintFrom(
      name: device.name,
      address: device.id,
    );
    final sw = Stopwatch()..start();
    ReaderConnectionLog.write(action: 'connect_start', deviceHint: hint);

    // 別リーダーへ切り替えるときは先に切断完了を確認
    final previous = _connectedDevice;
    if (previous != null && previous.id != device.id) {
      try {
        setState(() => _isDisconnecting = true);
        _session.markDisconnecting();
        await _reader.disconnect();
      } on PlatformException catch (e) {
        ReaderConnectionLog.write(
          action: 'pre_connect_disconnect',
          result: 'error',
          errorCode: e.code,
          deviceHint: hint,
          elapsedMs: sw.elapsedMilliseconds,
        );
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isDisconnecting = false;
            _connectingDevice = null;
          });
          _session.markConnectFailed(errorCode: e.code);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(connectFailureMessageForUser(e))),
          );
        }
        return;
      } catch (_) {
      } finally {
        if (mounted) {
          setState(() {
            _connectedDevice = null;
            _firmwareVersion = null;
            _isDisconnecting = false;
          });
        }
        await ConnectedDeviceStorage.clear();
        _session.markDisconnected();
      }
    }

    try {
      final ok = await _reader.connect(name: device.name, address: device.id);
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectingDevice = null;
      });
      if (!ok) {
        _session.markConnectFailed(errorCode: 'connect_failed');
        ReaderConnectionLog.write(
          action: 'connect_failed',
          result: 'false',
          deviceHint: hint,
          elapsedMs: sw.elapsedMilliseconds,
        );
        // 失敗後のクリーンアップ（スキャン残・状態）
        await _stopScan();
        final still = await _reader.isConnected();
        if (still) {
          try {
            await _reader.disconnect();
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(connectFailureMessageForUser(null)),
              duration: const Duration(seconds: 8),
            ),
          );
        }
        return;
      }
      await _stopScan();
      final fw = await _reader.getFirmwareVersion();
      if (!mounted) return;
      setState(() {
        _connectedDevice = device;
        _firmwareVersion = (fw != null && fw.isNotEmpty) ? fw : _firmwareVersion;
      });
      await ConnectedDeviceStorage.save(device.id, device.name);
      _session.markConnected(name: device.name, address: device.id);
      ReaderConnectionLog.write(
        action: 'connect_success',
        result: 'ok',
        deviceHint: hint,
        elapsedMs: sw.elapsedMilliseconds,
      );
      final forced = await HardwareTriggerModeStorage.forceToggleIfSr7AndHold();
      if (forced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SR-7接続のため、読取ボタン設定を「切替式」に自動変更しました。'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on PlatformException catch (e) {
      ReaderConnectionLog.write(
        action: 'connect_failed',
        result: 'error',
        errorCode: e.code,
        detail: e.message,
        deviceHint: hint,
        elapsedMs: sw.elapsedMilliseconds,
      );
      await _stopScan();
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingDevice = null;
        });
        _session.markConnectFailed(errorCode: e.code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(connectFailureMessageForUser(e)),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      ReaderConnectionLog.write(
        action: 'connect_failed',
        result: 'error',
        detail: e.toString(),
        deviceHint: hint,
        elapsedMs: sw.elapsedMilliseconds,
      );
      await _stopScan();
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingDevice = null;
        });
        _session.markConnectFailed();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(connectFailureMessageForUser(e)),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  /// 切断中表示を描いてからネイティブ切断へ進む。フレームが来ないときは待たずに進む。
  Future<void> _waitUntilDisconnectUiPainted() async {
    if (!mounted) {
      ReaderConnectionLog.write(
        action: 'disconnect_ui_frame',
        result: 'unmounted',
      );
      return;
    }
    final sw = Stopwatch()..start();
    try {
      await SchedulerBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 300),
      );
      ReaderConnectionLog.write(
        action: 'disconnect_ui_frame',
        result: 'ok',
        elapsedMs: sw.elapsedMilliseconds,
      );
    } on TimeoutException {
      // 画面破棄やバックグラウンドでフレームが来なくても、開始済みの切断は続ける。
      ReaderConnectionLog.write(
        action: 'disconnect_ui_frame',
        result: 'timeout',
        elapsedMs: sw.elapsedMilliseconds,
      );
    }
  }

  /// iOS の SDK `disconnect` はメインスレッドを占有する。
  /// 先に次のフレームまで返し、組んだ切断中画面を表示する機会を渡す。
  /// フレームが来ないときは短時間で打ち切り、切断は続ける。
  Future<void> _waitForIosDisconnectPresentation() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!mounted) {
      ReaderConnectionLog.write(
        action: 'disconnect_ui_present_wait',
        result: 'unmounted',
      );
      return;
    }
    final sw = Stopwatch()..start();
    ReaderConnectionLog.write(action: 'disconnect_ui_present_wait', result: 'start');
    try {
      await SchedulerBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 50),
      );
      ReaderConnectionLog.write(
        action: 'disconnect_ui_present_wait',
        result: 'ok',
        elapsedMs: sw.elapsedMilliseconds,
      );
    } on TimeoutException {
      ReaderConnectionLog.write(
        action: 'disconnect_ui_present_wait',
        result: 'timeout',
        elapsedMs: sw.elapsedMilliseconds,
      );
    }
  }

  /// true: まだ接続中 / false: 未接続 / null: 判定できない。
  Future<bool?> _readStillConnected() async {
    if (!_reader.supportsNativeRfid) return false;
    try {
      return await _reader.isConnected();
    } catch (_) {
      return null;
    }
  }

  Future<void> _finishFailedDisconnect(Object error) async {
    final still = await _readStillConnected();
    if (still == false) {
      await ConnectedDeviceStorage.clear();
      _session.markDisconnected();
    } else if (still == true) {
      _session.markDisconnectKeptConnected();
    } else {
      _session.markDisconnectUncertain();
    }
    if (!mounted) {
      ReaderConnectionLog.write(
        action: 'disconnect_ui_flag',
        result: 'unmounted_before_clear',
      );
      return;
    }
    ReaderConnectionLog.write(
      action: 'disconnect_ui_flag',
      result: 'clear_after_failure',
    );
    setState(() {
      _isDisconnecting = false;
      if (still == false) {
        _connectedDevice = null;
        _firmwareVersion = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(connectFailureMessageForUser(error)),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _disconnect() async {
    if (_isDisconnecting) return;
    if (_isConnecting || _session.phase == ReaderConnectionPhase.connecting) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(connectFailureMessageForUser(
              PlatformException(code: 'connect_in_progress'),
            )),
          ),
        );
      }
      return;
    }

    _disconnectUiBuildLogged = false;
    if (mounted) {
      setState(() => _isDisconnecting = true);
      ReaderConnectionLog.write(
        action: 'disconnect_ui_flag',
        result: 'set',
      );
    } else {
      ReaderConnectionLog.write(
        action: 'disconnect_ui_flag',
        result: 'unmounted_before_set',
      );
    }
    _session.markDisconnecting(manual: true);
    await _waitUntilDisconnectUiPainted();
    await _waitForIosDisconnectPresentation();

    final sw = Stopwatch()..start();
    final hint = ReaderConnectionLog.deviceHintFrom(
      name: _connectedDevice?.name,
      address: _connectedDevice?.id,
    );
    ReaderConnectionLog.write(action: 'disconnect_start', deviceHint: hint);

    try {
      if (_reader.supportsNativeRfid) {
        final swStop = Stopwatch()..start();
        ReaderConnectionLog.write(action: 'stop_inventory_start');
        try {
          await _reader.stopInventory();
          ReaderConnectionLog.write(
            action: 'stop_inventory_done',
            result: 'ok',
            elapsedMs: swStop.elapsedMilliseconds,
          );
        } catch (e) {
          ReaderConnectionLog.write(
            action: 'stop_inventory_done',
            result: 'error',
            detail: e.toString(),
            elapsedMs: swStop.elapsedMilliseconds,
          );
        }
        final swDisc = Stopwatch()..start();
        ReaderConnectionLog.write(action: 'disconnect_call_start');
        try {
          await _reader.disconnect();
          ReaderConnectionLog.write(
            action: 'disconnect_call_done',
            result: 'ok',
            elapsedMs: swDisc.elapsedMilliseconds,
          );
        } catch (e) {
          ReaderConnectionLog.write(
            action: 'disconnect_call_done',
            result: 'error',
            detail: e.toString(),
            elapsedMs: swDisc.elapsedMilliseconds,
          );
          rethrow;
        }
      } else {
        final override = DeviceConnectionScreen.debugDisconnectOverride;
        if (!kReleaseMode && override != null) {
          final ok = await override();
          if (!ok) {
            throw PlatformException(
              code: 'disconnect_incomplete',
              message: 'Disconnect completion was not confirmed.',
            );
          }
        }
      }
      ReaderConnectionLog.write(
        action: 'disconnect_done',
        result: 'ok',
        deviceHint: hint,
        elapsedMs: sw.elapsedMilliseconds,
      );
      if (mounted) {
        ReaderConnectionLog.write(
          action: 'disconnect_ui_flag',
          result: 'clear_after_disconnect',
        );
        setState(() {
          _connectedDevice = null;
          _firmwareVersion = null;
          _isDisconnecting = false;
        });
      } else {
        ReaderConnectionLog.write(
          action: 'disconnect_ui_flag',
          result: 'unmounted_before_clear',
        );
      }
      await ConnectedDeviceStorage.clear();
      _session.markDisconnected();
    } on PlatformException catch (e) {
      ReaderConnectionLog.write(
        action: 'disconnect_done',
        result: 'error',
        errorCode: e.code,
        detail: e.message,
        deviceHint: hint,
        elapsedMs: sw.elapsedMilliseconds,
      );
      await _finishFailedDisconnect(e);
    } catch (e) {
      ReaderConnectionLog.write(
        action: 'disconnect_done',
        result: 'error',
        detail: e.toString(),
        deviceHint: hint,
        elapsedMs: sw.elapsedMilliseconds,
      );
      await _finishFailedDisconnect(e);
    }
  }

  Widget _connectionProgressIndicator(BuildContext context, {double size = 22}) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS) {
      return CupertinoActivityIndicator(radius: size / 2);
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppDesign.primaryButton,
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF666666),
        ),
      ),
    );
  }

  Future<bool> _confirmRemoveBondedDevice(MockBleDevice device) async {
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('一覧から削除しますか？'),
        content: Text(
          _reader.supportsNativeRfid
              ? (_reader.isAndroid
                  ? 'OS の Bluetooth 設定でペアリング解除します。\n'
                      'あわせてこのアプリ側の保存データ（接続候補など）も削除します。'
                  : 'このアプリの一覧から削除します。\n'
                      '（OS の Bluetooth 設定でペアリング解除する操作ではありません。）')
              : '一覧からこのデバイスを削除します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    return go == true;
  }

  Future<void> _removeBondedDevice(MockBleDevice device) async {
    if (_connectedDevice?.id == device.id) {
      await _disconnect();
    }
    if (_reader.supportsNativeRfid) {
      await _reader.removeBondedDeviceFromList(address: device.id);
      if (mounted) await _loadBondedDevices();
    } else {
      setState(() {
        _bondedDevices = _bondedDevices.where((d) => d.id != device.id).toList();
      });
    }
  }

  Future<void> _onDeleteBondedDeviceTap(MockBleDevice device) async {
    if (!await _confirmRemoveBondedDevice(device)) return;
    await _removeBondedDevice(device);
  }

  Widget _bondedDeviceCard(MockBleDevice device) {
    return Dismissible(
      key: ValueKey<String>('bonded_${device.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (_buttonsLocked) return false;
        if (!await _confirmRemoveBondedDevice(device)) return false;
        await _removeBondedDevice(device);
        return true;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: _deviceCard(
        device,
        onDelete: () {
          _onDeleteBondedDeviceTap(device);
        },
      ),
    );
  }

  Widget _deviceCard(
    MockBleDevice device, {
    VoidCallback? onDelete,
  }) {
    final isConnected = _connectedDevice?.id == device.id;
    final isThisConnecting = _connectingDevice?.id == device.id;
    final connectButton = ElevatedButton(
      onPressed: _buttonsLocked
          ? null
          : () {
              _connect(device);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppDesign.primaryButton,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: const Text('接続'),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isThisConnecting || (isConnected && _isDisconnecting)
            ? _connectionProgressIndicator(context, size: 26)
            : Icon(
                isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                color: isConnected ? AppDesign.statusOk : null,
              ),
        title: Text(device.name),
        subtitle: Text(device.id, style: const TextStyle(fontSize: 12)),
        trailing: isConnected
            ? TextButton(
                onPressed: _disconnectLocked
                    ? null
                    : () {
                        _disconnect();
                      },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E0E0),
                  foregroundColor: const Color(0xFF333333),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(_isDisconnecting ? '切断中…' : '切断'),
              )
            : isThisConnecting
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _connectionProgressIndicator(context, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          '接続中…',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : (onDelete != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          connectButton,
                          IconButton(
                            onPressed: _buttonsLocked ? null : onDelete,
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '削除',
                            color: Colors.red,
                            padding: const EdgeInsets.only(left: 8),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ],
                      )
                    : connectButton),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisconnecting && !_disconnectUiBuildLogged) {
      _disconnectUiBuildLogged = true;
      ReaderConnectionLog.write(
        action: 'disconnect_ui_build',
        result: 'first',
      );
    }
    return Scaffold(
      backgroundColor: AppDesign.scaffoldBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDesign.deviceWidth),
          child: Material(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MainFlowNavBar(
                  showBackButton: widget.showBackButton,
                  title: 'タグリーダー接続',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _isConnecting || _isDisconnecting
                      ? const Color(0xFFE8F4FD)
                      : _connectedDevice != null
                          ? AppDesign.linkedBackground
                          : const Color(0xFFF0F0F0),
                  child: Row(
                    children: [
                      if (_isConnecting || _isDisconnecting)
                        _connectionProgressIndicator(context, size: 28)
                      else
                        Icon(
                          _connectedDevice != null ? Icons.link : Icons.link_off,
                          size: 28,
                          color: _connectedDevice != null
                              ? AppDesign.statusOk
                              : const Color(0xFF666666),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isDisconnecting
                              ? '切断中…'
                              : _isConnecting
                                  ? '接続中: ${_connectingDevice?.name ?? ''}'
                                  : _connectedDevice != null
                                      ? '接続中: ${_connectedDevice!.name}${_firmwareVersion != null ? '（FW: $_firmwareVersion）' : ''}'
                                      : '未接続',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (_connectedDevice != null && !_isConnecting)
                        TextButton(
                          onPressed: _disconnectLocked
                              ? null
                              : () {
                                  _disconnect();
                                },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            foregroundColor: const Color(0xFF333333),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text(_isDisconnecting ? '切断中…' : '切断'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning
                          ? _stopScan
                          : () {
                              _startScan();
                            },
                      icon: Icon(_isScanning ? Icons.stop : Icons.search),
                      label: Text(
                        _isScanning ? 'スキャン停止' : '新しいタグリーダーとペアリング設定',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesign.primaryButton,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _bondedDevices.isEmpty && _scannedBleDevices.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _isScanning
                                  ? 'スキャン中...'
                                  : (_reader.supportsNativeRfid
                                      ? '上のボタンで周辺のリーダーを検索できます（ペアリング済みは上に表示されます）'
                                      : '上のボタンでデバイスを検索'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            if (_bondedDevices.isNotEmpty) ...[
                              _sectionHeader('ペアリング済みデバイス'),
                              ..._bondedDevices.map((d) => _bondedDeviceCard(d)),
                            ],
                            if (_scannedBleDevices.isNotEmpty) ...[
                              _sectionHeader('検出されたデバイス'),
                              ..._scannedBleDevices.map((d) => _deviceCard(d)),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
