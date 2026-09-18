import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import 'tag_id_product_link_screen.dart';
import 'tag_id_reset_screen.dart';

/// 設定 > タグ設定（タグ関連機能への入口）
class TagSettingsScreen extends StatelessWidget {
  const TagSettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

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
                  showBackButton: showBackButton,
                  title: 'タグ設定',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.qr_code_2, color: Color(0xFFE65100)),
                        title: const Text('タグID再設定'),
                        subtitle: const Text('ICタグ本体の EPC を書き換える'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const TagIdResetScreen(showBackButton: true),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.link, color: Color(0xFF00897B)),
                        title: const Text('タグID×商品コード×番号　設定'),
                        subtitle: const Text('未登録タグの新規登録のみ（変更はPCのレンタル商品管理）'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const TagIdProductLinkScreen(showBackButton: true),
                            ),
                          );
                        },
                      ),
                    ],
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
