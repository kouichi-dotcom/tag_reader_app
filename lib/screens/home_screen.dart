import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../services/connected_device_storage.dart';
import '../services/employee_cache.dart';
import '../services/operation_history_service.dart';
import '../services/product_cache.dart';
import '../services/reader_connection_session.dart';
import '../services/tag_ledger_cache.dart';
import '../services/tag_reader_service.dart';
import '../theme/app_design.dart';
import 'device_connection_screen.dart';
import 'employee_code_screen.dart';
import 'hardware_trigger_settings_screen.dart';
import 'operation_history_screen.dart';
import 'radio_power_screen.dart';
import 'slip_load_screen.dart';
import 'storage_location_screen.dart';
import 'tag_list_screen.dart';
import 'tag_settings_screen.dart';
import 'zaicon_main_shell.dart';

/// 主要5タブの親。ホームは設定の入口、他タブは既存の作業画面。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  /// 一度開いたタブは破棄しない。未表示のタブは作らない。
  final Set<int> _visited = {0};

  static const int _icTagTab = 1;

  late final List<Widget> _pages = const [
    _HomeMenu(),
    SizedBox.shrink(),
    SlipLoadScreen(showBackButton: false),
    ZaiconMainShell(showBackButton: false),
    OperationHistoryScreen(showBackButton: false),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'ホーム',
    ),
    NavigationDestination(
      icon: Icon(Icons.nfc_outlined),
      selectedIcon: Icon(Icons.nfc),
      label: 'ICタグ更新',
    ),
    NavigationDestination(
      icon: Icon(Icons.description_outlined),
      selectedIcon: Icon(Icons.description),
      label: '伝票',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: '在庫',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: '履歴',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStartup();
  }

  Future<void> _loadStartup() async {
    await fetchAndCacheApiEnvironment();
    if (mounted) setState(() {});
    OperationHistoryService.instance.purgeOlderThanRetention();
    final cache = EmployeeCache.instance;
    cache
        .init()
        .then((_) {
          final api = ApiClient(baseUrl: kApiBaseUrl);
          return cache.ensureInitialLoaded(api);
        })
        .then((ok) {
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('担当者一覧の取得に失敗しました。オンライン時に再試行します。')),
            );
          }
        });
    final productCache = ProductCache.instance;
    productCache
        .init()
        .then((_) {
          final api = ApiClient(baseUrl: kApiBaseUrl);
          return productCache.ensureInitialLoaded(api);
        })
        .then((ok) {
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('商品一覧の取得に失敗しました。オンライン時に再試行します。')),
            );
          }
        });
    TagLedgerCache.instance
        .init()
        .then((_) {
          final api = ApiClient(baseUrl: kApiBaseUrl);
          return TagLedgerCache.instance.ensureInitialLoaded(api);
        })
        .then((ok) {
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('タグ台帳の取得に失敗しました。オンライン時に再試行します。')),
            );
          }
        });
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _visited.add(index);
    });
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
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    sizing: StackFit.expand,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        if (!_visited.contains(i))
                          const SizedBox.shrink()
                        else if (i == _icTagTab)
                          TagListScreen(
                            key: const ValueKey('ic-tag-tab'),
                            showBackButton: false,
                            hardwareTriggerEnabled: _index == _icTagTab,
                          )
                        else
                          _pages[i],
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppDesign.navBarBorder,
                ),
                NavigationBarTheme(
                  data: NavigationBarThemeData(
                    height: 64,
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.white,
                    indicatorColor: const Color(0xFFD6E4FF),
                    labelPadding: const EdgeInsets.only(top: 2),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return TextStyle(
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? AppDesign.primaryButton
                            : const Color(0xFF666666),
                      );
                    }),
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        size: 24,
                        color: selected
                            ? AppDesign.primaryButton
                            : const Color(0xFF666666),
                      );
                    }),
                  ),
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: _selectTab,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: _destinations,
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

/// ホーム。Bluetooth接続状況と設定メニュー。
class _HomeMenu extends StatefulWidget {
  const _HomeMenu();

  @override
  State<_HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<_HomeMenu> {
  String? _deviceName;
  String? _firmware;

  final _reader = TagReaderService.instance;

  bool get _connected => _deviceName != null && _deviceName!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    ReaderConnectionSession.instance.ensureStarted();
    ReaderConnectionSession.instance.addListener(_onReaderSessionChanged);
    _refreshConnection();
  }

  @override
  void dispose() {
    ReaderConnectionSession.instance.removeListener(_onReaderSessionChanged);
    super.dispose();
  }

  void _onReaderSessionChanged() {
    if (!mounted) return;
    final session = ReaderConnectionSession.instance;
    if (!session.isConnected) {
      if (_deviceName != null || _firmware != null) {
        setState(() {
          _deviceName = null;
          _firmware = null;
        });
      }
      return;
    }
    final name = session.deviceName;
    if (name != null && name.isNotEmpty && name != _deviceName) {
      setState(() => _deviceName = name);
      _loadFirmware();
    }
  }

  Future<void> _refreshConnection() async {
    final session = ReaderConnectionSession.instance;
    session.ensureStarted();
    String? name;
    if (_reader.supportsNativeRfid) {
      await session.refreshFromNative();
      final connected = session.isConnected || await _reader.isConnected();
      if (!connected) {
        await ConnectedDeviceStorage.clear();
      } else {
        name = session.deviceName ?? await ConnectedDeviceStorage.getName();
      }
    } else {
      name = await ConnectedDeviceStorage.getName();
    }
    if (!mounted) return;
    setState(() {
      _deviceName = (name != null && name.isNotEmpty) ? name : null;
      if (_deviceName == null) _firmware = null;
    });
    if (_deviceName != null) {
      await _loadFirmware();
    }
  }

  Future<void> _loadFirmware() async {
    if (!_reader.supportsNativeRfid) return;
    String? firmware;
    try {
      final value = await _reader.getFirmwareVersion();
      if (value != null && value.trim().isNotEmpty) firmware = value.trim();
    } catch (_) {
      firmware = null;
    }
    if (!mounted || _deviceName == null) return;
    setState(() => _firmware = firmware);
  }

  Future<void> _openConnection() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            const DeviceConnectionScreen(showBackButton: true),
      ),
    );
    if (!mounted) return;
    await _refreshConnection();
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  String get _connectionDetail {
    final lines = <String>[_connected ? '接続済み' : '未接続'];
    if (_connected) {
      lines.add(_deviceName!);
      if (_firmware != null) lines.add('FW: $_firmware');
    } else if (!_reader.supportsNativeRfid) {
      lines.add('この端末ではリーダー非対応');
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final title = kDbLabel.isEmpty ? 'ホーム' : 'ホーム $kDbLabel';
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
                _HomeHeader(title: title),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      _ConnectionTile(
                        connected: _connected,
                        detail: _connectionDetail,
                        onTap: _openConnection,
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Icons.tune,
                        iconColor: const Color(0xFF8BC34A),
                        title: 'リーダーの出力設定',
                        subtitle: '出力モード・電波強度の調整',
                        onTap: () => _openScreen(
                          const RadioPowerScreen(showBackButton: true),
                        ),
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Icons.badge_outlined,
                        iconColor: const Color(0xFF26A69A),
                        title: '担当者設定',
                        subtitle: '担当者の設定',
                        onTap: () => _openScreen(
                          const EmployeeCodeScreen(showBackButton: true),
                        ),
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Icons.warehouse_outlined,
                        iconColor: const Color(0xFFFF9800),
                        title: '保管場所設定',
                        subtitle: '手動 / GPS自動判定の設定',
                        onTap: () => _openScreen(
                          const StorageLocationScreen(showBackButton: true),
                        ),
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Icons.touch_app_outlined,
                        iconColor: const Color(0xFF5C6BC0),
                        title: '読み取りボタン動作設定',
                        subtitle: '切替式・時間式・長押し式',
                        onTap: () => _openScreen(
                          const HardwareTriggerSettingsScreen(
                            showBackButton: true,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Icons.sell_outlined,
                        iconColor: const Color(0xFFE65100),
                        title: 'タグ設定',
                        subtitle: 'タグID再設定など',
                        onTap: () => _openScreen(
                          const TagSettingsScreen(showBackButton: true),
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
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppDesign.navBarBackground,
        border: Border(
          bottom: BorderSide(color: AppDesign.navBarBorder, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.connected,
    required this.detail,
    required this.onTap,
  });

  final bool connected;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    return Material(
      color: connected ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          connected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: color,
          size: 28,
        ),
        title: const Text(
          'Bluetooth接続状況',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          detail,
          style: const TextStyle(
            fontSize: 14,
            height: 1.35,
            color: Color(0xFF444444),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      minVerticalPadding: 12,
      leading: Icon(icon, color: iconColor, size: 28),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          height: 1.3,
          color: Color(0xFF666666),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
