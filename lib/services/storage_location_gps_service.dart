import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config/storage_location_config.dart';
import '../models/storage_location.dart';
import '../utils/geo_distance.dart';
import 'storage_location_catalog.dart';

/// GPS による保管場所判定結果（アプリ内一時状態。DB へは保存しない）。
class StorageLocationGpsResult {
  const StorageLocationGpsResult({
    required this.checkedAt,
    this.detected,
  });

  final DateTime checkedAt;

  /// 200m 以内の最寄り拠点。該当なし / 取得失敗時は null。
  final StorageLocation? detected;
}

/// タグ更新時の GPS 保管場所判定。
/// 5分以内は再取得せず前回結果を使う。失敗時は null（業務更新は続行）。
class StorageLocationGpsService {
  StorageLocationGpsService._();

  static final StorageLocationGpsService instance = StorageLocationGpsService._();

  DateTime? _lastGpsCheckedAt;
  StorageLocation? _lastDetectedStorageLocation;

  /// テスト用: キャッシュを消す
  @visibleForTesting
  void clearCache() {
    _lastGpsCheckedAt = null;
    _lastDetectedStorageLocation = null;
  }

  /// テスト用: キャッシュを差し込む
  @visibleForTesting
  void seedCache({
    required DateTime checkedAt,
    StorageLocation? detected,
  }) {
    _lastGpsCheckedAt = checkedAt;
    _lastDetectedStorageLocation = detected;
  }

  DateTime? get lastGpsCheckedAt => _lastGpsCheckedAt;
  StorageLocation? get lastDetectedStorageLocation => _lastDetectedStorageLocation;

  /// タグ更新開始時に呼ぶ。5分ルールに従い GPS 判定する。
  Future<StorageLocationGpsResult> resolveForTagUpdate({
    DateTime? now,
    List<StorageLocation>? locations,
  }) async {
    final at = now ?? DateTime.now();
    final last = _lastGpsCheckedAt;
    if (last != null &&
        at.difference(last) < StorageLocationConfig.gpsRecheckInterval) {
      return StorageLocationGpsResult(
        checkedAt: last,
        detected: _lastDetectedStorageLocation,
      );
    }

    final detected = await _detectNearbyLocation(locations: locations);
    _lastGpsCheckedAt = at;
    _lastDetectedStorageLocation = detected;
    return StorageLocationGpsResult(checkedAt: at, detected: detected);
  }

  /// 現在地から [StorageLocationConfig.proximityRadiusMeters] 以内の最寄り拠点を返す。
  /// 権限なし・GPS無効・タイムアウト等は null（例外は外に出さない）。
  Future<StorageLocation?> _detectNearbyLocation({
    List<StorageLocation>? locations,
  }) async {
    try {
      final position = await _getCurrentPosition();
      if (position == null) return null;
      return findNearestWithinRadius(
        latitude: position.latitude,
        longitude: position.longitude,
        locations: locations ?? StorageLocationCatalog.all,
        radiusMeters: StorageLocationConfig.proximityRadiusMeters,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[StorageLocationGps] detect failed: $e\n$st');
      }
      return null;
    }
  }

  Future<Position?> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: StorageLocationConfig.gpsTimeout,
      ),
    );
  }

  /// 純関数: 半径内で最も近い拠点。座標未設定の拠点は除外。
  static StorageLocation? findNearestWithinRadius({
    required double latitude,
    required double longitude,
    required List<StorageLocation> locations,
    required double radiusMeters,
  }) {
    StorageLocation? best;
    var bestDistance = double.infinity;

    for (final loc in locations) {
      if (!loc.hasCoordinates) continue;
      final d = distanceMeters(
        lat1: latitude,
        lon1: longitude,
        lat2: loc.latitude!,
        lon2: loc.longitude!,
      );
      if (d <= radiusMeters && d < bestDistance) {
        bestDistance = d;
        best = loc;
      }
    }
    return best;
  }
}
