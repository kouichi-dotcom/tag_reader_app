import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../config/feature_flags.dart';
import '../models/output_mode.dart';
import '../services/connected_device_storage.dart';
import '../services/reader_connection_session.dart';
import '../services/employee_cache.dart';
import '../services/tag_reader_service.dart';
import '../services/employee_storage.dart';
import '../services/operation_history_service.dart';
import '../services/product_cache.dart';
import '../services/radio_power_storage.dart';
import '../services/storage_location_storage.dart';
import '../services/tag_ledger_cache.dart';
import '../theme/app_design.dart';
import 'device_connection_screen.dart';
import 'operation_history_screen.dart';
import 'radio_power_screen.dart';
import 'zaicon_main_shell.dart';
import 'settings_screen.dart';
import 'slip_load_screen.dart';
import 'tag_list_screen.dart';
import '../services/urgent_store_delivery_session.dart';
import 'urgent_store_delivery_screen.dart';

/// メイン画面
/// 接続状態・作業メニュー・出力現状表示・設定への入口
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

  final _reader = TagReaderService.instance;

  /// 現在適用済みの出力モード（表示用）
  OutputMode _appliedOutputMode = OutputMode.hand;

  bool get _isReaderConnected =>
      _connectedDeviceName != null && _connectedDeviceName!.isNotEmpty;

  /// 実機で未接続のときだけ ICタグ作業を止める（Windows 等はシミュレート可のため常に有効）
  bool get _canUseTagRead =>
      !_reader.supportsNativeRfid || _isReaderConnected;

  Future<void> _loadEmployee() async {
    final name = await EmployeeStorage.getName();
    if (mounted) setState(() => _employeeName = name);
  }

  Future<void> _loadConnectedDevice() async {
    final session = ReaderConnectionSession.instance;
    session.ensureStarted();
    // Storage は表示補助。実接続は SDK / セッションを優先する。
    if (TagReaderService.instance.supportsNativeRfid) {
      await session.refreshFromNative();
      final connected = session.isConnected ||
          await TagReaderService.instance.isConnected();
      if (!connected) {
        await ConnectedDeviceStorage.clear();
        if (mounted) setState(() => _connectedDeviceName = null);
        return;
      }
      final name = session.deviceName ?? await ConnectedDeviceStorage.getName();
      if (mounted) setState(() => _connectedDeviceName = name);
      return;
    }
    final name = await ConnectedDeviceStorage.getName();
    if (mounted) setState(() => _connectedDeviceName = name);
  }

  Future<void> _loadStorageLocation() async {
    // ホーム表示は DB 上の保管場所（直近観測）。手動ドロップダウン値ではない。
    final name = await StorageLocationStorage.getLastDbStorageLocationName();
    if (mounted) setState(() => _storageLocationName = name);
  }

  Future<void> _loadOutputMode() async {
    final storedDecrease = await RadioPowerStorage.getDecreaseDecibel();
    final storedDbm = (30 - storedDecrease).clamp(0, 30);
    var mode = OutputModeX.fromDbm(storedDbm);

    if (_reader.supportsNativeRfid) {
      try {
        final connected = await _reader.isConnected();
        if (connected) {
          final currentDbm = await _reader.getRadioPower();
          if (currentDbm != null && currentDbm > 0) {
            mode = OutputModeX.fromDbm(currentDbm);
          }
        }
      } catch (_) {
        // 読めなかった場合は保存値のまま
      }
    }

    if (!mounted) return;
    setState(() => _appliedOutputMode = mode);
  }

  Future<void> _openConnectionScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const DeviceConnectionScreen(showBackButton: true),
      ),
    );
    await _loadConnectedDevice();
    await _loadOutputMode();
  }

  Future<void> _openOutputSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const RadioPowerScreen(showBackButton: true),
      ),
    );
    if (!mounted) return;
    await _loadOutputMode();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const SettingsScreen(showBackButton: true),
      ),
    );
    if (!mounted) return;
    await _loadEmployee();
    await _loadStorageLocation();
    await _loadOutputMode();
  }

  Widget _buildConnectionStatusCard() {
    final supportsRfid = _reader.supportsNativeRfid;
    final connected = _isReaderConnected;

    if (!supportsRfid) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: const Row(
          children: [
            Icon(Icons.computer, size: 22, color: Color(0xFF666666)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'タグリーダー　この端末では非対応',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ICタグ読取はシミュレートで利用できます',
                    style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: connected ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _openConnectionScreen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: connected ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                size: 22,
                color: connected ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'タグリーダー　接続済み' : 'タグリーダー　未接続',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: connected
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected ? _connectedDeviceName! : '接続してからICタグ読取を行えます',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              if (!connected)
                TextButton(
                  onPressed: _openConnectionScreen,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE65100),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '接続する',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: Color(0xFF666666)),
            ],
          ),
        ),
      ),
    );
  }

  /// 通常の作業メニューと区別する「急ぎ来店納品」入口（薄い琥珀系・警告色は使わない）
  Widget _buildUrgentDeliveryAction({required VoidCallback onTap}) {
    // 件数はアプリ内メモリの当日未処理（仮）。本実装時は API／永続化に差し替え。
    final pendingCount = UrgentStoreDeliverySession.instance.pendingCount;

    return Material(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4A017), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.flash_on_outlined,
                size: 28,
                color: Color(0xFF8D6E63),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '急ぎ来店納品',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '未処理 $pendingCount点',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8D6E63),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '伝票を選ばず先にタグを読み取る',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8D6E63)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final titleColor = enabled ? Colors.black : const Color(0xFF999999);
    final subtitleColor = enabled ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    return Material(
      color: enabled ? Colors.white : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 28, color: titleColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: subtitleColor, height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: enabled ? const Color(0xFF666666) : const Color(0xFFCCCCCC),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkSection() {
    final canTag = _canUseTagRead;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '作業',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        _buildWorkAction(
          icon: Icons.nfc,
          title: 'ICタグを読み取る・更新する',
          subtitle: canTag ? 'ICタグと商品を登録・変更' : 'リーダーを接続してください',
          enabled: canTag,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const TagListScreen(showBackButton: true),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildWorkAction(
          icon: Icons.description_outlined,
          title: '伝票を読み込む',
          subtitle: '納品伝票の商品を読み込み',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const SlipLoadScreen(showBackButton: true),
              ),
            );
          },
        ),
        if (enableUrgentStoreDelivery) ...[
          const SizedBox(height: 8),
          _buildUrgentDeliveryAction(
            onTap: () async {
              await Navigator.of(context).push(buildUrgentStoreDeliveryRoute());
              if (mounted) setState(() {});
            },
          ),
        ],
        const SizedBox(height: 8),
        _buildWorkAction(
          icon: Icons.inventory_2_outlined,
          title: '在庫を見る',
          subtitle: '現在の商品・タグを確認',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ZaiconMainShell(showBackButton: true),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildWorkAction(
          icon: Icons.history,
          title: '更新履歴',
          subtitle: 'この端末の更新操作を確認',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    const OperationHistoryScreen(showBackButton: true),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOutputModePicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'リーダー出力',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '現在：${_appliedOutputMode.displayLabel}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _openOutputSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: _outputTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '出力設定',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
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
    // 更新履歴の古いデータを削除（失敗しても業務に影響しない）
    OperationHistoryService.instance.purgeOlderThanRetention();
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
    // タグ台帳キャッシュ（案 A': その日の初回起動で全件再取得）
    TagLedgerCache.instance.init().then((_) {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      return TagLedgerCache.instance.ensureInitialLoaded(api);
    }).then((ok) {
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('タグ台帳の取得に失敗しました。オンライン時に再試行します。'),
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    ReaderConnectionSession.instance.ensureStarted();
    ReaderConnectionSession.instance.addListener(_onReaderSessionChanged);
    _loadAll();
  }

  void _onReaderSessionChanged() {
    if (!mounted) return;
    final session = ReaderConnectionSession.instance;
    if (!session.isConnected) {
      if (_connectedDeviceName != null) {
        setState(() => _connectedDeviceName = null);
      }
    } else if (session.deviceName != null &&
        session.deviceName != _connectedDeviceName) {
      setState(() => _connectedDeviceName = session.deviceName);
    }
  }

  @override
  void dispose() {
    ReaderConnectionSession.instance.removeListener(_onReaderSessionChanged);
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
                  title: '大宮タグリーダーアプリ $kDbLabel',
                  employeeName: _employeeName,
                  storageLocationName: _storageLocationName,
                  onSettingsPressed: _openSettings,
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  (constraints.maxHeight - 32).clamp(0.0, double.infinity),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildConnectionStatusCard(),
                                const SizedBox(height: 16),
                                _buildWorkSection(),
                                const SizedBox(height: 16),
                                _buildOutputModePicker(),
                              ],
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
    required this.onSettingsPressed,
    this.employeeName,
    this.storageLocationName,
  });

  final String title;
  final VoidCallback onSettingsPressed;
  final String? employeeName;
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
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
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
            Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    onPressed: onSettingsPressed,
                    tooltip: '設定',
                    icon: const Icon(Icons.settings, color: Colors.black87),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
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
          ],
        ),
      ),
    );
  }
}
