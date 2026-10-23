import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import '../widgets/zaicon_inventory_body.dart';

/// 在庫確認。タブのルートでは戻るを出さず、商品一覧は従来どおりこの画面へ戻る。
class ZaiconMainShell extends StatelessWidget {
  const ZaiconMainShell({super.key, this.showBackButton = true});

  final bool showBackButton;

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
                if (showBackButton)
                  MainFlowNavBar(
                    showBackButton: true,
                    title: '在庫確認',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                const Expanded(child: ZaiconInventoryBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
