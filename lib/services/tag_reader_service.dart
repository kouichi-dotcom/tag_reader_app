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

  /// Android / iOS 実機の TSS RFID ネイティブブリッジが有効なとき true（Windows 等はモック）。
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
    final ok = await _method.invokeMethod<bool>('startInventory', {
      'dateTime': dateTime,
      'radioPower': radioPower,
      'channel': channel,
      'temp': temp,
      'phase': phase,
      'noRepeat': noRepeat,
    });
    return ok ?? false;
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
}

