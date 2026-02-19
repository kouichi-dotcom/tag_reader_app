// 商品データ更新リクエスト（API 設計に基づく型）
// 参照: docs/API設計.md

/// 商品データ更新 API のリクエスト Body 用モデル
class ProductUpdateRequest {
  final String epc;
  final String? productId;
  final String readAt; // ISO 8601
  final Map<String, dynamic> changes; // 在庫・ステータス・メモ等
  final String? deviceId;
  final String? userId;

  const ProductUpdateRequest({
    required this.epc,
    this.productId,
    required this.readAt,
    required this.changes,
    this.deviceId,
    this.userId,
  });

  factory ProductUpdateRequest.fromJson(Map<String, dynamic> json) {
    return ProductUpdateRequest(
      epc: json['epc'] as String,
      productId: json['product_id'] as String?,
      readAt: json['read_at'] as String,
      changes: Map<String, dynamic>.from(json['changes'] as Map),
      deviceId: json['device_id'] as String?,
      userId: json['user_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'epc': epc,
        'product_id': productId,
        'read_at': readAt,
        'changes': changes,
        'device_id': deviceId,
        'user_id': userId,
      };
}
