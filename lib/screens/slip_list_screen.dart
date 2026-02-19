import 'package:flutter/material.dart';

import '../mocks/mock_data.dart';
import '../theme/app_design.dart';
import 'slip_link_screen.dart';

/// 画面 7: 伝票一覧・選択（design/screen7-slip-list-wireframe.html 準拠）
class SlipListScreen extends StatefulWidget {
  const SlipListScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<SlipListScreen> createState() => _SlipListScreenState();
}

class _SlipListScreenState extends State<SlipListScreen> {
  bool _fetching = false;
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
    final count = _selectedSlipIdsForSend.length;
    setState(() => _selectedSlipIdsForSend.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('伝票を送信しました（${count}件）。')),
    );
  }

  void _fetchSlips() {
    setState(() => _fetching = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _fetching = false);
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
                _SlipNavBar(
                  showBackButton: widget.showBackButton,
                  onBack: () => Navigator.of(context).pop(),
                ),
                // 伝票取得ボタン
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppDesign.controlBarBackground,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _fetching ? null : _fetchSlips,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesign.primaryButton,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('伝票一覧を取得', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                // 一覧ヘッダー
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppDesign.navBarBackground,
                  child: const Text(
                    '伝票一覧（タップ: 詳細 / ダブルタップ: 送信選択）',
                    style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                ),
                // 伝票一覧
                Expanded(
                  child: ListView.builder(
                    itemCount: mockSlips.length,
                    itemBuilder: (context, index) {
                      final slip = mockSlips[index];
                      final isSelectedForSend = _selectedSlipIdsForSend.contains(slip.id);
                      final isLinked = _linkedSlipIds.contains(slip.id);
                      return _SlipRow(
                        slip: slip,
                        isSelectedForSend: isSelectedForSend,
                        isLinked: isLinked,
                        onTap: () => _showSlipDetail(slip),
                        onDoubleTap: () => _toggleSlipForSend(slip.id),
                      );
                    },
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
                              ? '選択伝票送信（ダブルタップで選択）'
                              : '選択伝票送信（${_selectedSlipIdsForSend.length}件）',
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

  void _showSlipDetail(MockSlip slip) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDesign.deviceWidth),
          child: Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  _DetailField(label: '伝票番号', value: slip.no),
                  _DetailField(label: '会社名', value: slip.company),
                  _DetailField(label: '現場', value: slip.site),
                  _DetailField(label: '用件', value: slip.subject),
                  _DetailField(label: '配達商品', value: slip.products),
                  if (_linkedProductsBySlipId.containsKey(slip.id)) ...[
                    _DetailField(
                      label: '紐付けた商品',
                      value: _linkedProductsBySlipId[slip.id]!
                          .map((p) => '${p.name}（${p.code}）')
                          .join('、'),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              final result = await Navigator.of(context).push<List<MockLinkProduct>>(
                                MaterialPageRoute(
                                  builder: (context) => SlipLinkScreen(
                                    slip: slip,
                                    initialLinkedProducts: _linkedProductsBySlipId[slip.id],
                                  ),
                                ),
                              );
                              if (mounted && result != null) {
                                setState(() {
                                  _linkedSlipIds.add(slip.id);
                                  _linkedProductsBySlipId[slip.id] = result;
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
  const _SlipNavBar({required this.showBackButton, required this.onBack});

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
            const Expanded(
              child: Text(
                '伝票一覧・選択',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
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
    required this.isSelectedForSend,
    required this.isLinked,
    required this.onTap,
    required this.onDoubleTap,
  });

  final MockSlip slip;
  final bool isSelectedForSend;
  final bool isLinked;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelectedForSend ? AppDesign.selectedBackground : null,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
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
              Text(
                slip.no,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              const SizedBox(height: 6),
              Text(slip.company, style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
              Text(slip.site, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
              Text(slip.subject, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
              const SizedBox(height: 4),
              Text(slip.products, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
              if (isLinked) ...[
                const SizedBox(height: 4),
                const Text(
                  '紐付け済',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, color: Colors.black)),
        ],
      ),
    );
  }
}
