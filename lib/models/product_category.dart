/// GET /api/products/categories の1件（商品区分マスター）
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? 0;
    }

    return ProductCategory(
      id: toInt(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}
