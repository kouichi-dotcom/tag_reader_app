import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/product_update_request.dart';
import '../services/employee_storage.dart';
import '../theme/app_design.dart';

/// 画面 2: タグ読取・一覧（design/screen2-tag-list-wireframe.html 準拠）
/// 読取開始/停止、タグ一覧（EPC・商品名・ステータス・日時）、送信待ち・送信ボタン
class TagListScreen extends StatefulWidget {
  const TagListScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<TagListScreen> createState() => _TagListScreenState();
}

/// ステータス候補（tag_mode2 の全データに合わせる）
const List<String> _statusOptions = [
  'ＯＫ',
  '在庫',
  '自社使用',
  '修理中',
  '整備中',
  '清掃中',
  '貸出中',
  '登録',
  '廃棄',
  '予約',
  '不明',
];

/// 一覧に表示する1件（API またはタグリーダーから取得）
class _TagReadItem {
  _TagReadItem({
    required this.epc,
    required this.productName,
    required this.status,
    required this.readAt,
    this.productCode,
    this.number,
  });
  final String epc;
  final String productName;
  final String status;
  final String readAt;
  final int? productCode;
  final int? number;
}

class _TagListScreenState extends State<TagListScreen> {
  bool _isReading = false;
  final List<_TagReadItem> _reads = [];
  final Set<int> _selectedForSend = {};
  final Set<int> _sentIndices = {};
  final Map<int, String> _statusOverrides = {};
  bool _randomLoading = false;

  int get _pendingCount => _selectedForSend.length;

  String _effectiveStatus(int index) {
    if (_statusOverrides.containsKey(index)) return _statusOverrides[index]!;
    if (index >= _reads.length) return '不明';
    return _reads[index].status.isEmpty ? '不明' : _reads[index].status;
  }

  /// テスト用: API からランダムに1件取得し、読み取りとして追加
  Future<void> _addRandomRead() async {
    if (_randomLoading) return;
    setState(() => _randomLoading = true);
    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final list = await api.fetchRandomProducts(count: 1);
      if (!mounted) return;
      final now = DateTime.now();
      final readAt = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      for (final p in list) {
        setState(() {
          _reads.add(_TagReadItem(
            epc: p.tagId2,
            productName: p.productName.isEmpty ? '商品不明' : p.productName,
            status: p.status.isEmpty ? '不明' : p.status,
            readAt: readAt,
            productCode: p.productCode,
            number: p.number,
          ));
        });
      }
      if (list.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('取得できるデータがありませんでした。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取得エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _randomLoading = false);
    }
  }

  void _toggleRead() {
    setState(() => _isReading = !_isReading);
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedForSend.contains(index)) {
        _selectedForSend.remove(index);
      } else {
        _selectedForSend.add(index);
      }
    });
  }

  void _showStatusDialog(BuildContext context, int index) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.55;
        return Stack(
          children: [
            // 暗い部分タップで閉じる（バリア）
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(ctx),
                child: const ColoredBox(color: Color(0x80000000)),
              ),
            ),
            // 白いシート
            Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {}, // シート上のタップはバリアに伝播させない
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AppDesign.deviceWidth,
                    maxHeight: maxH,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                            child: Text(
                              'ステータスを選択',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: maxH - 80),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: _statusOptions
                                    .map(
                                      (status) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() => _statusOverrides[index] = status);
                                            Navigator.pop(ctx);
                                          },
                                          style: OutlinedButton.styleFrom(
                                            alignment: Alignment.centerLeft,
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            side: const BorderSide(color: Color(0xFFEEEEEE)),
                                          ),
                                          child: Text(status, style: const TextStyle(fontSize: 15)),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendSelected() async {
    final toSend = Set<int>.from(_selectedForSend);
    if (toSend.isEmpty) return;

    final api = ApiClient(baseUrl: kApiBaseUrl);
    final userId = await EmployeeStorage.getCode();

    int successCount = 0;
    String? errorMessage;

    for (final index in toSend) {
      if (index >= _reads.length) continue;
      final tag = _reads[index];
      final status = _effectiveStatus(index);
      final request = ProductUpdateRequest(
        epc: tag.epc,
        readAt: tag.readAt,
        changes: {'status': status},
        userId: userId,
      );
      try {
        await api.submitProductUpdate(request);
        successCount++;
      } catch (e) {
        errorMessage = e.toString();
        break;
      }
    }

    if (!mounted) return;
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送信エラー: $errorMessage'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      _sentIndices.addAll(toSend);
      _selectedForSend.removeAll(toSend);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('送信しました（$successCount 件）。DB を更新しました。')),
    );
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
                _NavBar(
                  showBackButton: widget.showBackButton,
                  title: 'タグ読取・一覧',
                  onBack: () => Navigator.of(context).pop(),
                ),
                // 読取コントロール
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppDesign.controlBarBackground,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _toggleRead,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isReading ? AppDesign.stopButton : AppDesign.primaryButton,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(_isReading ? '読取停止' : '読取開始'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isReading ? '読取中…' : '停止中',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _randomLoading ? null : _addRandomRead,
                        icon: _randomLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.shuffle, size: 18),
                        label: Text(_randomLoading ? '取得中…' : 'テスト: ランダムに1件読み取り'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF666666),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                // 送信待ちバー
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppDesign.pendingBarBackground,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '送信待ち: $_pendingCount 件',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF8A7000)),
                      ),
                      ElevatedButton(
                        onPressed: _pendingCount > 0 ? _sendSelected : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesign.sendButton,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('送信', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                // 一覧ヘッダー
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppDesign.navBarBackground,
                  child: const Text(
                    'タグ一覧（ダブルタップ: 送信選択 / 長押し・右クリック: ステータス変更）',
                    style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                ),
                // タグ一覧
                Expanded(
                  child: _reads.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '読み取ったタグがありません',
                                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '「テスト: ランダムに1件読み取り」でAPIから取得',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _reads.length,
                          itemBuilder: (context, index) {
                            final tag = _reads[index];
                            final productName = tag.productName;
                            final isSelected = _selectedForSend.contains(index);
                            final isSent = _sentIndices.contains(index);
                            final statusLabel = _effectiveStatus(index);
                            final statusStyle = _statusStyleFromLabel(statusLabel);

                            return Material(
                              color: isSelected ? AppDesign.selectedBackground : null,
                              child: GestureDetector(
                                onDoubleTap: () => _toggleSelect(index),
                                onLongPress: () => _showStatusDialog(context, index),
                                onSecondaryTapDown: (_) => _showStatusDialog(context, index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: isSelected ? AppDesign.selectedBorder : Colors.transparent,
                                        width: 4,
                                      ),
                                      bottom: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
                                    ),
                                  ),
                                    child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'EPC: ${tag.epc}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF888888),
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      if (tag.productCode != null || tag.number != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (tag.productCode != null) '商品コード: ${tag.productCode}',
                                            if (tag.number != null) '番号: ${tag.number}',
                                          ].join('  '),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              productName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          if (isSent)
                                            const Text(
                                              '送信済み',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppDesign.statusOk,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusStyle.bg,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: statusStyle.fg,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            tag.readAt,
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Text(
                    '※ テスト時は「ランダムに1件読み取り」でAPIから表示',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({Color fg, Color bg}) _statusStyleFromLabel(String label) {
    switch (label) {
      case 'OK':
      case 'ＯＫ':
        return (fg: AppDesign.statusOk, bg: AppDesign.statusOkBg);
      case '在庫':
      case '登録':
        return (fg: AppDesign.statusOk, bg: AppDesign.statusOkBg);
      case '自社使用':
        return (fg: AppDesign.statusMaintenance, bg: AppDesign.statusMaintenanceBg);
      case '予約':
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
      case '不明':
        return (fg: AppDesign.statusUnknown, bg: AppDesign.statusUnknownBg);
      default:
        return (fg: AppDesign.statusOk, bg: AppDesign.statusOkBg);
    }
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.showBackButton,
    required this.title,
    required this.onBack,
  });

  final bool showBackButton;
  final String title;
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
              const SizedBox(width: 60),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 60),
          ],
        ),
      ),
    );
  }
}
