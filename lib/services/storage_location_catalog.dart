import '../models/storage_location.dart';

/// 保管場所一覧の提供口。
/// 当面はハードコード。将来は DB / API マスタ取得に差し替え可能。
///
/// 保管場所の記録・取得・更新は必ず [ICタグ台帳].[保管場所コード] を使用する。
/// `tag_mode` / `tag_mode2` は保管場所には使わない。
class StorageLocationCatalog {
  StorageLocationCatalog._();

  /// 登録済み拠点（コード固定: 1=本社, 2=山川, 3=東風平, 4=友寄）。
  static const List<StorageLocation> all = [
    StorageLocation(
      code: 1,
      name: '本社',
      latitude: 26.17702225570757,
      longitude: 127.71272580687263,
    ),
    StorageLocation(
      code: 2,
      name: '山川',
      latitude: 26.17713019892619,
      longitude: 127.71977016827337,
    ),
    StorageLocation(
      code: 3,
      name: '東風平',
      latitude: 26.14884522634526,
      longitude: 127.7215387580033,
    ),
    StorageLocation(
      code: 4,
      name: '友寄',
      latitude: 26.166713834915814,
      longitude: 127.719429129843,
    ),
  ];

  static StorageLocation? byCode(int? code) {
    if (code == null) return null;
    for (final loc in all) {
      if (loc.code == code) return loc;
    }
    return null;
  }

  static StorageLocation? byName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final loc in all) {
      if (loc.name == name) return loc;
    }
    return null;
  }

  static String displayName(int? code) {
    return byCode(code)?.name ?? '未設定';
  }

  static List<String> get names => all.map((e) => e.name).toList();
}
