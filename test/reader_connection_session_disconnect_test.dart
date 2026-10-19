import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_reader_app/services/connected_device_storage.dart';
import 'package:tag_reader_app/services/reader_connection_session.dart';

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = ReaderConnectionSession.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session.debugReset();
    await ConnectedDeviceStorage.clear();
  });

  test('手動切断中の disconnected では完了にせず保存も消さない', () async {
    await ConnectedDeviceStorage.save('AA:BB:CC:DD:EE:FF', 'R-5000');
    session.markConnected(name: 'R-5000', address: 'AA:BB:CC:DD:EE:FF');
    session.markDisconnecting(manual: true);

    session.debugDispatchEvent({'type': 'disconnected'});
    await _flushAsync();

    expect(session.phase, ReaderConnectionPhase.disconnecting);
    expect(session.awaitsManualDisconnectResult, isTrue);
    expect(session.deviceName, 'R-5000');
    expect(await ConnectedDeviceStorage.getId(), 'AA:BB:CC:DD:EE:FF');
  });

  test('手動切断中の link_lost も完了扱いにしない', () async {
    await ConnectedDeviceStorage.save('AA:BB:CC:DD:EE:FF', 'R-5000');
    session.markConnected(name: 'R-5000', address: 'AA:BB:CC:DD:EE:FF');
    session.markDisconnecting(manual: true);

    session.debugDispatchEvent({'type': 'link_lost'});
    await _flushAsync();

    expect(session.phase, ReaderConnectionPhase.disconnecting);
    expect(await ConnectedDeviceStorage.getName(), 'R-5000');
  });

  test('切り替え前の切断では従来どおりイベントで未接続にする', () async {
    await ConnectedDeviceStorage.save('AA:BB:CC:DD:EE:FF', 'R-5000');
    session.markConnected(name: 'R-5000', address: 'AA:BB:CC:DD:EE:FF');
    session.markDisconnecting();

    session.debugDispatchEvent({'type': 'disconnected'});
    await _flushAsync();

    expect(session.phase, ReaderConnectionPhase.disconnected);
    expect(session.awaitsManualDisconnectResult, isFalse);
    expect(await ConnectedDeviceStorage.getId(), isNull);
  });

  test('接続中の意図しない切断は従来どおり処理する', () async {
    await ConnectedDeviceStorage.save('AA:BB:CC:DD:EE:FF', 'R-5000');
    session.markConnected(name: 'R-5000', address: 'AA:BB:CC:DD:EE:FF');

    session.debugDispatchEvent({'type': 'link_lost'});
    await _flushAsync();

    expect(session.phase, ReaderConnectionPhase.linkLost);
    expect(await ConnectedDeviceStorage.getId(), isNull);
  });
}
