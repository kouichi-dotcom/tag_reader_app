import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/reception_detail_item.dart';
import '../models/reception_slip.dart';
import '../models/slip_list_filter.dart';
import '../models/urgent_store_delivery.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import 'urgent_store_delivery_slip_detail_screen.dart';

/// 急ぎ来店納品 伝票選択（来店(納品)・期日今日・未確認）
class UrgentStoreDeliverySlipSelectScreen extends StatefulWidget {
  const UrgentStoreDeliverySlipSelectScreen({
    super.key,
    required this.selectedItems,
  });

  final List<UrgentReadItem> selectedItems;

  @override
  State<UrgentStoreDeliverySlipSelectScreen> createState() =>
      _UrgentStoreDeliverySlipSelectScreenState();
}

class _UrgentStoreDeliverySlipSelectScreenState
    extends State<UrgentStoreDeliverySlipSelectScreen> {
  List<ReceptionSlip> _slips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _todayLocal {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (!kUseApi) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'API が無効のため伝票を取得できません。';
        _slips = [];
      });
      return;
    }

    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final slips = await api.fetchReceptionSlips(
        filter: SlipListFilter.urgentVisitDelivery.copyWith(date: _todayLocal),
      );
      if (!mounted) return;
      setState(() {
        _slips = slips;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '伝票の取得に失敗しました。\n$e';
        _slips = [];
      });
    }
  }

  void _openDetail(ReceptionSlip slip) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UrgentStoreDeliverySlipDetailScreen(
          slip: slip,
          selectedItems: widget.selectedItems,
        ),
      ),
    );
  }

  String _formatDueDate(DateTime? d) {
    if (d == null) return '--';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  String _productLine(ReceptionDetailItem d) {
    final name = d.productName.trim().isEmpty ? '--' : d.productName.trim();
    final qty = d.quantity != null ? d.quantity!.toInt().toString() : '--';
    return '$name　$qty';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.scaffoldBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDesign.deviceWidth),
          child: Material(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MainFlowNavBar(
                  title: '伝票を選択',
                  showBackButton: true,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  color: AppDesign.controlBarBackground,
                  child: Text(
                    '選択中の商品 ${widget.selectedItems.length}点　／　来店(納品)・期日今日',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                child: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      );
    }
    if (_slips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '該当する伝票はありません',
              style: TextStyle(fontSize: 15, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _slips.length,
        itemBuilder: (context, index) {
          final slip = _slips[index];
          final deadline = slip.deadlineName?.trim().isNotEmpty == true
              ? slip.deadlineName!.trim()
              : '--';
          final deadline2 = slip.deadline2?.trim().isNotEmpty == true
              ? slip.deadline2!.trim()
              : '--';

          return Material(
            color: Colors.white,
            child: InkWell(
              onTap: () => _openDetail(slip),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppDesign.navBarBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slip.listCustomerName.trim().isEmpty
                          ? '--'
                          : slip.listCustomerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '期日：${_formatDueDate(slip.dueDate)}　'
                      '期限：$deadline　'
                      '期限２：$deadline2',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF555555),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (slip.details.isEmpty)
                      const Text(
                        '商品なし',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF888888),
                        ),
                      )
                    else
                      ...slip.details.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            _productLine(d),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
