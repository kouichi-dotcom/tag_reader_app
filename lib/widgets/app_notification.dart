import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../utils/api_error_presenter.dart';

/// アプリ共通の通知。画面に表示し、OKボタンで閉じる。
/// スマホ・タブレットで確実に表示され、ユーザーがOKで消すまで残る。
void showAppNotification(
  BuildContext context,
  String message, {
  String? title,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: title == null
          ? null
          : Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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

/// API 通信エラーをログし、ユーザー向けダイアログを表示する。
void showAppApiError(
  BuildContext context,
  Object error, {
  String? apiName,
  StackTrace? stackTrace,
}) {
  logApiError(error, apiName: apiName, stackTrace: stackTrace);
  final userError = toUserFacingApiError(error);
  showAppNotification(context, userError.message, title: userError.title);
}
