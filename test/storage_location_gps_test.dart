import 'package:flutter_test/flutter_test.dart';
import 'package:tag_reader_app/config/storage_location_config.dart';
import 'package:tag_reader_app/models/storage_location.dart';
import 'package:tag_reader_app/services/storage_location_catalog.dart';
import 'package:tag_reader_app/services/storage_location_gps_service.dart';
import 'package:tag_reader_app/utils/geo_distance.dart';

void main() {
  group('StorageLocationCatalog 実座標', () {
    test('4拠点すべてに座標がありコードが固定', () {
      expect(StorageLocationCatalog.all.length, 4);
      expect(StorageLocationCatalog.all.every((e) => e.hasCoordinates), isTrue);
      expect(
        StorageLocationCatalog.all.map((e) => e.code).toList(),
        [1, 2, 3, 4],
      );
      expect(StorageLocationCatalog.byCode(1)?.name, '本社');
      expect(StorageLocationCatalog.byCode(2)?.name, '山川');
      expect(StorageLocationCatalog.byCode(3)?.name, '東風平');
      expect(StorageLocationCatalog.byCode(4)?.name, '友寄');
    });

    test('本社座標にいると本社と判定（200m）', () {
      final hq = StorageLocationCatalog.byCode(1)!;
      final nearest = StorageLocationGpsService.findNearestWithinRadius(
        latitude: hq.latitude!,
        longitude: hq.longitude!,
        locations: StorageLocationCatalog.all,
        radiusMeters: StorageLocationConfig.proximityRadiusMeters,
      );
      expect(nearest?.code, 1);
    });

    test('山川座標にいると山川と判定（200m）', () {
      final yamakawa = StorageLocationCatalog.byCode(2)!;
      final nearest = StorageLocationGpsService.findNearestWithinRadius(
        latitude: yamakawa.latitude!,
        longitude: yamakawa.longitude!,
        locations: StorageLocationCatalog.all,
        radiusMeters: StorageLocationConfig.proximityRadiusMeters,
      );
      expect(nearest?.code, 2);
    });

    test('本社と山川は互いに200m超（同時該当しない）', () {
      final hq = StorageLocationCatalog.byCode(1)!;
      final yamakawa = StorageLocationCatalog.byCode(2)!;
      final d = distanceMeters(
        lat1: hq.latitude!,
        lon1: hq.longitude!,
        lat2: yamakawa.latitude!,
        lon2: yamakawa.longitude!,
      );
      expect(d, greaterThan(StorageLocationConfig.proximityRadiusMeters));
    });

    test('拠点から離れた地点は該当なし', () {
      final nearest = StorageLocationGpsService.findNearestWithinRadius(
        latitude: 26.0,
        longitude: 127.5,
        locations: StorageLocationCatalog.all,
        radiusMeters: StorageLocationConfig.proximityRadiusMeters,
      );
      expect(nearest, isNull);
    });
  });

  group('distanceMeters', () {
    test('同一座標は 0m', () {
      final d = distanceMeters(
        lat1: 26.2,
        lon1: 127.7,
        lat2: 26.2,
        lon2: 127.7,
      );
      expect(d, closeTo(0, 0.01));
    });

    test('約 100m 離れた点を概算できる', () {
      // 緯度 1度 ≒ 111km → 0.001度 ≒ 111m
      final d = distanceMeters(
        lat1: 26.2000,
        lon1: 127.7000,
        lat2: 26.2010,
        lon2: 127.7000,
      );
      expect(d, greaterThan(100));
      expect(d, lessThan(130));
    });
  });

  group('findNearestWithinRadius', () {
    test('複数が半径内なら近い方を採用', () {
      final withClose = [
        const StorageLocation(code: 1, name: '本社', latitude: 26.2000, longitude: 127.7000),
        const StorageLocation(code: 9, name: '近傍', latitude: 26.2001, longitude: 127.7000),
      ];
      final nearest = StorageLocationGpsService.findNearestWithinRadius(
        latitude: 26.20005,
        longitude: 127.7000,
        locations: withClose,
        radiusMeters: 200,
      );
      expect(nearest?.code, 9);
    });

    test('座標未設定の拠点は判定対象外', () {
      final nearest = StorageLocationGpsService.findNearestWithinRadius(
        latitude: 26.2000,
        longitude: 127.7000,
        locations: const [
          StorageLocation(code: 3, name: '東風平'),
        ],
        radiusMeters: 200,
      );
      expect(nearest, isNull);
    });
  });

  group('5分キャッシュ', () {
    tearDown(() {
      StorageLocationGpsService.instance.clearCache();
    });

    test('間隔内は再取得せず前回結果を返す', () async {
      final hq = StorageLocationCatalog.byCode(1)!;
      final t0 = DateTime(2026, 10, 7, 12, 0);
      StorageLocationGpsService.instance.seedCache(
        checkedAt: t0,
        detected: hq,
      );

      final result = await StorageLocationGpsService.instance.resolveForTagUpdate(
        now: t0.add(const Duration(minutes: 4)),
        locations: const [], // 再取得されても座標なしで null。キャッシュなら本社のまま
      );

      expect(result.detected?.code, 1);
      expect(result.checkedAt, t0);
    });
  });
}
