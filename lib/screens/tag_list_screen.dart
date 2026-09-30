import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/inventory_epc.dart';
import '../models/product_update_request.dart';
import '../services/employee_storage.dart';
import '../services/hardware_trigger_handler.dart';
import '../services/hardware_trigger_mode_storage.dart';
import '../services/product_cache.dart';
import '../services/storage_location_storage.dart';
import '../services/tag_ledger_cache.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';
import '../utils/api_error_presenter.dart';
import '../widgets/app_notification.dart';
import '../widgets/main_flow_nav_bar.dart';
import '../widgets/reader_not_connected_dialog.dart';

/// 画面 2: ICタグ読取・更新（design/screen2-tag-list-wireframe.html 準拠）
/// 読取開始/停止、タグ一覧（EPC・商品名・ステータス）、送信待ち・送信ボタン
class TagListScreen extends StatefulWidget {
  const TagListScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<TagListScreen> createState() => _TagListScreenState();
}

/// ステータス候補（tag_mode2 の全データに合わせる）
const List<String> _statusOptions = [
  'ＯＫ',
  '清掃中',
  '整備中',
  '修理中',
  '貸出中',
  '廃棄',
  '在庫',
  '予約',
  '自社使用',
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
    this.fromCache = false,
    this.needsDbLookup = false,
    this.statusFromDb = false,
  });
  final String epc;
  final String productName;
  final String status;
  final String readAt;
  final int? productCode;
  final int? number;

  /// ローカル台帳キャッシュで照合できた
  final bool fromCache;

  /// キャッシュ未ヒットのため、ユーザー操作で DB 照会が必要
  final bool needsDbLookup;

  /// fetchProduct で状態（tag_mode2）を取得済み
  final bool statusFromDb;
}

class _TagListScreenState extends State<TagListScreen> {
  bool _isReading = false;
  final List<_TagReadItem> _reads = [];
  /// ステータス一括更新用（チェックボックス）
  final Set<int> _selectedForStatus = {};
  /// 送信待ち（背景色で表示）
  final Set<int> _selectedForSend = {};
  final Set<int> _sentIndices = {};
  final Map<int, String> _statusOverrides = {};
  /// 行ごとの DB 照会中インデックス
  final Set<int> _dbQuerying = {};
  bool _randomLoading = false;
  bool _isSending = false;
  int _sendCompleted = 0;
  int _sendTotal = 0;

  final _reader = TagReaderService.instance;
  StreamSubscription<InventoryEpc>? _invSub;
  HardwareTriggerHandler? _hwTriggerHandler;
  HardwareTriggerMode _hwTriggerMode = HardwareTriggerMode.toggle;
  double _hwTimedSeconds = HardwareTriggerModeStorage.timedSecondsDefault;

  int get _pendingCount => _selectedForSend.length;

  String _formatNow() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  String _effectiveStatus(int index) {
    if (_statusOverrides.containsKey(index)) return _statusOverrides[index]!;
    if (index >= _reads.length) return '不明';
    return _reads[index].status.isEmpty ? '不明' : _reads[index].status;
  }

  /// 行の「DB確認」「状態を見る」「再取得」から呼ぶ。fetchProduct で商品・状態を更新する。
  Future<void> _queryProductFromDb(int index) async {
    if (!kUseApi) return;
    if (index < 0 || index >= _reads.length) return;
    if (_dbQuerying.contains(index)) return;

    setState(() => _dbQuerying.add(index));
    try {
      final epc = _reads[index].epc;
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final p = await api.fetchProduct(epc);
      if (!mounted) return;
      if (p == null) {
        setState(() {
          _statusOverrides.remove(index);
          final cur = _reads[index];
          _reads[index] = _TagReadItem(
            epc: cur.epc,
            productName: cur.productName,
            status: 'データなし',
            readAt: cur.readAt,
            productCode: cur.productCode,
            number: cur.number,
            fromCache: cur.fromCache,
            needsDbLookup: false,
            statusFromDb: true,
          );
        });
        return;
      }
      await TagLedgerCache.instance.put(
        epc,
        productCode: p.productCode,
        number: p.number,
      );
      if (!mounted) return;
      setState(() {
        _statusOverrides.remove(index);
        final cur = _reads[index];
        _reads[index] = _TagReadItem(
          epc: cur.epc,
          productName: p.productName.isEmpty ? '商品不明' : p.productName,
          status: p.status.isEmpty ? '不明' : p.status,
          readAt: cur.readAt,
          productCode: p.productCode,
          number: p.number,
          fromCache: cur.fromCache,
          needsDbLookup: false,
          statusFromDb: true,
        );
      });
    } catch (e, st) {
      logApiError(e, apiName: 'products', stackTrace: st);
      if (mounted) {
        final userError = toUserFacingApiError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userError.displayText)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _dbQuerying.remove(index));
      }
    }
  }

  /// テスト用: API からランダムに1件取得し、読み取りとして追加（WindowsなどAPI接続時のみ）
  Future<void> _addRandomRead() async {
    if (_randomLoading) return;
    if (!kUseApi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('読み取りシミュレートはAPI接続時（Windowsなど）のみ利用できます。')),
      );
      return;
    }
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
            statusFromDb: true,
          ));
        });
      }
      if (list.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('取得できるデータがありませんでした。')),
        );
      }
    } catch (e, st) {
      logApiError(e, apiName: 'products/random', stackTrace: st);
      if (mounted) {
        final userError = toUserFacingApiError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userError.displayText)),
        );
      }
    } finally {
      if (mounted) setState(() => _randomLoading = false);
    }
  }

  /// 読取停止（ボタン・トリガー両方から利用）
  Future<void> _stopInventoryAndState() async {
    _hwTriggerHandler?.notifyStoppedByAppButton();
    await _invSub?.cancel();
    _invSub = null;
    await _reader.stopInventory();
    if (mounted) setState(() => _isReading = false);
  }

  /// 読取開始（ボタン・トリガー両方から利用）。RFID ネイティブ非対応では何もしない。
  Future<void> _startInventoryIfReady() async {
    if (_isReading) return;
    if (!_reader.supportsNativeRfid) return;

    setState(() => _isReading = true);

    final okPerm = await _reader.requestBluetoothPermissions();
    final okConn = await _reader.isConnected();
    if (!mounted) return;
    if (!okPerm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth権限が必要です。設定から許可してください。')),
      );
      setState(() => _isReading = false);
      return;
    }
    if (!okConn) {
      await showReaderNotConnectedDialog(context);
      setState(() => _isReading = false);
      return;
    }

    await _invSub?.cancel();
    _invSub = _reader.inventoryEpcStream.listen((inv) async {
      if (!mounted || !_isReading) return;
      final epc = inv.epcForLookup;
      // 重複排除: 既に同じ EPC が一覧にあれば追加しない
      if (_reads.any((r) => r.epc == epc)) return;

      // まずローカル台帳＋商品台帳で照合（自動 API はしない）
      await TagLedgerCache.instance.init();
      await ProductCache.instance.init();
      if (!mounted || !_isReading) return;
      if (_reads.any((r) => r.epc == epc)) return;

      final readAt = _formatNow();
      final entry = TagLedgerCache.instance.lookup(epc);
      if (entry != null) {
        final productName = ProductCache.instance.getNameFromMemory(entry.productCode?.toString() ?? '') ?? '商品不明';
        setState(() {
          _reads.add(_TagReadItem(
            epc: epc,
            productName: productName,
            status: '不明',
            readAt: readAt,
            productCode: entry.productCode,
            number: entry.number,
            fromCache: true,
          ));
        });
        return;
      }

      // キャッシュ未ヒット: 「商品不明」で確定。API 利用時は右端「DB確認」で照会
      setState(() {
        _reads.add(_TagReadItem(
          epc: epc,
          productName: '商品不明',
          status: '不明',
          readAt: readAt,
          needsDbLookup: kUseApi,
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
      await _invSub?.cancel();
      _invSub = null;
      setState(() => _isReading = false);
    }
  }

  Future<void> _toggleRead() async {
    if (_isReading) {
      await _stopInventoryAndState();
      return;
    }
    await _startInventoryIfReady();
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadHardwareTriggerHints());
    if (_reader.supportsNativeRfid) {
      _hwTriggerHandler = HardwareTriggerHandler(
        onStart: _startInventoryIfReady,
        onStop: _stopInventoryAndState,
        isReading: () => _isReading,
        mounted: () => mounted,
      );
      unawaited(_hwTriggerHandler!.attach(_reader));
    }
  }

  @override
  void dispose() {
    if (_hwTriggerHandler != null) {
      unawaited(_hwTriggerHandler!.cancelSubscriptionOnly());
    }
    _invSub?.cancel();
    _reader.stopInventory();
    super.dispose();
  }

  void _toggleStatusSelect(int index) {
    if (kProductUpdatesForbidden) return;
    setState(() {
      if (_selectedForStatus.contains(index)) {
        _selectedForStatus.remove(index);
      } else {
        _selectedForStatus.add(index);
      }
    });
  }

  void _toggleSelectAll() {
    if (kProductUpdatesForbidden) return;
    setState(() {
      if (_selectedForStatus.length == _reads.length) {
        _selectedForStatus.clear();
      } else {
        _selectedForStatus
          ..clear()
          ..addAll(List.generate(_reads.length, (i) => i));
      }
    });
  }

  bool get _allStatusSelected =>
      _reads.isNotEmpty && _selectedForStatus.length == _reads.length;

  void _showStatusDialog(BuildContext context, int index) {
    if (kProductUpdatesForbidden) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('本番DBでは読み取り専用のため、ステータスを変更できません。'),
        ),
      );
      return;
    }
    final bulkApply =
        _selectedForStatus.contains(index) && _selectedForStatus.length > 1;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // 全候補がスクロールなしで表示されるよう、シートの最大高さを広めに（画面の90%）
        final maxH = MediaQuery.of(ctx).size.height * 0.9;
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
            // 白いシート（内容に合わせた高さ、最大 maxH）
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                            child: Text(
                              bulkApply
                                  ? 'ステータスを選択（チェック ${_selectedForStatus.length} 件すべてに適用）'
                                  : 'ステータスを選択',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: maxH - 80),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: _statusOptions
                                    .map(
                                      (status) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              final targets = _selectedForStatus.contains(index)
                                                  ? Set<int>.from(_selectedForStatus)
                                                  : {index};
                                              for (final i in targets) {
                                                if (i < _reads.length) {
                                                  _statusOverrides[i] = status;
                                                  _selectedForSend.add(i);
                                                }
                                              }
                                            });
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
    if (toSend.isEmpty || _isSending) return;
    if (!kUseApi) {
      showAppNotification(context, 'Androidでは送信できません。API接続時（Windowsなど）のみ送信可能です。');
      return;
    }

    setState(() {
      _isSending = true;
      _sendCompleted = 0;
      _sendTotal = toSend.length;
    });

    final api = ApiClient(baseUrl: kApiBaseUrl);
    final userId = await EmployeeStorage.getCode();
    final storageLocationCode = await StorageLocationStorage.getStorageLocationCode();

    int successCount = 0;
    UserFacingApiError? sendError;

    try {
      for (final index in toSend) {
        if (index >= _reads.length) continue;
        final tag = _reads[index];
        final status = _effectiveStatus(index);
        final request = ProductUpdateRequest(
          epc: tag.epc,
          readAt: tag.readAt,
          changes: {'status': status},
          userId: userId,
          storageLocation: storageLocationCode,
        );
        try {
          await api.submitProductUpdate(request);
          successCount++;
          if (mounted) {
            setState(() => _sendCompleted = successCount);
          }
        } catch (e, st) {
          logApiError(e, apiName: 'product-updates', stackTrace: st);
          sendError = toUserFacingApiError(e);
          break;
        }
      }

      if (!mounted) return;
      if (sendError != null) {
        showAppNotification(context, sendError.message, title: sendError.title);
        return;
      }
      setState(() {
        _sentIndices.addAll(toSend);
        _selectedForSend.removeAll(toSend);
      });
      showAppNotification(context, '送信しました（$successCount 件）。DB を更新しました。');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sendCompleted = 0;
          _sendTotal = 0;
        });
      }
    }
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
                  showBackButton: widget.showBackButton,
                  title: 'ICタグ読取・更新',
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
                          onPressed: () => _toggleRead(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isReading ? AppDesign.stopButton : AppDesign.primaryButton,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isReading ? '読取停止' : '読取開始',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isReading ? '読取中…' : '停止中',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_reader.supportsNativeRfid) ...[
                        const SizedBox(height: 8),
                        Text(
                          HardwareTriggerModeStorage.describeForTagList(
                            _hwTriggerMode,
                            _hwTimedSeconds,
                          ),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (!_reader.supportsNativeRfid) ...[
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
                    ],
                  ),
                ),
                // 送信待ちバー（product-updates 禁止時は送信不可）
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppDesign.pendingBarBackground,
                  child: Row(
                    children: [
                      Expanded(
                        child: kProductUpdatesForbidden
                            ? Text(
                                '読込件数: ${_reads.length} 件  本番のため読み取り専用（送信不可）',
                                style: const TextStyle(fontSize: 14, color: Color(0xFF8A7000)),
                              )
                            : Row(
                                children: [
                                  Text(
                                    '読込件数: ${_reads.length} 件',
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF8A7000)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      _isSending
                                          ? '送信中… $_sendCompleted / $_sendTotal 件'
                                          : '送信待ち: $_pendingCount 件',
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF8A7000)),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (!_isSending && !kProductUpdatesForbidden && _pendingCount > 0)
                            ? _sendSelected
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesign.sendButton,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppDesign.sendButton.withValues(alpha: 0.55),
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _isSending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '送信中…',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              )
                            : Text(
                                kProductUpdatesForbidden ? '送信（無効）' : '送信',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ),
                // 一覧ヘッダー（全選択）
                if (_reads.isNotEmpty && !kProductUpdatesForbidden)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: AppDesign.navBarBackground,
                      border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                    ),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _toggleSelectAll,
                          style: TextButton.styleFrom(
                            foregroundColor: AppDesign.primaryLink,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _allStatusSelected ? '全解除' : '全選択',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                // タグ一覧
                Expanded(
                  child: Container(
                    color: Colors.white,
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
                                  _reader.supportsNativeRfid
                                      ? HardwareTriggerModeStorage.describeEmptyStateHint(
                                          _hwTriggerMode,
                                        )
                                      : '「テスト: ランダムに1件読み取り」でAPIから取得',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                          itemCount: _reads.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFF9E9E9E),
                            indent: 52,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final tag = _reads[index];
                            final productName = tag.productName;
                            final isSent = _sentIndices.contains(index);
                            final isStatusSelected = _selectedForStatus.contains(index);
                            final isPendingSend =
                                _selectedForSend.contains(index) && !isSent;
                            final statusLabel = _effectiveStatus(index);
                            final statusStyle = _statusStyleFromLabel(statusLabel);
                            final showStatusBadge = statusLabel != '不明';
                            final canSelect = !kProductUpdatesForbidden;

                            return Material(
                              color: isPendingSend
                                  ? AppDesign.selectedForSendBackground
                                  : Colors.white,
                              child: InkWell(
                                onLongPress: () => _showStatusDialog(context, index),
                                onSecondaryTapDown: (_) => _showStatusDialog(context, index),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (canSelect)
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: isStatusSelected,
                                            onChanged: (_) => _toggleStatusSelect(index),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        )
                                      else
                                        const SizedBox(width: 24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InkWell(
                                          onTap: canSelect ? () => _toggleStatusSelect(index) : null,
                                          child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    [
                                                      if (tag.productCode != null) '商品コード: ${tag.productCode}',
                                                      if (tag.productCode != null && tag.number != null) '  ',
                                                      if (tag.number != null) '番号: ${tag.number}',
                                                    ].join(),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF455A64),
                                                    ),
                                                  ),
                                                ),
                                                if (showStatusBadge)
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
                                              ],
                                            ),
                                            const SizedBox(height: 6),
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
                                                  const Padding(
                                                    padding: EdgeInsets.only(right: 4),
                                                    child: Text(
                                                      '送信済み',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppDesign.statusOk,
                                                      ),
                                                    ),
                                                  ),
                                                if (kUseApi) ...[
                                                  if (_dbQuerying.contains(index))
                                                    const Padding(
                                                      padding: EdgeInsets.only(left: 4),
                                                      child: SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      ),
                                                    )
                                                  else if (_dbActionLabel(tag) != null)
                                                    OutlinedButton(
                                                      onPressed: () => _queryProductFromDb(index),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: AppDesign.primaryLink,
                                                        side: const BorderSide(color: AppDesign.primaryLink),
                                                        backgroundColor: const Color(0xFFEAF3FF),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        minimumSize: const Size(0, 32),
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        visualDensity: VisualDensity.compact,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        _dbActionLabel(tag)!,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ),
                // Padding(
                //   padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                //   child: Text(
                //     '※ テスト時は「ランダムに1件読み取り」でAPIから表示',
                //     style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                //     textAlign: TextAlign.center,
                //   ),
                // ),
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
      case 'データなし':
        return (fg: AppDesign.statusDisposed, bg: AppDesign.statusDisposedBg);
      case '不明':
        return (fg: AppDesign.statusUnknown, bg: AppDesign.statusUnknownBg);
      default:
        return (fg: AppDesign.statusOk, bg: AppDesign.statusOkBg);
    }
  }

  /// 行右端の DB 操作ラベル。null ならボタン非表示。
  String? _dbActionLabel(_TagReadItem tag) {
    if (tag.needsDbLookup) return 'DB確認';
    if (tag.fromCache && !tag.statusFromDb) return '状態を見る';
    if (tag.statusFromDb) return '再取得';
    return null;
  }
}
