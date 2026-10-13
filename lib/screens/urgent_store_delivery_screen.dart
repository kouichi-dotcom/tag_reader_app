import 'package:flutter/material.dart';

import '../models/urgent_store_delivery.dart';
import '../services/connected_device_storage.dart';
import '../services/tag_reader_service.dart';
import '../services/urgent_store_delivery_session.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import '../widgets/urgent_read_item_tile.dart';
import 'urgent_store_delivery_confirm_screen.dart';
import 'urgent_store_delivery_slip_select_screen.dart';

/// 急ぎ来店納品の統合画面（タグ読取想定 + 当日未処理一覧 + 商品選択）
/// 実読取・永続保存・API は未接続。後から差し替えやすい構成。
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
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {
      // 送信後に消えた ID を選択から除去
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

  Widget _buildConnectionStatusCard() {
    final supportsRfid = _reader.supportsNativeRfid;
    final connected = _isReaderConnected;

    if (!supportsRfid) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: const Row(
          children: [
            Icon(Icons.computer, size: 22, color: Color(0xFF666666)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'タグリーダー　この端末では非対応',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ICタグ読取はシミュレートで利用できます',
                    style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 22,
            color: connected ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'タグリーダー　接続済み' : 'タグリーダー　未接続',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: connected
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connected
                      ? (_connectedDeviceName ?? '')
                      : '接続してからICタグ読取を行えます',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        color: const Color(0xFFFFF8E1),
                        child: const Text(
                          '伝票を選ばず、先に商品タグを読み取ります。',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5D4037),
                            height: 1.4,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: _buildConnectionStatusCard(),
                      ),
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
                              '本日の未処理商品はありません',
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
    builder: (context) =>
        UrgentStoreDeliveryScreen(showBackButton: showBackButton),
  );
}
