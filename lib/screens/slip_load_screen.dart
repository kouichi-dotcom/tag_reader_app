import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/slip_list_filter.dart';
import '../services/employee_storage.dart';
import '../theme/app_design.dart';
import '../widgets/app_notification.dart';
import 'slip_list_screen.dart';

/// 伝票読込画面。担当伝票・全伝票・来店伝票のいずれかを選んで一覧へ進む。
class SlipLoadScreen extends StatelessWidget {
  const SlipLoadScreen({super.key, this.showBackButton = true});

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
                _NavBar(
                  showBackButton: showBackButton,
                  onBack: () => Navigator.of(context).pop(),
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
                                label: '担当伝票のみ表示',
                                backgroundColor: const Color(0xFFE3F2FD),
                                textColor: const Color(0xFF1565C0),
                                onPressed: () async {
                                  final code = await EmployeeStorage.getCode();
                                  if (!context.mounted) return;
                                  if (code == null || code.trim().isEmpty) {
                                    showAppNotification(
                                      context,
                                      '担当者コードが未設定です。\nホームの「担当者コード入力」で設定してください。',
                                    );
                                    return;
                                  }
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SlipListScreen(
                                        showBackButton: true,
                                        listTitle: '担当伝票のみ表示',
                                        filter: SlipListFilter(assigneeCode: code.trim()),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: '全伝票一覧',
                                backgroundColor: const Color(0xFFFCE4EC),
                                textColor: const Color(0xFFB71C1C),
                                onPressed: () {
                                  // 日付指定なしで最新10件（転記済=0のみ）。ローカルはランダム10件でテスト可能
                                  final filter = kIsProductionDb
                                      ? SlipListFilter(random: false)
                                      : SlipListFilter.randomForTest;
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SlipListScreen(
                                        showBackButton: true,
                                        listTitle: '全伝票一覧',
                                        filter: filter,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: '来店伝票一覧',
                                backgroundColor: const Color(0xFFF3E5F5),
                                textColor: const Color(0xFF7B1FA2),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SlipListScreen(
                                        showBackButton: true,
                                        listTitle: '来店伝票一覧',
                                        filter: SlipListFilter.visitSlipOnly,
                                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.showBackButton, required this.onBack});

  final bool showBackButton;
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
                child: const Text('← メイン', style: TextStyle(fontSize: 16)),
              )
            else
              const SizedBox(width: 52),
            const Expanded(
              child: Text(
                '伝票読込',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 52),
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
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Material(
          color: backgroundColor ?? AppDesign.primaryButton,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
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
