import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import 'employee_code_screen.dart';
import 'epc_test_screen.dart';
import 'hardware_trigger_settings_screen.dart';
import 'radio_power_screen.dart';
import 'storage_location_screen.dart';
import 'tag_settings_screen.dart';

/// 設定画面（担当者コード・保管場所・出力詳細設定への入口）
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

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
                  showBackButton: showBackButton,
                  title: '設定',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge, color: Color(0xFF26A69A)),
                        title: const Text('担当者コード入力'),
                        subtitle: const Text('担当者の設定'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (context) => const EmployeeCodeScreen(showBackButton: true),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.warehouse, color: Color(0xFFFF9800)),
                        title: const Text('保管場所選択'),
                        subtitle: const Text('ICタグ更新時の保管場所'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const StorageLocationScreen(showBackButton: true),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.hardware, color: Color(0xFF5C6BC0)),
                        title: const Text('タグリーダー本体の読み取りボタン設定'),
                        subtitle: const Text('切替式・時間式・長押し式'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const HardwareTriggerSettingsScreen(showBackButton: true),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.tune, color: Color(0xFF8BC34A)),
                        title: const Text('出力詳細設定'),
                        subtitle: const Text('電波強度（dBm）の手動調整'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => const RadioPowerScreen(showBackButton: true),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.sell, color: Color(0xFFE65100)),
                        title: const Text('タグ設定'),
                        subtitle: const Text('タグID再設定など'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const TagSettingsScreen(showBackButton: true),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Text(
                          '開発者向け',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.bug_report_outlined, color: Color(0xFF7B1FA2)),
                        title: const Text('EPC読取テスト'),
                        subtitle: const Text('タグEPCの読取・表示（テスト）'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const EpcTestScreen(showBackButton: true),
                            ),
                          );
                        },
                      ),
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
