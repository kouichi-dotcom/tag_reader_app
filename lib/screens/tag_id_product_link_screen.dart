import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/inventory_epc.dart';
import '../models/tag_ledger_register.dart';
import '../services/employee_storage.dart';
import '../services/product_cache.dart';
import '../services/radio_power_storage.dart';
import '../services/tag_ledger_cache.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';
import '../widgets/reader_not_connected_dialog.dart';

/// 設定 > タグ設定 > タグID×商品コード×番号　設定
/// 1枚読取 → 商品コード・番号（または自動連番）→ 確認 → [ICタグ台帳] へ登録。
class TagIdProductLinkScreen extends StatefulWidget {
  const TagIdProductLinkScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<TagIdProductLinkScreen> createState() => _TagIdProductLinkScreenState();
}

class _TagIdProductLinkScreenState extends State<TagIdProductLinkScreen> {
  static const int _targetPowerDbm = 5;

  final _reader = TagReaderService.instance;
  final _productCodeController = TextEditingController();
  final _numberController = TextEditingController();

  StreamSubscription<InventoryEpc>? _invSub;

  bool _isReading = false;
  bool _isBusy = false;
  bool _autoNumber = true;

  String? _currentEpc;
  bool _ledgerHit = false;
  int? _existingProductCode;
  int? _existingNumber;
  String? _productName;
  String? _statusMessage;

  @override
  void dispose() {
    unawaited(_stopReading(restorePower: true));
    _productCodeController.dispose();
    _numberController.dispose();
    super.dispose();
  }

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
              _ledgerHit = true;
              _existingProductCode = p.productCode;
              _existingNumber = p.number;
              _productName = p.productName;
              _statusMessage =
                  '既に台帳登録あり（変更不可）。既存の組み合わせ変更はPCのレンタル商品管理を使ってください';
            });
          }
          return;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _currentEpc = epc;
      _ledgerHit = entry != null;
      _existingProductCode = entry?.productCode;
      _existingNumber = entry?.number;
      _productName = name;
      _statusMessage = entry != null
          ? '既に台帳登録あり（変更不可）。既存の組み合わせ変更はPCのレンタル商品管理を使ってください'
          : 'タグを認識しました（未登録・新規登録できます）';
    });
  }

  Future<void> _lookupProductName() async {
    final code = int.tryParse(_productCodeController.text.trim());
    if (code == null || code <= 0) {
      setState(() => _productName = null);
      return;
    }
    await ProductCache.instance.init();
    var name = ProductCache.instance.getNameFromMemory(code.toString());
    if ((name == null || name.isEmpty) && kUseApi) {
      try {
        final item = await ApiClient(baseUrl: kApiBaseUrl).fetchProductByCode(code);
        name = item?.productName;
      } catch (_) {}
    }
    if (mounted) setState(() => _productName = name);
  }

  Future<void> _onRegisterPressed() async {
    final epc = _currentEpc;
    if (epc == null || epc.isEmpty) {
      _snack('先にタグを読み取ってください');
      return;
    }
    if (_ledgerHit) {
      _snack(
        'このタグは既に台帳登録済みです。既存の組み合わせ変更はPCのレンタル商品管理から行ってください',
      );
      return;
    }
    if (_isBusy) return;

    final code = int.tryParse(_productCodeController.text.trim());
    if (code == null || code <= 0) {
      _snack('商品コードを入力してください');
      return;
    }

    int? number;
    if (!_autoNumber) {
      number = int.tryParse(_numberController.text.trim());
      if (number == null || number <= 0) {
        _snack('個体番号を入力するか、「個体番号を自動で割り振る」にチェックしてください');
        return;
      }
    }

    final staffName = await EmployeeStorage.getName();
    final staffCode = await EmployeeStorage.getCode();
    if (staffName == null || staffName.isEmpty) {
      _snack('先に設定で担当者コードを入力してください');
      return;
    }

    if (!kUseApi) {
      _snack('API 未接続のため登録できません');
      return;
    }

    setState(() => _isBusy = true);
    await _stopReading(restorePower: false);

    int previewNumber = number ?? 0;
    if (_autoNumber) {
      try {
        previewNumber =
            await ApiClient(baseUrl: kApiBaseUrl).fetchNextTagNumber(code);
      } catch (e) {
        await _restoreUserPower();
        if (mounted) setState(() => _isBusy = false);
        _snack('次の個体番号の取得に失敗しました: $e');
        return;
      }
    }

    if (!mounted) return;
    final confirmed = await _confirmRegister(
      epc: epc,
      productCode: code,
      number: previewNumber,
      autoNumber: _autoNumber,
      productName: _productName,
      staffName: staffName,
    );
    if (!confirmed) {
      await _restoreUserPower();
      if (mounted) setState(() => _isBusy = false);
      return;
    }

    try {
      final result = await ApiClient(baseUrl: kApiBaseUrl).registerTagLedger(
        TagLedgerRegisterRequest(
          epc: epc,
          productCode: code,
          number: _autoNumber ? null : number,
          autoNumber: _autoNumber,
          userId: staffCode,
          userName: staffName,
        ),
      );
      await TagLedgerCache.instance.put(
        result.tagId2,
        productCode: result.productCode,
        number: result.number,
      );
      if (!mounted) return;
      setState(() {
        _ledgerHit = true;
        _existingProductCode = result.productCode;
        _existingNumber = result.number;
        _statusMessage = '登録完了（個体番号: ${result.number}）';
        _isBusy = false;
      });
      await _restoreUserPower();
      _snack('台帳に登録しました（個体番号: ${result.number}）');
    } catch (e) {
      await _restoreUserPower();
      if (mounted) setState(() => _isBusy = false);
      _snack('$e');
    }
  }

  Future<bool> _confirmRegister({
    required String epc,
    required int productCode,
    required int number,
    required bool autoNumber,
    required String? productName,
    required String staffName,
  }) async {
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('新規登録しますか？'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '未登録のタグIDへ、商品コードと個体番号を新規登録します。',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                '読取部に密着した1枚だけが対象です。',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text('タグID:\n$epc',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(height: 8),
              Text('商品コード: $productCode'),
              Text(
                autoNumber
                    ? '個体番号: $number（自動で割り振ります）'
                    : '個体番号: $number',
              ),
              Text(
                '商品名: ${(productName != null && productName.isNotEmpty) ? productName : '—'}',
              ),
              Text('担当者: $staffName'),
              const SizedBox(height: 8),
              const Text(
                'tag_mode2 は「登録」で ICタグ台帳へ追加します。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
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
            child: const Text('登録する'),
          ),
        ],
      ),
    );
    return go == true;
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
                  title: 'タグID×商品コード×番号　設定',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'この画面は「未登録のタグID」への新規登録専用です。\n'
                          '既存のタグID×商品コード×番号の変更は、PCのレンタル商品管理から行ってください。\n'
                          '出力は $_targetPowerDbm dBm（近距離）です。タグを1枚だけ密着させて読み取ってください。',
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
                        _statusMessage ?? (_isReading ? '読取中…' : '停止中'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '読取タグ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      _infoCard(
                        children: [
                          _labelValue('タグID', epc ?? '（未読取）', mono: true),
                          if (_ledgerHit) ...[
                            _labelValue(
                              '登録済 商品コード',
                              _existingProductCode?.toString() ?? '—',
                            ),
                            _labelValue(
                              '登録済 個体番号',
                              _existingNumber?.toString() ?? '—',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _productCodeController,
                        enabled: !_isBusy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: '商品コード',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => unawaited(_lookupProductName()),
                      ),
                      if (_productName != null && _productName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '商品名: $_productName',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('個体番号を自動で割り振る'),
                        subtitle: const Text(
                          '同じ商品コードのうち、いちばん大きい個体番号の次の番号を割り当てます',
                        ),
                        value: _autoNumber,
                        onChanged: _isBusy
                            ? null
                            : (v) {
                                setState(() {
                                  _autoNumber = v ?? true;
                                });
                              },
                      ),
                      if (!_autoNumber) ...[
                        const SizedBox(height: 4),
                        TextField(
                          controller: _numberController,
                          enabled: !_isBusy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: '個体番号',
                            helperText: 'この商品のなかでの通し番号（手入力）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: (_isBusy || epc == null || _ledgerHit)
                            ? null
                            : _onRegisterPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
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
                            : Text(
                                _ledgerHit ? '設定（登録済みのため不可）' : '新規登録',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _ledgerHit
                            ? 'このタグIDは既に登録済みです。既存の組み合わせを変更する場合は、PCのレンタル商品管理を使ってください。'
                            : '未登録のタグIDのみ新規登録できます。確認ダイアログのあと ICタグ台帳へ追加されます（tag_mode2＝登録）。\n'
                                '既存の組み合わせ変更は PC のレンタル商品管理から行ってください。',
                        style: TextStyle(
                          fontSize: 12,
                          color: _ledgerHit
                              ? const Color(0xFFBF360C)
                              : Colors.grey.shade600,
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
