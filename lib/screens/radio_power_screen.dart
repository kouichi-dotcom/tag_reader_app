import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/tag_reader_service.dart';
import '../services/radio_power_storage.dart';
import '../theme/app_design.dart';

/// 電波強度画面（メーターUI・既定値に戻す・±10/±1 ボタン）
class RadioPowerScreen extends StatefulWidget {
  const RadioPowerScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<RadioPowerScreen> createState() => _RadioPowerScreenState();
}

const int _maxDecreaseDecibel = 30;
const int _defaultMaxDbm = 30;

class _RadioPowerScreenState extends State<RadioPowerScreen> {
  int _decreaseDecibel = 0;
  int _maxDbm = _defaultMaxDbm;

  final _reader = TagReaderService.instance;

  int get _currentDbm => _maxDbm - _decreaseDecibel;

  double get _currentMw => math.pow(10, _currentDbm / 10.0).toDouble();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // まずローカル保存値を読み出し
    var decrease = await RadioPowerStorage.getDecreaseDecibel();
    decrease = decrease.clamp(0, _maxDecreaseDecibel);
    var maxDbm = _defaultMaxDbm;

    // Android 実機かつ接続済みなら、リーダーから現在値／最大値を取得して上書き
    if (_reader.isAndroid) {
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
    });
  }

  Future<void> _saveAndUpdate(int value) async {
    final clamped = value.clamp(0, _maxDecreaseDecibel);
    if (mounted) {
      setState(() => _decreaseDecibel = clamped);
    }
    await RadioPowerStorage.saveDecreaseDecibel(clamped);

    if (_reader.isAndroid) {
      try {
        final connected = await _reader.isConnected();
        if (!connected) return;
        final ok = await _reader.setRadioPower(clamped);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('電波強度の設定に失敗しました（リーダー接続状態を確認してください）。')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('電波強度の設定に失敗しました: $e')),
          );
        }
      }
    }
  }

  void _adjust(int delta) {
    _saveAndUpdate(_decreaseDecibel + delta);
  }

  void _resetToDefault() {
    _saveAndUpdate(0);
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
                  title: '電波強度',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _RadioPowerMeter(decreaseDecibel: _decreaseDecibel),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_currentDbm',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const Text(
                                    'dBm',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatMw(_currentMw),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const Text(
                                    'mW',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _resetToDefault,
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFFE0E0E0),
                                      foregroundColor: const Color(0xFF333333),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('既定値に戻す'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StepButton(
                              icon: Icons.keyboard_double_arrow_left,
                              label: '-10',
                              onPressed: () => _adjust(10),
                            ),
                            _StepButton(
                              icon: Icons.chevron_left,
                              label: '-1',
                              onPressed: () => _adjust(1),
                            ),
                            _StepButton(
                              icon: Icons.chevron_right,
                              label: '+1',
                              onPressed: () => _adjust(-1),
                            ),
                            _StepButton(
                              icon: Icons.keyboard_double_arrow_right,
                              label: '+10',
                              onPressed: () => _adjust(-10),
                            ),
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
      ),
    );
  }

  String _formatMw(double mw) {
    if (mw >= 100) return mw.toStringAsFixed(0);
    if (mw >= 10) return mw.toStringAsFixed(1);
    if (mw >= 1) return mw.toStringAsFixed(2);
    return mw.toStringAsFixed(2);
  }
}

/// 円形メーター（減衰量に応じて塗りつぶし。出力が強いほど緑が多い）
class _RadioPowerMeter extends StatelessWidget {
  const _RadioPowerMeter({required this.decreaseDecibel});

  final int decreaseDecibel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(260, 260),
      painter: _RadioPowerMeterPainter(
        filledRatio: (_maxDecreaseDecibel - decreaseDecibel) / _maxDecreaseDecibel,
      ),
    );
  }
}

class _RadioPowerMeterPainter extends CustomPainter {
  _RadioPowerMeterPainter({required this.filledRatio});

  final double filledRatio;

  static const Color _fillColor = AppDesign.radioPowerMeterGreen;
  static const Color _trackColor = Color(0xFFE0E0E0);

  /// 下部を欠けた円：弧の総角度（約270°）、下端にギャップ
  static const double _gapRad = math.pi / 2; // 90°のギャップ
  static const double _totalSweepRad = 2 * math.pi - _gapRad; // 約270°

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 欠けた円の開始角：下端ギャップの左端から時計回りに描く（下端中央が空く）
    const startAngle = math.pi / 2 + _gapRad / 2; // 135°（左下あたり）から

    // 背景弧（グレー）— 欠けた円の全体
    final trackPaint = Paint()
      ..color = _trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, _totalSweepRad, false, trackPaint);

    // 塗りつぶし弧（緑）。弧の左側から filledRatio だけ
    final fillPaint = Paint()
      ..color = _fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fillSweep = _totalSweepRad * filledRatio;
    canvas.drawArc(rect, startAngle, fillSweep, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _RadioPowerMeterPainter oldDelegate) {
    return oldDelegate.filledRatio != filledRatio;
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
                child: const Text('← メインに戻る', style: TextStyle(fontSize: 16)),
              )
            else
              const SizedBox(width: 100),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 100),
          ],
        ),
      ),
    );
  }
}
