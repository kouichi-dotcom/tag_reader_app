import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../mocks/mock_data.dart';
import '../models/inventory_epc.dart';
import '../models/product_by_epc.dart';
import '../models/reception_slip.dart';
import '../models/slip_link_match.dart';
import '../models/slip_tag_link_request.dart';
import '../services/employee_cache.dart';
import '../services/employee_storage.dart';
import '../services/hardware_trigger_handler.dart';
import '../services/hardware_trigger_mode_storage.dart';
import '../services/product_cache.dart';
import '../services/tag_ledger_cache.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';
import '../widgets/app_notification.dart';
import '../widgets/main_flow_nav_bar.dart';
import '../widgets/reader_not_connected_dialog.dart';

/// 伝票・商品紐付け画面（design/screen7 の link-overlay 準拠）
/// 伝票詳細で「この伝票を選択」／交換の「交換納品」「交換返品」後に表示
class SlipLinkScreen extends StatefulWidget {
  const SlipLinkScreen({
    super.key,
    required this.slip,
    this.initialLinkedProducts,
    this.linkMode,
  });

  final ReceptionSlip slip;
  /// すでに紐付け済みの商品（再表示時はチェック済みで一覧に表示）
  final List<MockLinkProduct>? initialLinkedProducts;
  /// 用件「交換」時のモード（交換納品 / 交換返品）。通常用件は null。
  final String? linkMode;

  @override
  State<SlipLinkScreen> createState() => _SlipLinkScreenState();
}

class _SlipLinkScreenState extends State<SlipLinkScreen> {
  static const double _codeColumnWidth = 72;
  static const double _numberColumnWidth = 56;

  final List<MockLinkProduct> _products = [];
  final Set<String> _selectedIds = {};
  int _readCounter = 0;
  /// 担当者コードから取得した担当者名（伝票に handlerName が無い場合に EmployeeCache で解決）
  String? _resolvedHandlerName;

  /// 実機タグ読取中か（Android のみ使用）
  bool _isLinkingReading = false;
  final _reader = TagReaderService.instance;
  StreamSubscription<InventoryEpc>? _linkInvSub;
  HardwareTriggerHandler? _hwTriggerHandler;
  HardwareTriggerMode _hwTriggerMode = HardwareTriggerMode.toggle;
  double _hwTimedSeconds = HardwareTriggerModeStorage.timedSecondsDefault;

  @override
  void dispose() {
    if (_hwTriggerHandler != null) {
      unawaited(_hwTriggerHandler!.cancelSubscriptionOnly());
    }
    _linkInvSub?.cancel();
    _reader.stopInventory();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadHardwareTriggerHints());
    if (_reader.supportsNativeRfid) {
      _hwTriggerHandler = HardwareTriggerHandler(
        onStart: _startLinkingRead,
        onStop: _stopLinkingRead,
        isReading: () => _isLinkingReading,
        mounted: () => mounted,
      );
      unawaited(_hwTriggerHandler!.attach(_reader));
    }
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

  /// モック用: 非 Android で「読み取り」ボタン押下時
  void _readTags() {
    setState(() {
      final start = _readCounter % mockLinkProductPool.length;
      final count = 2 + (_readCounter % 2);
      for (var i = 0; i < count; i++) {
        final p = mockLinkProductPool[(start + i) % mockLinkProductPool.length];
        _products.add(MockLinkProduct(
          id: '${p.id}_${_products.length}',
          name: p.name,
          code: p.code,
          number: p.number,
        ));
      }
      _readCounter++;
    });
  }

  /// 実機読取停止（ボタン・トリガー両方から利用）
  Future<void> _stopLinkingRead() async {
    _hwTriggerHandler?.notifyStoppedByAppButton();
    await _linkInvSub?.cancel();
    _linkInvSub = null;
    await _reader.stopInventory();
    if (mounted) setState(() => _isLinkingReading = false);
  }

  /// 実機読取開始（ボタン・トリガー両方から利用）。Android 以外では何もしない。
  Future<void> _startLinkingRead() async {
    if (_isLinkingReading) return;
    if (!_reader.supportsNativeRfid) return;

    final okPerm = await _reader.requestBluetoothPermissions();
    final okConn = await _reader.isConnected();
    if (!mounted) return;
    if (!okPerm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth権限が必要です。設定から許可してください。')),
      );
      return;
    }
    if (!okConn) {
      await showReaderNotConnectedDialog(context);
      return;
    }

    setState(() => _isLinkingReading = true);
    await _linkInvSub?.cancel();
    _linkInvSub = _reader.inventoryEpcStream.listen((inv) async {
      if (!mounted || !_isLinkingReading) return;
      final epc = inv.epcForLookup;
      if (_products.any((p) => p.id == epc)) return;

      // まずローカル台帳＋商品台帳で照合（APIが使えない開発時も本番同様に表示）
      await TagLedgerCache.instance.init();
      await ProductCache.instance.init();
      final entry = TagLedgerCache.instance.lookup(epc);
      if (entry != null) {
        final name = ProductCache.instance.getNameFromMemory(entry.productCode?.toString() ?? '') ?? '商品不明';
        if (!mounted) return;
        setState(() {
          _products.add(MockLinkProduct(
            id: epc,
            name: name,
            code: entry.productCode?.toString() ?? '--',
            number: entry.number,
          ));
        });
        return;
      }

      // Android では API を呼ばず「商品不明」で追加
      if (!kUseApi) {
        if (!mounted) return;
        setState(() {
          _products.add(MockLinkProduct(id: epc, name: '商品不明', code: '--'));
        });
        return;
      }

      final api = ApiClient(baseUrl: kApiBaseUrl);
      ProductByEpc? p;
      try {
        p = await api.fetchProduct(epc);
      } catch (_) {}
      if (!mounted) return;
      if (p != null) {
        await TagLedgerCache.instance.put(
          epc,
          productCode: p.productCode,
          number: p.number,
        );
      }
      if (!mounted) return;
      final name = (p == null || p.productName.isEmpty) ? '商品不明' : p.productName;
      final code = p?.productCode?.toString() ?? '--';
      setState(() {
        _products.add(MockLinkProduct(
          id: epc,
          name: name,
          code: code,
          number: p?.number,
        ));
      });
    });

    final ok = await _reader.startInventory(
      dateTime: true,
      radioPower: true,
      channel: true,
      temp: false,
      phase: false,
      noRepeat: true,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('読取開始に失敗しました（接続状態を確認してください）。')),
      );
      await _stopLinkingRead();
    }
  }

  void _toggleLinkingRead() {
    if (_isLinkingReading) {
      _stopLinkingRead();
    } else {
      _startLinkingRead();
    }
  }

  Future<void> _loadHardwareTriggerHints() async {
    final m = await HardwareTriggerModeStorage.getMode();
    final s = await HardwareTriggerModeStorage.getTimedSeconds();
    if (mounted) {
      setState(() {
        _hwTriggerMode = m;
        _hwTimedSeconds = s;
      });
    }
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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SlipLinkConfirmDialog(
        slip: widget.slip,
        linkMode: widget.linkMode,
        selected: selected,
        onRevise: () => Navigator.pop(ctx),
        onSaveWithoutSend: () {
          Navigator.pop(ctx);
          Navigator.pop(
            context,
            SlipLinkPopResult(products: selected, submitted: false),
          );
        },
        onSubmitted: () {
          Navigator.pop(ctx);
          Navigator.pop(
            context,
            SlipLinkPopResult(products: selected, submitted: true),
          );
        },
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

  Widget _productListColumnHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 34),
          const Expanded(
            child: Text(
              '商品名',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
            ),
          ),
          SizedBox(
            width: _codeColumnWidth,
            child: const Text(
              '商品コード',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _numberColumnWidth,
            child: const Text(
              '番号',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productListRow(MockLinkProduct p, bool selected) {
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
              SizedBox(
                width: _codeColumnWidth,
                child: Text(
                  p.code,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF555555), fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: _numberColumnWidth,
                child: Text(
                  p.numberDisplay,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF555555), fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                MainFlowNavBar(
                  showBackButton: true,
                  title: widget.linkMode != null && widget.linkMode!.isNotEmpty
                      ? '伝票・商品紐付け（${widget.linkMode}）'
                      : '伝票・商品紐付け',
                  onBack: () => Navigator.pop(context),
                ),
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
                              value: ReceptionSlip.formatHandlerDisplayName(
                                slip.handlerName?.trim().isNotEmpty == true
                                    ? slip.handlerName!
                                    : (_resolvedHandlerName ?? slip.handlerDisplay),
                              ),
                            ),
                            _InfoLine(label: '会社名', value: slip.customerName),
                            _InfoLine(label: '現場名', value: slip.siteName),
                            _InfoLine(label: '用件', value: slip.subject),
                            _InfoLine(label: '商品・台数', value: _detailsSummary(slip)),
                          ],
                        ),
                        // 読み取りボタン（Android: 実機読取開始/停止、それ以外: モック）
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _reader.supportsNativeRfid
                                  ? _toggleLinkingRead
                                  : _readTags,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _reader.supportsNativeRfid && _isLinkingReading
                                    ? AppDesign.stopButton
                                    : AppDesign.primaryButton,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: Text(
                                _reader.supportsNativeRfid
                                    ? (_isLinkingReading ? '読取停止' : '読取開始')
                                    : '商品をタグリーダーから読み取り',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        if (_reader.supportsNativeRfid) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Text(
                              HardwareTriggerModeStorage.describeForTagList(
                                _hwTriggerMode,
                                _hwTimedSeconds,
                              ),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
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
                        else ...[
                          _productListColumnHeader(),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final p = _products[index];
                              final selected = _selectedIds.contains(p.id);
                              return _productListRow(p, selected);
                            },
                          ),
                        ],
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

/// 紐付け内容の確認ダイアログ（過不足表示・送信）
class _SlipLinkConfirmDialog extends StatefulWidget {
  const _SlipLinkConfirmDialog({
    required this.slip,
    required this.selected,
    required this.onRevise,
    required this.onSaveWithoutSend,
    required this.onSubmitted,
    this.linkMode,
  });

  final ReceptionSlip slip;
  final String? linkMode;
  final List<MockLinkProduct> selected;
  final VoidCallback onRevise;
  final VoidCallback onSaveWithoutSend;
  final VoidCallback onSubmitted;

  @override
  State<_SlipLinkConfirmDialog> createState() => _SlipLinkConfirmDialogState();
}

class _SlipLinkConfirmDialogState extends State<_SlipLinkConfirmDialog> {
  bool _forceSendAck = false;
  bool _sending = false;

  late final SlipLinkMatch _match = SlipLinkMatch.analyze(
    details: widget.slip.details,
    linked: widget.selected,
  );

  bool get _canSend {
    if (widget.selected.isEmpty || _sending) return false;
    if (_match.isComplete) return true;
    return _forceSendAck;
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    if (!kUseApi) {
      showAppNotification(context, 'API 未接続のため送信できません。');
      return;
    }
    if (kLinkTagsForbidden) {
      showAppNotification(context, '本番DBでは読み取り専用のため送信できません。');
      return;
    }

    setState(() => _sending = true);
    try {
      final userId = await EmployeeStorage.getCode();
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final request = SlipTagLinkRequest(
        userId: userId,
        linkMode: widget.linkMode,
        items: widget.selected
            .map((p) => SlipTagLinkItem(epc: p.id, productCode: p.code))
            .toList(),
      );
      await api.submitSlipTagLinks(
        receptionNo: widget.slip.receptionNo,
        request: request,
      );
      if (!mounted) return;
      widget.onSubmitted();
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppApiError(context, e, apiName: 'reception-slips/link-tags', stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slip = widget.slip;
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppDesign.deviceWidth, maxHeight: maxH),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '紐付け内容の確認',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text('伝票: ${slip.receptionNo}', style: const TextStyle(fontSize: 14)),
                Text('会社名: ${slip.customerName}', style: const TextStyle(fontSize: 14)),
                Text('用件: ${slip.subject}', style: const TextStyle(fontSize: 14)),
                if (widget.linkMode != null && widget.linkMode!.isNotEmpty)
                  Text('モード: ${widget.linkMode}', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionTitle('伝票内容と合致する紐付け商品'),
                        if (_match.matchedProducts.isEmpty)
                          const _EmptyHint('該当い')
                        else
                          ..._match.matchedProducts.map(_buildMatchedRow),
                        const _SectionDivider(),
                        _sectionTitle('伝票内容と不足する商品'),
                        if (_match.shortageRows.isEmpty)
                          const _EmptyHint('不足なし')
                        else
                          ..._match.shortageRows.map(_buildShortageRow),
                        const _SectionDivider(),
                        _sectionTitle('伝票内容にない紐付け商品'),
                        if (_match.notOnSlipProducts.isEmpty)
                          const _EmptyHint('なし')
                        else
                          ..._match.notOnSlipProducts.map(_buildNotOnSlipRow),
                        if (_match.hasMismatch) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFE082)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '伝票明細と選択内容に差があります。不足は黄、伝票にない商品は赤の「！」で示しています。',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.4),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => setState(() => _forceSendAck = !_forceSendAck),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _forceSendAck,
                                          onChanged: (v) =>
                                              setState(() => _forceSendAck = v ?? false),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          '不足・不要な商品があることを確認し、この内容のまま送信する',
                                          style: TextStyle(fontSize: 13, color: Color(0xFF333333), height: 1.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_match.isComplete) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppDesign.linkedBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppDesign.linkedBorder),
                            ),
                            child: const Text(
                              '伝票の商品はすべて紐付け済みです。このまま送信できます。',
                              style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSend ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.sendButton,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppDesign.disabledButton,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(
                      _sending ? '送信中…' : '送信',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _sending ? null : widget.onSaveWithoutSend,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF333333),
                      side: const BorderSide(color: AppDesign.navBarBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      '送信せず一覧へ戻る',
                      style: TextStyle(
                        fontSize: 15,
                        locale: Locale('ja', 'JP'),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _sending ? null : widget.onRevise,
                  child: const Text(
                    '戻って修正する',
                    style: TextStyle(
                      fontSize: 14,
                      locale: Locale('ja', 'JP'),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
      ),
    );
  }

  Widget _buildMatchedRow(MockLinkProduct p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1565C0),
                  ),
                ),
                Text(
                  '（${p.code} / ${p.numberDisplay}）',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
          const Text(
            '✓',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortageRow(SlipLinkShortageRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.productName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  'コード ${row.productCode}  不足 ${row.shortageQty}（必要 ${row.requiredQty} / 紐付 ${row.linkedQty}）',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFF9A825)),
                ),
              ],
            ),
          ),
          const Text(
            '!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF9A825),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotOnSlipRow(MockLinkProduct p) {
    final onSlipButExcess = widget.slip.details.any(
      (d) => d.productCode?.toString().trim() == p.code.trim(),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                Text(
                  '（${p.code} / ${p.numberDisplay}）'
                  '${onSlipButExcess ? '  ← 必要数を超えた紐付け' : '  ← 伝票にない商品'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFD32F2F)),
                ),
              ],
            ),
          ),
          const Text(
            '!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFFD32F2F),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
      ),
    );
  }
}
