import 'dart:async';

import 'package:flutter/material.dart';

import '../mocks/mock_data.dart';
import '../services/connected_device_storage.dart';
import '../models/inventory_epc.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';

/// タグ情報表示（SDKで取得できる情報をできるだけ一覧表示する画面）
///
/// - inventoryTag() → onInventoryEPC の EPC 文字列（PC+UII）＋付加情報（TIME/RSSI/CH/TEMP/PH）
/// - readTag()      → RESERVED/EPC/TID/USER 各メモリバンクのデータ（CRC は EPC を offset=0 で取得可）
class TagInfoScreen extends StatefulWidget {
  const TagInfoScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<TagInfoScreen> createState() => _TagInfoScreenState();
}

class _TagInfoScreenState extends State<TagInfoScreen> {
  bool _isReading = false;
  final List<_TagFullInfo> _items = [];

  final _reader = TagReaderService.instance;
  StreamSubscription<InventoryEpc>? _sub;
  StreamSubscription<Map<String, dynamic>>? _debugSub;
  String _lastEventType = '';
  int _eventCount = 0;
  String? _streamError;

  Future<({bool channel, bool temp, bool phase})> _capsForConnectedReader() async {
    // SDK上、付加情報の CH/TEMP/PH は DOTR-2000/3000/R-5000 系でのみ有効。
    // DOTR-900J（現場想定）では TIME/RSSI を中心に扱う。
    final name = (await ConnectedDeviceStorage.getName()) ?? '';
    final supportsChannelTempPhase =
        name.startsWith('DOTR2') || name.startsWith('DOTR3') || name.startsWith('R-5000') || name.startsWith('TSS2100') || name.startsWith('TSS3100');
    return (channel: supportsChannelTempPhase, temp: supportsChannelTempPhase, phase: supportsChannelTempPhase);
  }

  Future<void> _toggleRead() async {
    if (_isReading) {
      await _reader.stopInventory();
      await _sub?.cancel();
      await _debugSub?.cancel();
      _sub = null;
      _debugSub = null;
      if (mounted) setState(() => _isReading = false);
      return;
    }

    setState(() {
      _isReading = true;
      _items.clear();
      _lastEventType = '';
      _eventCount = 0;
      _streamError = null;
    });

    if (_reader.isAndroid) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('タグリーダーが未接続です。先に「タグリーダー接続」で接続してください。')),
        );
        setState(() => _isReading = false);
        return;
      }

      await _sub?.cancel();
      await _debugSub?.cancel();
      _debugSub = _reader.events.listen(
        (e) {
          if (!mounted || !_isReading) return;
          final type = e['type'] as String? ?? '';
          setState(() {
            _lastEventType = type;
            _eventCount++;
          });
        },
        onError: (err, st) {
          if (mounted) setState(() => _streamError = err.toString());
        },
      );
      _sub = _reader.inventoryEpcStream.listen((inv) {
        if (!mounted || !_isReading) return;
        final full = _TagFullInfo.fromInventory(inv);
        setState(() => _items.insert(0, full));
      });

      final caps = await _capsForConnectedReader();
      final ok = await _reader.startInventory(
        dateTime: true,
        radioPower: true,
        channel: caps.channel,
        temp: caps.temp,
        phase: caps.phase,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('読取開始に失敗しました（接続状態を確認してください）。')),
        );
        await _sub?.cancel();
        await _debugSub?.cancel();
        _sub = null;
        _debugSub = null;
        setState(() => _isReading = false);
      }
      return;
    }

    // Windows等: モックで動作
    await _simulateReads(count: 3);
    if (mounted) setState(() => _isReading = false);
  }

  Future<void> _simulateReads({required int count}) async {
    for (final t in mockTagReads.take(count)) {
      if (!mounted) return;
      if (!_isReading) return;

      final inv = InventoryEpc.parse(_buildInventoryLikeString(t.epc));
      final full = _TagFullInfo.fromInventory(inv);
      setState(() => _items.insert(0, full));
      await Future.delayed(const Duration(milliseconds: 180));
    }
  }

  String _buildInventoryLikeString(String epcPcUii) {
    // SDKの例: "PC+UII,TIME=...,RSSI=-61.4,CH=28,TEMP=31,PH=31"
    // モックは再現性を高くするため「DOTR-900J相当」を基本（TIME/RSSI）に寄せる。
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // EPCに依存した疑似RSSI（同じEPCなら概ね同じ値になる）
    final h = epcPcUii.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final base = 45 + (h % 35); // 45..79
    final decimal = ((h ~/ 97) % 10) / 10.0;
    final rssi = (-(base + decimal)).toStringAsFixed(1);

    return '$epcPcUii'
        ',TIME=$nowMs'
        ',RSSI=$rssi';
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debugSub?.cancel();
    _reader.stopInventory();
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
                _NavBar(
                  showBackButton: widget.showBackButton,
                  title: 'タグ情報表示',
                  onBack: () => Navigator.of(context).pop(),
                ),
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
                      if (_isReading && (_lastEventType.isNotEmpty || _streamError != null)) ...[
                        const SizedBox(height: 8),
                        Text(
                          _streamError != null
                              ? 'エラー: $_streamError'
                              : '受信イベント: $_lastEventType (${_eventCount}件)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888888),
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: _items.isEmpty
                        ? const Center(
                            child: Text(
                              '読み取ったタグがありません',
                              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFF9E9E9E),
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: _TagInfoCard(item: item),
                              );
                            },
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

class _TagInfoCard extends StatelessWidget {
  const _TagInfoCard({required this.item});

  final _TagFullInfo item;

  @override
  Widget build(BuildContext context) {
    final lines = <({String k, String v})>[
      if (item.pcHex != null) (k: 'PC', v: item.pcHex!),
      if (item.uiiHex != null) (k: 'UII', v: item.uiiHex!),
      if (item.timeMs != null) (k: 'TIME', v: item.timeMs.toString()),
      if (item.rssi != null) (k: 'RSSI', v: item.rssi.toString()),
      if (item.channel != null) (k: 'CH', v: item.channel.toString()),
      if (item.temp != null) (k: 'TEMP', v: item.temp.toString()),
      if (item.phase != null) (k: 'PH', v: item.phase.toString()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EPC: ${item.epcPcUiiRaw}',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF888888),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in lines) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 92,
                        child: Text(
                          l.k,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l.v,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF222222),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
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

class _TagFullInfo {
  const _TagFullInfo({
    required this.epcPcUiiRaw,
    this.pcHex,
    this.uiiHex,
    this.timeMs,
    this.rssi,
    this.channel,
    this.temp,
    this.phase,
  });

  final String epcPcUiiRaw;
  final String? pcHex;
  final String? uiiHex;
  final int? timeMs;
  final double? rssi;
  final int? channel;
  final int? temp;
  final int? phase;

  static _TagFullInfo fromInventory(InventoryEpc inv) {
    return _TagFullInfo(
      epcPcUiiRaw: inv.epcPcUii,
      pcHex: inv.pcHex,
      uiiHex: inv.uiiHex,
      timeMs: inv.timeMs,
      rssi: inv.rssi,
      channel: inv.channel,
      temp: inv.temp,
      phase: inv.phase,
    );
  }
}

