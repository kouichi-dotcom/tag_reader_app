import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../services/connected_device_storage.dart';
import '../services/employee_cache.dart';
import '../services/tag_reader_service.dart';
import '../services/employee_storage.dart';
import '../services/product_cache.dart';
import '../services/radio_power_storage.dart';
import '../services/storage_location_storage.dart';
import '../services/tag_ledger_cache.dart';
import '../theme/app_design.dart';
import 'device_connection_screen.dart';
import 'settings_screen.dart';
import 'slip_load_screen.dart';
import 'storage_location_screen.dart';
import 'tag_list_screen.dart';

enum _OutputMode { hand, near, mid, far }

extension on _OutputMode {
  String get mainLabel {
    switch (this) {
      case _OutputMode.hand:
        return '手元';
      case _OutputMode.near:
        return '近距離';
      case _OutputMode.mid:
        return '中距離';
      case _OutputMode.far:
        return '遠距離';
    }
  }

  String get subLabel {
    switch (this) {
      case _OutputMode.hand:
        return '（3-5）';
      case _OutputMode.near:
        return '（15-30）';
      case _OutputMode.mid:
        return '（30-50）';
      case _OutputMode.far:
        return '（最大1m20）';
    }
  }

  /// ターゲットdBm目安（内部変換用）
  int get targetDbm {
    switch (this) {
      case _OutputMode.hand:
        return 4; // 3-5 の中間
      case _OutputMode.near:
        return 15;
      case _OutputMode.mid:
        return 20;
      case _OutputMode.far:
        return 30;
    }
  }
}

/// メイン画面（design/index.html 準拠）
/// タグリーダー接続・タグ読み取り・伝票一覧・従業員コード入力・設定への入口
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _employeeName;
  String? _connectedDeviceName;
  String? _storageLocationName;

  static const Color _outputTeal = Color(0xFF00897B);
  static const Color _outputTealBg = Color(0xFFE0F2F1);

  final _reader = TagReaderService.instance;

  _OutputMode _selectedOutputMode = _OutputMode.hand;

  Future<void> _loadEmployee() async {
    final name = await EmployeeStorage.getName();
    if (mounted) setState(() => _employeeName = name);
  }

  Future<void> _loadConnectedDevice() async {
    final name = await ConnectedDeviceStorage.getName();
    // Android: 実態が未接続なら表示を合わせる（アプリ再起動後など）
    if (name != null &&
        name.isNotEmpty &&
        TagReaderService.instance.supportsNativeRfid &&
        !(await TagReaderService.instance.isConnected())) {
      await ConnectedDeviceStorage.clear();
      if (mounted) setState(() => _connectedDeviceName = null);
      return;
    }
    if (mounted) setState(() => _connectedDeviceName = name);
  }

  Future<void> _loadStorageLocation() async {
    final name = await StorageLocationStorage.getName();
    if (mounted) setState(() => _storageLocationName = name);
  }

  static const int _maxDecreaseDecibel = 30;

  _OutputMode _dbmToMode(int dbm) {
    final v = dbm.clamp(0, _maxDecreaseDecibel);
    if (v <= 5) return _OutputMode.hand;
    if (v <= 15) return _OutputMode.near;
    if (v <= 20) return _OutputMode.mid;
    return _OutputMode.far;
  }

  Future<void> _loadOutputMode() async {
    final storedDecrease = await RadioPowerStorage.getDecreaseDecibel();
    final storedDbm = (30 - storedDecrease).clamp(0, 30);
    var mode = _dbmToMode(storedDbm);

    if (_reader.supportsNativeRfid) {
      try {
        final connected = await _reader.isConnected();
        if (connected) {
          final currentDbm = await _reader.getRadioPower();
          if (currentDbm != null && currentDbm > 0) {
            mode = _dbmToMode(currentDbm);
          }
        }
      } catch (_) {
        // 読めなかった場合は保存値のまま
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedOutputMode = mode;
    });
  }

  int _modeToTargetDbm(_OutputMode mode) => mode.targetDbm;

  Future<void> _applyOutputMode(_OutputMode mode) async {
    final targetDbm = _modeToTargetDbm(mode);

    int maxDbm = 30;
    bool connected = false;
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
        // 読めなかった場合は既定（30）のまま
      }
    }

    final decreaseDecibel = (maxDbm - targetDbm).clamp(0, _maxDecreaseDecibel);
    await RadioPowerStorage.saveDecreaseDecibel(decreaseDecibel);

    String message;
    if (_reader.supportsNativeRfid) {
      try {
        if (connected) {
          final ok = await _reader.setRadioPower(decreaseDecibel);
          message = ok
              ? '出力モードを「${mode.mainLabel}${mode.subLabel}」に設定しました。'
              : '出力モードの反映に失敗しました（接続状態を確認してください）。';
        } else {
          message = '出力モードを保存しました。接続後に反映されます。';
        }
      } catch (e) {
        message = '出力モードの反映に失敗しました: $e';
      }
    } else {
      message = '出力モードを保存しました（モバイル実機以外ではリーダーへ反映されません）。';
    }

    if (!mounted) return;
    setState(() {
      _selectedOutputMode = mode;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildOutputModePicker() {
    const tileRadius = 10.0;
    const tilePadding = EdgeInsets.symmetric(horizontal: 10, vertical: 7);
    const tileBorderWidth = 1.0;

    Color tileBorderColor(_OutputMode m) => m == _selectedOutputMode
        ? _outputTeal
        : Colors.grey.shade300;
    Color tileBg(_OutputMode m) => m == _selectedOutputMode ? _outputTealBg : Colors.white;

    Widget tile(_OutputMode m) {
      final selected = m == _selectedOutputMode;
      return InkWell(
        borderRadius: BorderRadius.circular(tileRadius),
        onTap: () => setState(() => _selectedOutputMode = m),
        child: Container(
          padding: tilePadding,
          decoration: BoxDecoration(
            color: tileBg(m),
            borderRadius: BorderRadius.circular(tileRadius),
            border: Border.all(color: tileBorderColor(m), width: tileBorderWidth),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      m.mainLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      m.subLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.1,
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
                    child: Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '出力モード',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _applyOutputMode(_selectedOutputMode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _outputTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '適用',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.8,
            children: [
              tile(_OutputMode.hand),
              tile(_OutputMode.near),
              tile(_OutputMode.mid),
              tile(_OutputMode.far),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadAll() async {
    // API の環境（本番/開発）を取得し、ヘッダーの (本番DB)/(ローカルDB) を正しく表示
    await fetchAndCacheApiEnvironment();
    if (mounted) setState(() {});
    await Future.wait([
      _loadEmployee(),
      _loadConnectedDevice(),
      _loadStorageLocation(),
      _loadOutputMode(),
    ]);
    // 担当者キャッシュを初回一括取得で準備（バックグラウンド）
    final cache = EmployeeCache.instance;
    cache.init().then((_) {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      return cache.ensureInitialLoaded(api);
    }).then((ok) {
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('担当者一覧の取得に失敗しました。オンライン時に再試行します。'),
          ),
        );
      }
    });
    // 商品キャッシュを初回一括取得で準備（バックグラウンド）
    final productCache = ProductCache.instance;
    productCache.init().then((_) {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      return productCache.ensureInitialLoaded(api);
    }).then((ok) {
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('商品一覧の取得に失敗しました。オンライン時に再試行します。'),
          ),
        );
      }
    });
    // 台帳キャッシュ（assets の tag_ledger.json）を読み込み（開発時・APIなし時の照合用）
    TagLedgerCache.instance.init();
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
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
                  title: '大宮タグリーダーアプリ $kDbLabel',
                  employeeName: _employeeName,
                  connectedDeviceName: _connectedDeviceName,
                  storageLocationName: _storageLocationName,
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 24,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 280,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _MenuButton(
                                      label: 'タグリーダー接続',
                                      backgroundColor: const Color(0xFF90CAF9),
                                      textColor: Colors.black,
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (context) =>
                                                const DeviceConnectionScreen(showBackButton: true),
                                          ),
                                        );
                                        _loadConnectedDevice();
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    _MenuButton(
                                      label: 'ICタグ読取・更新',
                                      backgroundColor: const Color(0xFFCDE990),
                                      textColor: Colors.black,
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (context) =>
                                                const TagListScreen(showBackButton: true),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    _MenuButton(
                                      label: '伝票読込',
                                      backgroundColor: const Color(0xFFFCE4EC),
                                      textColor: const Color(0xFFB71C1C),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (context) =>
                                                const SlipLoadScreen(showBackButton: true),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    _MenuButton(
                                      label: '保管場所選択',
                                      backgroundColor: const Color(0xFFFFCC80),
                                      textColor: Colors.black,
                                      onPressed: () async {
                                        final updated = await Navigator.of(context).push<bool>(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const StorageLocationScreen(showBackButton: true),
                                          ),
                                        );
                                        if (updated == true) _loadStorageLocation();
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    _MenuButton(
                                      label: '設定',
                                      backgroundColor: const Color(0xFFB2DFDB),
                                      textColor: Colors.black,
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (context) =>
                                                const SettingsScreen(showBackButton: true),
                                          ),
                                        );
                                        if (!mounted) return;
                                        await _loadOutputMode();
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    _buildOutputModePicker(),
                                  ],
                                ),
                              ),
                            ),
                          ),
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

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.title,
    this.employeeName,
    this.connectedDeviceName,
    this.storageLocationName,
  });

  final String title;
  final String? employeeName;
  final String? connectedDeviceName;
  final String? storageLocationName;

  @override
  Widget build(BuildContext context) {
    final hasEmployee = employeeName != null && employeeName!.isNotEmpty;
    final hasLocation = storageLocationName != null && storageLocationName!.isNotEmpty;

    String? infoLine;
    if (hasEmployee && hasLocation) {
      infoLine = '担当: $employeeName  |  保管場所: $storageLocationName';
    } else if (hasEmployee) {
      infoLine = '担当: $employeeName';
    } else if (hasLocation) {
      infoLine = '保管場所: $storageLocationName';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppDesign.navBarBackground,
        border: Border(bottom: BorderSide(color: AppDesign.navBarBorder, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            if (infoLine != null) ...[
              const SizedBox(height: 4),
              Text(
                infoLine,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (connectedDeviceName != null && connectedDeviceName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '接続中: $connectedDeviceName',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (backgroundColor ?? AppDesign.primaryButton)
        : AppDesign.disabledButton;
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
