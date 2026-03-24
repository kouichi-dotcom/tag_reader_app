import 'package:flutter/services.dart';

/// タグリーダー接続失敗時にユーザーへ表示する文言（現場で試せる手順を含む）
String connectFailureMessageForUser(Object? error) {
  if (error is PlatformException) {
    if (error.code == 'permission_required') {
      return 'Bluetoothの使用が許可されていません。\n'
          '設定アプリで Bluetooth をオンにし、このアプリの Bluetooth 権限を許可してください。';
    }
    if (error.code == 'connect_failed') {
      final detail = (error.message ?? '').trim();
      if (detail.isNotEmpty) {
        // Android 等で SDK の英語メッセージのみのときは、対処の目安を先に出す
        if (!_containsJapanese(detail)) {
          return '$_defaultMessage\n\n（詳細: $detail）';
        }
        // ネイティブが日本語で具体的な場合はそのまま（補足が薄いときだけ追加）
        if (_needsExtraTip(detail)) {
          return '$detail\n\n$_extraTipOneLine';
        }
        return detail;
      }
    }
  }
  return _defaultMessage;
}

bool _containsJapanese(String s) {
  return RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]').hasMatch(s);
}

bool _needsExtraTip(String detail) {
  // すでに「試す」「スキャン」等まで書いてある場合は重複させない
  if (detail.contains('スキャン')) return false;
  if (detail.contains('お試し')) return false;
  if (detail.length > 120) return false;
  return true;
}

const String _extraTipOneLine =
    'それでも接続できない場合は、リーダーの電源を入れ直し、「新しいタグリーダーとペアリング設定」で周辺をスキャンしてから再度「接続」してください。';

const String _defaultMessage =
    '接続できませんでした。次を確認してください。\n'
    '・リーダーの電源が入っているか、スマホを至近距離に置いているか\n'
    '・他のスマホやPCが同じリーダーに接続していないか\n'
    '・「新しいタグリーダーとペアリング設定」で周辺をスキャンしてから、もう一度「接続」する';
