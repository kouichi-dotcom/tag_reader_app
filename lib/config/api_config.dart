import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_stub.dart' if (dart.library.io) 'api_config_io.dart' as _impl;

/// true: ローカルAPI（＝ローカルDB）でテスト。false: 本番API（本番DB）。
/// リリースビルド時は必ず false にすること。
/// ローカルテスト手順: (1) この値を true のまま (2) TagReaderApi を「http」プロファイルで起動
const bool kUseLocalApi = true;

/// API のベース URL（開発・本番で切り替え）
/// - ローカル API テスト: kUseLocalApi = true にすると _impl.getApiBaseUrl()（エミュレータ: 10.0.2.2:5262）
/// - 実機で同じ PC の API を叩く: api_config_io で Platform 判定。要: API を 0.0.0.0 で待ち受け・ファイアウォール許可
/// - Azure デプロイ先: https://tagreader-api-fqgkazd5frb7daa5.japanwest-01.azurewebsites.net
String get kApiBaseUrl =>
    kUseLocalApi ? _impl.getApiBaseUrl() : 'https://tagreader-api-fqgkazd5frb7daa5.japanwest-01.azurewebsites.net';

/// API から取得した環境（Production = 本番DB）。未取得時は null。
bool? _isProductionFromApi;

bool _urlBasedIsProduction() {
  final u = kApiBaseUrl.toLowerCase();
  return !u.contains('localhost') && !u.contains('127.0.0.1') && !u.contains('10.0.2.2');
}

/// 本番DB接続時は true（読み取り専用）。API の /api/environment で取得した環境を優先し、未取得時は URL で判定。
bool get kIsProductionDb => _isProductionFromApi ?? _urlBasedIsProduction();

/// ヘッダー表示用: 「(ローカルDB)」または「(本番DB)」
String get kDbLabel => kIsProductionDb ? '(本番DB)' : '(ローカルDB)';

/// API の環境を取得してキャッシュ。起動時に呼ぶと、localhost でも本番プロファイルで動いている API なら (本番DB) になる。
Future<void> fetchAndCacheApiEnvironment() async {
  try {
    final base = kApiBaseUrl.endsWith('/') ? kApiBaseUrl : '$kApiBaseUrl/';
    final uri = Uri.parse('${base}api/environment');
    final response = await http.get(uri).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('timeout'),
    );
    if (response.statusCode != 200) return;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final env = json['environment'] as String?;
    _isProductionFromApi = env == 'Production';
  } catch (_) {
    // 取得失敗時は _isProductionFromApi を触らず URL 判定のまま
  }
}

// ----- 実機テスト用コード（見送りのためコメントアウト） -----
// 実行環境で自動切り替え（Android 実機は --dart-define=API_BASE_URL=http://PCのIP:5262 で上書き）する場合は以下を使用。
// import 'api_config_stub.dart' if (dart.library.io) 'api_config_io.dart' as _impl;
// String get kApiBaseUrl {
//   const env = String.fromEnvironment('API_BASE_URL', defaultValue: '');
//   return env.isEmpty ? _impl.getApiBaseUrl() : env;
// }
// 実機で API を受け付けるには API 側で 0.0.0.0 で待ち受け（launchSettings.json の applicationUrl: "http://0.0.0.0:5262"）と
// Windows ファイアウォールでポート 5262 を許可する必要あり。
