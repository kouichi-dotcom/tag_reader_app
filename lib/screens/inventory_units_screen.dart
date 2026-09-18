import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/inventory_item.dart';
import '../models/inventory_unit_row.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';

/// 在庫確認: 商品詳細（料金・ステータス集計・メーカー別内訳）
class InventoryUnitsScreen extends StatefulWidget {
  const InventoryUnitsScreen({
    super.key,
    required this.productCode,
    required this.productName,
    required this.item,
  });

  final int productCode;
  final String productName;
  final InventoryItem item;

  @override
  State<InventoryUnitsScreen> createState() => _InventoryUnitsScreenState();
}

class _ManufacturerStatusCounts {
  _ManufacturerStatusCounts(this.name);

  final String name;
  int ok = 0;
  int cleaning = 0;
  int maintenance = 0;
  int storage = 0;

  void add(String? statusKey) {
    switch (statusKey) {
      case 'ok':
        ok++;
      case 'cleaning':
        cleaning++;
      case 'maintenance':
        maintenance++;
      case 'storage':
        storage++;
    }
  }
}

class _InventoryUnitsScreenState extends State<InventoryUnitsScreen> {
  List<_ManufacturerStatusCounts> _byManufacturer = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final data = await api.fetchInventoryUnits(widget.productCode);
      if (!mounted) return;
      setState(() {
        _byManufacturer = _groupByManufacturer(
          data.where((r) => InventoryUnitRow.isAllowedTagMode2ForInventory(r.tagMode2)).toList(),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _byManufacturer = [];
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  static List<_ManufacturerStatusCounts> _groupByManufacturer(List<InventoryUnitRow> rows) {
    final map = <String, _ManufacturerStatusCounts>{};
    for (final r in rows) {
      final key = r.manufacturer.trim().isEmpty ? '（メーカー未設定）' : r.manufacturer.trim();
      map.putIfAbsent(key, () => _ManufacturerStatusCounts(key));
      map[key]!.add(InventoryUnitRow.inventoryStatusKey(r.tagMode2));
    }
    final list = map.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
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
                  title: widget.productName,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _headerCard(),
          const SizedBox(height: 12),
          if (_byManufacturer.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'メーカー別データがありません',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ),
            )
          else
            ..._byManufacturer.map(_manufacturerCard),
        ],
      ),
    );
  }

  Widget _headerCard() {
    final item = widget.item;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasPricing(item)) ...[
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (item.baseFee != null && item.baseFee! > 0)
                    Text(
                      '基本料：${_commaInt(item.baseFee!)}円',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  if (item.dailyPrice != null && item.dailyPrice! > 0)
                    Text(
                      '日単価：${_commaInt(item.dailyPrice!)}円',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  if (item.monthlyPrice != null && item.monthlyPrice! > 0)
                    Text(
                      '月単価：${_commaInt(item.monthlyPrice!)}円',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              _statusSummaryLine(
                ok: item.countOk,
                cleaning: item.countCleaning,
                maintenance: item.countMaintenance,
                storage: item.countStorage,
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _manufacturerCard(_ManufacturerStatusCounts m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: m.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                TextSpan(
                  text: '　${_statusSummaryLine(ok: m.ok, cleaning: m.cleaning, maintenance: m.maintenance, storage: m.storage)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _hasPricing(InventoryItem item) {
    return (item.baseFee != null && item.baseFee! > 0) ||
        (item.dailyPrice != null && item.dailyPrice! > 0) ||
        (item.monthlyPrice != null && item.monthlyPrice! > 0);
  }

  static String _statusSummaryLine({
    required int ok,
    required int cleaning,
    required int maintenance,
    required int storage,
  }) {
    return 'OK:${ok}台　清掃中:${cleaning}台　整備中:${maintenance}台　在庫:${storage}台';
  }

  String _commaInt(double v) {
    final s = v.round().toString();
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }
}
