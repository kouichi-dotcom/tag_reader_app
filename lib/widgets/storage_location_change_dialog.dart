import 'package:flutter/material.dart';

/// 保管場所変更の確認ダイアログ。
/// 「キャンセル」は保管場所変更のみ取り消し（タグ更新自体は続行する前提で呼び出し側が扱う）。
Future<bool?> showStorageLocationChangeDialog(
  BuildContext context, {
  required String currentName,
  required String detectedName,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('保管場所を変更しますか？'),
        content: Text(
          '現在地から「$detectedName」と判定しました。\n\n'
          '$currentName → $detectedName',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('変更する'),
          ),
        ],
      );
    },
  );
}
