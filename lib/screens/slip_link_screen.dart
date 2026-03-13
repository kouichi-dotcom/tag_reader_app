import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../mocks/mock_data.dart';
import '../models/reception_slip.dart';
import '../services/employee_cache.dart';
import '../theme/app_design.dart';

/// 伝票・商品紐付け画面（design/screen7 の link-overlay 準拠）
/// 伝票詳細で「この伝票を選択」後に表示
class SlipLinkScreen extends StatefulWidget {
  const SlipLinkScreen({
    super.key,
    required this.slip,
    this.initialLinkedProducts,
  });

  final ReceptionSlip slip;
  /// すでに紐付け済みの商品（再表示時はチェック済みで一覧に表示）
  final List<MockLinkProduct>? initialLinkedProducts;

  @override
  State<SlipLinkScreen> createState() => _SlipLinkScreenState();
}

class _SlipLinkScreenState extends State<SlipLinkScreen> {
  final List<MockLinkProduct> _products = [];
  final Set<String> _selectedIds = {};
  int _readCounter = 0;
  /// 担当者コードから取得した担当者名（伝票に handlerName が無い場合に EmployeeCache で解決）
  String? _resolvedHandlerName;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLinkedProducts;
    if (initial != null && initial.isNotEmpty) {
      _products.addAll(initial);
      _selectedIds.addAll(initial.map((e) => e.id));
    }
    final slip = widget.slip;
    if (slip.handlerCode != null &&
        slip.handlerCode!.trim().isNotEmpty &&
        (slip.handlerName == null || slip.handlerName!.trim().isEmpty)) {
      _resolvedHandlerName = EmployeeCache.instance.getNameFromMemory(slip.handlerCode!);
      if (_resolvedHandlerName == null) {
        final api = ApiClient(baseUrl: kApiBaseUrl);
        EmployeeCache.instance.resolveName(api, slip.handlerCode!).then((name) {
          if (mounted && name != null) setState(() => _resolvedHandlerName = name);
        });
      }
    }
  }

  void _readTags() {
    setState(() {
      // モック: プールから 2〜3 件ずつ追加（重複しないよう id に通番）
      final start = _readCounter % mockLinkProductPool.length;
      final count = 2 + (_readCounter % 2);
      for (var i = 0; i < count; i++) {
        final p = mockLinkProductPool[(start + i) % mockLinkProductPool.length];
        _products.add(MockLinkProduct(
          id: '${p.id}_${_products.length}',
          name: p.name,
          code: p.code,
          status: p.status,
        ));
      }
      _readCounter++;
    });
  }

  void _toggleProduct(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _showConfirm() {
    final selected = _products.where((p) => _selectedIds.contains(p.id)).toList();
    final slip = widget.slip;
    final lines = <String>[
      '伝票: ${slip.receptionNo}',
      '会社名: ${slip.customerName}',
      '',
      ...selected.map((p) => '${p.name}（${p.code}）: ${p.status}'),
    ];
    if (selected.isEmpty) {
      lines.add('選択された商品はありません。');
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDesign.deviceWidth),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '紐付け内容の確認',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lines.join('\n'),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context, selected);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesign.primaryButton,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('伝票一覧に戻る', style: TextStyle(fontSize: 16)),
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

  /// 商品・台数の表示文字列（詳細と同じ形式）
  static String _detailsSummary(ReceptionSlip slip) {
    if (slip.details.isEmpty) return '--';
    return slip.details
        .map((d) => '${d.productName}（${d.quantity != null ? d.quantity!.toInt() : '--'}）')
        .join('・');
  }

  ({Color fg, Color bg}) _statusStyle(String status) {
    switch (status) {
      case 'OK':
        return (fg: AppDesign.statusOk, bg: AppDesign.statusOkBg);
      case '貸出中':
        return (fg: AppDesign.statusLent, bg: AppDesign.statusLentBg);
      case '清掃中':
        return (fg: AppDesign.statusCleaning, bg: AppDesign.statusCleaningBg);
      case '整備中':
        return (fg: AppDesign.statusMaintenance, bg: AppDesign.statusMaintenanceBg);
      case '修理中':
        return (fg: AppDesign.statusRepair, bg: AppDesign.statusRepairBg);
      case '廃棄':
        return (fg: AppDesign.statusDisposed, bg: AppDesign.statusDisposedBg);
      default:
        return (fg: AppDesign.statusUnknown, bg: AppDesign.statusUnknownBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slip = widget.slip;
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
                _LinkNavBar(onBack: () => Navigator.pop(context)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 伝票基本情報
                        _LinkSection(
                          title: '伝票基本情報',
                          children: [
                            _InfoLine(label: '伝票番号', value: slip.receptionNo),
                            _InfoLine(
                              label: '担当者',
                              value: slip.handlerName?.trim().isNotEmpty == true
                                  ? slip.handlerName!
                                  : (_resolvedHandlerName ?? slip.handlerDisplay),
                            ),
                            _InfoLine(label: '会社名', value: slip.customerName),
                            _InfoLine(label: '現場名', value: slip.siteName),
                            _InfoLine(label: '用件', value: slip.subject),
                            _InfoLine(label: '商品・台数', value: _detailsSummary(slip)),
                          ],
                        ),
                        // 読み取りボタン
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _readTags,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppDesign.primaryButton,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: const Text('商品をタグリーダーから読み取り', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        // 商品一覧ヘッダー
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: AppDesign.navBarBackground,
                          child: const Text(
                            '商品一覧（タップで選択）',
                            style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                          ),
                        ),
                        // 商品一覧
                        if (_products.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                '「読み取り」で商品を追加',
                                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final p = _products[index];
                              final selected = _selectedIds.contains(p.id);
                              final style = _statusStyle(p.status);
                              return Material(
                                color: selected ? AppDesign.selectedBackground : null,
                                child: InkWell(
                                  onTap: () => _toggleProduct(p.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: Checkbox(
                                            value: selected,
                                            onChanged: (_) => _toggleProduct(p.id),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black),
                                          ),
                                        ),
                                        Text(
                                          p.code,
                                          style: const TextStyle(fontSize: 14, color: Color(0xFF555555), fontFamily: 'monospace'),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: style.bg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            p.status,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: style.fg),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                // フッター
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
                        onPressed: _showConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesign.statusOk,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text('紐付け完了・確認', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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

class _LinkNavBar extends StatelessWidget {
  const _LinkNavBar({required this.onBack});

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
            TextButton(
              onPressed: onBack,
              style: TextButton.styleFrom(
                foregroundColor: AppDesign.primaryLink,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('← 戻る', style: TextStyle(fontSize: 16)),
            ),
            const Expanded(
              child: Text(
                '伝票・商品紐付け',
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

class _LinkSection extends StatelessWidget {
  const _LinkSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(color: Color(0xFF666666))),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
