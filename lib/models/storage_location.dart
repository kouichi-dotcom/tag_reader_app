/// 保管場所（拠点）1件。
/// 将来は DB の保管場所マスタから取得する想定。座標・名称の取得元を差し替えやすいよう独立させる。
class StorageLocation {
  const StorageLocation({
    required this.code,
    required this.name,
    this.latitude,
    this.longitude,
  });

  /// 1=本社, 2=山川, 3=東風平, 4=友寄
  final int code;
  final String name;

  /// 拠点の基準緯度。未設定時は GPS 判定対象外。
  final double? latitude;

  /// 拠点の基準経度。未設定時は GPS 判定対象外。
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}
