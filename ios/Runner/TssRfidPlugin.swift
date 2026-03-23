import Flutter

/// Android MainActivity の MethodChannel / EventChannel と同一の名前で Flutter に公開する。
/// BLE スキャンは TSS_SDK.scan（TssRfidSdkSession）に統一。
final class TssRfidPlugin: NSObject, FlutterStreamHandler {
  private static let methodChannelName = "tss_rfid/method"
  private static let eventChannelName = "tss_rfid/events"

  private var eventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let instance = TssRfidPlugin()

    let method = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    method.setMethodCallHandler(instance.handleMethodCall)

    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    events.setStreamHandler(instance)

    TssRfidNativeBridge.setEventSinkCallback { dict in
      instance.emitEvent(dict as [AnyHashable: Any])
    }
  }

  private func emitEvent(_ map: [AnyHashable: Any]) {
    DispatchQueue.main.async {
      self.eventSink?(map)
    }
  }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - MethodChannel

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestBluetoothPermissions":
      handleRequestBluetoothPermissions(result: result)
    case "getBondedDevices":
      handleGetBondedDevices(result: result)
    case "startBleScan":
      handleStartBleScan(result: result)
    case "stopBleScan":
      handleStopBleScan(result: result)
    case "connect":
      handleConnect(call: call, result: result)
    case "disconnect":
      result(TssRfidNativeBridge.disconnect())
    case "startInventory":
      handleStartInventory(call: call, result: result)
    case "stopInventory":
      result(TssRfidNativeBridge.stopInventory())
    case "isConnected":
      result(TssRfidNativeBridge.isConnected())
    case "getFirmwareVersion":
      result(TssRfidNativeBridge.firmwareVersion())
    case "getRadioPower":
      handleGetRadioPower(result: result)
    case "getMaxRadioPower":
      handleGetMaxRadioPower(result: result)
    case "setRadioPower":
      handleSetRadioPower(call: call, result: result)
    case "setBeeperVolumeMin", "setGoodReadBeepOff":
      // Android は接続後に onConnected で呼ぶ。iOS は SDK 実装後に対応。
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleRequestBluetoothPermissions(result: @escaping FlutterResult) {
    // TSS_SDK が内部で CoreBluetooth を管理。Info.plist の利用目的文言を参照。
    result(true)
  }

  private func handleGetBondedDevices(result: @escaping FlutterResult) {
    let list = TssRfidNativeBridge.knownBondedStyleDevices() as? [[String: Any]] ?? []
    result(list)
  }

  private func handleStartBleScan(result: @escaping FlutterResult) {
    TssRfidNativeBridge.startBleScan()
    result(true)
  }

  private func handleStopBleScan(result: @escaping FlutterResult) {
    TssRfidNativeBridge.stopBleScan()
    result(true)
  }

  private func handleConnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let name = (args?["name"] as? String) ?? ""
    let address = (args?["address"] as? String) ?? ""
    if name.isEmpty || address.isEmpty {
      result(false)
      return
    }
    TssRfidNativeBridge.rememberDeviceName(name, address: address)
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try TssRfidNativeBridge.connect(withName: name, address: address)
        DispatchQueue.main.async {
          result(true)
        }
      } catch let e as NSError {
        DispatchQueue.main.async {
          result(FlutterError(code: "connect_failed", message: e.localizedDescription, details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "connect_failed", message: "\(error)", details: nil))
        }
      }
    }
  }

  private func handleStartInventory(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let dateTime = (args?["dateTime"] as? Bool) ?? true
    let radioPower = (args?["radioPower"] as? Bool) ?? true
    let channel = (args?["channel"] as? Bool) ?? true
    let temp = (args?["temp"] as? Bool) ?? false
    let phase = (args?["phase"] as? Bool) ?? false
    let noRepeat = (args?["noRepeat"] as? Bool) ?? false

    do {
      // ObjC の BOOL + NSError** は Swift で throws にマップされるが、戻り BOOL が Void と推論されることがある。
      // result に () を渡すと Standard codec が "Unsupported value" で落ちるため、成功時は明示的に true を返す。
      try TssRfidNativeBridge.startInventoryDateTime(
        dateTime,
        radioPower: radioPower,
        channel: channel,
        temp: temp,
        phase: phase,
        noRepeat: noRepeat
      )
      result(true)
    } catch let e as NSError {
      result(FlutterError(code: "inventory_failed", message: e.localizedDescription, details: nil))
    } catch {
      result(FlutterError(code: "inventory_failed", message: "\(error)", details: nil))
    }
  }

  private func handleGetRadioPower(result: @escaping FlutterResult) {
    result(TssRfidNativeBridge.radioPower())
  }

  private func handleGetMaxRadioPower(result: @escaping FlutterResult) {
    result(TssRfidNativeBridge.maxRadioPower())
  }

  private func handleSetRadioPower(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let decrease = (args?["decreaseDecibel"] as? Int) ?? 0
    do {
      try TssRfidNativeBridge.setRadioPowerDecreaseDecibel(decrease)
      result(true)
    } catch let e as NSError {
      result(FlutterError(code: "set_radio_power_failed", message: e.localizedDescription, details: nil))
    } catch {
      result(FlutterError(code: "set_radio_power_failed", message: "\(error)", details: nil))
    }
  }
}
