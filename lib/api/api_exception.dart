/// API 通信失敗を表す例外。
///
/// ユーザー画面には [toString] を出さず、
/// [statusCode] / [apiName] / [debugMessage] は開発ログ用に使う。
class ApiException implements Exception {
  /// HTTP ステータスコード（通信未成立時は null）
  final int? statusCode;

  /// API 論理名（例: product-updates, reception-slips）
  final String apiName;

  /// 開発ログ用の短い補足（response body 要約など。UI には出さない）
  final String? debugMessage;

  const ApiException({
    required this.apiName,
    this.statusCode,
    this.debugMessage,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException($apiName, $statusCode)';
    }
    return 'ApiException($apiName)';
  }
}
