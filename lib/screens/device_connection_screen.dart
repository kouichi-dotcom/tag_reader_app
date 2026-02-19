import 'package:flutter/material.dart';

import '../mocks/mock_data.dart';
import '../services/connected_device_storage.dart';
import '../theme/app_design.dart';

/// 画面 1: タグリーダー接続（design/screen1-connection-wireframe.html 準拠）
/// スキャン・デバイス一覧・接続・切断（モック）
class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  List<MockBleDevice> _devices = [];
  MockBleDevice? _connectedDevice;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadSavedConnection();
  }

  Future<void> _loadSavedConnection() async {
    final id = await ConnectedDeviceStorage.getId();
    final name = await ConnectedDeviceStorage.getName();
    if (id != null && name != null && mounted) {
      setState(() => _connectedDevice = MockBleDevice(id: id, name: name));
    }
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices = List.from(mockBleDevices);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  void _stopScan() {
    setState(() {
      _isScanning = false;
    });
  }

  void _connect(MockBleDevice device) {
    setState(() => _connectedDevice = device);
    ConnectedDeviceStorage.save(device.id, device.name);
  }

  void _disconnect() {
    setState(() => _connectedDevice = null);
    ConnectedDeviceStorage.clear();
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
                      : const Color(0xFFF0F0F0),
                  child: Row(
                    children: [
                      Icon(
                        _connectedDevice != null ? Icons.link : Icons.link_off,
                        size: 28,
                        color: _connectedDevice != null ? AppDesign.statusOk : const Color(0xFF666666),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _connectedDevice != null
                              ? '接続中: ${_connectedDevice!.name}'
                              : '未接続',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (_connectedDevice != null)
                        TextButton(
                          onPressed: _disconnect,
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
                      onPressed: _isScanning ? _stopScan : _startScan,
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
                  child: _devices.isEmpty
                      ? Center(
                          child: Text(
                            _isScanning ? 'スキャン中...' : '「スキャン」でデバイスを検索',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final isConnected = _connectedDevice?.id == device.id;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                                  color: isConnected ? AppDesign.statusOk : null,
                                ),
                                title: Text(device.name),
                                subtitle: Text(device.id, style: const TextStyle(fontSize: 12)),
                                trailing: isConnected
                                    ? TextButton(onPressed: _disconnect, child: const Text('切断'))
                                    : ElevatedButton(
                                        onPressed: () => _connect(device),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppDesign.primaryButton,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                        ),
                                        child: const Text('接続'),
                                      ),
                              ),
                            );
                          },
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
