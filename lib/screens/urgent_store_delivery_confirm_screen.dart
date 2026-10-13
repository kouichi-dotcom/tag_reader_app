import 'package:flutter/material.dart';

import '../models/urgent_store_delivery.dart';
import '../services/urgent_store_delivery_session.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import '../widgets/urgent_read_item_tile.dart';

/// 急ぎ来店納品 最終確認（商品＋伝票）。送信は UI 仮実装のみ。
class UrgentStoreDeliveryConfirmScreen extends StatefulWidget {
  const UrgentStoreDeliveryConfirmScreen({
    super.key,
    required this.slip,
    required this.items,
  });

  final UrgentSlipCandidate slip;
  final List<UrgentReadItem> items;

  @override
  State<UrgentStoreDeliveryConfirmScreen> createState() =>
      _UrgentStoreDeliveryConfirmScreenState();
}

class _UrgentStoreDeliveryConfirmScreenState
    extends State<UrgentStoreDeliveryConfirmScreen> {
  bool _sending = false;

  Future<void> _onSend() async {
    if (_sending) return;
    setState(() => _sending = true);

    // 本実装時はここで API 送信。現状は UI 確認のみ。
    await Future<void>.delayed(const Duration(milliseconds: 200));

    UrgentStoreDeliverySession.instance
        .removeByIds(widget.items.map((e) => e.id));

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('送信しました'),
        content: Text(
          '選択した${widget.items.length}点を伝票（納品No. ${widget.slip.deliveryNo}）へ送信しました。\n'
          '（仮実装：実際の登録はまだ行いません）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    // 急ぎ来店納品の統合画面まで戻す
    Navigator.of(context).popUntil((route) {
      return route.isFirst ||
          (route.settings.name == UrgentStoreDeliveryRoutes.main);
    });
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
                  title: '急ぎ来店納品 確認',
                  showBackButton: true,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: const Text(
                          '選択した伝票',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
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
                              '納品No. ${widget.slip.deliveryNo}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.slip.companyName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.slip.siteName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          '選択した商品　${widget.items.length}点',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                      ...widget.items.map(
                        (item) => UrgentReadItemTile(
                          item: item,
                          showCheckbox: false,
                          showReadTime: false,
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
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _sending ? null : () => Navigator.of(context).pop(),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _sending ? null : _onSend,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppDesign.statusOk,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppDesign.disabledButton,
                              disabledForegroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _sending ? '送信中…' : '送信',
                              style: const TextStyle(
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
}

/// ルート名定数（送信後に統合画面へ戻すため）
class UrgentStoreDeliveryRoutes {
  UrgentStoreDeliveryRoutes._();
  static const String main = 'urgent_store_delivery_main';
}
