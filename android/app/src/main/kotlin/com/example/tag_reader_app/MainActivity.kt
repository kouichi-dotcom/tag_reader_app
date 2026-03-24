package com.example.tag_reader_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import jp.co.tss21.uhfrfid.dotr_android.EnMaskFlag
import jp.co.tss21.uhfrfid.dotr_android.OnDotrEventListener
import jp.co.tss21.uhfrfid.tssrfid.TssRfidUtill

class MainActivity : FlutterActivity(), OnDotrEventListener {
    companion object {
        private const val PREFS_BRIDGE = "tss_rfid_bridge"
        private const val KEY_HIDDEN_BONDED = "hidden_bonded_addresses"
    }

    private val methodChannelName = "tss_rfid/method"
    private val eventChannelName = "tss_rfid/events"

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val rfidUtil: TssRfidUtill = TssRfidUtill()

    private val reqCodeBtPermissions = 1001

    private var bleScanner: BluetoothLeScanner? = null
    private val epcCooldownMs: Long = 30_000L
    private val epcLastNotifiedAt = mutableMapOf<String, Long>()
    private val bleScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device ?: return
            val address = device.address ?: return
            val name = result.scanRecord?.deviceName?.trim()?.ifBlank { null }
                ?: device.name?.trim()?.ifBlank { null }
                ?: ""
            if (name.isEmpty() || !isLikelyReaderName(name)) return
            emitEvent(mapOf(
                "type" to "ble_device_found",
                "name" to name,
                "address" to address
            ))
        }

        override fun onScanFailed(errorCode: Int) {
            // Flutter can keep showing previous results; no need to emit error for now
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        rfidUtil.setOnDotrEventListener(this)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBluetoothPermissions" -> handleRequestBluetoothPermissions(result)
                "getBondedDevices" -> handleGetBondedDevices(result)
                "removeBondedDevice" -> handleRemoveBondedDevice(call, result)
                "startBleScan" -> handleStartBleScan(result)
                "stopBleScan" -> handleStopBleScan(result)
                "connect" -> handleConnect(call, result)
                "disconnect" -> result.success(rfidUtil.disconnect())
                "startInventory" -> handleStartInventory(call, result)
                "stopInventory" -> runCatching { rfidUtil.stop(); true }.getOrElse { false }.also { result.success(it) }
                "isConnected" -> result.success(rfidUtil.isConnect())
                "getFirmwareVersion" -> result.success(rfidUtil.firmwareVersion)
                "getRadioPower" -> handleGetRadioPower(result)
                "getMaxRadioPower" -> handleGetMaxRadioPower(result)
                "setRadioPower" -> handleSetRadioPower(call, result)
                "setBeeperVolumeMin" -> handleSetBeeperVolumeMin(result)
                "setGoodReadBeepOff" -> handleSetGoodReadBeepOff(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun emitEvent(map: Map<String, Any?>) {
        runOnUiThread {
            eventSink?.success(map)
        }
    }

    private fun shouldEmitInventoryEpc(rawEpc: String): Boolean {
        val epc = rawEpc.trim()
        if (epc.isEmpty()) return false

        val now = System.currentTimeMillis()
        val last = epcLastNotifiedAt[epc]
        if (last != null && now - last < epcCooldownMs) {
            return false
        }
        epcLastNotifiedAt[epc] = now

        // Keep memory bounded by removing entries inactive for >2 cooldown windows.
        if (epcLastNotifiedAt.size > 2048) {
            val expireBefore = now - (epcCooldownMs * 2)
            val it = epcLastNotifiedAt.entries.iterator()
            while (it.hasNext()) {
                if (it.next().value < expireBefore) it.remove()
            }
        }
        return true
    }

    private fun requiredBtPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        } else {
            emptyArray()
        }
    }

    private fun hasAllPermissions(perms: Array<String>): Boolean {
        return perms.all { p ->
            ContextCompat.checkSelfPermission(this, p) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun handleRequestBluetoothPermissions(result: MethodChannel.Result) {
        val perms = requiredBtPermissions()
        if (perms.isEmpty()) {
            result.success(true)
            return
        }
        if (hasAllPermissions(perms)) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_request_in_progress", "Permission request already running.", null)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, perms, reqCodeBtPermissions)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != reqCodeBtPermissions) return

        val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    private fun ensureConnected(result: MethodChannel.Result): Boolean {
        if (!rfidUtil.isConnect()) {
            result.error("not_connected", "Tag reader is not connected.", null)
            return false
        }
        return true
    }

    private fun hiddenBondedAddresses(): MutableSet<String> {
        val raw = getSharedPreferences(PREFS_BRIDGE, Context.MODE_PRIVATE)
            .getStringSet(KEY_HIDDEN_BONDED, emptySet()) ?: emptySet()
        return raw.map { it.uppercase() }.toMutableSet()
    }

    private fun saveHiddenBonded(set: Set<String>) {
        getSharedPreferences(PREFS_BRIDGE, Context.MODE_PRIVATE).edit()
            .putStringSet(KEY_HIDDEN_BONDED, set)
            .apply()
    }

    private fun handleGetBondedDevices(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.success(emptyList<Any>())
            return
        }

        val perms = requiredBtPermissions()
        if (perms.isNotEmpty() && !hasAllPermissions(perms)) {
            result.error("permission_required", "Bluetooth permission is required.", null)
            return
        }

        val hidden = hiddenBondedAddresses()
        val devices = adapter.bondedDevices
            .filter { d ->
                val addr = d.address?.uppercase() ?: ""
                addr !in hidden
            }
            .mapNotNull { d ->
                val name = d.name ?: ""
                val addr = d.address ?: ""
                if (name.isBlank() || addr.isBlank()) return@mapNotNull null
                if (!isLikelyReaderName(name)) return@mapNotNull null
                mapOf("name" to name, "address" to addr)
            }
            .sortedBy { (it["name"] as String) }

        result.success(devices)
    }

    private fun handleRemoveBondedDevice(call: MethodCall, result: MethodChannel.Result) {
        val addr = call.argument<String>("address")?.trim()?.uppercase() ?: run {
            result.success(false)
            return
        }
        if (addr.isEmpty()) {
            result.success(false)
            return
        }
        val hidden = hiddenBondedAddresses()
        hidden.add(addr)
        saveHiddenBonded(hidden)
        result.success(true)
    }

    private fun handleStartBleScan(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.success(false)
            return
        }
        val perms = requiredBtPermissions()
        if (perms.isNotEmpty() && !hasAllPermissions(perms)) {
            result.error("permission_required", "Bluetooth permission is required.", null)
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            result.success(false)
            return
        }
        bleScanner = scanner
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        try {
            scanner.startScan(null, settings, bleScanCallback)
            result.success(true)
        } catch (e: SecurityException) {
            result.error("ble_scan_failed", e.message, null)
        } catch (e: Exception) {
            result.error("ble_scan_failed", e.message, null)
        }
    }

    private fun handleStopBleScan(result: MethodChannel.Result) {
        val scanner = bleScanner
        bleScanner = null
        if (scanner != null) {
            try {
                scanner.stopScan(bleScanCallback)
            } catch (_: Exception) { }
        }
        result.success(true)
    }

    private fun isLikelyReaderName(name: String): Boolean {
        val prefixes = listOf(
            "HQ_UHF_READER",
            "TSS91JJ-",
            "TSS92JJ-",
            "DOTR2100-",
            "DOTR2200-",
            "TSS2100",
            "TSS2200",
            "DOTR3100",
            "DOTR3200",
            "TSS3100",
            "TSS3200",
            "R-5000",
            "SR7_",
            "MR20_",
            "SR160_",
            "BLE SPP",
            "TSS91JI-",
            "TSS92JI-",
        )
        return prefixes.any { p -> name.equals(p, ignoreCase = true) || name.startsWith(p) }
    }

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name") ?: ""
        val address = call.argument<String>("address") ?: ""
        if (name.isBlank() || address.isBlank()) {
            result.success(false)
            return
        }

        val perms = requiredBtPermissions()
        if (perms.isNotEmpty() && !hasAllPermissions(perms)) {
            result.error("permission_required", "Bluetooth permission is required.", null)
            return
        }

        runCatching {
            // 接続前に context とリーダー名を設定
            rfidUtil.initReader(this, name)
            rfidUtil.connect(address)
        }.onSuccess { ok ->
            result.success(ok)
        }.onFailure { e ->
            result.error("connect_failed", e.message, null)
        }
    }

    private fun handleStartInventory(call: MethodCall, result: MethodChannel.Result) {
        if (!rfidUtil.isConnect()) {
            result.success(false)
            return
        }

        val dateTime = call.argument<Boolean>("dateTime") ?: true
        val radioPower = call.argument<Boolean>("radioPower") ?: true
        val channel = call.argument<Boolean>("channel") ?: true
        val temp = call.argument<Boolean>("temp") ?: false
        val phase = call.argument<Boolean>("phase") ?: false
        val noRepeat = call.argument<Boolean>("noRepeat") ?: false

        runCatching {
            epcLastNotifiedAt.clear()
            rfidUtil.setNoRepeat(noRepeat)
            if (!noRepeat) {
                rfidUtil.clearAccessEPCList()
            }
            rfidUtil.setInventoryReportMode(dateTime, radioPower, channel, temp, phase)
            rfidUtil.inventoryTag(false, EnMaskFlag.None, 0)
            true
        }.onSuccess { ok ->
            result.success(ok)
        }.onFailure { e ->
            result.error("inventory_failed", e.message, null)
        }
    }

    private fun handleGetRadioPower(result: MethodChannel.Result) {
        if (!ensureConnected(result)) return
        runCatching {
            // getRadioPower() の Kotlin プロパティアクセサ
            rfidUtil.radioPower
        }.onSuccess { value ->
            result.success(value)
        }.onFailure { e ->
            result.error("get_radio_power_failed", e.message, null)
        }
    }

    private fun handleGetMaxRadioPower(result: MethodChannel.Result) {
        if (!ensureConnected(result)) return
        runCatching {
            // getMaxRadioPower() の Kotlin プロパティアクセサ
            rfidUtil.maxRadioPower
        }.onSuccess { value ->
            result.success(value)
        }.onFailure { e ->
            result.error("get_max_radio_power_failed", e.message, null)
        }
    }

    private fun handleSetRadioPower(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureConnected(result)) return
        val decreaseDecibel = (call.argument<Int>("decreaseDecibel") ?: 0).coerceAtLeast(0)
        runCatching {
            rfidUtil.setRadioPower(decreaseDecibel)
        }.onSuccess { ok ->
            result.success(ok)
        }.onFailure { e ->
            result.error("set_radio_power_failed", e.message, null)
        }
    }

    private fun handleSetBeeperVolumeMin(result: MethodChannel.Result) {
        if (!ensureConnected(result)) return
        runCatching {
            trySetBeeperVolumeMin()
        }.onSuccess { ok ->
            result.success(ok)
        }.onFailure { e ->
            result.error("set_beeper_volume_failed", e.message, null)
        }
    }

    private fun handleSetGoodReadBeepOff(result: MethodChannel.Result) {
        if (!ensureConnected(result)) return
        runCatching {
            trySetGoodReadBeepOff()
        }.onSuccess { ok ->
            result.success(ok)
        }.onFailure { e ->
            result.error("set_good_read_beep_off_failed", e.message, null)
        }
    }

    private fun trySetBeeperVolumeMin(): Boolean {
        // SDK version differences are handled by trying method candidates via reflection.
        val target = rfidUtil
        val clazz = target.javaClass

        val intCandidates = listOf("setBeeperVolume", "setBeepVolume", "setBuzzerVolume", "setVolume")
        for (name in intCandidates) {
            val m = clazz.methods.firstOrNull {
                it.name == name && it.parameterTypes.size == 1 && it.parameterTypes[0] == Int::class.javaPrimitiveType
            } ?: continue
            val r = m.invoke(target, 0)
            return (r as? Boolean) ?: true
        }

        val objCandidates = listOf("setBeeperVolume", "setBeepVolume", "setBuzzerVolume")
        for (name in objCandidates) {
            val m = clazz.methods.firstOrNull { it.name == name && it.parameterTypes.size == 1 } ?: continue
            val p = m.parameterTypes[0]
            runCatching {
                when {
                    p == String::class.java -> {
                        val r = m.invoke(target, "MIN")
                        return (r as? Boolean) ?: true
                    }
                    p.isEnum -> {
                        val values = p.enumConstants ?: emptyArray<Any>()
                        val minLike = values.firstOrNull {
                            val s = it.toString().uppercase()
                            s.contains("MIN") || s.contains("LOW")
                        } ?: values.firstOrNull()
                        if (minLike != null) {
                            val r = m.invoke(target, minLike)
                            return (r as? Boolean) ?: true
                        }
                    }
                }
            }
        }

        return false
    }

    private fun trySetGoodReadBeepOff(): Boolean {
        // SDK version differences are handled by trying method candidates via reflection.
        val target = rfidUtil
        val clazz = target.javaClass

        // Simple boolean switches.
        val boolCandidates = listOf(
            "setGoodReadBeep",
            "setGoodReadBeeper",
            "setInventoryBeep",
            "setReadBeep",
            "setBeepOnRead"
        )
        for (name in boolCandidates) {
            val m = clazz.methods.firstOrNull {
                it.name == name && it.parameterTypes.size == 1 && it.parameterTypes[0] == Boolean::class.javaPrimitiveType
            } ?: continue
            val r = m.invoke(target, false)
            return (r as? Boolean) ?: true
        }

        // Mode setters (string/enum): try OFF-like value.
        val modeCandidates = listOf("setBeeperMode", "setBeepMode", "setReadBeepMode", "setGoodReadBeepMode")
        for (name in modeCandidates) {
            val m = clazz.methods.firstOrNull { it.name == name && it.parameterTypes.size == 1 } ?: continue
            val p = m.parameterTypes[0]
            runCatching {
                when {
                    p == String::class.java -> {
                        val r = m.invoke(target, "OFF")
                        return (r as? Boolean) ?: true
                    }
                    p.isEnum -> {
                        val values = p.enumConstants ?: emptyArray<Any>()
                        val offLike = values.firstOrNull {
                            val s = it.toString().uppercase()
                            s.contains("OFF") || s.contains("NONE") || s.contains("DISABLE")
                        } ?: values.firstOrNull()
                        if (offLike != null) {
                            val r = m.invoke(target, offLike)
                            return (r as? Boolean) ?: true
                        }
                    }
                }
            }
        }

        return false
    }

    override fun onConnected() {
        // Best effort: if SDK supports it, turn off success beep first, then lower beeper volume.
        runCatching { trySetGoodReadBeepOff() }
        runCatching { trySetBeeperVolumeMin() }
        emitEvent(mapOf("type" to "connected"))
        val ver = runCatching { rfidUtil.firmwareVersion }.getOrNull()
        if (!ver.isNullOrBlank()) {
            emitEvent(mapOf("type" to "firmware", "version" to ver))
        }
    }

    override fun onDisconnected() {
        epcLastNotifiedAt.clear()
        emitEvent(mapOf("type" to "disconnected"))
    }

    override fun onLinkLost() {
        emitEvent(mapOf("type" to "link_lost"))
    }

    override fun onTriggerChaned(trigger: Boolean) {
        emitEvent(mapOf("type" to "trigger_changed", "trigger" to trigger))
    }

    override fun onInventoryEPC(epc: String) {
        if (!shouldEmitInventoryEpc(epc)) return
        emitEvent(mapOf("type" to "inventory_epc", "raw" to epc))
    }

    override fun onReadTagData(data: String, epc: String) {
        emitEvent(mapOf("type" to "read_tag_data", "data" to data, "epc" to epc))
    }

    override fun onWriteTagData(epc: String) {
        emitEvent(mapOf("type" to "write_tag_data", "epc" to epc))
    }

    override fun onUploadTagData(data: String) {
        emitEvent(mapOf("type" to "upload_tag_data", "data" to data))
    }

    override fun onTagMemoryLocked(arg0: String) {
        emitEvent(mapOf("type" to "tag_memory_locked", "data" to arg0))
    }

    override fun onScanCode(code: String) {
        emitEvent(mapOf("type" to "scan_code", "code" to code))
    }

    override fun onScanTriggerChanged(trigger: Boolean) {
        emitEvent(mapOf("type" to "scan_trigger_changed", "trigger" to trigger))
    }
}
