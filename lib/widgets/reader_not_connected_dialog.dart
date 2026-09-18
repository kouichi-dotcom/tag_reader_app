import 'package:flutter/material.dart';

import '../screens/device_connection_screen.dart';

/// タグリーダー未接続時の案内ダイアログ。
/// 「接続画面へ」で [DeviceConnectionScreen] へ遷移する。
Future<void> showReaderNotConnectedDialog(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('タグリーダー未接続'),
      content: const Text(
        'この操作にはタグリーダーの接続が必要です。\n接続画面でペアリング・接続してください。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('閉じる'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('接続画面へ'),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const DeviceConnectionScreen(showBackButton: true),
      ),
    );
  }
}
