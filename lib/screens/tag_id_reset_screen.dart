import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/inventory_epc.dart';
import '../services/product_cache.dart';
import '../services/radio_power_storage.dart';
import '../services/tag_ledger_cache.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';
import '../utils/api_error_presenter.dart';
import '../utils/epc_generator.dart';
import '../widgets/main_flow_nav_bar.dart';
import '../widgets/reader_not_connected_dialog.dart';

/// 設定 > タグ設定 > タグID再設定
/// 読取したタグの EPC を自社規則（c0de0038 + 日時）へ書き換える。
class TagIdResetScreen extends StatefulWidget {
  const TagIdResetScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<TagIdResetScreen> createState() => _TagIdResetScreenState();
}

class _TagIdResetScreenState extends State<TagIdResetScreen> {
  /// この画面の目標出力（密着前提で範囲を狭くする）
  static const int _targetPowerDbm = 5;

  final _reader = TagReaderService.instance;
  StreamSubscription<InventoryEpc>? _invSub;

  bool _isReading = false;
  bool _isBusy = false;

  String? _currentEpc;
  int? _productCode;
  int? _number;
  String? _productName;
  bool _ledgerHit = false;
  String? _statusMessage;

  @override
  void dispose() {
    unawaited(_stopReading(restorePower: true));
    super.dispose();
  }

  /// 目標 dBm になるよう減衰量を計算して設定する。
  Future<void> _applyTargetPowerDbm(int targetDbm) async {
    if (!_reader.supportsNativeRfid) return;
    try {
      final connected = await _reader.isConnected();
      if (!connected) return;
      final max = await _reader.getMaxRadioPower() ?? 30;
      final decrease = (max - targetDbm).clamp(0, 30);
      await _reader.setRadioPower(decrease);
    } catch (_) {}
  }

  Future<void> _restoreUserPower() async {
    if (!_reader.supportsNativeRfid) return;
    try {
      final connected = await _reader.isConnected();
      if (!connected) return;
      final saved = await RadioPowerStorage.getDecreaseDecibel();
      await _reader.setRadioPower(saved.clamp(0, 30));
    } catch (_) {}
  }

  Future<void> _stopReading({required bool restorePower}) async {
    await _invSub?.cancel();
    _invSub = null;
    if (_reader.supportsNativeRfid) {
      try {
        await _reader.stopInventory();
      } catch (_) {}
    }
    if (restorePower) {
      await _restoreUserPower();
    }
    if (mounted) setState(() => _isReading = false);
  }

  Future<void> _startReading() async {
    if (_isReading || _isBusy) return;
    if (!_reader.supportsNativeRfid) {
      _snack('この機能は Android / iOS 実機のタグリーダー接続時のみ利用できます');
      return;
    }
    final okPerm = await _reader.requestBluetoothPermissions();
    if (!okPerm) {
      _snack('Bluetooth権限が必要です');
      return;
    }
    final connected = await _reader.isConnected();
    if (!connected) {
      await showReaderNotConnectedDialog(context);
      return;
    }

    await TagLedgerCache.instance.init();
    await ProductCache.instance.init();

    await _applyTargetPowerDbm(_targetPowerDbm);

    _invSub = _reader.inventoryEpcStream.listen((inv) {
      final epc = inv.epcForLookup.trim().toLowerCase();
      if (epc.isEmpty) return;
      if (_currentEpc == epc) return;
      unawaited(_onEpcRead(epc));
    });

    final started = await _reader.startInventory(noRepeat: true);
    if (!started) {
      await _invSub?.cancel();
      _invSub = null;
      await _restoreUserPower();
      _snack('読取を開始できませんでした');
      return;
    }
    if (mounted) {
      setState(() {
        _isReading = true;
        _statusMessage = '読取中… タグを読取部に密着させてください';
      });
    }
  }

  Future<void> _onEpcRead(String epc) async {
    await TagLedgerCache.instance.init();
    final entry = TagLedgerCache.instance.lookup(epc);
    String? name;
    if (entry?.productCode != null) {
      name = ProductCache.instance
          .getNameFromMemory(entry!.productCode!.toString());
    }

    if (kUseApi && (entry == null || name == null || name.isEmpty)) {
      try {
        final api = ApiClient(baseUrl: kApiBaseUrl);
        final p = await api.fetchProduct(epc);
        if (p != null) {
          await TagLedgerCache.instance.put(
            epc,
            productCode: p.productCode,
            number: p.number,
          );
          if (mounted) {
            setState(() {
              _currentEpc = epc;
              _productCode = p.productCode;
              _number = p.number;
              _productName = p.productName;
              _ledgerHit = true;
              _statusMessage = 'タグを認識しました';
            });
          }
          return;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _currentEpc = epc;
      _productCode = entry?.productCode;
      _number = entry?.number;
      _productName = name;
      _ledgerHit = entry != null;
      _statusMessage = entry != null ? 'タグを認識しました' : '台帳未登録のタグです（再設定は可能）';
    });
  }

  Future<bool> _isEpcTaken(String epc) async {
    if (TagLedgerCache.instance.containsEpc(epc)) return true;
    if (!kUseApi) return false;
    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      final p = await api.fetchProduct(epc);
      return p != null;
    } catch (_) {
      // API 不通時はキャッシュのみで続行（確認ダイアログで注記）
      return false;
    }
  }

  Future<void> _onResetPressed() async {
    final current = _currentEpc;
    if (current == null || current.isEmpty) {
      _snack('先にタグを読み取ってください');
      return;
    }
    if (_isBusy) return;

    setState(() => _isBusy = true);
    await _stopReading(restorePower: false);

    late final String newEpc;
    final apiChecked = kUseApi;
    try {
      String? found;
      for (var i = 0; i < EpcGenerator.maxCollisionRetries; i++) {
        final candidate = EpcGenerator.generate(
          at: DateTime.now().add(Duration(milliseconds: 10 * i)),
        );
        if (!await _isEpcTaken(candidate)) {
          found = candidate;
          break;
        }
      }
      if (found == null) {
        throw StateError('一意な EPC を確保できませんでした');
      }
      newEpc = found;
    } catch (e, st) {
      logApiError(e, apiName: 'epc-generate', stackTrace: st);
      await _restoreUserPower();
      if (mounted) setState(() => _isBusy = false);
      _snack(toUserFacingApiError(e).displayText);
      return;
    }

    if (!mounted) return;
    final confirmed = await _confirmReset(
      currentEpc: current,
      newEpc: newEpc,
      apiChecked: apiChecked,
    );
    if (!confirmed) {
      await _restoreUserPower();
      if (mounted) setState(() => _isBusy = false);
      return;
    }

    await _performWrite(currentEpc: current, newEpc: newEpc);
  }

  Future<bool> _confirmReset({
    required String currentEpc,
    required String newEpc,
    required bool apiChecked,
  }) async {
    final codeLabel = _productCode?.toString() ?? '—';
    final numberLabel = _number?.toString() ?? '—';
    final nameLabel = (_productName != null && _productName!.isNotEmpty)
        ? _productName!
        : (_ledgerHit ? '—' : '未登録');

    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('タグIDを変更しますか？'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '読取部に密着した1枚だけが対象です。周囲に他のタグを置かないでください。',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text('変更前のタグID:\n$currentEpc',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(height: 8),
              Text('変更後のタグID:\n$newEpc',
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                '【重要】変更後のタグIDには、商品コード・番号・商品名は結びつきません。'
                'このタグは商品未登録の状態になります。'
                '（もともと正しいタグ側の商品情報はそのまま残ります）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBF360C),
                ),
              ),
              const SizedBox(height: 12),
              Text('いま読んでいるタグに表示されている商品情報（参考）',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text('商品コード: $codeLabel'),
              Text('番号: $numberLabel'),
              Text('商品名: $nameLabel'),
              if (!apiChecked) ...[
                const SizedBox(height: 8),
                const Text(
                  '※ API 未接続のため、端末キャッシュのみで重複確認しています。',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('変更する'),
          ),
        ],
      ),
    );
    return go == true;
  }

  /// 書込み後に inventory で新 EPC を再読取し、実タグへ反映されたか確認する。
  Future<bool> _verifyWrittenEpc(
    String expectedEpc, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final expected = expectedEpc.trim().toLowerCase();
    if (expected.isEmpty) return false;

    await _applyTargetPowerDbm(_targetPowerDbm);

    final completer = Completer<bool>();
    late final StreamSubscription<InventoryEpc> sub;
    sub = _reader.inventoryEpcStream.listen((inv) {
      final epc = inv.epcForLookup.trim().toLowerCase();
      if (epc.isEmpty) return;
      if (epc == expected && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    final started = await _reader.startInventory(noRepeat: true);
    if (!started) {
      await sub.cancel();
      return false;
    }

    try {
      return await completer.future.timeout(timeout, onTimeout: () => false);
    } finally {
      await sub.cancel();
      try {
        await _reader.stopInventory();
      } catch (_) {}
    }
  }

  Future<void> _performWrite({
    required String currentEpc,
    required String newEpc,
  }) async {
    if (!_reader.supportsNativeRfid) {
      await _restoreUserPower();
      if (mounted) setState(() => _isBusy = false);
      _snack('実機のタグリーダーが必要です');
      return;
    }

    if (mounted) {
      setState(() => _statusMessage = '書込み中… タグを密着させたままお待ちください');
    }

    await _applyTargetPowerDbm(_targetPowerDbm);

    // 公式サンプル同様マスクなし。5dBm＋密着で誤書込を抑える。
    await _reader.writeEpc(
      currentEpc: currentEpc,
      newEpc: newEpc,
      useMask: false,
      timeout: const Duration(seconds: 15),
    );

    // SDK の書込み成功イベントだけでは不十分な場合があるため、再読取で確定する。
    if (mounted) {
      setState(() =>
          _statusMessage = '確認中… タグをリーダーに近づけたままお待ちください');
    }
    final verified = await _verifyWrittenEpc(newEpc);

    await _restoreUserPower();

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (verified) {
      // 原本の EPC×商品 はノータッチ。新 EPC は未紐付けのまま（キャッシュにも載せない）
      setState(() {
        _currentEpc = newEpc;
        _productCode = null;
        _number = null;
        _productName = null;
        _ledgerHit = false;
        _statusMessage = '再設定が完了しました（商品未紐付け）';
      });
      _snack('タグIDを再設定しました。このタグは商品未紐付けです');
    } else {
      setState(() => _statusMessage =
          '失敗しました。タグをリーダーに近づけてください。');
      _snack('再設定に失敗しました。タグをリーダーに近づけて再試行してください');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final epc = _currentEpc;
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
                  title: 'タグID再設定',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '出力は ${_targetPowerDbm} dBm（近距離）です。タグを読取部に密着させ、周囲に他のタグを置かないでください。',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isBusy
                                  ? null
                                  : (_isReading
                                      ? () => _stopReading(restorePower: true)
                                      : _startReading),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isReading
                                    ? Colors.grey.shade600
                                    : AppDesign.primaryButton,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_isReading ? '読取停止' : '読取開始'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage ??
                            (_isReading ? '読取中…' : '停止中'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('現在のタグ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      _infoCard(
                        children: [
                          _labelValue(
                            'タグID',
                            epc ?? '（未読取）',
                            mono: true,
                          ),
                          _labelValue(
                            '商品コード',
                            _productCode?.toString() ??
                                (epc == null ? '—' : '未登録'),
                          ),
                          _labelValue(
                            '番号',
                            _number?.toString() ??
                                (epc == null ? '—' : '未登録'),
                          ),
                          _labelValue(
                            '商品名',
                            _productName?.isNotEmpty == true
                                ? _productName!
                                : (epc == null
                                    ? '—'
                                    : (_ledgerHit ? '—' : '未登録')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: (_isBusy || epc == null) ? null : _onResetPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isBusy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('再設定', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '重複が発覚した側のタグ向けです。再設定後のタグIDには商品コード・番号・商品名は結びつかず、原本の商品情報はそのまま残ります。\n'
                        '再設定を押した時刻で新しいタグID（c0de0038＋日時）を自動生成します。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _labelValue(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 14,
              fontFamily: mono ? 'monospace' : null,
              fontWeight: mono ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
