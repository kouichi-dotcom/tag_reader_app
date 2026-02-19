// 画面モック用のモックデータ（2-3〜2-5）
// 本番ではタグリーダー・API に差し替える

import '../models/product.dart';

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

/// スキャンで出てくるデバイス一覧（画面 1）
const List<MockBleDevice> mockBleDevices = [
  MockBleDevice(id: 'MOCK-001', name: 'DOTR-900J (モック1)'),
  MockBleDevice(id: 'MOCK-002', name: 'DOTR-900J (モック2)'),
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

/// 伝票 1 件（画面 7 用）
class MockSlip {
  final String id;
  final String no;
  final String company;
  final String site;
  final String subject;
  final String products;

  const MockSlip({
    required this.id,
    required this.no,
    required this.company,
    required this.site,
    required this.subject,
    required this.products,
  });
}

/// 紐付け用に読み取った商品 1 件（画面 7 伝票・商品紐付け）
class MockLinkProduct {
  final String id;
  final String name;
  final String code;
  final String status; // OK, 貸出中, 清掃中, 整備中, 修理中, 廃棄, 不明

  const MockLinkProduct({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
  });
}

/// タグリーダー読み取りシミュレート用プール（伝票・商品紐付けで「読み取り」時に追加）
const List<MockLinkProduct> mockLinkProductPool = [
  MockLinkProduct(id: 'lp1', name: 'レンタル機材A', code: '001', status: 'OK'),
  MockLinkProduct(id: 'lp2', name: 'レンタル機材A', code: '002', status: '貸出中'),
  MockLinkProduct(id: 'lp3', name: 'レンタル機材B', code: '101', status: '清掃中'),
  MockLinkProduct(id: 'lp4', name: 'レンタル機材B', code: '102', status: '整備中'),
  MockLinkProduct(id: 'lp5', name: 'レンタル機材C', code: '201', status: '修理中'),
  MockLinkProduct(id: 'lp6', name: 'レンタル機材A', code: '003', status: 'OK'),
];

/// 伝票一覧（画面 7）
const List<MockSlip> mockSlips = [
  MockSlip(
    id: '1',
    no: 'D-2025-001',
    company: '株式会社サンプル建設',
    site: '〇〇現場（東京都）',
    subject: 'レンタル機材納品',
    products: 'レンタル機材A ×2, レンタル機材B ×1',
  ),
  MockSlip(
    id: '2',
    no: 'D-2025-002',
    company: '△△商事',
    site: '△△倉庫（神奈川県）',
    subject: '返却受入',
    products: 'レンタル機材C ×1',
  ),
  MockSlip(
    id: '3',
    no: 'D-2025-003',
    company: '□□運輸',
    site: '□□本社（埼玉県）',
    subject: '新規レンタル',
    products: 'レンタル機材A ×1, レンタル機材B ×2',
  ),
];
