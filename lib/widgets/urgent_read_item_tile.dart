import 'package:flutter/material.dart';

import '../models/urgent_store_delivery.dart';
import '../theme/app_design.dart';

/// 急ぎ来店納品の未処理商品 1 行（選択可／確認表示の両用）
class UrgentReadItemTile extends StatelessWidget {
  const UrgentReadItemTile({
    super.key,
    required this.item,
    this.selected,
    this.onToggle,
    this.showCheckbox = false,
    this.showTagId = true,
    this.showReadTime = true,
  });

  final UrgentReadItem item;

  /// null のとき選択 UI なし（確認画面用）
  final bool? selected;
  final VoidCallback? onToggle;
  final bool showCheckbox;
  final bool showTagId;
  final bool showReadTime;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == true;
    final selectable = showCheckbox && onToggle != null;

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppDesign.selectedBackground : Colors.white,
        border: const Border(
          bottom: BorderSide(color: AppDesign.navBarBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCheckbox) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: isSelected,
                  onChanged: selectable ? (_) => onToggle!() : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '商品コード：${item.productCode}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
                const SizedBox(height: 2),
                Text(
                  '番号：${item.number}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
                if (showTagId) ...[
                  const SizedBox(height: 2),
                  Text(
                    'タグID：${item.tagId}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF555555),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (showReadTime) ...[
                  const SizedBox(height: 2),
                  Text(
                    '読取：${item.readTimeLabel}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF555555),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!selectable) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: content,
      ),
    );
  }
}
