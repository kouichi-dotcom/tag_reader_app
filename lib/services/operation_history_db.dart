import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 更新履歴用 SQLite の open / スキーマ作成
class OperationHistoryDb {
  OperationHistoryDb._();

  static const _dbName = 'operation_history.db';
  static const _dbVersion = 1;

  static Database? _db;

  /// テスト用に DB ファイルパスを上書きする（null で既定）
  static String? debugDatabasePath;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final path = debugDatabasePath ??
        p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE operation_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  operation_type TEXT NOT NULL,
  result_status TEXT NOT NULL,
  http_status INTEGER,
  error_message TEXT,
  environment TEXT,
  user_id TEXT,
  user_name TEXT,
  reception_no TEXT,
  company_name TEXT,
  site_name TEXT,
  subject TEXT,
  link_mode TEXT
)
''');
        await db.execute('''
CREATE TABLE operation_history_item (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  history_id INTEGER NOT NULL,
  epc TEXT,
  product_code TEXT,
  number TEXT,
  product_name TEXT,
  status_before TEXT,
  status_after TEXT,
  tag_mode TEXT,
  result_status TEXT NOT NULL,
  http_status INTEGER,
  error_message TEXT,
  epc_before TEXT,
  epc_after TEXT,
  product_code_before TEXT,
  product_code_after TEXT,
  number_before TEXT,
  number_after TEXT,
  FOREIGN KEY (history_id) REFERENCES operation_history(id) ON DELETE CASCADE
)
''');
        await db.execute(
          'CREATE INDEX idx_operation_history_created_at_ms ON operation_history(created_at_ms)',
        );
        await db.execute(
          'CREATE INDEX idx_operation_history_item_history_id ON operation_history_item(history_id)',
        );
      },
    );
    return _db!;
  }

  /// テスト用: DB 接続を閉じる
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
