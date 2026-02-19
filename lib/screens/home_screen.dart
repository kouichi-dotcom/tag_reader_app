import 'package:flutter/material.dart';

import '../services/connected_device_storage.dart';
import '../services/employee_storage.dart';
import '../theme/app_design.dart';
import 'device_connection_screen.dart';
import 'employee_code_screen.dart';
import 'tag_list_screen.dart';
import 'slip_list_screen.dart';

/// メイン画面（design/index.html 準拠）
/// タグリーダー接続・タグ読み取り・伝票一覧・従業員コード入力・設定への入口
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _employeeName;
  String? _connectedDeviceName;

  Future<void> _loadEmployee() async {
    final name = await EmployeeStorage.getName();
    if (mounted) setState(() => _employeeName = name);
  }

  Future<void> _loadConnectedDevice() async {
    final name = await ConnectedDeviceStorage.getName();
    if (mounted) setState(() => _connectedDeviceName = name);
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadEmployee(), _loadConnectedDevice()]);
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
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
                  title: '大宮タグリーダーアプリ',
                  employeeName: _employeeName,
                  connectedDeviceName: _connectedDeviceName,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _MenuButton(
                                label: 'タグリーダー接続',
                                textColor: Colors.black,
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) => const DeviceConnectionScreen(showBackButton: true),
                                    ),
                                  );
                                  _loadConnectedDevice();
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: 'タグ読み取り・一覧表示',
                                backgroundColor: const Color(0xFF9ACD32),
                                textColor: Colors.black,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) => const TagListScreen(showBackButton: true),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: '伝票一覧',
                                backgroundColor: const Color(0xFFFCE4EC),
                                textColor: const Color(0xFFB71C1C),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) => const SlipListScreen(showBackButton: true),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: '担当者コード入力',
                                backgroundColor: const Color(0xFF26A69A),
                                textColor: Colors.black,
                                onPressed: () async {
                                  final updated = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (context) => const EmployeeCodeScreen(showBackButton: true),
                                    ),
                                  );
                                  if (updated == true) _loadEmployee();
                                },
                              ),
                              const SizedBox(height: 16),
                              const _MenuButton(
                                label: '設定（未実装）',
                                enabled: false,
                                textColor: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    required this.title,
    this.employeeName,
    this.connectedDeviceName,
  });

  final String title;
  final String? employeeName;
  final String? connectedDeviceName;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            if (employeeName != null && employeeName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '担当: $employeeName',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (connectedDeviceName != null && connectedDeviceName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '接続中: $connectedDeviceName',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (backgroundColor ?? AppDesign.primaryButton)
        : AppDesign.disabledButton;
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
