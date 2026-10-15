import 'package:flutter/services.dart';

/// タグリーダー接続失敗時にユーザーへ表示する文言
String connectFailureMessageForUser(Object? error) {
  if (error is PlatformException) {
    final code = error.code;
    switch (code) {
      case 'bluetooth_off':
        return 'BluetoothがOFFです。スマホのBluetoothをONにしてください。';
      case 'permission_required':
      case 'permission_request_in_progress':
        return 'Bluetoothの使用が許可されていません。スマホの設定を確認してください。';
      case 'connect_timeout':
        return '接続が完了しませんでした。タグリーダーの電源と他の端末の接続状況を確認してください。\n'
            '$_otherDeviceHint';
      case 'not_found':
      case 'device_not_found':
        return 'タグリーダーが見つかりません。電源と通信範囲を確認してください。';
      case 'connect_in_progress':
        return '現在、接続処理中です。処理が完了してから操作してください。';
      case 'disconnect_in_progress':
        return '現在、切断処理中です。';
      case 'disconnect_incomplete':
        return '切断の完了を確認できませんでした。数秒待ってから、もう一度切断するか、リーダーの電源を確認してください。';
      case 'connect_failed':
        final detail = (error.message ?? '').trim();
        if (_isKnownUserMessage(detail)) {
          return detail;
        }
        return '$_unknownConnect\n\n$_otherDeviceHint';
      default:
        break;
    }
  }
  return '$_unknownConnect\n\n$_otherDeviceHint';
}

String linkLostMessageForUser() => 'タグリーダーとの接続が切れました。';

bool _isKnownUserMessage(String detail) {
  if (!_containsJapanese(detail)) return false;
  // ネイティブが既にユーザー向け日本語を返している場合
  if (detail.contains('見つかりません')) return true;
  if (detail.contains('タイムアウト')) return true;
  if (detail.contains('Bluetooth')) return true;
  if (detail.contains('電源')) return true;
  if (detail.contains('接続')) return true;
  return detail.length >= 8;
}

bool _containsJapanese(String s) {
  return RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]').hasMatch(s);
}

const String _otherDeviceHint =
    '他のスマホが接続中の可能性があります。使用中の端末から切断してください。';

const String _unknownConnect = 'タグリーダーに接続できませんでした。もう一度お試しください。';
