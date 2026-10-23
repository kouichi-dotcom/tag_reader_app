import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_reader_app/models/operation_history.dart';
import 'package:tag_reader_app/services/product_cache.dart';
import 'package:tag_reader_app/widgets/history/history_list_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('キャッシュにある商品コードは商品名も出す', (tester) async {
    SharedPreferences.setMockInitialValues({
      'product_cache_json':
          '[{"productCode":5022,"productName":"高圧洗浄機"}]',
    });
    await ProductCache.instance.init();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryListTile(
            history: OperationHistory(
              createdAtMs: DateTime(2026, 10, 23, 9, 0).millisecondsSinceEpoch,
              operationType: OperationType.statusUpdate,
              resultStatus: HistoryResultStatus.success,
              items: const [
                OperationHistoryItem(
                  productCode: '5022',
                  statusBefore: 'ＯＫ',
                  statusAfter: '清掃中',
                ),
                OperationHistoryItem(
                  productCode: '9999',
                  statusBefore: 'ＯＫ',
                  statusAfter: '廃棄',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('5022　高圧洗浄機　ＯＫ → 清掃中'), findsOneWidget);
    expect(find.textContaining('9999　ＯＫ → 廃棄'), findsOneWidget);
    expect(find.textContaining('9999　高圧洗浄機'), findsNothing);
  });
}
