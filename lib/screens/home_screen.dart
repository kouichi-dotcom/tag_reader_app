import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../services/connected_device_storage.dart';
import '../services/employee_cache.dart';
import '../services/tag_reader_service.dart';
import '../services/employee_storage.dart';
import '../services/product_cache.dart';
import '../services/storage_location_storage.dart';
import '../services/tag_ledger_cache.dart';
import '../theme/app_design.dart';
import 'device_connection_screen.dart';
import 'employee_code_screen.dart';
import 'radio_power_screen.dart';
import 'slip_load_screen.dart';
import 'storage_location_screen.dart';
import 'tag_info_screen.dart';
import 'tag_list_screen.dart';

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

  Future<void> _loadEmployee() async {
    final name = await EmployeeStorage.getName();
    if (mounted) setState(() => _employeeName = name);
  }

  Future<void> _loadConnectedDevice() async {
    final name = await ConnectedDeviceStorage.getName();
    // Android: 実態が未接続なら表示を合わせる（アプリ再起動後など）
    if (name != null &&
        name.isNotEmpty &&
        TagReaderService.instance.isAndroid &&
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

  Future<void> _loadAll() async {
    // API の環境（本番/開発）を取得し、ヘッダーの (本番DB)/(ローカルDB) を正しく表示
    await fetchAndCacheApiEnvironment();
    if (mounted) setState(() {});
    await Future.wait([_loadEmployee(), _loadConnectedDevice(), _loadStorageLocation()]);
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
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
                                      builder: (context) => const DeviceConnectionScreen(showBackButton: true),
                                    ),
                                  );
                                  _loadConnectedDevice();
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: 'ICタグ読取・更新',
                                backgroundColor: const Color(0xFFCDE990),
                                textColor: Colors.black,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) => const TagListScreen(showBackButton: true),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: '伝票読込',
                                backgroundColor: const Color(0xFFFCE4EC),
                                textColor: const Color(0xFFB71C1C),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) => const SlipLoadScreen(showBackButton: true),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: '担当者コード入力',
                                backgroundColor: const Color(0xFF80CBC4),
                                textColor: Colors.black,
                                onPressed: () async {
                                  final updated = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (context) => const EmployeeCodeScreen(showBackButton: true),
                                    ),
                                  );
                                  if (updated == true) _loadEmployee();
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: '保管場所選択',
                                backgroundColor: const Color(0xFFFFCC80),
                                textColor: Colors.black,
                                onPressed: () async {
                                  final updated = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (context) => const StorageLocationScreen(showBackButton: true),
                                    ),
                                  );
                                  if (updated == true) _loadStorageLocation();
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: '出力設定',
                                backgroundColor: const Color(0xFFB0BEC5),
                                textColor: Colors.black,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) => const RadioPowerScreen(showBackButton: true),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _MenuButton(
                                label: 'タグ情報表示',
                                backgroundColor: const Color(0xFFB39DDB),
                                textColor: Colors.black,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) => const TagInfoScreen(showBackButton: true),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
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
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
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
