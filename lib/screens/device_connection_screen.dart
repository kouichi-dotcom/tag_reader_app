import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../mocks/mock_data.dart';
import '../services/connected_device_storage.dart';
import '../services/hardware_trigger_mode_storage.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';
import '../utils/connect_error_messages.dart';
import '../widgets/main_flow_nav_bar.dart';

/// 画面 1: タグリーダー接続（design/screen1-connection-wireframe.html 準拠）
/// スキャン・デバイス一覧・接続・切断
class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

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
  MockBleDevice? _connectingDevice;
  String? _firmwareVersion;

  final _reader = TagReaderService.instance;
  StreamSubscription<Map<String, dynamic>>? _sub;
  StreamSubscription<Map<String, dynamic>>? _bleScanSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedConnection();
    // ペアリング済み一覧はスキャン不要で表示（ネイティブは getBondedDevices、モックは固定リスト）
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
          setState(() {
            _connectedDevice = null;
            _firmwareVersion = null;
          });
          ConnectedDeviceStorage.clear();
          break;
        case 'firmware':
          final v = e['version'] as String?;
          if (v != null && v.isNotEmpty) setState(() => _firmwareVersion = v);
          break;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _bleScanSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted && _reader.supportsNativeRfid) {
      _loadBondedDevices();
      _loadSavedConnection();
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
              const SnackBar(content: Text('Bluetooth権限が必要です。設定から許可してください。')),
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
      if (e.code == 'permission_required') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth権限が必要です。設定から許可してください。')),
        );
      } else if (e.code == 'bluetooth_off') {
        await _promptEnableBluetooth();
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
    if (id == null || name == null || !mounted) return;
    // Android: 実態の接続状態を確認。アプリ再起動後は接続が切れているので未接続に合わせる
    if (_reader.supportsNativeRfid) {
      final actuallyConnected = await _reader.isConnected();
      if (!actuallyConnected && mounted) {
        setState(() {
          _connectedDevice = null;
          _firmwareVersion = null;
        });
        await ConnectedDeviceStorage.clear();
        return;
      }
    }
    if (mounted) setState(() => _connectedDevice = MockBleDevice(id: id, name: name));
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      if (_reader.supportsNativeRfid) {
        final ok = await _reader.requestBluetoothPermissions();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth権限が必要です。設定から許可してください。')),
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
        // Windows等: 画面モック用（実機と同じ2セクション・同じデザイン）
        setState(() {
          _bondedDevices = List.from(mockBleDevices);
          _scannedBleDevices = List.from(mockScannedBleDevices);
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        if (e.code == 'permission_required') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth権限が必要です。設定から許可してください。')),
          );
        } else if (e.code == 'bluetooth_off') {
          await _promptEnableBluetooth();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('スキャン失敗: $e')),
          );
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

  Future<void> _connect(MockBleDevice device) async {
    // Windows等はモック
    if (!_reader.supportsNativeRfid) {
      setState(() => _connectedDevice = device);
      ConnectedDeviceStorage.save(device.id, device.name);
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectingDevice = device;
    });
    // ネイティブ connect がメインスレッドを占有すると 1 フレームも描画されないことがあるため、
    // 接続処理の前に 1 フレーム分待ってスピナーを表示する。
    await SchedulerBinding.instance.endOfFrame;

    try {
      final ok = await _reader.connect(name: device.name, address: device.id);
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectingDevice = null;
      });
      if (!ok) {
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
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingDevice = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(connectFailureMessageForUser(e)),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingDevice = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(connectFailureMessageForUser(e)),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      if (_reader.supportsNativeRfid) {
        await _reader.disconnect();
      }
    } finally {
      if (mounted) {
        setState(() {
          _connectedDevice = null;
          _firmwareVersion = null;
        });
      }
      ConnectedDeviceStorage.clear();
    }
  }

  /// 接続中の「ぐるぐる」。iOS は CupertinoActivityIndicator、それ以外は色付き CircularProgressIndicator。
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
      onPressed: _isConnecting
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
        leading: isThisConnecting
            ? _connectionProgressIndicator(context, size: 26)
            : Icon(
                isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                color: isConnected ? AppDesign.statusOk : null,
              ),
        title: Text(device.name),
        subtitle: Text(device.id, style: const TextStyle(fontSize: 12)),
        trailing: isConnected
            ? TextButton(
                onPressed: () {
                  _disconnect();
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E0E0),
                  foregroundColor: const Color(0xFF333333),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('切断'),
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
                            onPressed: onDelete,
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
                // 接続状態
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _connectedDevice != null
                      ? AppDesign.linkedBackground
                      : _isConnecting
                          ? const Color(0xFFE8F4FD)
                          : const Color(0xFFF0F0F0),
                  child: Row(
                    children: [
                      if (_isConnecting)
                        _connectionProgressIndicator(context, size: 28)
                      else
                        Icon(
                          _connectedDevice != null ? Icons.link : Icons.link_off,
                          size: 28,
                          color: _connectedDevice != null ? AppDesign.statusOk : const Color(0xFF666666),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isConnecting
                              ? '接続中: ${_connectingDevice?.name ?? ''}'
                              : _connectedDevice != null
                                  ? '接続中: ${_connectedDevice!.name}${_firmwareVersion != null ? '（FW: $_firmwareVersion）' : ''}'
                                  : '未接続',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (_connectedDevice != null && !_isConnecting)
                        TextButton(
                          onPressed: () {
                            _disconnect();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            foregroundColor: const Color(0xFF333333),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: const Text('切断'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 周辺スキャン（ペアリング済みは _loadBondedDevices で先に表示）
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
