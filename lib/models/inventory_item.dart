/// GET /api/products/inventory の 1 件（在庫確認画面用）
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.sku,
    required this.imageUrl,
    required this.description,
    required this.countOk,
    required this.countStorage,
    required this.countCleaning,
    required this.countMaintenance,
    required this.countRented,
    this.categoryId,
    this.baseFee,
    this.dailyPrice,
    this.monthlyPrice,
  });

  final String id;
  final String name;
  final int? categoryId;
  final String category;
  final String sku;
  final String imageUrl;
  final String description;
  final int countOk;
  final int countStorage;
  final int countCleaning;
  final int countMaintenance;
  final int countRented;
  final double? baseFee;
  final double? dailyPrice;
  final double? monthlyPrice;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? 0;
    }

    int? toIntOrNull(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString());
    }

    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return InventoryItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      categoryId: toIntOrNull(json['categoryId']),
      category: json['category']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      countOk: toInt(json['countOk']),
      countStorage: toInt(json['countStorage']),
      countCleaning: toInt(json['countCleaning']),
      countMaintenance: toInt(json['countMaintenance']),
      countRented: toInt(json['countRented']),
      baseFee: toDouble(json['baseFee']),
      dailyPrice: toDouble(json['dailyPrice']),
      monthlyPrice: toDouble(json['monthlyPrice']),
    );
  }
}
