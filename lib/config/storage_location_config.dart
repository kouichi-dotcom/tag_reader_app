/// 保管場所 GPS 判定まわりの定数。
/// 距離・再取得間隔・拠点一覧の取得元を画面や更新処理へベタ書きしないための集約点。
class StorageLocationConfig {
  StorageLocationConfig._();

  /// 拠点付近と判定する半径（メートル）
  static const double proximityRadiusMeters = 200;

  /// GPS を再取得する最小間隔
  static const Duration gpsRecheckInterval = Duration(minutes: 5);

  /// GPS 取得のタイムアウト
  static const Duration gpsTimeout = Duration(seconds: 10);
}
