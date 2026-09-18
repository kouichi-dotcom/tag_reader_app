import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/inventory_epc.dart';

class BondedDevice {
  const BondedDevice({required this.name, required this.address});

  final String name;
  final String address;

  static BondedDevice fromJson(Map<dynamic, dynamic> json) {
    return BondedDevice(
      name: (json['name'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
    );
  }
}

class TagReaderService {
  TagReaderService._();

  static final TagReaderService instance = TagReaderService._();

  static const MethodChannel _method = MethodChannel('tss_rfid/method');
  static const EventChannel _events = EventChannel('tss_rfid/events');

  Stream<dynamic>? _rawEventStream;

  bool get isAndroid => Platform.isAndroid;

  /// Android / iOS 実機の TSS RFID ネイティブブリッジが有効なとき true（Windows 等デスクトップは false）。
  bool get supportsNativeRfid => Platform.isAndroid || Platform.isIOS;

  Stream<Map<String, dynamic>> get events {
    _rawEventStream ??= _events.receiveBroadcastStream();
    return _rawEventStream!.map((e) => Map<String, dynamic>.from(e as Map));
  }

  Stream<InventoryEpc> get inventoryEpcStream {
    return events
        .where((e) => e['type'] == 'inventory_epc')
        .map((e) => InventoryEpc.parse((e['raw'] as String?) ?? ''));
  }

  /// R-5000: trigger_changed, SR7: scan_trigger_changed をマージしたトリガー押下/離しのストリーム。
  /// SDK 仕様どおり「押下 true / 離し false」（TSS リファレンス: true でトリガ ON）。
  /// ネイティブRFID未対応のプラットフォームでは空ストリーム。
  Stream<bool> get triggerStream {
    if (!supportsNativeRfid) return Stream<bool>.empty();
    return events
        .where((e) =>
            e['type'] == 'trigger_changed' || e['type'] == 'scan_trigger_changed')
        .map((e) => e['trigger'] as bool? ?? false);
  }

  Future<bool> requestBluetoothPermissions() async {
    if (!supportsNativeRfid) return true;
    final ok = await _method.invokeMethod<bool>('requestBluetoothPermissions');
    return ok ?? false;
  }

  Future<List<BondedDevice>> getBondedDevices() async {
    if (!supportsNativeRfid) return const [];
    final list = await _method.invokeMethod<List<dynamic>>('getBondedDevices');
    final devices = (list ?? const [])
        .map((e) => BondedDevice.fromJson(e as Map<dynamic, dynamic>))
        .where((d) => d.name.isNotEmpty && d.address.isNotEmpty)
        .toList();
    return devices;
  }

  /// 一覧から削除。
  /// Android は OS ペアリング解除＋アプリ側の保存データもクリア。
  /// iOS は（現時点）アプリ保存の接続候補を削除（OS アンペアは未対応）。
  Future<bool> removeBondedDeviceFromList({required String address}) async {
    if (!supportsNativeRfid) return false;
    final ok = await _method.invokeMethod<bool>('removeBondedDevice', {
      'address': address,
    });
    return ok ?? false;
  }

  Future<void> startBleScan() async {
    if (!supportsNativeRfid) return;
    await _method.invokeMethod<void>('startBleScan');
  }

  Future<void> stopBleScan() async {
    if (!supportsNativeRfid) return;
    await _method.invokeMethod<void>('stopBleScan');
  }

  Future<bool> connect({required String name, required String address}) async {
    if (!supportsNativeRfid) return false;
    final ok = await _method.invokeMethod<bool>('connect', {
      'name': name,
      'address': address,
    });
    return ok ?? false;
  }

  Future<bool> disconnect() async {
    if (!supportsNativeRfid) return false;
    final ok = await _method.invokeMethod<bool>('disconnect');
    return ok ?? false;
  }

  Future<bool> startInventory({
    bool dateTime = true,
    bool radioPower = true,
    bool channel = true,
    bool temp = false,
    bool phase = false,
    bool noRepeat = true,
  }) async {
    if (!supportsNativeRfid) return false;
    try {
      final ok = await _method.invokeMethod<bool>('startInventory', {
        'dateTime': dateTime,
        'radioPower': radioPower,
        'channel': channel,
        'temp': temp,
        'phase': phase,
        'noRepeat': noRepeat,
      });
      return ok ?? false;
    } on PlatformException {
      // Android/iOS は失敗時に inventory_failed 等を返す。呼び出し側は bool のまま扱えるようにする。
      return false;
    }
  }

  Future<bool> stopInventory() async {
    if (!supportsNativeRfid) return false;
    final ok = await _method.invokeMethod<bool>('stopInventory');
    return ok ?? false;
  }

  Future<bool> isConnected() async {
    if (!supportsNativeRfid) return false;
    final ok = await _method.invokeMethod<bool>('isConnected');
    return ok ?? false;
  }

  Future<String?> getFirmwareVersion() async {
    if (!supportsNativeRfid) return null;
    return _method.invokeMethod<String>('getFirmwareVersion');
  }

  Future<int?> getRadioPower() async {
    if (!supportsNativeRfid) return null;
    final value = await _method.invokeMethod<int>('getRadioPower');
    return value;
  }

  Future<int?> getMaxRadioPower() async {
    if (!supportsNativeRfid) return null;
    final value = await _method.invokeMethod<int>('getMaxRadioPower');
    return value;
  }

  Future<bool> setRadioPower(int decreaseDecibel) async {
    if (!supportsNativeRfid) return false;
    final ok = await _method.invokeMethod<bool>('setRadioPower', {
      'decreaseDecibel': decreaseDecibel,
    });
    return ok ?? false;
  }

  /// 物理タグの EPC（UII）を書き換える。
  /// 成功時 true。タイムアウト時は false（リーダー側は stop する）。
  Future<bool> writeEpc({
    required String currentEpc,
    required String newEpc,
    bool useMask = false,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!supportsNativeRfid) return false;
    final current = currentEpc.trim().toLowerCase();
    final next = newEpc.trim().toLowerCase();
    if (current.isEmpty || next.isEmpty) return false;

    final completer = Completer<bool>();
    late final StreamSubscription<Map<String, dynamic>> sub;
    sub = events.listen((e) {
      final type = e['type'] as String?;
      if (type == 'write_tag_data') {
        if (!completer.isCompleted) completer.complete(true);
      } else if (type == 'write_tag_failed') {
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    try {
      final started = await _method.invokeMethod<bool>('writeTag', {
        'currentEpc': current,
        'newEpc': next,
        'useMask': useMask,
      });
      if (started != true) return false;
      return await completer.future.timeout(timeout, onTimeout: () => false);
    } on PlatformException {
      return false;
    } finally {
      await sub.cancel();
      try {
        await stopInventory();
      } catch (_) {}
    }
  }
}

