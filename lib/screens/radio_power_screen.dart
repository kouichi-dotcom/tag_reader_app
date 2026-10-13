import 'package:flutter/material.dart';

import '../models/output_mode.dart';
import '../services/radio_power_storage.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';

/// 出力設定画面（簡単設定：距離モード / 詳細設定：電波出力）
class RadioPowerScreen extends StatefulWidget {
  const RadioPowerScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<RadioPowerScreen> createState() => _RadioPowerScreenState();
}

const int _maxDecreaseDecibel = 30;
const int _defaultMaxDbm = 30;
const Color _outputTeal = Color(0xFF00897B);
const Color _outputTealBg = Color(0xFFE0F2F1);

class _RadioPowerScreenState extends State<RadioPowerScreen> {
  int _decreaseDecibel = 0;
  int _maxDbm = _defaultMaxDbm;

  OutputMode _selectedOutputMode = OutputMode.hand;
  OutputMode _appliedOutputMode = OutputMode.hand;

  final _reader = TagReaderService.instance;

  int get _currentDbm => _maxDbm - _decreaseDecibel;

  /// 0.0〜1.0（出力が強いほど 1 に近い）
  double get _powerRatio {
    if (_maxDbm <= 0) return 0;
    return (_currentDbm / _maxDbm).clamp(0.0, 1.0);
  }

  /// 距離モードを選択したが未適用
  bool get _hasPendingMode => _selectedOutputMode != _appliedOutputMode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _syncModeFromDbm() {
    final mode = OutputModeX.fromDbm(_currentDbm, maxDbm: _maxDbm);
    _selectedOutputMode = mode;
    _appliedOutputMode = mode;
  }

  Future<void> _load() async {
    var decrease = await RadioPowerStorage.getDecreaseDecibel();
    decrease = decrease.clamp(0, _maxDecreaseDecibel);
    var maxDbm = _defaultMaxDbm;

    if (_reader.supportsNativeRfid) {
      try {
        final connected = await _reader.isConnected();
        if (connected) {
          final deviceMax = await _reader.getMaxRadioPower();
          final deviceCurrent = await _reader.getRadioPower();
          if (deviceMax != null && deviceMax > 0) {
            maxDbm = deviceMax;
            if (deviceCurrent != null && deviceCurrent > 0) {
              decrease = (maxDbm - deviceCurrent).clamp(0, _maxDecreaseDecibel);
            }
          }
        }
      } catch (_) {
        // 実機から取得できなかった場合はローカル値のまま表示
      }
    }

    if (!mounted) return;
    setState(() {
      _maxDbm = maxDbm;
      _decreaseDecibel = decrease;
      _syncModeFromDbm();
    });
  }

  Future<void> _saveAndUpdate(int value) async {
    final clamped = value.clamp(0, _maxDecreaseDecibel);
    if (mounted) {
      setState(() {
        _decreaseDecibel = clamped;
        _syncModeFromDbm();
      });
    }
    await RadioPowerStorage.saveDecreaseDecibel(clamped);

    if (_reader.supportsNativeRfid) {
      try {
        final connected = await _reader.isConnected();
        if (!connected) return;
        final ok = await _reader.setRadioPower(clamped);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('電波出力の設定に失敗しました（リーダー接続状態を確認してください）。'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('電波出力の設定に失敗しました: $e')),
          );
        }
      }
    }
  }

  void _adjust(int delta) {
    _saveAndUpdate(_decreaseDecibel + delta);
  }

  Future<void> _onApplyPressed() async {
    if (!_hasPendingMode) return;
    final mode = _selectedOutputMode;
    if (mode == OutputMode.far && mode != _appliedOutputMode) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('遠距離に変更しますか？'),
          content: const Text(
            '出力を「遠距離」に変更します。\n周辺のタグも読み取る可能性があります。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('変更する'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _applyOutputMode(mode);
  }

  Future<void> _applyOutputMode(OutputMode mode) async {
    final targetDbm = mode.targetDbm;

    int maxDbm = _maxDbm;
    var connected = false;
    if (_reader.supportsNativeRfid) {
      try {
        connected = await _reader.isConnected();
        if (connected) {
          final deviceMaxDbm = await _reader.getMaxRadioPower();
          if (deviceMaxDbm != null && deviceMaxDbm > 0) {
            maxDbm = deviceMaxDbm;
          }
        }
      } catch (_) {
        // 読めなかった場合は現状のまま
      }
    }

    final decreaseDecibel = (maxDbm - targetDbm).clamp(0, _maxDecreaseDecibel);
    await RadioPowerStorage.saveDecreaseDecibel(decreaseDecibel);

    var appliedOk = true;
    String? errorMessage;
    if (_reader.supportsNativeRfid) {
      try {
        if (connected) {
          final ok = await _reader.setRadioPower(decreaseDecibel);
          appliedOk = ok;
          if (!ok) {
            errorMessage = '出力モードの反映に失敗しました（接続状態を確認してください）。';
          }
        }
      } catch (e) {
        appliedOk = false;
        errorMessage = '出力モードの反映に失敗しました: $e';
      }
    }

    if (!mounted) return;
    setState(() {
      _maxDbm = maxDbm;
      _decreaseDecibel = decreaseDecibel;
      _selectedOutputMode = mode;
      if (appliedOk) {
        _appliedOutputMode = mode;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(appliedOk ? '設定しました' : (errorMessage ?? '設定に失敗しました')),
      ),
    );
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasPendingMode) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('変更を破棄しますか？'),
        content: const Text('設定が変更されています。適用せずに戻りますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('破棄して戻る'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _onBackPressed() async {
    if (!await _confirmDiscardIfNeeded()) return;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _buildOutputModeSection() {
    const tileRadius = 10.0;
    const tilePadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);

    Widget tile(OutputMode m) {
      final selected = m == _selectedOutputMode;
      return InkWell(
        borderRadius: BorderRadius.circular(tileRadius),
        onTap: () => setState(() => _selectedOutputMode = m),
        child: Container(
          padding: tilePadding,
          decoration: BoxDecoration(
            color: selected ? _outputTealBg : Colors.white,
            borderRadius: BorderRadius.circular(tileRadius),
            border: Border.all(
              color: selected ? _outputTeal : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      m.mainLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      m.distanceHint,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? _outputTeal : Colors.grey.shade400,
                    width: 1.5,
                  ),
                  color: selected ? _outputTeal : Colors.transparent,
                ),
                child: Center(
                  child: Opacity(
                    opacity: selected ? 1 : 0,
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '出力モード（簡単設定）',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _hasPendingMode ? _onApplyPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _outputTeal,
                  disabledBackgroundColor: Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '適用',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '読み取りたい距離を選択してください',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.5,
            children: [
              tile(OutputMode.hand),
              tile(OutputMode.near),
              tile(OutputMode.mid),
              tile(OutputMode.far),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '※読み取り距離は目安です。タグや周囲の環境によって変化します。',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedPowerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '電波出力（詳細設定）',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '出力を上げると読み取り距離が伸びます',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 16),
        _PowerBarIndicator(
          ratio: _powerRatio,
          dbmLabel: '$_currentDbm dBm',
        ),
        const SizedBox(height: 8),
        Text(
          '数値が大きいほど出力が強くなります',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '出力を微調整',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'dBmを増減します',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StepButton(
              icon: Icons.keyboard_double_arrow_left,
              label: '−10',
              onPressed: () => _adjust(10),
            ),
            _StepButton(
              icon: Icons.chevron_left,
              label: '−1',
              onPressed: () => _adjust(1),
            ),
            _StepButton(
              icon: Icons.chevron_right,
              label: '＋1',
              onPressed: () => _adjust(-1),
            ),
            _StepButton(
              icon: Icons.keyboard_double_arrow_right,
              label: '＋10',
              onPressed: () => _adjust(-10),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasPendingMode,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscardIfNeeded()) {
          if (!mounted) return;
          nav.pop();
        }
      },
      child: Scaffold(
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
                    title: '出力設定',
                    onBack: _onBackPressed,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          _buildOutputModeSection(),
                          const SizedBox(height: 24),
                          _buildDetailedPowerSection(),
                          const SizedBox(height: 16),
                        ],
                      ),
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
}

/// 横棒インジケーター（弱い ← → 強い、現在値は dBm のみ）
class _PowerBarIndicator extends StatelessWidget {
  const _PowerBarIndicator({
    required this.ratio,
    required this.dbmLabel,
  });

  final double ratio;
  final String dbmLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              '弱い',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 18,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFFE0E0E0)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: ratio,
                        child: const ColoredBox(
                          color: AppDesign.radioPowerMeterGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '強い',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          dbmLabel,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppDesign.radioPowerMeterGreen,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
