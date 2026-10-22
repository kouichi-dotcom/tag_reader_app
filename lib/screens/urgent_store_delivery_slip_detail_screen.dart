import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../models/reception_detail_item.dart';
import '../models/reception_slip.dart';
import '../models/urgent_store_delivery.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import 'urgent_store_delivery_blocked_page.dart';
import 'urgent_store_delivery_confirm_screen.dart';

/// 急ぎ来店納品 伝票詳細（現場名・全商品）。戻る／確認へ進む。
class UrgentStoreDeliverySlipDetailScreen extends StatelessWidget {
  const UrgentStoreDeliverySlipDetailScreen({
    super.key,
    required this.slip,
    required this.selectedItems,
  });

  final ReceptionSlip slip;
  final List<UrgentReadItem> selectedItems;

  String _formatDueDate(DateTime? d) {
    if (d == null) return '--';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  String _productLine(ReceptionDetailItem d) {
    final name = d.productName.trim().isEmpty ? '--' : d.productName.trim();
    final qty = d.quantity != null ? d.quantity!.toInt().toString() : '--';
    return '$name　$qty';
  }

  void _goConfirm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UrgentStoreDeliveryConfirmScreen(
          slip: slip,
          items: selectedItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enableUrgentStoreDelivery) {
      return const UrgentStoreDeliveryBlockedPage();
    }
    final deadline = slip.deadlineName?.trim().isNotEmpty == true
        ? slip.deadlineName!.trim()
        : '--';
    final deadline2 = slip.deadline2?.trim().isNotEmpty == true
        ? slip.deadline2!.trim()
        : '--';
    final company = slip.listCustomerName.trim().isEmpty
        ? '--'
        : slip.listCustomerName;
    final site =
        slip.listSiteName.trim().isEmpty ? '--' : slip.listSiteName;

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
                  title: '伝票詳細',
                  showBackButton: true,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      _labelValue('会社名', company),
                      _labelValue('現場名', site),
                      _labelValue('期日', _formatDueDate(slip.dueDate)),
                      _labelValue('期限', deadline),
                      _labelValue('期限２', deadline2),
                      const SizedBox(height: 12),
                      const Text(
                        '商品',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (slip.details.isEmpty)
                        const Text(
                          '商品なし',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF888888),
                          ),
                        )
                      else
                        ...slip.details.map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              _productLine(d),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F8F8),
                    border: Border(
                      top: BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Color(0xFFCCCCCC)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '戻る',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _goConfirm(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppDesign.primaryButton,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '確認へ進む',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
