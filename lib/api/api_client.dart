// バックエンド API 呼び出し
// 参照: docs/API設計.md

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/employee.dart';
import '../models/product.dart';
import '../models/product_by_epc.dart';
import '../models/product_catalog_item.dart';
import '../models/product_update_request.dart';
import '../models/reception_slip.dart';
import '../models/slip_list_filter.dart';

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
  /// 本番DB接続時は読み取り専用のため呼び出し不可。失敗時は例外を投げる。
  Future<void> submitProductUpdate(ProductUpdateRequest request) async {
    if (kIsProductionDb) {
      throw Exception('本番DBでは読み取り専用のため更新できません。');
    }
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

  /// 受付台帳の伝票一覧を取得（GET /api/reception-slips）
  /// [filter] 取得条件。省略時は全伝票（最新10件）。
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
