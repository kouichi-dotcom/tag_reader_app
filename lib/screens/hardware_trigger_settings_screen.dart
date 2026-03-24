import 'package:flutter/material.dart';

import '../services/hardware_trigger_mode_storage.dart';
import '../theme/app_design.dart';

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
  double _timedSeconds = HardwareTriggerModeStorage.timedSecondsDefault.toDouble();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await HardwareTriggerModeStorage.getMode();
    final s = await HardwareTriggerModeStorage.getTimedSeconds();
    if (!mounted) return;
    setState(() {
      _mode = m;
      _timedSeconds = s.toDouble();
      _loading = false;
    });
  }

  Future<void> _setMode(HardwareTriggerMode value) async {
    setState(() => _mode = value);
    await HardwareTriggerModeStorage.saveMode(value);
  }

  Future<void> _setTimedSeconds(double value) async {
    final i = value.round();
    setState(() => _timedSeconds = value);
    await HardwareTriggerModeStorage.saveTimedSeconds(i);
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
                  title: 'タグリーダー本体の読み取りボタン設定',
                  onBack: () => Navigator.of(context).pop(),
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
                              segments: const [
                                ButtonSegment<HardwareTriggerMode>(
                                  value: HardwareTriggerMode.toggle,
                                  label: Text('切替式'),
                                ),
                                ButtonSegment<HardwareTriggerMode>(
                                  value: HardwareTriggerMode.hold,
                                  label: Text('長押し式'),
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
                              Text(
                                '自動停止までの秒数: ${_timedSeconds.round()} 秒',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Slider(
                                min: HardwareTriggerModeStorage.timedSecondsMin.toDouble(),
                                max: HardwareTriggerModeStorage.timedSecondsMax.toDouble(),
                                divisions: HardwareTriggerModeStorage.timedSecondsMax -
                                    HardwareTriggerModeStorage.timedSecondsMin,
                                value: _timedSeconds.clamp(
                                  HardwareTriggerModeStorage.timedSecondsMin.toDouble(),
                                  HardwareTriggerModeStorage.timedSecondsMax.toDouble(),
                                ),
                                label: '${_timedSeconds.round()} 秒',
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
                child: const Text('← 戻る', style: TextStyle(fontSize: 16)),
              )
            else
              const SizedBox(width: 100),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.2,
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
