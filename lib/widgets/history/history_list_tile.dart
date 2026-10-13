import 'package:flutter/material.dart';

import '../../models/operation_history.dart';
import '../../theme/app_design.dart';

/// operation_type に応じて履歴行の表示を切り替える。
class HistoryListTile extends StatelessWidget {
  const HistoryListTile({
    super.key,
    required this.history,
    this.onTap,
  });

  final OperationHistory history;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppDesign.navBarBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderRow(history: history),
            const SizedBox(height: 6),
            ..._bodyWidgets(),
            if (history.errorMessage != null &&
                history.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                history.errorMessage!,
                style: TextStyle(
                  fontSize: 13,
                  color: history.resultStatus == HistoryResultStatus.success
                      ? const Color(0xFFE65100)
                      : const Color(0xFFC62828),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _bodyWidgets() {
    switch (history.operationType) {
      case OperationType.statusUpdate:
        return history.items
            .map((item) => _StatusUpdateItemRow(item: item))
            .toList();
      case OperationType.slipLink:
        return [
          Text(
            '${history.companyName ?? '--'}　${history.siteName ?? '--'}',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          if ((history.subject ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                history.linkMode != null && history.linkMode!.isNotEmpty
                    ? '${history.subject}（${history.linkMode}）'
                    : history.subject!,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          ...history.items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${item.productCode ?? '--'}　'
                  '${item.number ?? '--'}　'
                  '${item.statusAfter ?? '--'}',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              )),
        ];
      case OperationType.tagRegistration:
        return history.items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '商品 ${item.productCode ?? '--'}　'
              '番号 ${item.number ?? '--'}\n'
              'EPC ${item.epc ?? '--'}\n'
              'ステータス ${item.statusAfter ?? '登録'}',
              style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black87),
            ),
          );
        }).toList();
      case OperationType.epcUpdate:
        return history.items.map((item) {
          final before = item.epcBefore ?? '--';
          final after = item.epcAfter ?? item.epc ?? '--';
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$before → $after　${item.resultStatus.displayLabel}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          );
        }).toList();
      case OperationType.productCodeUpdate:
        return [
          Text(
            history.operationType.displayName,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          ...history.items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${item.epc ?? item.productCode ?? '--'}　${item.resultStatus.displayLabel}',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              )),
        ];
    }
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.history});

  final OperationHistory history;

  @override
  Widget build(BuildContext context) {
    final local = history.createdAtLocal;
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final resultColor = switch (history.resultStatus) {
      HistoryResultStatus.success => AppDesign.statusOk,
      HistoryResultStatus.failed => const Color(0xFFC62828),
      HistoryResultStatus.partialFailure => const Color(0xFFE65100),
    };

    return Row(
      children: [
        Expanded(
          child: Text(
            '$mm/$dd $hh:$min　${history.operationType.displayName}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        Text(
          history.resultStatus.displayLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: resultColor,
          ),
        ),
      ],
    );
  }
}

class _StatusUpdateItemRow extends StatelessWidget {
  const _StatusUpdateItemRow({required this.item});

  final OperationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final itemColor = switch (item.resultStatus) {
      ItemResultStatus.success => AppDesign.statusOk,
      ItemResultStatus.failed => const Color(0xFFC62828),
      ItemResultStatus.notSent => Colors.black45,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '${item.productCode ?? '--'}　'
              '${item.statusBefore ?? '--'} → ${item.statusAfter ?? '--'}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Text(
            item.resultStatus.displayLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: itemColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 履歴詳細（タップ時）
Future<void> showHistoryDetailSheet(
  BuildContext context,
  OperationHistory history,
) {
  final local = history.createdAtLocal;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  history.operationType.displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('結果: ${history.resultStatus.displayLabel}'),
                Text('日時: ${local.year}/'
                    '${local.month.toString().padLeft(2, '0')}/'
                    '${local.day.toString().padLeft(2, '0')} '
                    '${local.hour.toString().padLeft(2, '0')}:'
                    '${local.minute.toString().padLeft(2, '0')}:'
                    '${local.second.toString().padLeft(2, '0')}'),
                if (history.environment != null)
                  Text('環境: ${history.environment}'),
                if (history.httpStatus != null)
                  Text('HTTP: ${history.httpStatus}'),
                if (history.errorMessage != null)
                  Text('エラー: ${history.errorMessage}'),
                if (history.userId != null || history.userName != null)
                  Text(
                    '担当者: ${history.userName ?? '--'}'
                    '${history.userId != null ? '（${history.userId}）' : ''}',
                  ),
                if (history.receptionNo != null)
                  Text('受付番号: ${history.receptionNo}'),
                const SizedBox(height: 12),
                const Text(
                  '明細',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...history.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _detailItemText(history.operationType, item),
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _detailItemText(OperationType type, OperationHistoryItem item) {
  final resultLine =
      '結果: ${item.resultStatus.displayLabel}'
      '${item.httpStatus != null ? ' (HTTP ${item.httpStatus})' : ''}'
      '${item.errorMessage != null ? '\nエラー: ${item.errorMessage}' : ''}';

  switch (type) {
    case OperationType.epcUpdate:
      return '変更前EPC: ${item.epcBefore ?? '--'}\n'
          '変更後EPC: ${item.epcAfter ?? item.epc ?? '--'}\n'
          '$resultLine';
    case OperationType.tagRegistration:
      return 'EPC: ${item.epc ?? '--'}\n'
          '商品名: ${item.productName ?? '--'}\n'
          '商品: ${item.productCode ?? '--'} / ${item.number ?? '--'}\n'
          '$resultLine';
    case OperationType.statusUpdate:
    case OperationType.slipLink:
    case OperationType.productCodeUpdate:
      return '商品名: ${item.productName ?? '--'}\n'
          '商品: ${item.productCode ?? '--'} / ${item.number ?? '--'}\n'
          '$resultLine';
  }
}
