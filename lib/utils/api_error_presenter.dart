import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_exception.dart';

/// ユーザー向けに表示する API エラー文言
class UserFacingApiError {
  final String title;
  final String message;

  const UserFacingApiError({required this.title, required this.message});

  /// SnackBar / 画面内 Text 用（タイトル＋本文）
  String get displayText => '$title\n$message';
}

/// 例外をユーザー向けタイトル・本文に変換する。
UserFacingApiError toUserFacingApiError(Object error) {
  if (error is TimeoutException) {
    return const UserFacingApiError(
      title: '通信エラー',
      message: 'サーバーからの応答に時間がかかっています。\nもう一度お試しください。',
    );
  }

  if (_isNetworkFailure(error)) {
    return const UserFacingApiError(
      title: '通信エラー',
      message: 'サーバーに接続できませんでした。\nインターネット接続を確認して、もう一度お試しください。',
    );
  }

  if (error is ApiException && error.statusCode != null) {
    return _fromHttpStatus(error.statusCode!);
  }

  final business = _businessJapaneseMessage(error);
  if (business != null) {
    return UserFacingApiError(title: 'エラー', message: business);
  }

  return const UserFacingApiError(
    title: 'エラー',
    message: '予期しないエラーが発生しました。\n改善しない場合は、システム担当者へお問い合わせください。',
  );
}

/// 開発環境のコンソールへ詳細を出力する（本番では出力しない）。
void logApiError(Object error, {String? apiName, StackTrace? stackTrace}) {
  if (!kDebugMode) return;

  final resolvedApiName = apiName ??
      (error is ApiException ? error.apiName : null) ??
      'unknown';

  final buffer = StringBuffer('API通信エラー\n');

  if (error is ApiException && error.statusCode != null) {
    buffer.writeln('StatusCode: ${error.statusCode}');
    buffer.writeln('API: $resolvedApiName');
    final reason = _httpReasonPhrase(error.statusCode!);
    if (reason != null) {
      buffer.writeln('Message: $reason');
    }
    if (error.debugMessage != null && error.debugMessage!.isNotEmpty) {
      buffer.writeln('Detail: ${_truncate(error.debugMessage!)}');
    }
  } else if (error is TimeoutException) {
    buffer.writeln('ErrorType: Timeout');
    buffer.writeln('Exception: TimeoutException');
    buffer.writeln('Message: ${_truncate(error.message ?? 'timeout')}');
    buffer.writeln('API: $resolvedApiName');
  } else if (_isNetworkFailure(error)) {
    buffer.writeln('ErrorType: NetworkError');
    buffer.writeln('Exception: ${error.runtimeType}');
    buffer.writeln('Message: ${_truncate(_shortErrorMessage(error))}');
    buffer.writeln('API: $resolvedApiName');
  } else {
    buffer.writeln('ErrorType: UnexpectedError');
    buffer.writeln('Exception: ${error.runtimeType}');
    buffer.writeln('Message: ${_truncate(_shortErrorMessage(error))}');
    buffer.writeln('API: $resolvedApiName');
  }

  debugPrint(buffer.toString().trimRight());
  if (stackTrace != null) {
    debugPrint(stackTrace.toString());
  }
}

UserFacingApiError _fromHttpStatus(int statusCode) {
  switch (statusCode) {
    case 400:
      return const UserFacingApiError(
        title: '送信エラー',
        message: '送信内容を処理できませんでした。\n入力内容を確認して、もう一度お試しください。',
      );
    case 401:
      return const UserFacingApiError(
        title: '認証エラー',
        message: '認証に失敗しました。\nアプリを再起動して、もう一度お試しください。',
      );
    case 403:
      return const UserFacingApiError(
        title: '権限エラー',
        message: 'この操作を実行する権限がありません。',
      );
    case 404:
      return const UserFacingApiError(
        title: 'データ取得エラー',
        message: '必要な情報が見つかりませんでした。',
      );
    case 409:
      return const UserFacingApiError(
        title: 'データ更新エラー',
        message: 'データの状態が変更されています。\n最新の情報を確認して、もう一度お試しください。',
      );
    default:
      if (statusCode >= 500 && statusCode <= 599) {
        return const UserFacingApiError(
          title: 'サーバーエラー',
          message: 'サーバーでエラーが発生しました。\nしばらくしてから、もう一度お試しください。',
        );
      }
      return const UserFacingApiError(
        title: 'エラー',
        message: '予期しないエラーが発生しました。\n改善しない場合は、システム担当者へお問い合わせください。',
      );
  }
}

bool _isNetworkFailure(Object error) {
  if (error is http.ClientException) return true;

  // dart:io に依存せず（Web 互換）、型名で判定する
  final typeName = error.runtimeType.toString();
  if (typeName == 'SocketException' ||
      typeName == 'HandshakeException' ||
      typeName == 'TlsException' ||
      typeName == 'OSError') {
    return true;
  }

  final text = error.toString().toLowerCase();
  if (text.contains('failed host lookup')) return true;
  if (text.contains('socketexception')) return true;
  if (text.contains('clientexception')) return true;
  if (text.contains('connection refused')) return true;
  if (text.contains('network is unreachable')) return true;
  if (text.contains('connection reset')) return true;
  return false;
}

/// アプリ側の業務ガードなど、技術詳細を含まない日本語メッセージを取り出す。
String? _businessJapaneseMessage(Object error) {
  String raw;
  if (error is ApiException) {
    // statusCode 付きは HTTP マップ側で扱う
    if (error.statusCode != null) return null;
    raw = error.debugMessage ?? '';
  } else if (error is Exception) {
    raw = error.toString();
    const prefix = 'Exception: ';
    if (raw.startsWith(prefix)) {
      raw = raw.substring(prefix.length);
    }
  } else {
    raw = error.toString();
  }

  // StateError など: "Bad state: …"
  const badState = 'Bad state: ';
  if (raw.startsWith(badState)) {
    raw = raw.substring(badState.length);
  }

  raw = raw.trim();
  if (raw.isEmpty) return null;
  if (!_containsJapanese(raw)) return null;
  if (_looksTechnical(raw)) return null;
  return raw;
}

bool _containsJapanese(String s) {
  return RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]').hasMatch(s);
}

bool _looksTechnical(String s) {
  final lower = s.toLowerCase();
  if (lower.contains('http://') || lower.contains('https://')) return true;
  if (lower.contains('socketexception')) return true;
  if (lower.contains('clientexception')) return true;
  if (lower.contains('failed host lookup')) return true;
  if (RegExp(r'\berrno\b').hasMatch(lower)) return true;
  if (RegExp(r'\bstatus\s*code\b').hasMatch(lower)) return true;
  // "送信エラー: 500 {...}" のような旧形式
  if (RegExp(r':\s*\d{3}\b').hasMatch(s) && s.contains('{')) return true;
  return false;
}

String _shortErrorMessage(Object error) {
  if (error is http.ClientException) {
    return error.message;
  }
  if (error is TimeoutException) {
    return error.message ?? 'timeout';
  }
  if (error is ApiException) {
    return error.debugMessage ?? error.toString();
  }
  var text = error.toString();
  // uri= 以降の URL を落とす
  final uriIndex = text.toLowerCase().indexOf('uri=');
  if (uriIndex >= 0) {
    text = text.substring(0, uriIndex).trim();
    if (text.endsWith(',')) text = text.substring(0, text.length - 1).trim();
  }
  return text;
}

String? _httpReasonPhrase(int statusCode) {
  const phrases = <int, String>{
    400: 'Bad Request',
    401: 'Unauthorized',
    403: 'Forbidden',
    404: 'Not Found',
    409: 'Conflict',
    500: 'Internal Server Error',
    502: 'Bad Gateway',
    503: 'Service Unavailable',
    504: 'Gateway Timeout',
  };
  return phrases[statusCode];
}

String _truncate(String value, {int max = 200}) {
  final trimmed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (trimmed.length <= max) return trimmed;
  return '${trimmed.substring(0, max)}…';
}
