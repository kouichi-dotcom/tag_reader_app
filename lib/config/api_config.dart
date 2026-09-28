import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_stub.dart'
    if (dart.library.io) 'api_config_io.dart' as _impl;

/// Azure テスト API（staging Flavor）。既定ドメイン（推測しない）。
const String kStagingApiBaseUrl =
    'https://ohmiyakoki-tagapp-api-aygbh8h5gsh4gwc0.japanwest-01.azurewebsites.net';

/// Azure 本番 API（prod Flavor）。既定ドメイン（推測しない）。
const String kProdApiBaseUrl =
    'https://ohmiyakoki-tagapp-api-prod-gsdcabb4gzbzcyaw.japanwest-01.azurewebsites.net';

/// ビルド時に渡す Flavor（`--dart-define=FLAVOR=staging|prod`）。接続先の単一基準。
const String kFlavorDefine = String.fromEnvironment('FLAVOR');

/// 整合チェック用（`--dart-define=APP_ENV=test|prod|local`）。接続先の決定には使わない。
const String kAppEnvDefine = String.fromEnvironment('APP_ENV');

/// 起動時バリデーション結果。失敗時は [errorMessage] が非 null。
class AppEnvValidation {
  const AppEnvValidation._({
    required this.flavor,
    required this.isLocal,
    this.errorMessage,
  });

  final String? flavor;
  final bool isLocal;
  final String? errorMessage;

  bool get isValid => errorMessage == null;

  static AppEnvValidation validate() {
    final flavor = kFlavorDefine.trim().toLowerCase();
    final appEnv = kAppEnvDefine.trim().toLowerCase();

    // local: APP_ENV=local を明示したときだけ。FLAVOR=prod との併用は不可。
    if (appEnv == 'local') {
      if (flavor == 'prod') {
        return const AppEnvValidation._(
          flavor: null,
          isLocal: false,
          errorMessage:
              '環境設定エラー: APP_ENV=local と FLAVOR=prod は併用できません。\n'
              'ローカル API を使う場合は FLAVOR を付けないか staging にしてください。',
        );
      }
      if (flavor.isNotEmpty && flavor != 'staging') {
        return AppEnvValidation._(
          flavor: null,
          isLocal: false,
          errorMessage:
              '環境設定エラー: APP_ENV=local と FLAVOR=$flavor は併用できません。',
        );
      }
      return const AppEnvValidation._(flavor: null, isLocal: true);
    }

    if (flavor.isEmpty) {
      return const AppEnvValidation._(
        flavor: null,
        isLocal: false,
        errorMessage:
            '環境設定エラー: FLAVOR が未指定です。\n'
            'テスト: --flavor staging --dart-define=FLAVOR=staging --dart-define=APP_ENV=test\n'
            '本番: --flavor prod --dart-define=FLAVOR=prod --dart-define=APP_ENV=prod\n'
            'ローカル: --dart-define=APP_ENV=local\n'
            '※ 未指定時に本番 API へは接続しません。',
      );
    }

    if (flavor != 'staging' && flavor != 'prod') {
      return AppEnvValidation._(
        flavor: null,
        isLocal: false,
        errorMessage:
            '環境設定エラー: FLAVOR="$flavor" は不正です。staging または prod を指定してください。\n'
            '※ 不正時に本番 API へは接続しません。',
      );
    }

    if (appEnv.isNotEmpty) {
      final expected = flavor == 'staging' ? 'test' : 'prod';
      if (appEnv != expected) {
        return AppEnvValidation._(
          flavor: null,
          isLocal: false,
          errorMessage:
              '環境設定エラー: Flavor と APP_ENV が一致しません。\n'
              'FLAVOR=$flavor のとき APP_ENV は "$expected" である必要があります（指定値: "$appEnv"）。\n'
              '矛盾した指定では起動できません。',
        );
      }
    }

    return AppEnvValidation._(flavor: flavor, isLocal: false);
  }
}

final AppEnvValidation kAppEnvValidation = AppEnvValidation.validate();

/// prod Flavor か（接続先・更新禁止の基準）。
bool get kIsProdFlavor => kAppEnvValidation.flavor == 'prod';

/// staging Flavor か（テスト環境バナー用）。
bool get kIsStagingFlavor => kAppEnvValidation.flavor == 'staging';

/// ローカル API モードか。
bool get kUseLocalApi => kAppEnvValidation.isLocal;

/// API のベース URL。接続先は FLAVOR（または明示 local）のみで決定。
String get kApiBaseUrl {
  if (!kAppEnvValidation.isValid) {
    // 起動停止前提。誤って本番へ繋がないよう空文字を返す。
    return '';
  }
  if (kUseLocalApi) return _impl.getApiBaseUrl();
  if (kIsProdFlavor) return kProdApiBaseUrl;
  if (kIsStagingFlavor) return kStagingApiBaseUrl;
  return '';
}

/// Azure（staging/prod）接続時は常に true。local 時は IO 実装に従う。
bool get kUseApi {
  if (!kAppEnvValidation.isValid) return false;
  if (kUseLocalApi) return _impl.useApi;
  return true;
}

/// API から取得した読み取り専用フラグ。未取得時は null。
bool? _isReadOnlyFromApi;

/// API から取得した DB 種別（Test / Production / Local 等）。未取得時は null。
String? _databaseKindFromApi;

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

/// 更新禁止か。
/// - prod Flavor → 常に true（/api/environment 無視）
/// - それ以外 → API readOnly==true なら true。未取得時は false（更新可）
bool get kUpdatesForbidden {
  if (kIsProdFlavor) return true;
  if (_isReadOnlyFromApi == true) return true;
  return false;
}

/// 後方互換: UI / api_client が参照。意味は [kUpdatesForbidden] と同じ。
bool get kIsProductionDb => kUpdatesForbidden;

/// ヘッダー表示用: 「(テストDB)」「(本番DB)」「(ローカルDB)」など
String get kDbLabel {
  if (kIsProdFlavor) return '(本番DB)';
  if (kUseLocalApi) return '(ローカルDB)';
  final kind = _databaseKindFromApi;
  if (kind != null && kind.isNotEmpty) {
    return '(${_dbKindToLabel(kind)})';
  }
  if (kIsStagingFlavor) return '(テストDB)';
  return '';
}

/// API の環境を取得してキャッシュ。prod でもラベル表示用に取得するが、更新可否は Flavor 優先。
Future<void> fetchAndCacheApiEnvironment() async {
  if (!kUseApi) return;
  final baseUrl = kApiBaseUrl;
  if (baseUrl.isEmpty) return;
  try {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
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
    }
    final kind = json['databaseKind'] as String?;
    if (kind != null && kind.isNotEmpty) {
      _databaseKindFromApi = kind;
    }
  } catch (_) {
    // 取得失敗時はキャッシュを触らない
  }
}
