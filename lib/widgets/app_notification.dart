import 'package:flutter/material.dart';

import '../theme/app_design.dart';

/// アプリ共通の通知。画面に表示し、OKボタンで閉じる。
/// スマホ・タブレットで確実に表示され、ユーザーがOKで消すまで残る。
void showAppNotification(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: AppDesign.primaryButton,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32),
              ),
              child: const Text('OK', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
  );
}
