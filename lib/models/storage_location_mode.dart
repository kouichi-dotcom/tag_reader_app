/// 保管場所の設定方法
enum StorageLocationMode {
  /// タグ更新時に GPS で拠点を判定する
  gpsAuto,

  /// ユーザーが選んだ保管場所をタグ更新時に記録する
  manual,
}

extension StorageLocationModeX on StorageLocationMode {
  String get prefsValue => switch (this) {
        StorageLocationMode.gpsAuto => 'gps_auto',
        StorageLocationMode.manual => 'manual',
      };

  static StorageLocationMode fromPrefs(String? value) {
    if (value == StorageLocationMode.manual.prefsValue) {
      return StorageLocationMode.manual;
    }
    // 未保存・不明値は既存動作互換で GPS 自動判定
    return StorageLocationMode.gpsAuto;
  }

  String get label => switch (this) {
        StorageLocationMode.gpsAuto => 'GPS自動判定',
        StorageLocationMode.manual => '手動',
      };
}
