import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_reader_app/utils/connect_error_messages.dart';

void main() {
  group('connectFailureMessageForUser', () {
    test('Bluetooth OFF', () {
      final msg = connectFailureMessageForUser(
        PlatformException(code: 'bluetooth_off'),
      );
      expect(msg, contains('BluetoothがOFF'));
      expect(msg, isNot(contains('他のスマホが接続中')));
    });

    test('権限不足', () {
      final msg = connectFailureMessageForUser(
        PlatformException(code: 'permission_required'),
      );
      expect(msg, contains('許可されていません'));
    });

    test('接続タイムアウトは断定せず補足を付ける', () {
      final msg = connectFailureMessageForUser(
        PlatformException(code: 'connect_timeout'),
      );
      expect(msg, contains('接続が完了しませんでした'));
      expect(msg, contains('他のスマホが接続中の可能性'));
    });

    test('未発見', () {
      final msg = connectFailureMessageForUser(
        PlatformException(code: 'not_found'),
      );
      expect(msg, contains('見つかりません'));
    });

    test('接続処理中', () {
      final msg = connectFailureMessageForUser(
        PlatformException(code: 'connect_in_progress'),
      );
      expect(msg, contains('接続処理中'));
    });

    test('切断処理中', () {
      final msg = connectFailureMessageForUser(
        PlatformException(code: 'disconnect_in_progress'),
      );
      expect(msg, contains('切断処理中'));
    });

    test('切断未完了を断定しない文言', () {
      final msg = connectFailureMessageForUser(
        PlatformException(code: 'disconnect_incomplete'),
      );
      expect(msg, contains('確認できませんでした'));
      expect(msg, isNot(contains('切断しました')));
    });

    test('原因不明は補足付き', () {
      final msg = connectFailureMessageForUser(null);
      expect(msg, contains('接続できませんでした'));
      expect(msg, contains('他のスマホが接続中の可能性'));
    });

    test('技術詳細を通常メッセージに出さない', () {
      final msg = connectFailureMessageForUser(
        PlatformException(
          code: 'connect_failed',
          message: 'gatt status 133 https://example.com',
        ),
      );
      expect(msg, isNot(contains('https://')));
      expect(msg, isNot(contains('gatt status')));
    });
  });

  test('linkLostMessageForUser', () {
    expect(linkLostMessageForUser(), contains('接続が切れました'));
  });
}
