import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tag_reader_app/models/operation_history.dart';
import 'package:tag_reader_app/services/operation_history_db.dart';
import 'package:tag_reader_app/services/operation_history_repository.dart';
import 'package:tag_reader_app/services/operation_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await OperationHistoryDb.close();
    OperationHistoryDb.debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await OperationHistoryDb.close();
    OperationHistoryDb.debugDatabasePath = null;
  });

  test('insert and listRecent with items and created_at_ms', () async {
    final repo = OperationHistoryRepository();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    final id = await repo.insert(
      OperationHistory(
        createdAtMs: now,
        operationType: OperationType.statusUpdate,
        resultStatus: HistoryResultStatus.partialFailure,
        httpStatus: 500,
        errorMessage: 'サーバーエラー',
        environment: 'staging',
        userId: '001',
        userName: 'テスト',
        items: [
          const OperationHistoryItem(
            epc: 'EPC1',
            productCode: '5022',
            number: '0',
            statusBefore: '廃棄',
            statusAfter: '自社使用',
            resultStatus: ItemResultStatus.success,
          ),
          const OperationHistoryItem(
            epc: 'EPC2',
            productCode: '3013',
            number: '3',
            statusBefore: 'ＯＫ',
            statusAfter: '貸出中',
            resultStatus: ItemResultStatus.failed,
            httpStatus: 500,
            errorMessage: 'サーバーエラー',
          ),
          const OperationHistoryItem(
            epc: 'EPC3',
            productCode: '8301',
            number: '1',
            statusBefore: '整備中',
            statusAfter: 'ＯＫ',
            resultStatus: ItemResultStatus.notSent,
          ),
        ],
      ),
    );

    expect(id, greaterThan(0));

    final list = await repo.listRecent();
    expect(list.length, 1);
    final h = list.first;
    expect(h.operationType, OperationType.statusUpdate);
    expect(h.resultStatus, HistoryResultStatus.partialFailure);
    expect(h.items.length, 3);
    expect(h.items[0].resultStatus, ItemResultStatus.success);
    expect(h.items[1].resultStatus, ItemResultStatus.failed);
    expect(h.items[2].resultStatus, ItemResultStatus.notSent);
    expect(h.createdAtLocal.isUtc, isFalse);
  });

  test('purgeOlderThan deletes old histories and cascades items', () async {
    final repo = OperationHistoryRepository();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final old = now - (11 * 24 * 60 * 60 * 1000);

    await repo.insert(
      OperationHistory(
        createdAtMs: old,
        operationType: OperationType.tagRegistration,
        resultStatus: HistoryResultStatus.success,
        items: const [
          OperationHistoryItem(
            epc: 'OLD',
            productCode: '1',
            resultStatus: ItemResultStatus.success,
          ),
        ],
      ),
    );
    await repo.insert(
      OperationHistory(
        createdAtMs: now,
        operationType: OperationType.tagRegistration,
        resultStatus: HistoryResultStatus.success,
        items: const [
          OperationHistoryItem(
            epc: 'NEW',
            productCode: '2',
            resultStatus: ItemResultStatus.success,
          ),
        ],
      ),
    );

    final deleted = await repo.purgeOlderThan();
    expect(deleted, 1);

    final list = await repo.listRecent();
    expect(list.length, 1);
    expect(list.first.items.single.epc, 'NEW');
  });

  test('aggregateResult distinguishes success failed partial', () {
    expect(
      OperationHistory.aggregateResult(const [
        OperationHistoryItem(resultStatus: ItemResultStatus.success),
        OperationHistoryItem(resultStatus: ItemResultStatus.success),
      ]),
      HistoryResultStatus.success,
    );
    expect(
      OperationHistory.aggregateResult(const [
        OperationHistoryItem(resultStatus: ItemResultStatus.failed),
        OperationHistoryItem(resultStatus: ItemResultStatus.notSent),
      ]),
      HistoryResultStatus.failed,
    );
    expect(
      OperationHistory.aggregateResult(const [
        OperationHistoryItem(resultStatus: ItemResultStatus.success),
        OperationHistoryItem(resultStatus: ItemResultStatus.failed),
      ]),
      HistoryResultStatus.partialFailure,
    );
  });

  test('Service.record swallows repository failures', () async {
    final service = OperationHistoryService(
      repository: _ThrowingRepository(),
    );
    await service.recordStatusUpdate(
      userId: '001',
      userName: 'テスト',
      items: const [
        OperationHistoryItem(
          epc: 'X',
          resultStatus: ItemResultStatus.success,
        ),
      ],
    );
  });
}

class _ThrowingRepository extends OperationHistoryRepository {
  @override
  Future<int> insert(OperationHistory history) async {
    throw StateError('simulated sqlite failure');
  }
}
