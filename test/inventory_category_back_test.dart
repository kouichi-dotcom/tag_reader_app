import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_reader_app/screens/inventory_category_products_screen.dart';

void main() {
  testWidgets('商品一覧の戻るはカテゴリー一覧で止まり、ホームまでは戻らない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const _CategoryListStandIn(),
                  ),
                );
              },
              child: const Text('ホーム'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ホーム'));
    await tester.pumpAndSettle();
    expect(find.text('カテゴリー一覧'), findsOneWidget);

    await tester.tap(find.text('テントを開く'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('カテゴリーへ戻る'), findsOneWidget);
    expect(find.text('テント'), findsWidgets);
    expect(find.text('ホーム'), findsNothing);

    await tester.tap(find.text('カテゴリーへ戻る'));
    await tester.pumpAndSettle();

    expect(find.text('カテゴリー一覧'), findsOneWidget);
    expect(find.text('カテゴリーへ戻る'), findsNothing);
    expect(find.text('ホーム'), findsNothing);
  });
}

class _CategoryListStandIn extends StatelessWidget {
  const _CategoryListStandIn();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('カテゴリー一覧'),
          TextButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const InventoryCategoryProductsScreen(
                    categoryId: 1,
                    categoryName: 'テント',
                  ),
                ),
              );
            },
            child: const Text('テントを開く'),
          ),
        ],
      ),
    );
  }
}
