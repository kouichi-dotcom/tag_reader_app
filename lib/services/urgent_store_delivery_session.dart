import '../mocks/urgent_store_delivery_mock.dart';
import '../models/urgent_store_delivery.dart';

/// 急ぎ来店納品の当日未処理商品（アプリ内メモリ保持）。
/// 本実装時は永続化／API に差し替える。画面を跨いでも同じ一覧を共有する。
class UrgentStoreDeliverySession {
  UrgentStoreDeliverySession._() {
    _items = List<UrgentReadItem>.from(mockUrgentTodayItems);
  }

  static final UrgentStoreDeliverySession instance =
      UrgentStoreDeliverySession._();

  late List<UrgentReadItem> _items;
  final List<void Function()> _listeners = [];

  List<UrgentReadItem> get items => List.unmodifiable(_items);

  int get pendingCount => _items.length;

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (final l in List<void Function()>.from(_listeners)) {
      l();
    }
  }

  /// UI 確認用。実読取接続時はここへ追加する想定。
  void addItem(UrgentReadItem item) {
    _items = [..._items, item];
    _notify();
  }

  /// 送信成功後に未処理から外す（本実装時も同様の流れを想定）
  void removeByIds(Iterable<String> ids) {
    final idSet = ids.toSet();
    _items = _items.where((e) => !idSet.contains(e.id)).toList();
    _notify();
  }
}
