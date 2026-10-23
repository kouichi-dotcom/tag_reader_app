import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_reader_app/screens/home_screen.dart';
import 'package:tag_reader_app/screens/tag_list_screen.dart';
import 'package:tag_reader_app/services/connected_device_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventChannel = EventChannel('tss_rfid/events');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, const _EmptyStream());
    await ConnectedDeviceStorage.clear();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
    await ConnectedDeviceStorage.clear();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
  }

  Finder tabLabel(String label) {
    return find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );
  }

  testWidgets('ホームに接続状況と設定5項目があり、下部に5タブがある', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpHome(tester);

    expect(find.text('ホーム'), findsWidgets);
    expect(find.text('Bluetooth接続状況'), findsOneWidget);
    expect(find.textContaining('未接続'), findsOneWidget);
    expect(find.text('リーダーの出力設定'), findsOneWidget);
    expect(find.text('担当者設定'), findsOneWidget);
    expect(find.text('保管場所設定'), findsOneWidget);
    expect(find.text('読み取りボタン動作設定'), findsOneWidget);
    expect(find.text('タグ設定'), findsOneWidget);
    expect(find.text('EPC読取テスト'), findsNothing);
    expect(tabLabel('ホーム'), findsOneWidget);
    expect(tabLabel('ICタグ更新'), findsOneWidget);
    expect(tabLabel('伝票'), findsOneWidget);
    expect(tabLabel('在庫'), findsOneWidget);
    expect(tabLabel('履歴'), findsOneWidget);
  });

  testWidgets('保存済みリーダー名を接続済みとして表示する', (tester) async {
    await ConnectedDeviceStorage.save('AA:BB', 'R-5000');
    await pumpHome(tester);
    await tester.pump();

    expect(find.textContaining('接続済み'), findsOneWidget);
    expect(find.textContaining('R-5000'), findsOneWidget);
  });

  testWidgets('各設定画面へ移動して戻れる', (tester) async {
    await pumpHome(tester);

    Future<void> openAndBack(String menu, String uniqueText) async {
      final menuFinder = find.text(menu).hitTestable();
      await tester.ensureVisible(menuFinder);
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();
      expect(find.text(uniqueText).hitTestable(), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, '←').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Bluetooth接続状況').hitTestable(), findsOneWidget);
    }

    await openAndBack('リーダーの出力設定', '出力モード（簡単設定）');
    await openAndBack('担当者設定', '担当者コード入力');
    await openAndBack('保管場所設定', '保管場所選択');
    await openAndBack('読み取りボタン動作設定', '画面内の「読取開始／読取停止」ボタンは常に切替式（トグル）です。');
    await openAndBack('タグ設定', 'タグID再設定');
  });

  testWidgets('5タブを切り替えると既存画面のタイトルが出る', (tester) async {
    await pumpHome(tester);

    Future<void> openTab(String label, String title) async {
      await tester.tap(tabLabel(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(title), findsOneWidget);
    }

    await openTab('ICタグ更新', 'ICタグ読取・更新');
    await openTab('伝票', '伝票読込');
    await openTab('在庫', '在庫確認');
    await openTab('履歴', '更新履歴');
    await openTab('ホーム', 'Bluetooth接続状況');

    await tester.tap(tabLabel('ICタグ更新'));
    await tester.pump();
    expect(find.text('クリア'), findsOneWidget);

    await tester.tap(find.text('クリア'));
    await tester.pump();
    expect(find.text('読取データをクリアしますか？'), findsOneWidget);

    await tester.tap(find.text('キャンセル'));
    await tester.pump();
    expect(find.text('読取データをクリアしますか？'), findsNothing);
    expect(find.text('ICタグ読取・更新'), findsOneWidget);

    await tester.tap(find.text('クリア'));
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('クリア')),
    );
    await tester.pump();
    expect(find.text('読取データをクリアしますか？'), findsNothing);
    expect(find.textContaining('読込件数: 0 件'), findsOneWidget);

    await tester.tap(tabLabel('ICタグ更新'));
    await tester.pump();
    expect(find.text('ICタグ読取・更新'), findsOneWidget);
    expect(
      tester
          .widget<TagListScreen>(find.byType(TagListScreen))
          .hardwareTriggerEnabled,
      isTrue,
    );

    await tester.tap(tabLabel('伝票'));
    await tester.pump();
    expect(
      tester
          .widget<TagListScreen>(
            find.byType(TagListScreen, skipOffstage: false),
          )
          .hardwareTriggerEnabled,
      isFalse,
    );
  });

  testWidgets('Bluetooth接続状況から接続画面へ移動して戻れる', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Bluetooth接続状況'));
    await tester.pump();
    await tester.pump();

    expect(find.text('タグリーダー接続'), findsOneWidget);

    await tester.tap(find.text('←'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('リーダーの出力設定'), findsOneWidget);
  });
}

class _EmptyStream extends MockStreamHandler {
  const _EmptyStream();

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {}

  @override
  void onCancel(Object? arguments) {}
}
