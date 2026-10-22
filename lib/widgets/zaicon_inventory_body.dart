import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/product_category.dart';
import '../screens/inventory_category_products_screen.dart';
import '../utils/api_error_presenter.dart';
import '../zaicon/zaicon_constants.dart';

/// 在庫確認のカテゴリー一覧。
/// カテゴリー・全表示・検索結果は別画面で開く。戻る操作はホームまで一気に戻さない。
class ZaiconInventoryBody extends StatefulWidget {
  const ZaiconInventoryBody({super.key});

  @override
  State<ZaiconInventoryBody> createState() => _ZaiconInventoryBodyState();
}

class _ZaiconInventoryBodyState extends State<ZaiconInventoryBody> {
  final TextEditingController _filterController = TextEditingController();

  List<ProductCategory> _categories = [];
  bool _loadingCategories = true;
  String? _categoriesError;
  Timer? _searchDebounce;
  bool _suppressFilterListener = false;

  String get _filter => _filterController.text.trim();

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_onFilterChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });
    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final cats = await api.fetchProductCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
    } catch (e, st) {
      logApiError(e, apiName: 'products/categories', stackTrace: st);
      if (!mounted) return;
      setState(() {
        _categories = [];
        _loadingCategories = false;
        _categoriesError = toUserFacingApiError(e).displayText;
      });
    }
  }

  void _onFilterChanged() {
    if (_suppressFilterListener) return;
    final q = _filter;
    _searchDebounce?.cancel();
    if (q.isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _filter != q) return;
      _suppressFilterListener = true;
      _filterController.clear();
      _suppressFilterListener = false;
      _openProducts(InventoryCategoryProductsScreen(initialQuery: q));
    });
  }

  void _openCategory(ProductCategory category) {
    _searchDebounce?.cancel();
    _clearFilterQuietly();
    _openProducts(
      InventoryCategoryProductsScreen(
        categoryId: category.id,
        categoryName: category.name,
      ),
    );
  }

  void _openAllItems() {
    _searchDebounce?.cancel();
    _clearFilterQuietly();
    _openProducts(InventoryCategoryProductsScreen(showAll: true));
  }

  void _clearFilterQuietly() {
    if (_filterController.text.isEmpty) return;
    _suppressFilterListener = true;
    _filterController.clear();
    _suppressFilterListener = false;
  }

  void _openProducts(InventoryCategoryProductsScreen screen) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 16;

    if (_loadingCategories) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStickyTitleSearchRow(),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2563EB)),
                  SizedBox(height: 16),
                  Text(
                    'カテゴリーを読み込み中...',
                    style: TextStyle(color: Color(0xFF4B5563)),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_categoriesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStickyTitleSearchRow(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'カテゴリーを取得できませんでした',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _categoriesError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loadCategories,
                      icon: const Icon(Icons.refresh),
                      label: const Text('再試行'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStickyTitleSearchRow(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
            child: _buildCategoryScrollContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyTitleSearchRow() {
    return Material(
      color: const Color(0xFFF3F4F6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '在庫確認',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _filterController,
                decoration: InputDecoration(
                  hintText: '全商品を検索 (名前, ID)...',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF9CA3AF),
                    size: 22,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    maxHeight: 40,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryScrollContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'カテゴリー選択',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '商品区分がありません',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.75,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, i) {
              final cat = _categories[i];
              final color = zaiconCategoryColorAt(i);
              return Material(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => _openCategory(cat),
                  borderRadius: BorderRadius.circular(6),
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      cat.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: _openAllItems,
              borderRadius: BorderRadius.circular(8),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  '全表示一覧',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
