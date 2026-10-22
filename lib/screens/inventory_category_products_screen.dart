import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/inventory_item.dart';
import '../theme/app_design.dart';
import '../utils/api_error_presenter.dart';
import '../widgets/main_flow_nav_bar.dart';
import 'inventory_units_screen.dart';

/// 在庫確認の商品一覧。
///
/// カテゴリー一覧とは別ルートにする。端末の戻る操作（画面端スワイプ、戻るボタン）は
/// この一覧だけを閉じ、カテゴリー一覧へ戻す。
class InventoryCategoryProductsScreen extends StatefulWidget {
  const InventoryCategoryProductsScreen({
    super.key,
    this.categoryId,
    this.categoryName,
    this.showAll = false,
    this.initialQuery,
  });

  /// 商品区分ID。検索・全表示のときは null。
  final int? categoryId;

  /// 見出しに出す区分名。
  final String? categoryName;

  /// 全商品。
  final bool showAll;

  /// カテゴリー一覧の検索から開いたときの検索語。
  final String? initialQuery;

  @override
  State<InventoryCategoryProductsScreen> createState() =>
      _InventoryCategoryProductsScreenState();
}

class _InventoryCategoryProductsScreenState
    extends State<InventoryCategoryProductsScreen> {
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// デスクトップ内訳用のダミー商品。在庫確認では表示しない。
  static const String _kExcludedProductCode = '9999';

  List<InventoryItem> _items = [];
  bool _loadingInventory = true;
  String? _inventoryError;
  int _inventoryLoadGeneration = 0;
  Timer? _searchDebounce;

  /// 検索語で一覧を出している。空欄に戻したらカテゴリー一覧へ閉じる。
  bool _browsingSearch = false;
  bool _closing = false;

  String get _filter => _filterController.text.trim();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _filterController.text = initial;
      _filterController.selection = TextSelection.collapsed(
        offset: initial.length,
      );
      _browsingSearch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
    _filterController.addListener(_onFilterChanged);
    _loadForCurrentView();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadInventory({int? categoryId, String? query}) async {
    final generation = ++_inventoryLoadGeneration;
    setState(() {
      _loadingInventory = true;
      _inventoryError = null;
    });
    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final inventory = await api.fetchInventory(
        categoryId: categoryId,
        query: query,
      );
      if (!mounted || generation != _inventoryLoadGeneration) return;
      setState(() {
        _items = inventory
            .where((e) => e.id.trim() != _kExcludedProductCode)
            .toList();
        _loadingInventory = false;
      });
    } catch (e, st) {
      logApiError(e, apiName: 'products/inventory', stackTrace: st);
      if (!mounted || generation != _inventoryLoadGeneration) return;
      setState(() {
        _items = [];
        _loadingInventory = false;
        _inventoryError = toUserFacingApiError(e).displayText;
      });
    }
  }

  void _loadForCurrentView() {
    if (_browsingSearch) {
      _loadInventory(query: _filter);
    } else if (widget.showAll) {
      _loadInventory();
    } else if (widget.categoryId != null) {
      _loadInventory(categoryId: widget.categoryId);
    }
  }

  void _onFilterChanged() {
    final q = _filter;
    _searchDebounce?.cancel();
    if (q.isEmpty) {
      if (_browsingSearch && !_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _closeToCategoryList();
        });
      }
      return;
    }
    setState(() {
      _browsingSearch = true;
      _loadingInventory = true;
      _inventoryError = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _filter != q) return;
      _loadInventory(query: q);
    });
  }

  void _closeToCategoryList() {
    Navigator.of(context).pop();
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
    if (_browsingSearch || widget.showAll || widget.categoryId == null) {
      return true;
    }
    return item.categoryId == widget.categoryId;
  }

  List<InventoryItem> get _filteredItems {
    final list = _items
        .where((item) => _matchesText(item) && _matchesCategory(item))
        .toList();
    list.sort(_compareProductCodeAsc);
    return list;
  }

  static int _compareProductCodeAsc(InventoryItem a, InventoryItem b) {
    final ai = int.tryParse(a.id.trim());
    final bi = int.tryParse(b.id.trim());
    if (ai != null && bi != null) return ai.compareTo(bi);
    return a.id.compareTo(b.id);
  }

  String _listHeaderLabel() {
    if (_browsingSearch) return '検索結果';
    if (widget.showAll) return '全商品';
    final name = widget.categoryName;
    if (name != null && name.isNotEmpty) return name;
    return 'カテゴリー選択';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 16;

    return Scaffold(
      backgroundColor: AppDesign.scaffoldBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDesign.deviceWidth),
          child: Material(
            color: const Color(0xFFF3F4F6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MainFlowNavBar(
                  showBackButton: true,
                  title: '在庫確認',
                  onBack: _closeToCategoryList,
                ),
                _buildStickyTitleSearchRow(),
                _buildStickyListNavRow(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                    child: _buildListScrollContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                focusNode: _searchFocus,
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

  Widget _buildStickyListNavRow() {
    return Material(
      color: const Color(0xFFF3F4F6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: _closeToCategoryList,
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: Color(0xFF2563EB),
              ),
              label: const Text('カテゴリーへ戻る'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
      return _buildInventoryErrorPanel(onRetry: _loadForCurrentView);
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
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
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
          _badge(
            'OK (${item.countOk})',
            const Color(0xFF166534),
            const Color(0xFFDCFCE7),
          ),
        if (hasCleaning)
          _badge(
            '清掃中 (${item.countCleaning})',
            const Color(0xFF991B1B),
            const Color(0xFFFEE2E2),
          ),
        if (hasMaintenance)
          _badge(
            '整備中 (${item.countMaintenance})',
            const Color(0xFF1D4ED8),
            const Color(0xFFDBEAFE),
          ),
        if (hasStorage)
          _badge(
            '在庫 (${item.countStorage})',
            const Color(0xFF9A3412),
            const Color(0xFFFFEDD5),
          ),
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
