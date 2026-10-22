import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../mocks/urgent_store_delivery_mock.dart';
import '../models/inventory_epc.dart';
import '../models/product_by_epc.dart';
import '../models/urgent_store_delivery.dart';
import '../services/connected_device_storage.dart';
import '../services/hardware_trigger_handler.dart';
import '../services/hardware_trigger_mode_storage.dart';
import '../services/product_cache.dart';
import '../services/tag_ledger_cache.dart';
import '../services/tag_reader_service.dart';
import '../config/feature_flags.dart';
import '../services/urgent_store_delivery_session.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import '../widgets/reader_not_connected_dialog.dart';
import '../widgets/urgent_read_item_tile.dart';
import 'urgent_store_delivery_blocked_page.dart';
import 'urgent_store_delivery_confirm_screen.dart';
import 'urgent_store_delivery_slip_select_screen.dart';

/// 急ぎ来店納品の統合画面（タグ読取 + 当日未処理一覧 + 商品選択）
/// 伝票選択・送信はモック。永続保存・送信 API は未接続。
class UrgentStoreDeliveryScreen extends StatefulWidget {
  const UrgentStoreDeliveryScreen({
    super.key,
    this.showBackButton = true,
  });

  final bool showBackButton;

  @override
  State<UrgentStoreDeliveryScreen> createState() =>
      _UrgentStoreDeliveryScreenState();
}

class _UrgentStoreDeliveryScreenState extends State<UrgentStoreDeliveryScreen> {
  final _session = UrgentStoreDeliverySession.instance;
  final Set<String> _selectedIds = {};

  String? _connectedDeviceName;
  final _reader = TagReaderService.instance;

  bool _isReading = false;
  StreamSubscription<InventoryEpc>? _invSub;
  HardwareTriggerHandler? _hwTriggerHandler;
  HardwareTriggerMode _hwTriggerMode = HardwareTriggerMode.toggle;
  double _hwTimedSeconds = HardwareTriggerModeStorage.timedSecondsDefault;
  int _readCounter = 0;

  bool get _isReaderConnected =>
      _connectedDeviceName != null && _connectedDeviceName!.isNotEmpty;

  List<UrgentReadItem> get _items => _session.items;

  int get _selectedCount =>
      _selectedIds.where((id) => _items.any((e) => e.id == id)).length;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _loadConnectedDevice();
    unawaited(_loadHardwareTriggerHints());
    if (_reader.supportsNativeRfid) {
      _hwTriggerHandler = HardwareTriggerHandler(
        onStart: _startReading,
        onStop: _stopReading,
        isReading: () => _isReading,
        mounted: () => mounted,
      );
      unawaited(_hwTriggerHandler!.attach(_reader));
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    if (_hwTriggerHandler != null) {
      unawaited(_hwTriggerHandler!.cancelSubscriptionOnly());
    }
    _invSub?.cancel();
    _reader.stopInventory();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {
      _selectedIds.removeWhere((id) => !_items.any((e) => e.id == id));
    });
  }

  Future<void> _loadConnectedDevice() async {
    final name = await ConnectedDeviceStorage.getName();
    if (name != null &&
        name.isNotEmpty &&
        _reader.supportsNativeRfid &&
        !(await _reader.isConnected())) {
      await ConnectedDeviceStorage.clear();
      if (mounted) setState(() => _connectedDeviceName = null);
      return;
    }
    if (mounted) setState(() => _connectedDeviceName = name);
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

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_items.map((e) => e.id));
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  void _openSlipSelect() {
    if (_selectedCount == 0) return;
    final selected = _items.where((e) => _selectedIds.contains(e.id)).toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            UrgentStoreDeliverySlipSelectScreen(selectedItems: selected),
      ),
    );
  }

  /// 追加に成功したら選択にも入れる
  void _tryAddAndSelect(UrgentReadItem item) {
    if (_session.addItem(item)) {
      setState(() => _selectedIds.add(item.id));
    }
  }

  /// Windows 等: モックプールから数件追加
  void _simulateRead() {
    final start = _readCounter % mockUrgentTodayItems.length;
    final count = 2 + (_readCounter % 2);
    for (var i = 0; i < count; i++) {
      final src =
          mockUrgentTodayItems[(start + i) % mockUrgentTodayItems.length];
      final epc = '${src.tagId}_${_session.items.length + i}';
      _tryAddAndSelect(
        UrgentReadItem(
          id: epc,
          productName: src.productName,
          productCode: src.productCode,
          number: src.number,
          tagId: epc,
          readAt: DateTime.now(),
        ),
      );
    }
    _readCounter++;
  }

  Future<void> _stopReading() async {
    _hwTriggerHandler?.notifyStoppedByAppButton();
    await _invSub?.cancel();
    _invSub = null;
    await _reader.stopInventory();
    if (mounted) setState(() => _isReading = false);
  }

  Future<void> _startReading() async {
    if (_isReading) return;
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
      if (mounted) await _loadConnectedDevice();
      return;
    }

    setState(() => _isReading = true);
    await _invSub?.cancel();
    _invSub = _reader.inventoryEpcStream.listen((inv) async {
      if (!mounted || !_isReading) return;
      final epc = inv.epcForLookup;
      if (_session.items.any((p) => p.id == epc || p.tagId == epc)) return;

      await TagLedgerCache.instance.init();
      await ProductCache.instance.init();
      final entry = TagLedgerCache.instance.lookup(epc);
      if (entry != null) {
        final name = ProductCache.instance
                .getNameFromMemory(entry.productCode?.toString() ?? '') ??
            '商品不明';
        if (!mounted) return;
        _tryAddAndSelect(
          UrgentReadItem(
            id: epc,
            productName: name,
            productCode: entry.productCode?.toString() ?? '--',
            number: entry.number?.toString() ?? '--',
            tagId: epc,
            readAt: DateTime.now(),
          ),
        );
        return;
      }

      if (!kUseApi) {
        if (!mounted) return;
        _tryAddAndSelect(
          UrgentReadItem(
            id: epc,
            productName: '商品不明',
            productCode: '--',
            number: '--',
            tagId: epc,
            readAt: DateTime.now(),
          ),
        );
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
      final name =
          (p == null || p.productName.isEmpty) ? '商品不明' : p.productName;
      final code = p?.productCode?.toString() ?? '--';
      _tryAddAndSelect(
        UrgentReadItem(
          id: epc,
          productName: name,
          productCode: code,
          number: p?.number?.toString() ?? '--',
          tagId: epc,
          readAt: DateTime.now(),
        ),
      );
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
      await _stopReading();
    }
  }

  void _toggleReading() {
    if (_isReading) {
      _stopReading();
    } else {
      _startReading();
    }
  }

  Widget _buildReadButton() {
    final supportsRfid = _reader.supportsNativeRfid;
    final connected = _isReaderConnected;
    final Color bg;
    if (!supportsRfid) {
      bg = AppDesign.primaryButton;
    } else if (_isReading) {
      bg = AppDesign.stopButton;
    } else if (!connected) {
      bg = AppDesign.disabledButton;
    } else {
      bg = AppDesign.primaryButton;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // 未接続でも押下可（接続画面への誘導ダイアログを出す）
              onPressed: supportsRfid ? _toggleReading : _simulateRead,
              style: ElevatedButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                supportsRfid
                    ? (_isReading ? '読取停止' : '読取開始')
                    : '商品をタグリーダーから読み取り',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (supportsRfid) ...[
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enableUrgentStoreDelivery) {
      return const UrgentStoreDeliveryBlockedPage();
    }
    final items = _items;
    final hasItems = items.isNotEmpty;
    final selectedCount = _selectedCount;
    final canSelectSlip = selectedCount > 0;
    final allSelected = hasItems && selectedCount == items.length;

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
                  title: '急ぎ来店納品',
                  showBackButton: widget.showBackButton,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildReadButton(),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                        color: AppDesign.navBarBackground,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                hasItems
                                    ? '本日の未処理商品　${items.length}点'
                                    : '本日の未処理商品',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (hasItems)
                              TextButton(
                                onPressed:
                                    allSelected ? _clearSelection : _selectAll,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppDesign.primaryLink,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  allSelected ? '選択解除' : 'すべて選択',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!hasItems)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'タグを読み取るとここに表示されます',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ),
                        )
                      else
                        ...items.map(
                          (item) => UrgentReadItemTile(
                            item: item,
                            showCheckbox: true,
                            showTagId: false,
                            selected: _selectedIds.contains(item.id),
                            onToggle: () => _toggle(item.id),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F8F8),
                    border: Border(
                      top: BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          canSelectSlip
                              ? '$selectedCount点選択中'
                              : '商品を選択してください',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: canSelectSlip
                                ? Colors.black87
                                : const Color(0xFF888888),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canSelectSlip ? _openSlipSelect : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canSelectSlip
                                  ? AppDesign.primaryButton
                                  : AppDesign.disabledButton,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppDesign.disabledButton,
                              disabledForegroundColor: Colors.white70,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '伝票を選択',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
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

/// ホームなどから開くときの Route（送信後の popUntil 用）
Route<void> buildUrgentStoreDeliveryRoute({bool showBackButton = true}) {
  return MaterialPageRoute<void>(
    settings: const RouteSettings(name: UrgentStoreDeliveryRoutes.main),
    builder: (context) {
      if (!enableUrgentStoreDelivery) {
        return const UrgentStoreDeliveryBlockedPage();
      }
      return UrgentStoreDeliveryScreen(showBackButton: showBackButton);
    },
  );
}
