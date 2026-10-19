import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_reader_app/screens/device_connection_screen.dart';
import 'package:tag_reader_app/services/connected_device_storage.dart';
import 'package:tag_reader_app/services/reader_connection_session.dart';

class _ReaderEventHandler extends MockStreamHandler {
  MockStreamHandlerEventSink? sink;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    sink = events;
  }

  @override
  void onCancel(Object? arguments) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = ReaderConnectionSession.instance;
  final events = _ReaderEventHandler();
  const eventChannel = EventChannel('tss_rfid/events');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session.debugReset();
    await ConnectedDeviceStorage.clear();
    DeviceConnectionScreen.debugDisconnectOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, events);
  });

  tearDown(() async {
    DeviceConnectionScreen.debugDisconnectOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
    session.debugReset();
  });

  testWidgets('切断ボタンから完了保留中は切断中表示を維持し、完了後に未接続へ戻る', (tester) async {
    final gate = Completer<bool>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete(true);
    });
    DeviceConnectionScreen.debugDisconnectOverride = () => gate.future;

    await tester.pumpWidget(
      const MaterialApp(home: DeviceConnectionScreen()),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, '接続').first);
    await tester.pump();
    await tester.pump();

    expect(find.text('切断'), findsWidgets);
    expect(await ConnectedDeviceStorage.getId(), 'MOCK-001');

    await tester.tap(find.widgetWithText(TextButton, '切断').first);
    await tester.pump();

    expect(find.text('切断中…'), findsWidgets);
    expect(find.text('未接続'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == const Color(0xFFE8F4FD),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '接続')).onPressed,
      isNull,
    );
    for (final button in tester.widgetList<TextButton>(find.widgetWithText(TextButton, '切断中…'))) {
      expect(button.onPressed, isNull);
    }
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete_outline)).onPressed,
      isNull,
    );

    await tester.drag(find.text('DOTR-900J (モック1)'), const Offset(-500, 0));
    await tester.pump();
    expect(find.text('一覧から削除しますか？'), findsNothing);

    events.sink?.success(<String, dynamic>{'type': 'disconnected'});
    session.debugDispatchEvent({'type': 'disconnected'});
    await tester.pump();

    expect(find.text('切断中…'), findsWidgets);
    expect(find.text('未接続'), findsNothing);
    expect(session.phase, ReaderConnectionPhase.disconnecting);
    expect(session.awaitsManualDisconnectResult, isTrue);
    expect(await ConnectedDeviceStorage.getId(), 'MOCK-001');

    gate.complete(true);
    await tester.pump();
    await tester.pump();

    expect(find.text('切断中…'), findsNothing);
    expect(find.text('未接続'), findsOneWidget);
    expect(session.phase, ReaderConnectionPhase.disconnected);
    expect(session.awaitsManualDisconnectResult, isFalse);
    expect(await ConnectedDeviceStorage.getId(), isNull);
    expect(
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '接続').first).onPressed,
      isNotNull,
    );
  });
}
