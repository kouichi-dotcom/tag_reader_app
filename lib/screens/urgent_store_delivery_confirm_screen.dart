import 'package:flutter/material.dart';

import '../models/reception_detail_item.dart';
import '../models/reception_slip.dart';
import '../models/urgent_store_delivery.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import '../widgets/urgent_read_item_tile.dart';

/// 急ぎ来店納品 過不足確認（伝票明細 × 読取商品）。
/// 突き合わせロジック・送信は今後実装。現状は双方の一覧表示のみ。
class UrgentStoreDeliveryConfirmScreen extends StatelessWidget {
  const UrgentStoreDeliveryConfirmScreen({
    super.key,
    required this.slip,
    required this.items,
  });

  final ReceptionSlip slip;
  final List<UrgentReadItem> items;

  String _productLine(ReceptionDetailItem d) {
    final name = d.productName.trim().isEmpty ? '--' : d.productName.trim();
    final qty = d.quantity != null ? d.quantity!.toInt().toString() : '--';
    return '$name　$qty';
  }

  @override
  Widget build(BuildContext context) {
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
                  title: '過不足確認',
                  showBackButton: true,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        color: const Color(0xFFFFF8E1),
                        child: const Text(
                          '伝票の商品と読み取った商品の突き合わせは今後実装します。',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5D4037),
                            height: 1.4,
                          ),
                        ),
                      ),
                      _sectionTitle('伝票'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppDesign.navBarBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppDesign.navBarBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                company,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                site,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF555555),
                                ),
                              ),
                              const SizedBox(height: 10),
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
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      _productLine(d),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      _sectionTitle('読み取った商品　${items.length}点'),
                      ...items.map(
                        (item) => UrgentReadItemTile(
                          item: item,
                          showCheckbox: false,
                          showTagId: false,
                          showReadTime: true,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Color(0xFFCCCCCC)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF666666),
        ),
      ),
    );
  }
}

/// ルート名定数（送信後に統合画面へ戻すため）
class UrgentStoreDeliveryRoutes {
  UrgentStoreDeliveryRoutes._();
  static const String main = 'urgent_store_delivery_main';
}
