// バックエンド API 呼び出し
// 参照: docs/API設計.md

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/employee.dart';
import '../models/product.dart';
import '../models/product_by_epc.dart';
import '../models/product_update_request.dart';

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
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Employee.fromJson(json);
  }

  /// EPC（tag_id2）をキーに商品情報を取得（[ICﾀｸﾞ台帳]+[商品台帳]の商品名付き）
  Future<ProductByEpc?> fetchProduct(String epc) async {
    final uri = Uri.parse('${_normalizedBase}api/products').replace(
      queryParameters: {'epc': epc},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductByEpc.fromJson(json);
  }

  /// ランダムに N 件の商品情報を取得（タグリーダーなし時の読み取りシミュレート用）
  Future<List<ProductByEpc>> fetchRandomProducts({int count = 1}) async {
    final uri = Uri.parse('${_normalizedBase}api/products/random').replace(
      queryParameters: {'count': count.toString()},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ProductByEpc.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 変更した商品データを送信（POST /api/product-updates）。DB の [ICﾀｸﾞ台帳].tag_mode2 を更新。
  /// 失敗時は例外を投げる。
  Future<void> submitProductUpdate(ProductUpdateRequest request) async {
    final uri = Uri.parse('${_normalizedBase}api/product-updates');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode == 404) {
      throw Exception('該当するタグが見つかりませんでした（EPC: ${request.epc}）');
    }
    if (response.statusCode >= 400) {
      throw Exception('送信エラー: ${response.statusCode} ${response.body}');
    }
  }
}
