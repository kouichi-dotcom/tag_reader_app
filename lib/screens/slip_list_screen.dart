import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../mocks/mock_data.dart';
import '../models/reception_slip.dart';
import '../models/slip_list_filter.dart';
import '../models/reception_detail_item.dart';
import '../services/employee_cache.dart';
import '../services/product_cache.dart';
import '../theme/app_design.dart';
import '../widgets/app_notification.dart';
import 'slip_link_screen.dart';

/// 画面 7: 伝票一覧・選択（design/screen7-slip-list-wireframe.html 準拠）
class SlipListScreen extends StatefulWidget {
  const SlipListScreen({
    super.key,
    this.showBackButton = false,
    this.listTitle,
    this.filter,
  });

  final bool showBackButton;
  /// 画面上部のタイトル。省略時は「伝票一覧・選択」
  final String? listTitle;
  /// 取得条件。省略時は全伝票（SlipListFilter.all）
  final SlipListFilter? filter;

  @override
  State<SlipListScreen> createState() => _SlipListScreenState();
}

class _SlipListScreenState extends State<SlipListScreen> {
  bool _fetching = false;
  /// 受付台帳APIから取得した伝票（受付日時の新しい順で最大10件）
  List<ReceptionSlip> _displaySlips = [];
  final Set<String> _linkedSlipIds = {};
  final Map<String, List<MockLinkProduct>> _linkedProductsBySlipId = {};
  final Set<String> _selectedSlipIdsForSend = {};

  void _toggleSlipForSend(String slipId) {
    setState(() {
      if (_selectedSlipIdsForSend.contains(slipId)) {
        _selectedSlipIdsForSend.remove(slipId);
      } else {
        _selectedSlipIdsForSend.add(slipId);
      }
    });
  }

  void _sendSelectedSlips() {
    if (_selectedSlipIdsForSend.isEmpty) return;
    showAppNotification(context, '選択伝票送信は未実装です。');
  }

  Future<void> _fetchSlips() async {
    setState(() => _fetching = true);
    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final filter = widget.filter ?? SlipListFilter.all;
      final slips = await api.fetchReceptionSlips(filter: filter);
      if (!mounted) return;
      
      if (slips.isEmpty) {
        setState(() {
          _fetching = false;
          _displaySlips = [];
        });
        showAppNotification(context, '伝票が見つかりませんでした。\n（受付台帳にデータがありません）');
        return;
      }
      
      // API側で既に受付日時の新しい順でソート済み（TOP 10）なので、そのまま使用
      setState(() {
        _fetching = false;
        _displaySlips = slips;
      });
      // 担当者名が無い伝票は EmployeeCache で解決（キャッシュ or オンデマンド API）
      for (final s in slips) {
        if (s.handlerCode != null &&
            s.handlerCode!.trim().isNotEmpty &&
            (s.handlerName == null || s.handlerName!.trim().isEmpty)) {
          EmployeeCache.instance.resolveName(api, s.handlerCode!).then((_) {
            if (mounted) setState(() {});
          });
        }
      }
      // 商品名が空の明細は ProductCache で解決（オンデマンド）
      for (final s in slips) {
        for (final d in s.details) {
          if ((d.productName.isEmpty || d.productName.trim().isEmpty) &&
              d.productCode != null &&
              ProductCache.instance.getNameFromMemory(d.productCode.toString()) == null) {
            ProductCache.instance.resolveName(api, d.productCode!.toString()).then((_) {
              if (mounted) setState(() {});
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _fetching = false);
      showAppNotification(context, '伝票取得エラー: $e\n\nAPI URL: $kApiBaseUrl\n\nAPIサーバーが起動しているか確認してください。');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSlips());
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
                _SlipNavBar(
                  title: widget.listTitle ?? '伝票一覧・選択',
                  showBackButton: widget.showBackButton,
                  onBack: () => Navigator.of(context).pop(),
                ),
                // 一覧ヘッダー
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppDesign.navBarBackground,
                  child: const Text(
                    '伝票一覧（右クリック・長押し: 詳細 / ダブルタップ: 送信選択）',
                    style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                ),
                // 伝票一覧（プルで更新）
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await _fetchSlips();
                    },
                    child: _displaySlips.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: 300,
                              child: Center(
                                child: Text(
                                  _fetching ? '取得中...' : '下に引っ張って更新',
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _displaySlips.length,
                            itemBuilder: (context, index) {
                              final slip = _displaySlips[index];
                              final isSelectedForSend = _selectedSlipIdsForSend.contains(slip.receptionNo);
                              final isLinked = _linkedSlipIds.contains(slip.receptionNo);
                              return _SlipRow(
                                slip: slip,
                                handlerDisplay: _resolvedHandlerDisplay(slip),
                                getDetailDisplayName: _detailProductDisplay,
                                isSelectedForSend: isSelectedForSend,
                                isLinked: isLinked,
                                onOpenDetail: () => _showSlipDetail(slip),
                                onToggleSend: () => _toggleSlipForSend(slip.receptionNo),
                              );
                            },
                          ),
                  ),
                ),
                // 選択伝票送信ボタン
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F8F8),
                    border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedSlipIdsForSend.isEmpty ? null : _sendSelectedSlips,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesign.sendButton,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppDesign.disabledButton,
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(
                          _selectedSlipIdsForSend.isEmpty
                              ? '選択伝票送信（未実装・ダブルタップで選択）'
                              : '選択伝票送信（未実装・${_selectedSlipIdsForSend.length}件）',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  /// 明細の商品名表示：API の productName、空なら ProductCache、それも無ければ「商品コード: X」／「--」
  String _detailProductDisplay(ReceptionDetailItem d) {
    if (d.productName.trim().isNotEmpty) return d.productName;
    final code = d.productCode?.toString() ?? '';
    return ProductCache.instance.getNameFromMemory(code) ??
        (d.productCode != null ? '商品コード: ${d.productCode}' : '--');
  }

  /// 担当者表示：APIの handlerName または EmployeeCache、なければ「コード: X」／「--」
  String _resolvedHandlerDisplay(ReceptionSlip slip) {
    if (slip.handlerName != null && slip.handlerName!.trim().isNotEmpty) return slip.handlerName!;
    final code = slip.handlerCode?.trim();
    if (code != null && code.isNotEmpty) {
      final name = EmployeeCache.instance.getNameFromMemory(code);
      if (name != null) return name;
    }
    return slip.handlerDisplay;
  }

  void _showSlipDetail(ReceptionSlip slip) async {
    if (slip.handlerCode != null &&
        slip.handlerCode!.trim().isNotEmpty &&
        (slip.handlerName == null || slip.handlerName!.trim().isEmpty)) {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      await EmployeeCache.instance.resolveName(api, slip.handlerCode!);
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppDesign.deviceWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('← 閉じる', style: TextStyle(color: AppDesign.primaryLink, fontSize: 16)),
                        ),
                        const Expanded(
                          child: Text(
                            '伝票詳細',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 80),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DetailRow(label: '伝票番号', value: slip.receptionNo),
                          _DetailRow(label: '担当者', value: _resolvedHandlerDisplay(slip)),
                          // 紐付けた会社名（顧客台帳）・現場名（現場台帳）
                          _DetailRow(label: '会社名', value: slip.customerName),
                          if (slip.customerNameOther != null && slip.customerNameOther!.trim().isNotEmpty)
                            _DetailRow(label: '会社名その他', value: slip.customerNameOther!),
                          _DetailRow(label: '現場名', value: slip.siteName),
                          if (slip.siteNameOther != null && slip.siteNameOther!.trim().isNotEmpty)
                            _DetailRow(label: '現場名その他', value: slip.siteNameOther!),
                          _DetailRow(label: '用件', value: slip.subject),
                          // 期日・期限：左に項目名、右に 期日：期限：期限２ を繋げて表示
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text('期日・期限', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                                ),
                                Expanded(
                                  child: Text(
                                    [
                                      slip.dueDate != null ? slip.dueDate!.toString().split(' ')[0] : '--',
                                      (slip.deadlineName == null || slip.deadlineName!.trim().isEmpty) ? '--' : slip.deadlineName!,
                                      (slip.deadline2 == null || slip.deadline2!.trim().isEmpty) ? '--' : slip.deadline2!,
                                    ].join('：'),
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _DetailRow(label: 'メモ', value: slip.memo ?? ''),
                          // 商品とその台数：商品ごとに改行して ・商品名（台数）
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text('商品とその台数', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                                ),
                                Expanded(
                                  child: slip.details.isEmpty
                                      ? const Text('--', style: TextStyle(fontSize: 14, color: Colors.black))
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: slip.details
                                              .map((d) => Text(
                                                    '・${_detailProductDisplay(d)}（${d.quantity != null ? d.quantity!.toInt() : '--'}）',
                                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                                  ))
                                              .toList(),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          if (_linkedProductsBySlipId.containsKey(slip.receptionNo) && _linkedProductsBySlipId[slip.receptionNo]!.isNotEmpty)
                            _DetailRow(
                              label: '紐付けた商品',
                              value: _linkedProductsBySlipId[slip.receptionNo]!
                                  .map((p) => '${p.name}（${p.code}）')
                                  .join('、'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              final result = await Navigator.push<List<MockLinkProduct>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SlipLinkScreen(
                                    slip: slip,
                                    initialLinkedProducts: _linkedProductsBySlipId[slip.receptionNo],
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() {
                                  _linkedSlipIds.add(slip.receptionNo);
                                  _linkedProductsBySlipId[slip.receptionNo] = result;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppDesign.selectedBorder,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text('この伝票を選択', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF333333),
                              side: const BorderSide(color: AppDesign.navBarBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('戻る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlipNavBar extends StatelessWidget {
  const _SlipNavBar({
    required this.title,
    required this.showBackButton,
    required this.onBack,
  });

  final String title;
  final bool showBackButton;
  final VoidCallback onBack;

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
        child: Row(
          children: [
            if (showBackButton)
              TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: AppDesign.primaryLink,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('← メイン', style: TextStyle(fontSize: 16)),
              )
            else
              const SizedBox(width: 52),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 52),
          ],
        ),
      ),
    );
  }
}

class _SlipRow extends StatelessWidget {
  const _SlipRow({
    required this.slip,
    required this.handlerDisplay,
    this.getDetailDisplayName,
    required this.isSelectedForSend,
    required this.isLinked,
    required this.onOpenDetail,
    required this.onToggleSend,
  });

  final ReceptionSlip slip;
  /// 担当者表示文字列（担当者名 or コード: X or --）
  final String handlerDisplay;
  /// 明細の商品名表示（キャッシュ補完用）。null のときは d.productName を使用
  final String Function(ReceptionDetailItem)? getDetailDisplayName;
  final bool isSelectedForSend;
  final bool isLinked;
  final VoidCallback onOpenDetail;
  final VoidCallback onToggleSend;

  /// 一覧用：項目名（左）と内容（右）を横並び。内容が空は「--」
  Widget _listRow(String label, String value) {
    final displayValue = value.trim().isEmpty ? '--' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
          ),
          Expanded(
            child: Text(displayValue, style: const TextStyle(fontSize: 13, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelectedForSend ? AppDesign.selectedBackground : null,
      child: GestureDetector(
        onSecondaryTap: onOpenDetail,
        onLongPress: onOpenDetail,
        onDoubleTap: onToggleSend,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelectedForSend ? AppDesign.selectedBorder : Colors.transparent,
                width: 4,
              ),
              bottom: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _listRow('担当者', handlerDisplay),
              // 紐付けた会社名（顧客台帳）・現場名（現場台帳）
              _listRow('会社名', slip.customerName),
              if (slip.customerNameOther != null && slip.customerNameOther!.trim().isNotEmpty)
                _listRow('会社名その他', slip.customerNameOther!),
              _listRow('現場名', slip.siteName),
              if (slip.siteNameOther != null && slip.siteNameOther!.trim().isNotEmpty)
                _listRow('現場名その他', slip.siteNameOther!),
              _listRow('用件', slip.subject),
              // 商品名・台数：詳細と同じく ・商品名（台数）で改行
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 100,
                      child: Text('商品名・台数', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                    ),
                    Expanded(
                      child: slip.details.isEmpty
                          ? const Text('--', style: TextStyle(fontSize: 13, color: Colors.black))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: slip.details
                                  .map((d) => Text(
                                        '・${getDetailDisplayName != null ? getDetailDisplayName!(d) : d.productName}（${d.quantity != null ? d.quantity!.toInt() : '--'}）',
                                        style: const TextStyle(fontSize: 13, color: Colors.black),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
              if (isLinked)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '紐付け済',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 項目名（左）と内容（右）を横並びで表示。内容が空の場合は「--」
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '--' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
          ),
          Expanded(
            child: Text(displayValue, style: const TextStyle(fontSize: 14, color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
