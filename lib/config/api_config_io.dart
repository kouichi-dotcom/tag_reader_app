import 'dart:io' show Platform;

/// モバイル・デスクトップ用。Android のときはエミュレータからホスト PC へ届く 10.0.2.2 を使用。
String getApiBaseUrl() {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:5262';
  }
  return 'http://localhost:5262';
}

/// Android では API を使わず JSON のみ。Windows などでは API を使用する。
bool get useApi => !Platform.isAndroid;
