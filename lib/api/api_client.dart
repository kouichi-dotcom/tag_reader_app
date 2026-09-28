// バックエンド API 呼び出し
// 参照: docs/API設計.md

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/employee.dart';
import '../models/inventory_item.dart';
import '../models/inventory_unit_row.dart';
import '../models/product_by_epc.dart';
import '../models/product_catalog_item.dart';
import '../models/product_category.dart';
import '../models/product_update_request.dart';
import '../models/reception_slip.dart';
import '../models/slip_list_filter.dart';
import '../models/slip_tag_link_request.dart';
import '../models/tag_ledger_item.dart';
import '../models/tag_ledger_register.dart';

/// リクエストが返らない場合のタイムアウト（接続不可で「取得中」のままになるのを防ぐ）
const Duration _kRequestTimeout = Duration(seconds: 15);

/// 商品照合・担当者取得・商品データ更新 API を呼び出すクライアント
class ApiClient {
  final String baseUrl;

  ApiClient({required this.baseUrl});

  /// 末尾のスラッシュを除いたベース URL を返す
  String get _normalizedBase => baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';

  /// 担当者コードをキーに担当者氏名を取得（GET /api/employees?code=...）
  Future<Employee?> fetchEmployee(String code) async {
    final uri = Uri.parse('${_normalizedBase}api/employees').replace(
      queryParameters: {'code': code},
    );
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Employee.fromJson(json);
  }

  /// 担当者を範囲で一括取得（GET /api/employees/all）。初回キャッシュ用。
  Future<List<Employee>> fetchEmployeesInRange({
    int minCode = 1,
    int maxCode = 101,
  }) async {
    final uri = Uri.parse('${_normalizedBase}api/employees/all').replace(
      queryParameters: {
        'minCode': minCode.toString(),
        'maxCode': maxCode.toString(),
      },
    );
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Employee.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// EPC（tag_id2）をキーに商品情報を取得（[ICﾀｸﾞ台帳]+[商品台帳]の商品名付き）
  Future<ProductByEpc?> fetchProduct(String epc) async {
    final uri = Uri.parse('${_normalizedBase}api/products').replace(
      queryParameters: {'epc': epc},
    );
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductByEpc.fromJson(json);
  }

  /// 在庫確認用（GET /api/products/inventory）。[商品台帳] と [ICタグ台帳] の集計。
  /// [categoryId] で区分絞り込み、[query] で商品名・商品コードを部分一致検索。
  Future<List<InventoryItem>> fetchInventory({int? categoryId, String? query}) async {
    final params = <String, String>{};
    if (categoryId != null) params['categoryId'] = categoryId.toString();
    final q = query?.trim();
    if (q != null && q.isNotEmpty) params['q'] = q;
    final uri = Uri.parse('${_normalizedBase}api/products/inventory').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) {
      throw Exception('在庫取得エラー: ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw Exception('在庫APIの形式が不正です');
    }
    return decoded
        .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 在庫確認の区分グリッド用（GET /api/products/categories）。[商品区分マスター]。
  Future<List<ProductCategory>> fetchProductCategories() async {
    final uri = Uri.parse('${_normalizedBase}api/products/categories');
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) {
      throw Exception('商品区分取得エラー: ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw Exception('商品区分APIの形式が不正です');
    }
    return decoded
        .map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 在庫確認: 同一商品コードの個体一覧（GET /api/products/inventory/units?code=）
  Future<List<InventoryUnitRow>> fetchInventoryUnits(int productCode) async {
    final uri = Uri.parse('${_normalizedBase}api/products/inventory/units').replace(
      queryParameters: {'code': productCode.toString()},
    );
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) {
      throw Exception('個体一覧取得エラー: ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw Exception('個体一覧APIの形式が不正です');
    }
    return decoded
        .map((e) => InventoryUnitRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 商品台帳の現存商品一覧を一括取得（GET /api/products/catalog）。初回キャッシュ用。
  Future<List<ProductCatalogItem>> fetchProductCatalog() async {
    final uri = Uri.parse('${_normalizedBase}api/products/catalog');
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ProductCatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// ICタグ台帳の一括取得（GET /api/products/tag-ledger）。日次キャッシュ用（廃棄除外）。
  Future<List<TagLedgerItem>> fetchTagLedger() async {
    final uri = Uri.parse('${_normalizedBase}api/products/tag-ledger');
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) {
      throw Exception('タグ台帳取得エラー: ${response.statusCode} ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => TagLedgerItem.fromJson(e as Map<String, dynamic>))
        .where((e) => e.tagId2.isNotEmpty)
        .toList();
  }

  /// 商品コードで 1 件取得（GET /api/products/by-code）。オンデマンド用。
  Future<ProductCatalogItem?> fetchProductByCode(int code) async {
    final uri = Uri.parse('${_normalizedBase}api/products/by-code').replace(
      queryParameters: {'code': code.toString()},
    );
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductCatalogItem.fromJson(json);
  }

  /// ランダムに N 件の商品情報を取得（タグリーダーなし時の読み取りシミュレート用）
  Future<List<ProductByEpc>> fetchRandomProducts({int count = 1}) async {
    final uri = Uri.parse('${_normalizedBase}api/products/random').replace(
      queryParameters: {'count': count.toString()},
    );
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ProductByEpc.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 変更した商品データを送信（POST /api/product-updates）。DB の [ICタグ台帳].tag_mode2 を更新。
  /// prod Flavor または API readOnly 時は呼び出し不可。
  Future<void> submitProductUpdate(ProductUpdateRequest request) async {
    _ensureUpdatesAllowed('更新');
    final uri = Uri.parse('${_normalizedBase}api/product-updates');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(
          _kRequestTimeout,
          onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
        );
    if (response.statusCode == 404) {
      throw Exception('該当するタグが見つかりませんでした（EPC: ${request.epc}）');
    }
    if (response.statusCode >= 400) {
      throw Exception('送信エラー: ${response.statusCode} ${response.body}');
    }
  }

  /// 商品コードの次番号を取得（GET /api/products/tag-ledger/next-number）。
  Future<int> fetchNextTagNumber(int productCode) async {
    final uri = Uri.parse('${_normalizedBase}api/products/tag-ledger/next-number')
        .replace(queryParameters: {'code': productCode.toString()});
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    if (response.statusCode != 200) {
      throw Exception('次番号取得エラー: ${response.statusCode} ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['nextNumber'] as num).toInt();
  }

  /// ICタグ台帳へ新規登録（POST /api/products/tag-ledger）。
  Future<TagLedgerRegisterResult> registerTagLedger(TagLedgerRegisterRequest request) async {
    _ensureUpdatesAllowed('登録');
    final uri = Uri.parse('${_normalizedBase}api/products/tag-ledger');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(
          _kRequestTimeout,
          onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
        );
    if (response.statusCode == 404) {
      throw Exception('商品コードが見つかりません: ${response.body}');
    }
    if (response.statusCode == 409) {
      String msg = '登録できません（重複または読み取り専用）';
      try {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final m = map['message'] as String?;
        if (m != null && m.isNotEmpty) msg = m;
      } catch (_) {}
      throw Exception(msg);
    }
    if (response.statusCode >= 400) {
      throw Exception('登録エラー: ${response.statusCode} ${response.body}');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return TagLedgerRegisterResult.fromJson(map);
  }

  /// 受付伝票にタグを紐付けて送信（POST /api/reception-slips/{receptionNo}/link-tags）。
  /// 用件に応じて [ICタグ台帳].tag_mode2 / [tag_table3].tag_mode・complete を更新する。
  /// 配達・来店(納品)=納品、引取・来店(返品)=返品。用件「交換」のときは [SlipTagLinkRequest.linkMode] 必須。
  /// prod Flavor または API readOnly 時は呼び出し不可。
  Future<SlipTagLinkResult> submitSlipTagLinks({
    required String receptionNo,
    required SlipTagLinkRequest request,
  }) async {
    _ensureUpdatesAllowed('更新');
    final encodedNo = Uri.encodeComponent(receptionNo.trim());
    final uri = Uri.parse('${_normalizedBase}api/reception-slips/$encodedNo/link-tags');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(
          _kRequestTimeout,
          onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
        );
    if (response.statusCode == 404) {
      throw Exception('紐付け失敗（見つかりません）: ${response.body}');
    }
    if (response.statusCode == 409) {
      throw Exception('読み取り専用のため紐付けできません。');
    }
    if (response.statusCode >= 400) {
      throw Exception('紐付け送信エラー: ${response.statusCode} ${response.body}');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return SlipTagLinkResult.fromJson(map);
  }

  /// 更新系 API の入口ガード（prod Flavor は常に拒否、staging は API readOnly に従う）。
  void _ensureUpdatesAllowed(String actionLabel) {
    if (!kUpdatesForbidden) return;
    if (kIsProdFlavor) {
      throw Exception('本番アプリでは読み取り専用のため$actionLabelできません。');
    }
    throw Exception('読み取り専用のため$actionLabelできません。');
  }

  /// 受付台帳の伝票一覧を取得（GET /api/reception-slips）
  /// [filter] 取得条件。省略時は全伝票（limit/offset でページング）。
  Future<List<ReceptionSlip>> fetchReceptionSlips({
    SlipListFilter filter = SlipListFilter.all,
  }) async {
    final queryParams = <String, String>{};
    if (filter.date != null) {
      queryParams['date'] = filter.date!.toIso8601String().split('T')[0];
    }
    if (filter.assigneeCode != null) {
      queryParams['assigneeCode'] = filter.assigneeCode!;
    }
    if (filter.unassignedOnly) {
      queryParams['unassignedOnly'] = 'true';
    }
    if (filter.random) {
      queryParams['random'] = 'true';
    }
    if (filter.subjectFilter != null && filter.subjectFilter!.isNotEmpty) {
      queryParams['subjects'] = filter.subjectFilter!.join(',');
    }
    queryParams['limit'] = filter.limit.toString();
    queryParams['offset'] = filter.offset.toString();

    final uri = Uri.parse('${_normalizedBase}api/reception-slips').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    print('[API] GET $uri'); // デバッグ用
    final response = await http.get(uri).timeout(
      _kRequestTimeout,
      onTimeout: () => throw TimeoutException('接続がタイムアウトしました。API の URL とネットワークを確認してください。'),
    );
    print('[API] Status: ${response.statusCode}'); // デバッグ用
    if (response.statusCode != 200) {
      print('[API] Error body: ${response.body}'); // デバッグ用
      throw Exception('受付台帳取得エラー: ${response.statusCode} ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    print('[API] Received ${list.length} slips'); // デバッグ用
    return list
        .map((e) => ReceptionSlip.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
