import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_reader_app/config/feature_flags.dart';
import 'package:tag_reader_app/screens/home_screen.dart';
import 'package:tag_reader_app/screens/urgent_store_delivery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugUrgentStoreDeliveryOverride = null;
  });

  tearDown(() {
    debugUrgentStoreDeliveryOverride = null;
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
  }

  testWidgets('iOS prod では急ぎ来店納品を出さない', (tester) async {
    debugUrgentStoreDeliveryOverride = false;
    await pumpHome(tester);
    expect(find.text('急ぎ来店納品'), findsNothing);
    expect(find.text('ICタグを読み取る・更新する'), findsOneWidget);
    expect(find.text('伝票を読み込む'), findsOneWidget);
    expect(find.text('在庫を見る'), findsOneWidget);
    expect(find.text('更新履歴'), findsOneWidget);
  });

  testWidgets('iOS staging では急ぎ来店納品を出す', (tester) async {
    debugUrgentStoreDeliveryOverride = true;
    await pumpHome(tester);
    expect(find.text('急ぎ来店納品'), findsOneWidget);
    expect(find.text('伝票を選ばず先にタグを読み取る'), findsOneWidget);
    expect(find.text('伝票を読み込む'), findsOneWidget);
  });

  testWidgets('Android では急ぎ来店納品を出す', (tester) async {
    debugUrgentStoreDeliveryOverride = true;
    await pumpHome(tester);
    expect(find.text('急ぎ来店納品'), findsOneWidget);
  });

  testWidgets('iOS prod で直接開いても急ぎ来店納品の作業画面に入らない', (tester) async {
    debugUrgentStoreDeliveryOverride = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(buildUrgentStoreDeliveryRoute());
                },
                child: const Text('開く'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(find.text('この環境では急ぎ来店納品を使用できません。'), findsOneWidget);
    expect(find.text('伝票を選ばず先にタグを読み取る'), findsNothing);
  });
}
