import 'package:flutter/material.dart';

import '../theme/app_design.dart';

/// タグリーダー接続画面などと同じトップバー（左: 戻るリンク、中央: タイトル）
class MainFlowNavBar extends StatelessWidget {
  const MainFlowNavBar({
    super.key,
    required this.showBackButton,
    required this.title,
    required this.onBack,
    this.backLabel = '←',
    this.titleMaxLines = 1,
    this.titleStyle,
  });

  final bool showBackButton;
  final String title;
  final VoidCallback onBack;

  /// 左の戻りリンク文言（デフォルトは大きな矢印のみ）
  final String backLabel;

  final int titleMaxLines;
  final TextStyle? titleStyle;

  /// 戻るボタン表示時、タイトル左端の余白（ボタンと重ならない幅）
  static const double _titleLeftInsetWithBack = 48;

  static const TextStyle _defaultTitleStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppDesign.navBarBackground,
        border: Border(bottom: BorderSide(color: AppDesign.navBarBorder, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 40,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                left: showBackButton ? _titleLeftInsetWithBack - 16 : 0,
                right: 0,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    title,
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle ?? _defaultTitleStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (showBackButton)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: TextButton(
                    onPressed: onBack,
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesign.primaryLink,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      backLabel,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
