import 'package:flutter/material.dart';

import '../models/slip_list_filter.dart';
import '../services/employee_storage.dart';
import '../theme/app_design.dart';
import '../widgets/app_notification.dart';
import '../widgets/main_flow_nav_bar.dart';
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
                MainFlowNavBar(
                  showBackButton: showBackButton,
                  title: '伝票読込',
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
                                        subjectFilterOptions:
                                            SlipListScreen.allSubjectFilterOptions,
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
                                  // 日付指定なし・受付日時の新しい順で最新10件（転記済=0のみ）
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SlipListScreen(
                                        showBackButton: true,
                                        listTitle: '全伝票一覧',
                                        filter: SlipListFilter.all,
                                        subjectFilterOptions:
                                            SlipListScreen.allSubjectFilterOptions,
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
                                        subjectFilterOptions:
                                            SlipListScreen.visitSubjectFilterOptions,
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
