import 'package:flutter/material.dart';

import '../models/operation_history.dart';
import '../services/operation_history_service.dart';
import '../theme/app_design.dart';
import '../widgets/history/history_list_tile.dart';
import '../widgets/main_flow_nav_bar.dart';

/// この端末の更新操作履歴（直近10日）
class OperationHistoryScreen extends StatefulWidget {
  const OperationHistoryScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<OperationHistoryScreen> createState() => _OperationHistoryScreenState();
}

class _OperationHistoryScreenState extends State<OperationHistoryScreen> {
  bool _loading = true;
  List<OperationHistory> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await OperationHistoryService.instance.listRecent(
      purgeFirst: true,
    );
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
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
                MainFlowNavBar(
                  title: '更新履歴',
                  showBackButton: widget.showBackButton,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: AppDesign.controlBarBackground,
                  child: const Text(
                    'この端末の直近10日分の更新操作',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? const Center(
                              child: Text(
                                '履歴はまだありません',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _items.length,
                                itemBuilder: (context, index) {
                                  final h = _items[index];
                                  return HistoryListTile(
                                    history: h,
                                    onTap: () =>
                                        showHistoryDetailSheet(context, h),
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
