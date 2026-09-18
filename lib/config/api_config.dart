import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_stub.dart' if (dart.library.io) 'api_config_io.dart' as _impl;

/// true: ローカル API（PC 上の TagReaderApi）。false: Azure 上の API。
/// 実機で Azure × テスト DB を試すときは **false**。
const bool kUseLocalApi = false;

/// Azure App Service のベース URL（Hybrid Connection → この PC の SQL Server）。
const String kAzureApiBaseUrl =
    'https://ohmiyakoki-tagapp-api-aygbh8h5gsh4gwc0.japanwest-01.azurewebsites.net';

/// Azure API がテスト DB に接続している間は true。
/// API の `/api/environment` が `readOnly` を返すようになるまでの暫定（false にすると旧挙動）。
const bool kAzureUsesTestDatabase = true;

/// API のベース URL（開発・本番で切り替え）
/// - ローカル: kUseLocalApi = true → _impl.getApiBaseUrl()（エミュレータ: 10.0.2.2:5262）
/// - Azure: kUseLocalApi = false → [kAzureApiBaseUrl]
String get kApiBaseUrl =>
    kUseLocalApi ? _impl.getApiBaseUrl() : kAzureApiBaseUrl;

/// モバイル実機でも API を呼ぶか。
/// ローカル開発（assets モック優先）では Android/iOS は false。Azure 接続時は true。
bool get kUseApi => kUseLocalApi ? _impl.useApi : true;

/// API から取得した読み取り専用フラグ。未取得時は null。
bool? _isReadOnlyFromApi;

/// API から取得した DB 種別（Test / Production / Local 等）。未取得時は null。
String? _databaseKindFromApi;

bool _urlBasedIsProduction() {
  final u = kApiBaseUrl.toLowerCase();
  return !u.contains('localhost') && !u.contains('127.0.0.1') && !u.contains('10.0.2.2');
}

String _dbKindToLabel(String kind) {
  switch (kind.toLowerCase()) {
    case 'production':
      return '本番DB';
    case 'test':
      return 'テストDB';
    case 'local':
      return 'ローカルDB';
    default:
      return kind;
  }
}

/// 読み取り専用 DB 接続時は true。API の readOnly を優先し、未取得時は URL で判定。
bool get kIsProductionDb {
  if (_isReadOnlyFromApi != null) return _isReadOnlyFromApi!;
  if (!kUseLocalApi && kAzureUsesTestDatabase) return false;
  return _urlBasedIsProduction();
}

/// ヘッダー表示用: 「(テストDB)」「(本番DB)」「(ローカルDB)」など
String get kDbLabel {
  final kind = _databaseKindFromApi;
  if (kind != null && kind.isNotEmpty) {
    return '(${_dbKindToLabel(kind)})';
  }
  return kIsProductionDb ? '(本番DB)' : '(ローカルDB)';
}

/// API の環境を取得してキャッシュ。readOnly / databaseKind で書き込み可否とラベルを決める。
/// Android / iOS 実機（kUseApi が false）ではスキップする。
Future<void> fetchAndCacheApiEnvironment() async {
  if (!kUseApi) return;
  try {
    final base = kApiBaseUrl.endsWith('/') ? kApiBaseUrl : '$kApiBaseUrl/';
    final uri = Uri.parse('${base}api/environment');
    final response = await http.get(uri).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('timeout'),
    );
    if (response.statusCode != 200) return;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final readOnly = json['readOnly'] as bool?;
    if (readOnly != null) {
      _isReadOnlyFromApi = readOnly;
    } else {
      // 旧 API（environment のみ）との互換
      final env = json['environment'] as String?;
      if (!kUseLocalApi && kAzureUsesTestDatabase) {
        _isReadOnlyFromApi = false;
        _databaseKindFromApi ??= 'Test';
      } else {
        _isReadOnlyFromApi = env == 'Production';
      }
    }
    final kind = json['databaseKind'] as String?;
    if (kind != null && kind.isNotEmpty) {
      _databaseKindFromApi = kind;
    }
  } catch (_) {
    // 取得失敗時はキャッシュを触らず URL 判定のまま
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
