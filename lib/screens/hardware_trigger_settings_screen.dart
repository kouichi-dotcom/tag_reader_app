import 'package:flutter/material.dart';

import '../services/connected_device_storage.dart';
import '../services/hardware_trigger_mode_storage.dart';
import '../services/reader_family.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';

/// タグリーダー本体の読み取りボタン（triggerStream）の解釈モード設定
class HardwareTriggerSettingsScreen extends StatefulWidget {
  const HardwareTriggerSettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<HardwareTriggerSettingsScreen> createState() =>
      _HardwareTriggerSettingsScreenState();
}

class _HardwareTriggerSettingsScreenState extends State<HardwareTriggerSettingsScreen> {
  HardwareTriggerMode _mode = HardwareTriggerMode.toggle;
  double _timedSeconds = HardwareTriggerModeStorage.timedSecondsDefault;
  ReaderFamily _readerFamily = ReaderFamily.unknown;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final connectedName = await ConnectedDeviceStorage.getName();
      final family = detectReaderFamilyFromName(connectedName);
      final forced = await HardwareTriggerModeStorage.forceToggleIfSr7AndHold();
      final m = forced ? HardwareTriggerMode.toggle : await HardwareTriggerModeStorage.getMode();
      final s = await HardwareTriggerModeStorage.getTimedSeconds();
      if (!mounted) return;
      setState(() {
        _mode = m;
        _timedSeconds = s;
        _readerFamily = family;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setMode(HardwareTriggerMode value) async {
    setState(() => _mode = value);
    await HardwareTriggerModeStorage.saveMode(value);
  }

  Future<void> _setTimedSeconds(double value) async {
    final snapped = HardwareTriggerModeStorage.snapToStep(value);
    setState(() => _timedSeconds = snapped);
    await HardwareTriggerModeStorage.saveTimedSeconds(snapped);
  }

  void _adjustTimedSeconds(double delta) {
    _setTimedSeconds(_timedSeconds + delta);
  }

  Widget _timedSecondsStepperButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: Colors.grey.shade400),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
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
                MainFlowNavBar(
                  showBackButton: widget.showBackButton,
                  title: 'タグリーダー本体の読み取りボタン設定',
                  onBack: () => Navigator.of(context).pop(),
                  titleMaxLines: 2,
                  titleStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            const Text(
                              'タグリーダー本体の読み取りボタン',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '画面内の「読取開始／読取停止」ボタンは常に切替式（トグル）です。',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            SegmentedButton<HardwareTriggerMode>(
                              segments: [
                                ButtonSegment<HardwareTriggerMode>(
                                  value: HardwareTriggerMode.toggle,
                                  label: Text('切替式'),
                                ),
                                ButtonSegment<HardwareTriggerMode>(
                                  value: HardwareTriggerMode.hold,
                                  label: Text('長押し式'),
                                  enabled: _readerFamily != ReaderFamily.sr7,
                                ),
                                ButtonSegment<HardwareTriggerMode>(
                                  value: HardwareTriggerMode.timed,
                                  label: Text('時間式'),
                                ),
                              ],
                              selected: <HardwareTriggerMode>{_mode},
                              onSelectionChanged: (values) {
                                final selected = values.isNotEmpty ? values.first : null;
                                if (selected != null) {
                                  _setMode(selected);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_readerFamily == ReaderFamily.sr7) ...[
                              Text(
                                'SR-7 接続中は「長押し式」は利用できません（切替式/時間式のみ）。',
                                style: TextStyle(fontSize: 13, color: Colors.orange.shade800, height: 1.4),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
                              _mode == HardwareTriggerMode.toggle
                                  ? '1回押すと読取ON、もう1回でOFF'
                                  : _mode == HardwareTriggerMode.hold
                                      ? '押している間だけ読取'
                                      : '押下で読取開始し、一定時間後に自動停止（再押下で時間延長）',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                            ),
                            if (_mode == HardwareTriggerMode.timed) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '自動停止までの秒数: ${HardwareTriggerModeStorage.formatTimedSeconds(_timedSeconds)} 秒',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  _timedSecondsStepperButton(
                                    label: '∧',
                                    onPressed: _timedSeconds >=
                                            HardwareTriggerModeStorage.timedSecondsMax
                                        ? null
                                        : () => _adjustTimedSeconds(
                                              HardwareTriggerModeStorage.timedSecondsStep,
                                            ),
                                  ),
                                  const SizedBox(width: 4),
                                  _timedSecondsStepperButton(
                                    label: '∨',
                                    onPressed: _timedSeconds <=
                                            HardwareTriggerModeStorage.timedSecondsMin
                                        ? null
                                        : () => _adjustTimedSeconds(
                                              -HardwareTriggerModeStorage.timedSecondsStep,
                                            ),
                                  ),
                                ],
                              ),
                              Slider(
                                min: HardwareTriggerModeStorage.timedSecondsMin,
                                max: HardwareTriggerModeStorage.timedSecondsMax,
                                divisions: ((HardwareTriggerModeStorage.timedSecondsMax -
                                            HardwareTriggerModeStorage.timedSecondsMin) /
                                        HardwareTriggerModeStorage.timedSecondsStep)
                                    .round(),
                                value: _timedSeconds.clamp(
                                  HardwareTriggerModeStorage.timedSecondsMin,
                                  HardwareTriggerModeStorage.timedSecondsMax,
                                ),
                                label:
                                    '${HardwareTriggerModeStorage.formatTimedSeconds(_timedSeconds)} 秒',
                                onChanged: _setTimedSeconds,
                              ),
                            ],
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
}
