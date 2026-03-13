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
  /// 保管場所（1=本社, 2=山川, 3=東風平, 4=友寄）。テスト環境でのみ [ICタグ台帳].tag_mode に反映。
  final int? storageLocation;

  const ProductUpdateRequest({
    required this.epc,
    this.productId,
    required this.readAt,
    required this.changes,
    this.deviceId,
    this.userId,
    this.storageLocation,
  });

  factory ProductUpdateRequest.fromJson(Map<String, dynamic> json) {
    return ProductUpdateRequest(
      epc: json['epc'] as String,
      productId: json['product_id'] as String?,
      readAt: json['read_at'] as String,
      changes: Map<String, dynamic>.from(json['changes'] as Map),
      deviceId: json['device_id'] as String?,
      userId: json['user_id'] as String?,
      storageLocation: json['storage_location'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'epc': epc,
      'product_id': productId,
      'read_at': readAt,
      'changes': changes,
      'device_id': deviceId,
      'user_id': userId,
    };
    if (storageLocation != null) map['storage_location'] = storageLocation;
    return map;
  }
}
