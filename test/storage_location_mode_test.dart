import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_reader_app/models/storage_location_mode.dart';
import 'package:tag_reader_app/services/storage_location_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('モード未保存時は GPS自動判定', () async {
    final mode = await StorageLocationStorage.getMode();
    expect(mode, StorageLocationMode.gpsAuto);
  });

  test('モードと手動選択は再起動相当でも保持される', () async {
    await StorageLocationStorage.saveMode(StorageLocationMode.manual);
    await StorageLocationStorage.save('山川');

    expect(await StorageLocationStorage.getMode(), StorageLocationMode.manual);
    expect(await StorageLocationStorage.getName(), '山川');
    expect(await StorageLocationStorage.getStorageLocationCode(), 2);
  });

  test('現在の保管場所（DB観測）と手動選択は別管理', () async {
    await StorageLocationStorage.save('山川');
    await StorageLocationStorage.rememberDbStorageLocationCode(1);

    expect(await StorageLocationStorage.getName(), '山川');
    expect(await StorageLocationStorage.getLastDbStorageLocationName(), '本社');
    expect(await StorageLocationStorage.getStorageLocationCode(), 2);
  });
}
