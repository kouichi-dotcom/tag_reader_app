// 画面モック用のモックデータ（2-3〜2-5）
// 本番ではタグリーダー・API に差し替える

import '../models/product.dart';
import '../models/reception_detail_item.dart';
import '../models/reception_slip.dart';
import '../models/slip_list_filter.dart';

/// BLE デバイス 1 件（画面 1 用）
class MockBleDevice {
  final String id;
  final String name;

  const MockBleDevice({required this.id, required this.name});
}

/// タグ読み取り 1 件（画面 2 一覧用）
class MockTagRead {
  final String epc;
  final String readAt; // ISO 8601 または表示用

  const MockTagRead({required this.epc, required this.readAt});
}

// --- 従業員（従業員コード入力用・モック） ---
/// 従業員コード → 従業員名（本番では API 等に差し替え）
const Map<String, String> mockEmployeeNameByCode = {
  '001': '山田太郎',
  '002': '佐藤花子',
  '003': '鈴木一郎',
};

// --- モックデータ定義（ここを編集して増減） ---

/// スキャンで出てくるデバイス一覧（画面 1）ペアリング済み
const List<MockBleDevice> mockBleDevices = [
  MockBleDevice(id: 'MOCK-001', name: 'DOTR-900J (モック1)'),
  MockBleDevice(id: 'MOCK-002', name: 'DOTR-900J (モック2)'),
];

/// スキャンで検出したデバイス一覧（画面 1）モック用・実機と同じ2セクション表示
const List<MockBleDevice> mockScannedBleDevices = [
  MockBleDevice(id: 'MOCK-BLE-001', name: 'DOTR-900J (スキャン検出)'),
];

/// 読んだタグの一覧（画面 2）
const List<MockTagRead> mockTagReads = [
  MockTagRead(epc: '300000000000000000000001', readAt: '2026-02-18T10:00:00'),
  MockTagRead(epc: '300000000000000000000002', readAt: '2026-02-18T10:01:00'),
  MockTagRead(epc: '300000000000000000000003', readAt: '2026-02-18T10:02:00'),
];

/// EPC → 商品（照合用）。キーが無い EPC は「商品不明」（画面 2・3）
const Map<String, Product> mockProductByEpc = {
  '300000000000000000000001': Product(productId: 'P001', name: '商品A（モック）'),
  '300000000000000000000002': Product(productId: 'P002', name: '商品B（モック）'),
  // '300000000000000000000003' は意図的になし → 商品不明
};

/// 伝票に紐づく商品 1 行（受付明細）
class MockSlipDetailItem {
  final String productName;
  final num quantity;
  final String unitName;

  const MockSlipDetailItem({
    required this.productName,
    required this.quantity,
    required this.unitName,
  });
}

/// 伝票 1 件（画面 7 用）
class MockSlip {
  final String id;
  final String no;
  final String company;
  final String site;
  final String subject;
  final String products;
  /// 受付日時（新しい順で並べる用）
  final DateTime? receptionAt;
  /// 紐づく商品（受付明細）
  final List<MockSlipDetailItem> detailItems;

  const MockSlip({
    required this.id,
    required this.no,
    required this.company,
    required this.site,
    required this.subject,
    required this.products,
    this.receptionAt,
    this.detailItems = const [],
  });
}

/// 紐付け用に読み取った商品 1 件（画面 7 伝票・商品紐付け）
class MockLinkProduct {
  final String id;
  final String name;
  final String code;
  final int? number;

  const MockLinkProduct({
    required this.id,
    required this.name,
    required this.code,
    this.number,
  });

  String get numberDisplay => number?.toString() ?? '--';
}

/// タグリーダー読み取りシミュレート用プール（伝票・商品紐付けで「読み取り」時に追加）
const List<MockLinkProduct> mockLinkProductPool = [
  MockLinkProduct(id: 'lp1', name: 'レンタル機材A', code: '001', number: 1),
  MockLinkProduct(id: 'lp2', name: 'レンタル機材A', code: '002', number: 2),
  MockLinkProduct(id: 'lp3', name: 'レンタル機材B', code: '101', number: 1),
  MockLinkProduct(id: 'lp4', name: 'レンタル機材B', code: '102', number: 2),
  MockLinkProduct(id: 'lp5', name: 'レンタル機材C', code: '201', number: 1),
  MockLinkProduct(id: 'lp6', name: 'レンタル機材A', code: '003', number: 3),
];

/// 伝票一覧（画面 7）テスト用：受付日時の新しい順で10件表示するため10件用意
final List<MockSlip> mockSlips = [
  MockSlip(
    id: '1',
    no: 'D-2025-001',
    company: '株式会社サンプル建設',
    site: '〇〇現場（東京都）',
    subject: 'レンタル機材納品',
    products: 'レンタル機材A ×2, レンタル機材B ×1',
    receptionAt: DateTime(2025, 2, 19, 10, 30),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材A', quantity: 2, unitName: '台'),
      MockSlipDetailItem(productName: 'レンタル機材B', quantity: 1, unitName: '台'),
    ],
  ),
  MockSlip(
    id: '2',
    no: 'D-2025-002',
    company: '△△商事',
    site: '△△倉庫（神奈川県）',
    subject: '返却受入',
    products: 'レンタル機材C ×1',
    receptionAt: DateTime(2025, 2, 19, 9, 15),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材C', quantity: 1, unitName: '台'),
    ],
  ),
  MockSlip(
    id: '3',
    no: 'D-2025-003',
    company: '□□運輸',
    site: '□□本社（埼玉県）',
    subject: '新規レンタル',
    products: 'レンタル機材A ×1, レンタル機材B ×2',
    receptionAt: DateTime(2025, 2, 19, 8, 0),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材A', quantity: 1, unitName: '台'),
      MockSlipDetailItem(productName: 'レンタル機材B', quantity: 2, unitName: '台'),
    ],
  ),
  MockSlip(
    id: '4',
    no: 'D-2025-004',
    company: '〇〇建材',
    site: '〇〇倉庫（千葉県）',
    subject: '納品・点検',
    products: 'レンタル機材A ×3',
    receptionAt: DateTime(2025, 2, 18, 16, 45),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材A', quantity: 3, unitName: '台'),
    ],
  ),
  MockSlip(
    id: '5',
    no: 'D-2025-005',
    company: '△△建設',
    site: '△△現場（東京都）',
    subject: '返却',
    products: 'レンタル機材B ×2, レンタル機材C ×1',
    receptionAt: DateTime(2025, 2, 18, 14, 20),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材B', quantity: 2, unitName: '台'),
      MockSlipDetailItem(productName: 'レンタル機材C', quantity: 1, unitName: '台'),
    ],
  ),
  MockSlip(
    id: '6',
    no: 'D-2025-006',
    company: '□□物流',
    site: '□□配送センター（埼玉県）',
    subject: '新規レンタル',
    products: 'レンタル機材C ×2',
    receptionAt: DateTime(2025, 2, 18, 11, 0),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材C', quantity: 2, unitName: '台'),
    ],
  ),
  MockSlip(
    id: '7',
    no: 'D-2025-007',
    company: '株式会社サンプル建設',
    site: '別現場（東京都）',
    subject: '追加納品',
    products: 'レンタル機材A ×1, レンタル機材B ×1',
    receptionAt: DateTime(2025, 2, 17, 15, 30),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材A', quantity: 1, unitName: '台'),
      MockSlipDetailItem(productName: 'レンタル機材B', quantity: 1, unitName: '台'),
    ],
  ),
  MockSlip(
    id: '8',
    no: 'D-2025-008',
    company: '〇〇商事',
    site: '本社（神奈川県）',
    subject: '返却受入',
    products: 'レンタル機材A ×1',
    receptionAt: DateTime(2025, 2, 17, 10, 0),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材A', quantity: 1, unitName: '台'),
    ],
  ),
  MockSlip(
    id: '9',
    no: 'D-2025-009',
    company: '△△運輸',
    site: '△△倉庫（千葉県）',
    subject: 'レンタル機材納品',
    products: 'レンタル機材B ×3',
    receptionAt: DateTime(2025, 2, 16, 9, 45),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材B', quantity: 3, unitName: '台'),
    ],
  ),
  MockSlip(
    id: '10',
    no: 'D-2025-010',
    company: '□□建設',
    site: '□□現場（茨城県）',
    subject: '新規レンタル',
    products: 'レンタル機材A ×2, レンタル機材C ×1',
    receptionAt: DateTime(2025, 2, 16, 8, 15),
    detailItems: [
      MockSlipDetailItem(productName: 'レンタル機材A', quantity: 2, unitName: '台'),
      MockSlipDetailItem(productName: 'レンタル機材C', quantity: 1, unitName: '台'),
    ],
  ),
];

/// Android / iOS 実機向け：API なしで伝票一覧・経路案内を試す用。
/// latLng は「緯度,経度」。経路案内ボタンで Google マップがこの座標を目的地に開く。
/// 座標を変えたいときはここを編集する。
final List<ReceptionSlip> mockReceptionSlips = [
  ReceptionSlip(
    receptionNo: 'MOCK-ROUTE-001',
    subject: 'レンタル機材納品',
    customerName: '株式会社サンプル建設',
    siteName: '東京駅付近（経路案内テスト）',
    memo: '経路案内テスト用（東京駅）',
    receptionAt: DateTime(2025, 2, 19, 10, 30),
    handlerCode: '001',
    handlerName: '山田太郎',
    // 東京駅
    latLng: '35.681236,139.767125',
    details: const [
      ReceptionDetailItem(productName: 'レンタル機材A', quantity: 2, unitName: '台'),
    ],
  ),
  ReceptionSlip(
    receptionNo: 'MOCK-ROUTE-002',
    subject: '返却受入',
    customerName: '△△商事',
    siteName: '渋谷スクランブル交差点付近（経路案内テスト）',
    memo: '経路案内テスト用（渋谷）',
    receptionAt: DateTime(2025, 2, 19, 9, 15),
    handlerCode: '001',
    handlerName: '山田太郎',
    // 渋谷スクランブル交差点
    latLng: '35.6595,139.7004',
    details: const [
      ReceptionDetailItem(productName: 'レンタル機材C', quantity: 1, unitName: '台'),
    ],
  ),
  ReceptionSlip(
    receptionNo: 'MOCK-ROUTE-003',
    subject: '新規レンタル',
    customerName: '□□運輸',
    siteName: '那覇空港付近（経路案内テスト）',
    memo: '経路案内テスト用（那覇）',
    receptionAt: DateTime(2025, 2, 18, 16, 0),
    handlerCode: '002',
    handlerName: '佐藤花子',
    // 那覇空港付近（API コメント例に近い座標）
    latLng: '26.2064,127.6465',
    details: const [
      ReceptionDetailItem(productName: 'レンタル機材B', quantity: 1, unitName: '台'),
    ],
  ),
  ReceptionSlip(
    receptionNo: 'MOCK-ROUTE-004',
    subject: '納品・点検',
    customerName: '〇〇建材',
    siteName: '位置情報なし（ネガティブテスト）',
    memo: 'latLng 未設定 → 「位置情報が記録されていません」になること',
    receptionAt: DateTime(2025, 2, 18, 14, 0),
    handlerCode: '002',
    handlerName: '佐藤花子',
    latLng: null,
    details: const [
      ReceptionDetailItem(productName: 'レンタル機材A', quantity: 1, unitName: '台'),
    ],
  ),
  ReceptionSlip(
    receptionNo: 'MOCK-VISIT-001',
    subject: '来店(納品)',
    customerName: '来店テスト株式会社',
    siteName: '来店（経路案内ボタン非表示の確認用）',
    memo: '用件が来店 → 全伝票一覧から開いても経路案内ボタンが出ないこと（送信は配達と同じ納品モード）',
    receptionAt: DateTime(2025, 2, 17, 11, 0),
    handlerCode: '001',
    handlerName: '山田太郎',
    latLng: '35.681236,139.767125',
    details: const [
      ReceptionDetailItem(productName: 'レンタル機材A', quantity: 1, unitName: '台'),
    ],
  ),
  ReceptionSlip(
    receptionNo: 'MOCK-VISIT-002',
    subject: '来店(返品)',
    customerName: '来店返品テスト株式会社',
    siteName: '来店（返品・引取と同じ処理）',
    memo: '用件が来店(返品) → 引取と同じ返品モードで tag_mode2=在庫 / tag_mode=返品',
    receptionAt: DateTime(2025, 2, 17, 14, 30),
    handlerCode: '002',
    handlerName: '佐藤花子',
    latLng: null,
    details: const [
      ReceptionDetailItem(productName: 'レンタル機材B', quantity: 2, unitName: '台'),
    ],
  ),
];

/// API 未使用時の伝票一覧。フィルタを簡易適用して返す。
List<ReceptionSlip> mockReceptionSlipsForFilter(SlipListFilter filter) {
  Iterable<ReceptionSlip> list = mockReceptionSlips;

  final subjects = filter.subjectFilter;
  if (subjects != null && subjects.isNotEmpty) {
    list = list.where((s) => subjects.contains(s.subject));
  }

  final code = filter.assigneeCode?.trim();
  if (code != null && code.isNotEmpty) {
    list = list.where((s) => (s.handlerCode ?? '').trim() == code);
  }

  final sorted = list.toList()
    ..sort((a, b) {
      final at = a.receptionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.receptionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
  final offset = filter.offset < 0 ? 0 : filter.offset;
  final limit = filter.limit < 1 ? 10 : filter.limit;
  return sorted.skip(offset).take(limit).toList();
}
