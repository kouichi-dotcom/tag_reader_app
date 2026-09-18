import 'dart:async';

import 'package:flutter/material.dart';

import '../models/inventory_epc.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';

/// テスト用: 読み取ったEPCを一覧表示（DB照合なし）
///
/// - 在庫読取（inventory）で届く EPC（PC+UII）と RSSI 等
/// - ネイティブが `readTag` でメモリバンクを読んだときの `read_tag_data`（USER 等）があれば併記
class EpcTestScreen extends StatefulWidget {
  const EpcTestScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<EpcTestScreen> createState() => _EpcTestScreenState();
}

class _EpcRow {
  _EpcRow({
    required this.epcLookup,
    required this.rawPcUii,
    this.pcHex,
    this.uiiHex,
    this.rssi,
    this.channel,
    this.timeMs,
    required this.readAt,
    List<String>? readExtras,
  }) : readExtras = readExtras ?? [];

  final String epcLookup;
  final String rawPcUii;
  final String? pcHex;
  final String? uiiHex;
  final double? rssi;
  final int? channel;
  final int? timeMs;
  final String readAt;
  final List<String> readExtras;

  /// タグ表面の印字と同じ並びになることが多い（UII の16進を大文字化）
  String get surfaceStyleId => epcLookup.toUpperCase();

  static String _normKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s'), '');

  bool matchesReadTagEpc(String? sdkEpc) {
    if (sdkEpc == null || sdkEpc.isEmpty) return false;
    final k = _normKey(sdkEpc);
    if (k.isEmpty) return false;
    final raw = _normKey(rawPcUii);
    final look = _normKey(epcLookup);
    return k == raw ||
        k == look ||
        raw.endsWith(k) ||
        k.endsWith(raw) ||
        k.contains(look) ||
        look.contains(k);
  }
}

class _EpcTestScreenState extends State<EpcTestScreen> {
  final _reader = TagReaderService.instance;
  StreamSubscription<InventoryEpc>? _invSub;
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  bool _isReading = false;
  final List<_EpcRow> _rows = [];

  String _formatNow() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }

  Future<void> _stop() async {
    await _invSub?.cancel();
    _invSub = null;
    await _eventSub?.cancel();
    _eventSub = null;
    await _reader.stopInventory();
    if (mounted) setState(() => _isReading = false);
  }

  void _appendReadTagData(String? data, String? epcKey) {
    final payload = (data != null && data.isNotEmpty) ? data : '(データなし/エラー時は epc 側にメッセージのことがあります)';
    var attached = false;
    for (var i = 0; i < _rows.length; i++) {
      if (!_rows[i].matchesReadTagEpc(epcKey)) continue;
      setState(() {
        _rows[i].readExtras.add(
          epcKey != null && epcKey.isNotEmpty
              ? '[$epcKey] $payload'
              : payload,
        );
      });
      attached = true;
      break;
    }
    if (!attached && mounted) {
      setState(() {
        _rows.add(
          _EpcRow(
            epcLookup: epcKey ?? '—',
            rawPcUii: epcKey ?? '',
            readAt: _formatNow(),
            readExtras: [payload],
          ),
        );
      });
    }
  }

  Future<void> _start() async {
    if (_isReading) return;
    if (!_reader.supportsNativeRfid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'この画面は Android / iOS 実機（タグリーダー接続時）のみ利用できます。Windows 等のデスクトップでは RFID 非対応です。',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isReading = true);

    final okPerm = await _reader.requestBluetoothPermissions();
    final okConn = await _reader.isConnected();
    if (!mounted) return;
    if (!okPerm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth権限が必要です。')),
      );
      setState(() => _isReading = false);
      return;
    }
    if (!okConn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タグリーダーが未接続です。「タグリーダー接続」から接続してください。')),
      );
      setState(() => _isReading = false);
      return;
    }

    await _invSub?.cancel();
    await _eventSub?.cancel();

    _eventSub = _reader.events.listen(
      (e) {
        if (!mounted || !_isReading) return;
        if (e['type'] == 'read_tag_data') {
          _appendReadTagData(
            e['data'] as String?,
            e['epc'] as String?,
          );
        }
      },
      onError: (_) {},
    );

    _invSub = _reader.inventoryEpcStream.listen((inv) {
      if (!mounted || !_isReading) return;
      final lookup = inv.epcForLookup;
      if (_rows.any((r) => r.epcLookup == lookup)) return;

      setState(() {
        _rows.add(
          _EpcRow(
            epcLookup: lookup,
            rawPcUii: inv.epcPcUii,
            pcHex: inv.pcHex,
            uiiHex: inv.uiiHex,
            rssi: inv.rssi,
            channel: inv.channel,
            timeMs: inv.timeMs,
            readAt: _formatNow(),
          ),
        );
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
        const SnackBar(content: Text('読取開始に失敗しました。')),
      );
      await _invSub?.cancel();
      await _eventSub?.cancel();
      _invSub = null;
      _eventSub = null;
      setState(() => _isReading = false);
    }
  }

  Future<void> _toggle() async {
    if (_isReading) {
      await _stop();
    } else {
      await _start();
    }
  }

  void _clear() {
    setState(() => _rows.clear());
  }

  @override
  void dispose() {
    unawaited(_invSub?.cancel());
    unawaited(_eventSub?.cancel());
    unawaited(_reader.stopInventory());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF111111);
    const textSecondary = Color(0xFF424242);

    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppDesign.primaryButton,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MainFlowNavBar(
              showBackButton: widget.showBackButton,
              title: 'タグEPC読取・表示（テスト）',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                Text(
                  'タグ表面の文字（例: A00010000201）は、多くの場合 EPC の UII 部を16進で表したものです。'
                  '下の「表面表示」と一致すれば同じ番号です。',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade900, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  'USERメモリ・TID などは「在庫」だけでは送られないことがあります。'
                  'リーダー／SDK が readTag を実行するときに届くデータを、メモリ読取欄に追記します。',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _toggle,
                        icon: Icon(_isReading ? Icons.stop : Icons.play_arrow),
                        label: Text(_isReading ? '読取停止' : '読取開始'),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _isReading ? Colors.red.shade700 : AppDesign.primaryButton,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _rows.isEmpty ? null : _clear,
                      child: const Text('一覧クリア'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '検出: ${_rows.length} 件',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _rows.isEmpty
                      ? Center(
                          child: Text(
                            _reader.supportsNativeRfid
                                ? '読取開始後、タグをかざしてください。'
                                : 'Windows 等では利用できません。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _rows.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _rows[i];
                            final detail = <String>[
                              if (r.pcHex != null) 'PC: ${r.pcHex}',
                              if (r.uiiHex != null) 'UII(hex): ${r.uiiHex}',
                              'RAW(PC+UII): ${r.rawPcUii}',
                              if (r.rssi != null) 'RSSI: ${r.rssi}',
                              if (r.channel != null) 'CH: ${r.channel}',
                              if (r.timeMs != null) 'TIME(ms): ${r.timeMs}',
                              '時刻: ${r.readAt}',
                            ];

                            return Card(
                              margin: EdgeInsets.zero,
                              color: const Color(0xFFF5F5F5),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '表面表示（印字と同じ並びのことが多い）',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      r.surfaceStyleId,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '在庫読取（EPC）',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      r.epcLookup,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      detail.join('  ·  '),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade800,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (r.readExtras.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'メモリ読取（read_tag_data）',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      for (final line in r.readExtras)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: SelectableText(
                                            line,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              color: textSecondary,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }
}
