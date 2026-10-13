import 'package:flutter/material.dart';

import '../mocks/urgent_store_delivery_mock.dart';
import '../models/urgent_store_delivery.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import 'urgent_store_delivery_confirm_screen.dart';

/// 急ぎ来店納品 伝票選択（UI のみ・ダミー伝票）
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
  String? _selectedSlipId;

  UrgentSlipCandidate? get _selectedSlip {
    final id = _selectedSlipId;
    if (id == null) return null;
    for (final s in mockUrgentSlipCandidates) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _goConfirm() {
    final slip = _selectedSlip;
    if (slip == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UrgentStoreDeliveryConfirmScreen(
          slip: slip,
          items: widget.selectedItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _selectedSlip != null;

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
                    '選択中の商品 ${widget.selectedItems.length}点に紐付ける伝票を選んでください',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: mockUrgentSlipCandidates.length,
                    itemBuilder: (context, index) {
                      final slip = mockUrgentSlipCandidates[index];
                      final selected = slip.id == _selectedSlipId;
                      return Material(
                        color: selected
                            ? AppDesign.selectedBackground
                            : Colors.white,
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedSlipId = slip.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: const BorderSide(
                                  color: AppDesign.navBarBorder,
                                ),
                                left: BorderSide(
                                  color: selected
                                      ? AppDesign.selectedBorder
                                      : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 22,
                                    color: selected
                                        ? AppDesign.primaryButton
                                        : const Color(0xFF999999),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '納品No. ${slip.deliveryNo}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        slip.companyName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        slip.siteName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF555555),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
                      child: ElevatedButton(
                        onPressed: canProceed ? _goConfirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canProceed
                              ? AppDesign.primaryButton
                              : AppDesign.disabledButton,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppDesign.disabledButton,
                          disabledForegroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '確認へ進む',
                          style: TextStyle(
                            fontSize: 17,
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
}
