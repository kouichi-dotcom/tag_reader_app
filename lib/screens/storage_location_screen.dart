import 'package:flutter/material.dart';

import '../models/storage_location_mode.dart';
import '../services/storage_location_catalog.dart';
import '../services/storage_location_storage.dart';
import '../theme/app_design.dart';
import '../widgets/main_flow_nav_bar.dart';

/// 保管場所選択画面
/// GPS自動判定 / 手動の切替。手動時のみドロップダウンで保管場所を選ぶ。
/// 上部「現在の設定」は端末のモード・手動選択値（DB の保管場所コードとは別）。
class StorageLocationScreen extends StatefulWidget {
  const StorageLocationScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<StorageLocationScreen> createState() => _StorageLocationScreenState();
}

class _StorageLocationScreenState extends State<StorageLocationScreen> {
  StorageLocationMode _mode = StorageLocationMode.gpsAuto;
  String? _manualName;
  bool _loading = true;

  /// 端末の現在設定（モード＋手動選択）。DB 値は使わない。
  String get _currentSettingLabel {
    if (_mode == StorageLocationMode.gpsAuto) {
      return 'GPS自動判定';
    }
    final name = StorageLocationCatalog.names.contains(_manualName)
        ? _manualName!
        : '未選択';
    return '手動・$name';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await StorageLocationStorage.getMode();
    final manual = await StorageLocationStorage.getName();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _manualName = manual;
      _loading = false;
    });
  }

  Future<void> _setMode(StorageLocationMode mode) async {
    await StorageLocationStorage.saveMode(mode);
    if (!mounted) return;
    setState(() => _mode = mode);
  }

  Future<void> _setManualName(String? name) async {
    if (name == null || name.isEmpty) return;
    await StorageLocationStorage.save(name);
    if (!mounted) return;
    setState(() => _manualName = name);
  }

  @override
  Widget build(BuildContext context) {
    final manualValue =
        StorageLocationCatalog.names.contains(_manualName) ? _manualName : null;

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
                  title: '保管場所選択',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          children: [
                            Text(
                              '現在の設定：$_currentSettingLabel',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF222222),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'タグ更新時に使用する保管場所設定',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              '保管場所の設定方法',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF444444),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SegmentedButton<StorageLocationMode>(
                              segments: const [
                                ButtonSegment<StorageLocationMode>(
                                  value: StorageLocationMode.gpsAuto,
                                  label: Text('GPS自動判定'),
                                ),
                                ButtonSegment<StorageLocationMode>(
                                  value: StorageLocationMode.manual,
                                  label: Text('手動'),
                                ),
                              ],
                              selected: <StorageLocationMode>{_mode},
                              onSelectionChanged: (values) {
                                final selected =
                                    values.isNotEmpty ? values.first : null;
                                if (selected != null) {
                                  _setMode(selected);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _mode == StorageLocationMode.gpsAuto
                                  ? 'タグ更新時に現在地から保管場所を判定します'
                                  : '選択した保管場所をタグ更新時に記録します',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                            if (_mode == StorageLocationMode.manual) ...[
                              const SizedBox(height: 24),
                              const Text(
                                '保管場所',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF444444),
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                key: ValueKey(manualValue ?? 'none'),
                                initialValue: manualValue,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                hint: const Text('保管場所を選択'),
                                items: [
                                  for (final name
                                      in StorageLocationCatalog.names)
                                    DropdownMenuItem(
                                      value: name,
                                      child: Text(name),
                                    ),
                                ],
                                onChanged: _setManualName,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ここで選んだ場所は、次回のタグ更新時に記録されます',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
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
