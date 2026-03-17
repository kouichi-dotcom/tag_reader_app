/// Web など dart:io が使えない環境用。localhost を返す。
String getApiBaseUrl() => 'http://localhost:5262';

/// Web などでは API を使用する想定。
bool get useApi => true;
