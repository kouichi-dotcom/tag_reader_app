import '../models/operation_history.dart';
import 'operation_history_db.dart';

/// 更新履歴の永続化（SQLite）
class OperationHistoryRepository {
  OperationHistoryRepository();

  static const retentionDays = 10;
  static const retentionMs = retentionDays * 24 * 60 * 60 * 1000;

  /// 履歴本体 + 明細を 1 トランザクションで挿入。挿入後の id を返す。
  Future<int> insert(OperationHistory history) async {
    final db = await OperationHistoryDb.instance();
    return db.transaction((txn) async {
      final historyId = await txn.insert('operation_history', history.toMap());
      for (final item in history.items) {
        await txn.insert('operation_history_item', item.toMap(historyId));
      }
      return historyId;
    });
  }

  /// 新しい順で一覧取得（明細付き）。[sinceMs] 以降のみ（省略時は全件）。
  Future<List<OperationHistory>> list({int? sinceMs}) async {
    final db = await OperationHistoryDb.instance();
    final rows = sinceMs == null
        ? await db.query(
            'operation_history',
            orderBy: 'created_at_ms DESC',
          )
        : await db.query(
            'operation_history',
            where: 'created_at_ms >= ?',
            whereArgs: [sinceMs],
            orderBy: 'created_at_ms DESC',
          );

    if (rows.isEmpty) return const [];

    final result = <OperationHistory>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final itemRows = await db.query(
        'operation_history_item',
        where: 'history_id = ?',
        whereArgs: [id],
        orderBy: 'id ASC',
      );
      final items = itemRows.map(OperationHistoryItem.fromMap).toList();
      result.add(OperationHistory.fromMap(row, items: items));
    }
    return result;
  }

  /// 直近 [retentionDays] 日分を一覧取得。
  Future<List<OperationHistory>> listRecent() async {
    final cutoff = DateTime.now().toUtc().millisecondsSinceEpoch - retentionMs;
    return list(sinceMs: cutoff);
  }

  /// [created_at_ms] が閾値より古い履歴を削除（CASCADE で明細も削除）。
  /// 削除した本体件数を返す。
  Future<int> purgeOlderThan({int? olderThanMs}) async {
    final cutoff = olderThanMs ??
        (DateTime.now().toUtc().millisecondsSinceEpoch - retentionMs);
    final db = await OperationHistoryDb.instance();
    return db.delete(
      'operation_history',
      where: 'created_at_ms < ?',
      whereArgs: [cutoff],
    );
  }
}
