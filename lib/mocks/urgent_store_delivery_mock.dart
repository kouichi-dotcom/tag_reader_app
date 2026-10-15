import '../models/urgent_store_delivery.dart';

/// 急ぎ来店納品 UI 確認用の仮データ。
/// 実読取・一時保存・API 導入時に差し替える。

/// 本日の未処理商品（初期ダミー）
final List<UrgentReadItem> mockUrgentTodayItems = [
  UrgentReadItem(
    id: 'ur1',
    productName: '発電機 2.5kVA',
    productCode: '1234',
    number: '005',
    tagId: 'E280XXXXXXXX0001',
    readAt: DateTime(2026, 10, 8, 8, 15),
  ),
  UrgentReadItem(
    id: 'ur2',
    productName: '投光器 LED',
    productCode: '2045',
    number: '012',
    tagId: 'E280XXXXXXXX0002',
    readAt: DateTime(2026, 10, 8, 8, 16),
  ),
  UrgentReadItem(
    id: 'ur3',
    productName: 'コードリール 30m',
    productCode: '3010',
    number: '003',
    tagId: 'E280XXXXXXXX0003',
    readAt: DateTime(2026, 10, 8, 8, 18),
  ),
  UrgentReadItem(
    id: 'ur4',
    productName: '水中ポンプ',
    productCode: '9876',
    number: '002',
    tagId: 'E280XXXXXXXX0004',
    readAt: DateTime(2026, 10, 8, 9, 5),
  ),
  UrgentReadItem(
    id: 'ur5',
    productName: '高圧洗浄機',
    productCode: '4501',
    number: '001',
    tagId: 'E280XXXXXXXX0005',
    readAt: DateTime(2026, 10, 8, 9, 12),
  ),
];
