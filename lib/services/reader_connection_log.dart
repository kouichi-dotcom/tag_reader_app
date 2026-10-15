import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// 接続診断用の端末内ログ（API 送信なし）。
/// 直近エントリのみメモリ保持。確認は [recentEntries] / デバッグコンソール。
class ReaderConnectionLog {
  ReaderConnectionLog._();

  static const int _maxEntries = 200;
  static final ListQueue<String> _entries = ListQueue<String>();

  static List<String> get recentEntries => List.unmodifiable(_entries);

  /// [deviceHint] は名前やアドレス末尾など、全文の識別子を出さないこと。
  static void write({
    required String action,
    String? result,
    String? errorCode,
    String? detail,
    String? deviceHint,
    int? elapsedMs,
  }) {
    final platform = _platformLabel();
    final ts = DateTime.now().toIso8601String();
    final parts = <String>[
      ts,
      platform,
      action,
      if (result != null) 'result=$result',
      if (errorCode != null) 'code=$errorCode',
      if (elapsedMs != null) 'elapsedMs=$elapsedMs',
      if (deviceHint != null && deviceHint.isNotEmpty) 'device=$deviceHint',
      if (detail != null && detail.isNotEmpty) 'detail=$detail',
    ];
    final line = parts.join(' | ');
    _entries.addLast(line);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    debugPrint('[ReaderBT] $line');
    developer.log(line, name: 'ReaderBT');
  }

  static String deviceHintFrom({String? name, String? address}) {
    final n = (name ?? '').trim();
    final a = (address ?? '').trim();
    final tail = a.length <= 5 ? a : a.substring(a.length - 5);
    if (n.isEmpty && tail.isEmpty) return '';
    if (n.isEmpty) return '…$tail';
    if (tail.isEmpty) return n;
    return '$n(…$tail)';
  }

  static String _platformLabel() {
    try {
      // ignore: avoid_web_libraries_in_flutter
      return defaultTargetPlatform.name;
    } catch (_) {
      return 'unknown';
    }
  }
}
