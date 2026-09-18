import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/inventory_item.dart';
import '../models/product_category.dart';
import '../screens/inventory_units_screen.dart';
import '../zaicon/zaicon_constants.dart';

/// InventoryList.tsx 相当
class ZaiconInventoryBody extends StatefulWidget {
  const ZaiconInventoryBody({super.key});

  @override
  State<ZaiconInventoryBody> createState() => _ZaiconInventoryBodyState();
}

class _ZaiconInventoryBodyState extends State<ZaiconInventoryBody> {
  final TextEditingController _filterController = TextEditingController();

  /// デスクトップ内訳用のダミー商品。在庫確認では表示しない。
  static const String _kExcludedProductCode = '9999';

  List<InventoryItem> _items = [];
  List<ProductCategory> _categories = [];
  bool _loadingCategories = true;
  bool _loadingInventory = false;
  String? _categoriesError;
  String? _inventoryError;

  /// 同時リクエストの古い応答を捨てる
  int _inventoryLoadGeneration = 0;
  Timer? _searchDebounce;

  /// null = 区分未選択。選択時はその商品区分ID。
  int? _selectedCategoryId;

  /// 「全表示一覧」選択中
  bool _showAllItems = false;

  String get _filter => _filterController.text.trim();

  bool get _showList => _filter.isNotEmpty || _selectedCategoryId != null || _showAllItems;

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_onFilterChanged);
    _loadCategories();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categories = [];
        _loadingCategories = false;
        _categoriesError = e.toString();
      });
    }
  }

  Future<void> _loadInventory({int? categoryId, String? query}) async {
    final generation = ++_inventoryLoadGeneration;
    setState(() {
      _loadingInventory = true;
      _inventoryError = null;
    });
    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final inventory = await api.fetchInventory(categoryId: categoryId, query: query);
      if (!mounted || generation != _inventoryLoadGeneration) return;
      setState(() {
        _items = inventory.where((e) => e.id.trim() != _kExcludedProductCode).toList();
        _loadingInventory = false;
      });
    } catch (e) {
      if (!mounted || generation != _inventoryLoadGeneration) return;
      setState(() {
        _items = [];
        _loadingInventory = false;
        _inventoryError = e.toString();
      });
    }
  }

  void _loadInventoryForCurrentView() {
    if (_filter.isNotEmpty) {
      _loadInventory(query: _filter);
    } else if (_showAllItems) {
      _loadInventory();
    } else if (_selectedCategoryId != null) {
      _loadInventory(categoryId: _selectedCategoryId);
    }
  }

  void _onFilterChanged() {
    final q = _filter;
    _searchDebounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _items = [];
        _loadingInventory = false;
        _inventoryError = null;
      });
      return;
    }
    setState(() {
      _loadingInventory = true;
      _inventoryError = null;
      _selectedCategoryId = null;
      _showAllItems = false;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _filter != q) return;
      _loadInventory(query: q);
    });
  }

  void _selectCategory(int categoryId) {
    _searchDebounce?.cancel();
    setState(() {
      _selectedCategoryId = categoryId;
      _showAllItems = false;
      _filterController.clear();
      _items = [];
      _inventoryError = null;
    });
    _loadInventory(categoryId: categoryId);
  }

  void _selectAllItems() {
    _searchDebounce?.cancel();
    setState(() {
      _showAllItems = true;
      _selectedCategoryId = null;
      _filterController.clear();
      _items = [];
      _inventoryError = null;
    });
    _loadInventory();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    super.dispose();
  }

  void _clearCategorySelection() {
    _searchDebounce?.cancel();
    _inventoryLoadGeneration++;
    setState(() {
      _selectedCategoryId = null;
      _showAllItems = false;
      _filterController.clear();
      _items = [];
      _inventoryError = null;
      _loadingInventory = false;
    });
  }

  bool _matchesText(InventoryItem item) {
    if (_filter.isEmpty) return true;
    final q = _filter.toLowerCase();
    return item.name.toLowerCase().contains(q) ||
        item.sku.toLowerCase().contains(q) ||
        item.category.toLowerCase().contains(q) ||
        item.id.toLowerCase().contains(q);
  }

  bool _matchesCategory(InventoryItem item) {
    if (_filter.isNotEmpty) return true;
    if (_showAllItems) return true;
    if (_selectedCategoryId == null) return true;
    return item.categoryId == _selectedCategoryId;
  }

  List<InventoryItem> get _filteredItems {
    final list = _items.where((item) => _matchesText(item) && _matchesCategory(item)).toList();
    list.sort(_compareProductCodeAsc);
    return list;
  }

  /// 商品コード（[InventoryItem.id]）昇順。数値として解釈できる場合は数値順。
  static int _compareProductCodeAsc(InventoryItem a, InventoryItem b) {
    final ai = int.tryParse(a.id.trim());
    final bi = int.tryParse(b.id.trim());
    if (ai != null && bi != null) return ai.compareTo(bi);
    return a.id.compareTo(b.id);
  }

  String? get _selectedCategoryName {
    if (_selectedCategoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _selectedCategoryId) return c.name;
    }
    return null;
  }

  Widget _statusBadges(InventoryItem item) {
    final hasOk = item.countOk > 0;
    final hasCleaning = item.countCleaning > 0;
    final hasMaintenance = item.countMaintenance > 0;
    final hasStorage = item.countStorage > 0;
    if (!hasOk && !hasCleaning && !hasMaintenance && !hasStorage) {
      return _badge('在庫無し', const Color(0xFF6B7280), const Color(0xFFF3F4F6));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (hasOk)
          _badge('OK (${item.countOk})', const Color(0xFF166534), const Color(0xFFDCFCE7)),
        if (hasCleaning)
          _badge('清掃中 (${item.countCleaning})', const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
        if (hasMaintenance)
          _badge('整備中 (${item.countMaintenance})', const Color(0xFF1D4ED8), const Color(0xFFDBEAFE)),
        if (hasStorage)
          _badge('在庫 (${item.countStorage})', const Color(0xFF9A3412), const Color(0xFFFFEDD5)),
      ],
    );
  }

  Widget _badge(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  String _listHeaderLabel() {
    if (_filter.isNotEmpty) return '検索結果';
    if (_showAllItems) return '全商品';
    return _selectedCategoryName ?? 'カテゴリー選択';
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
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 22),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40, maxHeight: 40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyListNavRow() {
    return Material(
      color: const Color(0xFFF3F4F6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: _clearCategorySelection,
              icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF2563EB)),
              label: const Text('カテゴリーへ戻る'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade100),
                ),
              ),
            ),
            const Spacer(),
            Text(
              _listHeaderLabel(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
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
                  Text('カテゴリーを読み込み中...', style: TextStyle(color: Color(0xFF4B5563))),
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
                    Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'API: $kApiBaseUrl',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
        if (_showList) _buildStickyListNavRow(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
            child: _showList ? _buildListScrollContent() : _buildCategoryScrollContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryErrorPanel({required VoidCallback onRetry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.cloud_off, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              '在庫データを取得できませんでした',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800),
            ),
            if (_inventoryError != null) ...[
              const SizedBox(height: 8),
              Text(
                _inventoryError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('在庫データを再取得'),
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
                  onTap: () => _selectCategory(cat.id),
                  borderRadius: BorderRadius.circular(6),
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
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
              onTap: _selectAllItems,
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

  Widget _buildListScrollContent() {
    if (_loadingInventory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF2563EB)),
              const SizedBox(height: 16),
              Text(
                '在庫データを読み込み中...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }
    if (_inventoryError != null) {
      return _buildInventoryErrorPanel(onRetry: _loadInventoryForCurrentView);
    }

    final cards = _filteredItems.map(_itemCard).toList();
    if (_filteredItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            '該当する商品が見つかりません',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cards,
    );
  }

  Widget _itemCard(InventoryItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final code = int.tryParse(item.id.trim());
            if (code == null) return;
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (ctx) => InventoryUnitsScreen(
                  productCode: code,
                  productName: item.name,
                  item: item,
                ),
              ),
            );
          },
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (item.id.isNotEmpty)
                        TextSpan(
                          text: '：${item.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                _statusBadges(item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
