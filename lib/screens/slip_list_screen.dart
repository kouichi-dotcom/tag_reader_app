import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../mocks/mock_data.dart';
import '../models/reception_slip.dart';
import '../models/slip_list_filter.dart';
import '../models/reception_detail_item.dart';
import '../models/slip_link_match.dart';
import '../models/slip_tag_link_request.dart';
import '../services/employee_cache.dart';
import '../services/employee_storage.dart';
import '../services/product_cache.dart';
import '../theme/app_design.dart';
import '../widgets/app_notification.dart';
import '../widgets/main_flow_nav_bar.dart';
import 'slip_link_screen.dart';

/// 画面 7: 伝票一覧・選択（design/screen7-slip-list-wireframe.html 準拠）
class SlipListScreen extends StatefulWidget {
  const SlipListScreen({
    super.key,
    this.showBackButton = false,
    this.listTitle,
    this.filter,
    this.subjectFilterOptions,
  });

  final bool showBackButton;
  /// 画面上部のタイトル。省略時は「伝票一覧・選択」
  final String? listTitle;
  /// 取得条件。省略時は全伝票（SlipListFilter.all）
  final SlipListFilter? filter;
  /// 用件絞り込みボタン（null / 空なら非表示）。全伝票・担当は [allSubjectFilterOptions]、来店は [visitSubjectFilterOptions]
  final List<({String label, String value})>? subjectFilterOptions;

  /// 全伝票・担当伝票用の用件ボタン
  static const List<({String label, String value})> allSubjectFilterOptions = [
    (label: '配達', value: '<配達>'),
    (label: '引取', value: '引取'),
    (label: '交換', value: '交換'),
    (label: '来店（納品）', value: '来店(納品)'),
    (label: '来店（返品）', value: '来店(返品)'),
    (label: '連絡', value: '連絡'),
    (label: 'キャンセル', value: 'ｷｬﾝｾﾙ'),
    (label: '点検', value: '点検'),
    (label: 'キャンセル（配達）', value: 'ｷｬﾝｾﾙ(配達)'),
    (label: 'キャンセル（引取）', value: 'ｷｬﾝｾﾙ(引取)'),
  ];

  /// 来店伝票一覧用の用件ボタン
  static const List<({String label, String value})> visitSubjectFilterOptions = [
    (label: '来店（納品）', value: '来店(納品)'),
    (label: '来店（返品）', value: '来店(返品)'),
  ];

  @override
  State<SlipListScreen> createState() => _SlipListScreenState();
}

class _SlipListScreenState extends State<SlipListScreen> {
  static const int _pageSize = 5;

  bool _fetching = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  /// 受付台帳APIから取得した伝票（受付日時の新しい順）
  List<ReceptionSlip> _displaySlips = [];
  final Set<String> _linkedSlipIds = {};
  final Map<String, List<MockLinkProduct>> _linkedProductsBySlipId = {};
  /// 用件「交換」: 受付番号 → (交換納品|交換返品 → 紐付け商品)。両モードを同時に保持できる。
  final Map<String, Map<String, List<MockLinkProduct>>> _exchangeLinkedBySlipId = {};
  final Set<String> _selectedSlipIdsForSend = {};
  final Set<String> _sentSlipIds = {};
  bool _sending = false;
  final ScrollController _scrollController = ScrollController();

  /// 用件絞り込み（DB上の用件名）。null = 絞りなし（画面初期の subjectFilter を使用）
  String? _selectedSubjectValue;

  bool get _showSubjectFilters =>
      widget.subjectFilterOptions != null &&
      widget.subjectFilterOptions!.isNotEmpty;

  /// 用件「交換」のみ（交換（配達）/ 交換（引取）は含めない）
  static bool _isExchangeSubject(String subject) => subject.trim() == '交換';

  bool _hasLinkedProducts(String receptionNo) {
    final normal = _linkedProductsBySlipId[receptionNo];
    if (normal != null && normal.isNotEmpty) return true;
    final exchange = _exchangeLinkedBySlipId[receptionNo];
    if (exchange == null) return false;
    return exchange.values.any((list) => list.isNotEmpty);
  }

  /// 受付日時の新しい順（同日時は受付番号の大きい順）。null は末尾。
  static List<ReceptionSlip> _sortedByReceptionAtDesc(List<ReceptionSlip> slips) {
    final list = List<ReceptionSlip>.from(slips);
    list.sort((a, b) {
      final at = a.receptionAt;
      final bt = b.receptionAt;
      if (at == null && bt == null) {
        return b.receptionNo.compareTo(a.receptionNo);
      }
      if (at == null) return 1;
      if (bt == null) return -1;
      final byTime = bt.compareTo(at);
      if (byTime != 0) return byTime;
      return b.receptionNo.compareTo(a.receptionNo);
    });
    return list;
  }

  void _toggleSlipForSend(String slipId) {
    setState(() {
      if (_selectedSlipIdsForSend.contains(slipId)) {
        _selectedSlipIdsForSend.remove(slipId);
      } else {
        _selectedSlipIdsForSend.add(slipId);
      }
    });
  }

  Future<void> _sendSelectedSlips() async {
    if (_selectedSlipIdsForSend.isEmpty || _sending) return;

    if (!kUseApi) {
      showAppNotification(context, 'API 未接続のため送信できません。');
      return;
    }
    if (kIsProductionDb) {
      showAppNotification(context, '本番DBでは読み取り専用のため送信できません。');
      return;
    }

    final toSend = _selectedSlipIdsForSend.toList();
    final missingLink = toSend.where((id) => !_hasLinkedProducts(id)).toList();
    if (missingLink.isNotEmpty) {
      showAppNotification(
        context,
        '紐付け商品が無い伝票があります（${missingLink.join(', ')}）。\n先に伝票詳細からタグを紐付けてください。',
      );
      return;
    }

    setState(() => _sending = true);
    final userId = await EmployeeStorage.getCode();
    final api = ApiClient(baseUrl: kApiBaseUrl);
    var successCount = 0;
    final errors = <String>[];
    final warningNotes = <String>[];

    try {
      for (final receptionNo in toSend) {
        final slip = _displaySlips.cast<ReceptionSlip?>().firstWhere(
              (s) => s?.receptionNo == receptionNo,
              orElse: () => null,
            );
        final isExchange = slip != null && _isExchangeSubject(slip.subject);

        final payloads = <SlipTagLinkRequest>[];
        if (isExchange) {
          final byMode = _exchangeLinkedBySlipId[receptionNo] ?? {};
          for (final entry in byMode.entries) {
            if (entry.value.isEmpty) continue;
            payloads.add(SlipTagLinkRequest(
              userId: userId,
              linkMode: entry.key,
              items: entry.value
                  .map((p) => SlipTagLinkItem(epc: p.id, productCode: p.code))
                  .toList(),
            ));
          }
        } else {
          final products = _linkedProductsBySlipId[receptionNo] ?? const [];
          if (products.isEmpty) continue;
          payloads.add(SlipTagLinkRequest(
            userId: userId,
            items: products
                .map((p) => SlipTagLinkItem(epc: p.id, productCode: p.code))
                .toList(),
          ));
        }

        if (payloads.isEmpty) {
          errors.add('[$receptionNo] 送信する紐付けがありません');
          continue;
        }

        var slipOk = true;
        for (final request in payloads) {
          try {
            final result = await api.submitSlipTagLinks(
              receptionNo: receptionNo,
              request: request,
            );
            if (result.warnings.isNotEmpty) {
              final modeSuffix =
                  request.linkMode != null ? '/${request.linkMode}' : '';
              warningNotes.addAll(
                result.warnings.map((w) => '[$receptionNo$modeSuffix] $w'),
              );
            }
          } catch (e) {
            slipOk = false;
            final modeSuffix =
                request.linkMode != null ? '/${request.linkMode}' : '';
            errors.add('[$receptionNo$modeSuffix] $e');
          }
        }

        if (slipOk) {
          successCount++;
          if (mounted) {
            setState(() {
              _sentSlipIds.add(receptionNo);
              _selectedSlipIdsForSend.remove(receptionNo);
            });
          }
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    if (!mounted) return;
    if (errors.isEmpty) {
      final warnSuffix = warningNotes.isEmpty
          ? ''
          : '\n警告: ${warningNotes.take(3).join(' / ')}'
              '${warningNotes.length > 3 ? ' …' : ''}';
      showAppNotification(
        context,
        '$successCount 件の伝票を送信しました。$warnSuffix',
      );
    } else if (successCount == 0) {
      showAppNotification(
        context,
        '送信に失敗しました。\n${errors.first}',
      );
    } else {
      showAppNotification(
        context,
        '成功 $successCount 件 / 失敗 ${errors.length} 件。\n${errors.first}',
      );
    }
  }

  /// 画面の取得条件に、用件ボタンの選択を反映する（常に最新順・random なし）
  SlipListFilter _effectiveFilter({required int offset}) {
    final base = widget.filter ?? SlipListFilter.all;
    final subjects = _selectedSubjectValue != null
        ? <String>[_selectedSubjectValue!]
        : base.subjectFilter;
    return SlipListFilter(
      date: base.date,
      assigneeCode: base.assigneeCode,
      unassignedOnly: base.unassignedOnly,
      random: false,
      subjectFilter: subjects,
      limit: _pageSize,
      offset: offset,
    );
  }

  void _onSubjectFilterTap(String value) {
    setState(() {
      // 同じ用件を再タップで絞り解除
      _selectedSubjectValue =
          _selectedSubjectValue == value ? null : value;
    });
    unawaited(_fetchSlips());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (!_hasMore || _loadingMore || _fetching) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      unawaited(_fetchSlips(append: true));
    }
  }

  void _resolveCaches(ApiClient api, List<ReceptionSlip> slips) {
    for (final s in slips) {
      if (s.handlerCode != null &&
          s.handlerCode!.trim().isNotEmpty &&
          (s.handlerName == null || s.handlerName!.trim().isEmpty)) {
        EmployeeCache.instance.resolveName(api, s.handlerCode!).then((_) {
          if (mounted) setState(() {});
        });
      }
    }
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
  }

  Future<void> _fetchSlips({bool append = false}) async {
    if (append) {
      if (!_hasMore || _loadingMore || _fetching) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _fetching = true;
        _hasMore = true;
      });
    }

    final offset = append ? _displaySlips.length : 0;
    final filter = _effectiveFilter(offset: offset);

    if (!kUseApi) {
      final slips = _sortedByReceptionAtDesc(mockReceptionSlipsForFilter(filter));
      if (!mounted) return;
      setState(() {
        if (append) {
          final existing = _displaySlips.map((s) => s.receptionNo).toSet();
          _displaySlips = [
            ..._displaySlips,
            ...slips.where((s) => !existing.contains(s.receptionNo)),
          ];
          _loadingMore = false;
        } else {
          _displaySlips = slips;
          _fetching = false;
        }
        _hasMore = slips.length >= _pageSize;
      });
      if (!append) {
        if (slips.isEmpty) {
          showAppNotification(
            context,
            'モック伝票がありません。\n担当伝票の場合は担当者コード「001」または「002」を設定してください。',
          );
        } else {
          showAppNotification(
            context,
            'モック伝票を表示中（API未接続）。\n経路案内は伝票詳細からテストできます。',
          );
        }
      }
      return;
    }

    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final slips = await api.fetchReceptionSlips(filter: filter);
      if (!mounted) return;

      final sorted = _sortedByReceptionAtDesc(slips);
      setState(() {
        if (append) {
          final existing = _displaySlips.map((s) => s.receptionNo).toSet();
          _displaySlips = [
            ..._displaySlips,
            ...sorted.where((s) => !existing.contains(s.receptionNo)),
          ];
          _loadingMore = false;
        } else {
          _displaySlips = sorted;
          _fetching = false;
        }
        _hasMore = slips.length >= _pageSize;
      });

      if (!append && slips.isEmpty) {
        showAppNotification(context, '伝票が見つかりませんでした。\n（受付台帳にデータがありません）');
      }

      _resolveCaches(api, slips);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _loadingMore = false;
      });
      if (!append) {
        showAppNotification(context, '伝票取得エラー: $e\n\nAPI URL: $kApiBaseUrl\n\nAPIサーバーが起動しているか確認してください。');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSlips());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
                  title: widget.listTitle ?? '伝票一覧・選択',
                  showBackButton: widget.showBackButton,
                  onBack: () => Navigator.of(context).pop(),
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
                if (_showSubjectFilters) _buildSubjectFilterBar(),
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
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _displaySlips.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _displaySlips.length) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  if (_hasMore && !_loadingMore && !_fetching) {
                                    unawaited(_fetchSlips(append: true));
                                  }
                                });
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }
                              final slip = _displaySlips[index];
                              final isSelectedForSend = _selectedSlipIdsForSend.contains(slip.receptionNo);
                              final isLinked = _linkedSlipIds.contains(slip.receptionNo);
                              final isSent = _sentSlipIds.contains(slip.receptionNo);
                              return _SlipRow(
                                slip: slip,
                                handlerDisplay: _resolvedHandlerDisplay(slip),
                                getDetailDisplayName: _detailProductDisplay,
                                isSelectedForSend: isSelectedForSend,
                                isLinked: isLinked,
                                isSent: isSent,
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
                        onPressed: (_selectedSlipIdsForSend.isEmpty || _sending)
                            ? null
                            : _sendSelectedSlips,
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
                          _sending
                              ? '送信中…'
                              : _selectedSlipIdsForSend.isEmpty
                                  ? '選択伝票送信'
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

  Widget _buildSubjectFilterBar() {
    final options = widget.subjectFilterOptions!;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _SubjectFilterChip(
                label: options[i].label,
                selected: _selectedSubjectValue == options[i].value,
                onTap: () => _onSubjectFilterTap(options[i].value),
              ),
            ],
          ],
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

  Future<void> _openRouteGuidance(BuildContext context, ReceptionSlip slip) async {
    final coords = slip.latLng?.trim() ?? '';
    if (coords.isEmpty) {
      showAppNotification(context, '位置情報が記録されていません');
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$coords');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showAppNotification(context, '地図アプリを開けませんでした');
    }
  }

  /// 来店では経路案内不要。
  /// - 来店伝票一覧（subjectFilter あり）では常に非表示
  /// - 全伝票一覧などでも、用件が来店系の伝票は非表示
  bool _shouldShowRouteGuidance(ReceptionSlip slip) {
    final subjects = widget.filter?.subjectFilter;
    if (subjects != null && subjects.isNotEmpty) return false;
    if (_isVisitSubject(slip.subject)) return false;
    return true;
  }

  static bool _isVisitSubject(String subject) {
    final s = subject.trim();
    return s == '来店(納品)' || s == '来店(返品)' || s.startsWith('来店');
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
                          if (_hasLinkedProducts(slip.receptionNo)) ...[
                            ...?(_exchangeLinkedBySlipId[slip.receptionNo]
                                ?.entries
                                .where((e) => e.value.isNotEmpty)
                                .map(
                                  (e) => _DetailRow(
                                    label: e.key,
                                    value: e.value
                                        .map((p) => '${p.name}（${p.code}）')
                                        .join('、'),
                                  ),
                                )
                                .toList()),
                            if (_linkedProductsBySlipId[slip.receptionNo]
                                    ?.isNotEmpty ==
                                true)
                              _DetailRow(
                                label: '紐付けた商品',
                                value: _linkedProductsBySlipId[slip.receptionNo]!
                                    .map((p) => '${p.name}（${p.code}）')
                                    .join('、'),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_shouldShowRouteGuidance(slip)) ...[
                          OutlinedButton(
                            onPressed: () => _openRouteGuidance(context, slip),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF333333),
                              side: const BorderSide(color: AppDesign.navBarBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('経路案内', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_isExchangeSubject(slip.subject))
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    unawaited(_openSlipLink(
                                      slip,
                                      linkMode: SlipTagLinkMode.exchangeReturn,
                                    ));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppDesign.selectedBorder,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: const Text('交換返品', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    unawaited(_openSlipLink(
                                      slip,
                                      linkMode: SlipTagLinkMode.exchangeDelivery,
                                    ));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: const Text('交換納品', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    unawaited(_openSlipLink(slip));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppDesign.selectedBorder,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: const Text('ICタグ読取', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
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

  Future<void> _openSlipLink(ReceptionSlip slip, {String? linkMode}) async {
    final List<MockLinkProduct>? initial;
    if (linkMode != null) {
      initial = _exchangeLinkedBySlipId[slip.receptionNo]?[linkMode];
    } else {
      initial = _linkedProductsBySlipId[slip.receptionNo];
    }
    final result = await Navigator.push<SlipLinkPopResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SlipLinkScreen(
          slip: slip,
          initialLinkedProducts: initial,
          linkMode: linkMode,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _linkedSlipIds.add(slip.receptionNo);
        if (linkMode != null && linkMode.isNotEmpty) {
          final byMode = _exchangeLinkedBySlipId.putIfAbsent(
            slip.receptionNo,
            () => <String, List<MockLinkProduct>>{},
          );
          byMode[linkMode] = result.products;
          _linkedProductsBySlipId.remove(slip.receptionNo);
        } else {
          _linkedProductsBySlipId[slip.receptionNo] = result.products;
          _exchangeLinkedBySlipId.remove(slip.receptionNo);
        }
        if (result.submitted) {
          _sentSlipIds.add(slip.receptionNo);
          _selectedSlipIdsForSend.remove(slip.receptionNo);
        }
      });
      if (result.submitted) {
        showAppNotification(
          context,
          '送信完了しました。',
        );
      }
    }
  }
}

/// 用件絞り込みチップ（1行横スクロール用）
class _SubjectFilterChip extends StatelessWidget {
  const _SubjectFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppDesign.selectedBorder : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppDesign.selectedBorder : const Color(0xFFDDDDDD),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}

/// 用件バッジの背景色・文字色
({Color background, Color foreground}) _subjectBadgeColors(String subject) {
  final s = subject.trim();
  // 来店系は背景を揃え、納品／返品で文字色を変えて区別する
  if (s == '来店(納品)' || s.contains('来店') && s.contains('納品')) {
    return (background: const Color(0xFFF3E5F5), foreground: const Color(0xFF1565C0));
  }
  if (s == '来店(返品)' || s.contains('来店') && s.contains('返品')) {
    return (background: const Color(0xFFF3E5F5), foreground: const Color(0xFFC62828));
  }
  if (s.startsWith('来店')) {
    return (background: const Color(0xFFF3E5F5), foreground: const Color(0xFF7B1FA2));
  }
  if (s.contains('返却')) {
    return (background: const Color(0xFFFFF3E0), foreground: const Color(0xFFE65100));
  }
  if (s.contains('引取')) {
    return (background: const Color(0xFFFFEBEE), foreground: const Color(0xFFC62828));
  }
  if (s == '交換') {
    return (background: const Color(0xFFE8F5E9), foreground: const Color(0xFF2E7D32));
  }
  if (s.contains('配達') || s.contains('納品') || s.contains('レンタル')) {
    return (background: const Color(0xFFE3F2FD), foreground: const Color(0xFF1565C0));
  }
  return (background: const Color(0xFFEEEEEE), foreground: const Color(0xFF616161));
}

class _SubjectBadge extends StatelessWidget {
  const _SubjectBadge({required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final label = subject.trim().isEmpty ? '--' : subject.trim();
    final colors = _subjectBadgeColors(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.foreground),
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
    this.isSent = false,
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
  final bool isSent;
  final VoidCallback onOpenDetail;
  final VoidCallback onToggleSend;

  String _formatReceptionAt(DateTime? dt) {
    if (dt == null) return '--';
    final y = dt.year;
    final m = dt.month;
    final d = dt.day;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  String _detailName(ReceptionDetailItem d) {
    if (getDetailDisplayName != null) return getDetailDisplayName!(d);
    return d.productName.trim().isEmpty ? '--' : d.productName;
  }

  String _productSummary() {
    if (slip.details.isEmpty) return '--';
    final first = slip.details.first;
    final qty = first.quantity != null ? first.quantity!.toInt().toString() : '--';
    final firstLine = '${_detailName(first)}（$qty）';
    if (slip.details.length == 1) return firstLine;
    return '$firstLine  他${slip.details.length - 1}件';
  }

  String _dueDateLabel() {
    if (slip.dueDate == null) return '';
    final d = slip.dueDate!;
    return '期日 ${d.month}/${d.day}';
  }

  String _displayText(String value) => value.trim().isEmpty ? '--' : value.trim();

  @override
  Widget build(BuildContext context) {
    final dueDateLabel = _dueDateLabel();
    return Material(
      color: isSelectedForSend ? AppDesign.selectedBackground : null,
      child: InkWell(
        onTap: onOpenDetail,
        onLongPress: onOpenDetail,
        onDoubleTap: onToggleSend,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              if (slip.receptionAt != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatReceptionAt(slip.receptionAt),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _displayText(handlerDisplay),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SubjectBadge(subject: slip.subject),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _displayText(slip.customerName),
                style: const TextStyle(fontSize: 13, color: Colors.black),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _displayText(slip.siteName),
                style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _productSummary(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF444444)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (dueDateLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      dueDateLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
                    ),
                  ],
                ],
              ),
              if (isSent)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '送信済',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1)),
                  ),
                )
              else if (isLinked)
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
