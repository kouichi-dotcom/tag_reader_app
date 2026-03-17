import 'dart:async';

import 'package:flutter/material.dart';

import '../mocks/mock_data.dart';
import '../services/connected_device_storage.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';

/// 画面 1: タグリーダー接続（design/screen1-connection-wireframe.html 準拠）
/// スキャン・デバイス一覧・接続・切断
class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
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
    _loadSavedConnection();
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
    _sub?.cancel();
    _bleScanSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedConnection() async {
    final id = await ConnectedDeviceStorage.getId();
    final name = await ConnectedDeviceStorage.getName();
    if (id == null || name == null || !mounted) return;
    // Android: 実態の接続状態を確認。アプリ再起動後は接続が切れているので未接続に合わせる
    if (_reader.isAndroid) {
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
      if (_reader.isAndroid) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('スキャン失敗: $e')),
        );
        setState(() => _isScanning = false);
      }
    } finally {
      if (mounted && !_reader.isAndroid) setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    if (_reader.isAndroid) {
      await _reader.stopBleScan();
      _bleScanSub?.cancel();
      _bleScanSub = null;
    }
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _connect(MockBleDevice device) async {
    // Windows等はモック
    if (!_reader.isAndroid) {
      setState(() => _connectedDevice = device);
      ConnectedDeviceStorage.save(device.id, device.name);
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectingDevice = device;
    });

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
            const SnackBar(content: Text('接続に失敗しました（端末のBluetoothペアリングを確認してください）。')),
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
      ConnectedDeviceStorage.save(device.id, device.name);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingDevice = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('接続失敗: $e')),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      if (_reader.isAndroid) {
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

  Widget _deviceCard(MockBleDevice device) {
    final isConnected = _connectedDevice?.id == device.id;
    final isThisConnecting = _connectingDevice?.id == device.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isThisConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        const Text('接続中...', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  )
                : ElevatedButton(
                    onPressed: _isConnecting
                        ? null
                        : () {
                            _connect(device);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.primaryButton,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('接続'),
                  ),
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
                _NavBar(
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
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
                // スキャンボタン
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
                      label: Text(_isScanning ? 'スキャン停止' : 'スキャン'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesign.primaryButton,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
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
                          child: Text(
                            _isScanning
                                ? 'スキャン中...'
                                : (_reader.isAndroid
                                    ? '「スキャン」でペアリング済みデバイスと周辺のリーダーを表示'
                                    : '「スキャン」でデバイスを検索'),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            if (_bondedDevices.isNotEmpty) ...[
                              _sectionHeader('ペアリング済みデバイス'),
                              ..._bondedDevices.map((d) => _deviceCard(d)),
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

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.showBackButton,
    required this.title,
    required this.onBack,
  });

  final bool showBackButton;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppDesign.navBarBackground,
        border: Border(bottom: BorderSide(color: AppDesign.navBarBorder, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showBackButton)
              TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: AppDesign.primaryLink,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('← メインに戻る', style: TextStyle(fontSize: 16)),
              )
            else
              const SizedBox(width: 100),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 100),
          ],
        ),
      ),
    );
  }
}
