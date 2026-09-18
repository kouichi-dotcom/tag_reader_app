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
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import jp.co.tss21.uhfrfid.dotr_android.EnMaskFlag
import jp.co.tss21.uhfrfid.dotr_android.EnMemoryBank
import jp.co.tss21.uhfrfid.dotr_android.OnDotrEventListener
import jp.co.tss21.uhfrfid.dotr_android.TagAccessParameter
import jp.co.tss21.uhfrfid.tssrfid.TssRfidUtill
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterActivity(), OnDotrEventListener {
    companion object {
        private const val PREFS_BRIDGE = "tss_rfid_bridge"
        private const val KEY_HIDDEN_BONDED = "hidden_bonded_addresses"
        /// iOS の kKnownDevicesKey 相当。接続に成功したリーダーを保存し、getBondedDevices で OS ペアリングとマージする。
        private const val KEY_KNOWN_READERS_JSON = "known_reader_devices_json"
    }

    private val methodChannelName = "tss_rfid/method"
    private val eventChannelName = "tss_rfid/events"

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val rfidUtil: TssRfidUtill = TssRfidUtill()

    /// connect は長時間ブロックし得るため UI スレッドで実行しない（Flutter の接続中インジケータが描画されないのを防ぐ）
    private val rfidConnectExecutor = Executors.newSingleThreadExecutor()

    private val reqCodeBtPermissions = 1001

    private var bleScanner: BluetoothLeScanner? = null
    // 削除された（アプリ上で非表示にした）端末は、名前判定に引っかかっても再接続できるよう
    // スキャン結果としてイベントを流す対象に含める。
    private var scanHiddenBondedAddresses: MutableSet<String> = mutableSetOf()
    // スキャン開始時点の OS bonded 端末（削除した端末は OS 側に残り得るため、名前判定で捨てない担保にする）
    private var scanOsBondedAddresses: MutableSet<String> = mutableSetOf()
    private val bleScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device ?: return
            val address = device.address ?: return
            val addressUpper = address.uppercase(Locale.US)
            val nameFromAdv = result.scanRecord?.deviceName?.trim()?.ifBlank { null }
            val nameFromDevice = device.name?.trim()?.ifBlank { null }
            var name = nameFromAdv ?: nameFromDevice ?: ""

            val isHidden = scanHiddenBondedAddresses.contains(addressUpper)
            val isOsBonded = scanOsBondedAddresses.contains(addressUpper)
            val isLikely = name.isNotEmpty() && isLikelyReaderName(name)

            // 通常は「リーダーっぽい名称」のみ通知するが、削除済み（隠し）や OS bonded は再接続のため通知する。
            if (!isHidden && !isLikely && !isOsBonded) return

            if (!isLikely && (isHidden || isOsBonded)) {
                // 削除済み / OS bonded 端末は、advertisement 名が取れない場合があるため bonded 名を補完する（可能な場合）。
                val adapter = BluetoothAdapter.getDefaultAdapter()
                val bondedName = adapter
                    ?.bondedDevices
                    ?.firstOrNull { it.address?.uppercase(Locale.US) == addressUpper }
                    ?.name
                    ?.trim()
                    ?.ifBlank { null }
                if (bondedName != null) name = bondedName
            }
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
                "writeTag" -> handleWriteTag(call, result)
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
        // "hidden" 機能は撤廃する（unpair 実行に統一する）ため、過去データを参照しない。
        // ただし既存端末に残っている hidden データがある可能性があるので、このタイミングでキーを削除する。
        val prefs = getSharedPreferences(PREFS_BRIDGE, Context.MODE_PRIVATE)
        val raw = prefs.getStringSet(KEY_HIDDEN_BONDED, emptySet()) ?: emptySet()
        if (raw.isNotEmpty()) {
            prefs.edit().remove(KEY_HIDDEN_BONDED).apply()
        }
        return mutableSetOf()
    }

    private fun saveHiddenBonded(set: Set<String>) {
        // hidden 機能は撤廃するため、保存しない（確実に削除する）
        getSharedPreferences(PREFS_BRIDGE, Context.MODE_PRIVATE).edit()
            .remove(KEY_HIDDEN_BONDED)
            .apply()
    }

    private fun loadKnownReaderEntries(): MutableList<Pair<String, String>> {
        val json = getSharedPreferences(PREFS_BRIDGE, Context.MODE_PRIVATE)
            .getString(KEY_KNOWN_READERS_JSON, null) ?: return mutableListOf()
        val out = mutableListOf<Pair<String, String>>()
        runCatching {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val name = o.optString("name", "").trim()
                val addr = o.optString("address", "").trim()
                if (name.isNotEmpty() && addr.isNotEmpty()) {
                    out.add(name to addr)
                }
            }
        }
        return out
    }

    private fun saveKnownReaderEntries(list: List<Pair<String, String>>) {
        val arr = JSONArray()
        for ((name, addr) in list) {
            arr.put(
                JSONObject().apply {
                    put("name", name)
                    put("address", addr)
                },
            )
        }
        getSharedPreferences(PREFS_BRIDGE, Context.MODE_PRIVATE).edit()
            .putString(KEY_KNOWN_READERS_JSON, arr.toString())
            .apply()
    }

    /** iOS TssRfidNativeBridge.rememberDeviceName と同等。接続に成功したリーダーを一覧用に保存する。 */
    private fun rememberReaderDevice(name: String, address: String) {
        val n = name.trim()
        val a = address.trim()
        if (n.isEmpty() || a.isEmpty()) return
        val key = a.uppercase(Locale.US)
        val list = loadKnownReaderEntries()
        if (list.any { it.second.uppercase(Locale.US) == key }) return
        list.add(n to a)
        saveKnownReaderEntries(list)
    }

    /** 接続処理をブロックしないよう、結果返却後にメインで Known を更新（直前の同期 I/O で GATT と競合しない） */
    private fun scheduleRememberReaderDevice(name: String, address: String) {
        Handler(Looper.getMainLooper()).post {
            runCatching { rememberReaderDevice(name, address) }
        }
    }

    private fun removeKnownReaderEntry(addressUpper: String) {
        val list = loadKnownReaderEntries().filter {
            it.second.uppercase(Locale.US) != addressUpper
        }
        saveKnownReaderEntries(list)
    }

    private fun tryUnpairDevice(device: android.bluetooth.BluetoothDevice): Boolean {
        return runCatching {
            val method = device.javaClass.getMethod("removeBond")
            val result = method.invoke(device)
            (result as? Boolean) ?: false
        }.getOrDefault(false)
    }

    private fun handleGetBondedDevices(result: MethodChannel.Result) {
        val perms = requiredBtPermissions()
        if (perms.isNotEmpty() && !hasAllPermissions(perms)) {
            result.error("permission_required", "Bluetooth permission is required.", null)
            return
        }

        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter != null && !adapter.isEnabled) {
            result.error("bluetooth_off", "Bluetooth is off.", null)
            return
        }

        val hidden = hiddenBondedAddresses()
        val merged = linkedMapOf<String, Map<String, String>>()

        // 1) アプリが記録したリーダー（iOS UserDefaults の known と同様。名前プレフィックスは掛けない）
        for ((name, addr) in loadKnownReaderEntries()) {
            val u = addr.uppercase(Locale.US)
            if (u in hidden) continue
            merged[u] = mapOf("name" to name, "address" to addr)
        }

        // 2) OS ペアリング済みでリーダー名が一致するもの
        if (adapter != null) {
            for (d in adapter.bondedDevices) {
                val addr = d.address?.trim() ?: continue
                if (addr.isEmpty()) continue
                val u = addr.uppercase(Locale.US)
                if (u in hidden) continue
                val devName = d.name?.trim().orEmpty()
                if (devName.isEmpty() || !isLikelyReaderName(devName)) continue
                if (!merged.containsKey(u)) {
                    merged[u] = mapOf("name" to devName, "address" to addr)
                }
            }
        }

        val devices = merged.values.sortedBy { it["name"] as String }
        result.success(devices)
    }

    private fun handleRemoveBondedDevice(call: MethodCall, result: MethodChannel.Result) {
        val addr = call.argument<String>("address")?.trim()?.uppercase(Locale.US) ?: run {
            result.success(false)
            return
        }
        if (addr.isEmpty()) {
            result.success(false)
            return
        }

        // 1) アプリ側の一覧データは必ず消す（再表示や再接続候補を残さない）
        removeKnownReaderEntry(addr)
        val hidden = hiddenBondedAddresses()
        hidden.remove(addr)
        saveHiddenBonded(hidden)
        scanHiddenBondedAddresses.remove(addr)
        scanOsBondedAddresses.remove(addr)

        // 2) OS 側のペアリング解除（完全に unpair）
        val adapter = BluetoothAdapter.getDefaultAdapter()
        val bondedDevice = adapter
            ?.bondedDevices
            ?.firstOrNull { it.address?.uppercase(Locale.US) == addr }

        val unpairOk = bondedDevice?.let { tryUnpairDevice(it) } ?: true
        result.success(unpairOk)
    }

    private fun handleStartBleScan(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.success(false)
            return
        }
        if (!adapter.isEnabled) {
            result.error("bluetooth_off", "Bluetooth is off.", null)
            return
        }
        val perms = requiredBtPermissions()
        if (perms.isNotEmpty() && !hasAllPermissions(perms)) {
            result.error("permission_required", "Bluetooth permission is required.", null)
            return
        }
        // スキャン開始時点の隠し端末一覧をキャッシュして、スキャン中の判定を軽くする。
        scanHiddenBondedAddresses = hiddenBondedAddresses()
        // OS bonded 端末は削除後も残る可能性があるため、名前判定で捨てない担保にする。
        scanOsBondedAddresses = adapter.bondedDevices
            ?.mapNotNull { it.address }
            ?.map { it.uppercase(Locale.US) }
            ?.toMutableSet() ?: mutableSetOf()
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
            "R5000",
            "R-5000",
            "Rー5000",
            "SR_7",
            "SR-7",
            "SR＿7",
            "SR7",
            "SR７",
           
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

        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter != null && !adapter.isEnabled) {
            result.error("bluetooth_off", "Bluetooth is off.", null)
            return
        }

        val perms = requiredBtPermissions()
        if (perms.isNotEmpty() && !hasAllPermissions(perms)) {
            result.error("permission_required", "Bluetooth permission is required.", null)
            return
        }

        rfidConnectExecutor.execute {
            runCatching {
                // 接続前に context とリーダー名を設定
                rfidUtil.initReader(this@MainActivity, name)
                rfidUtil.connect(address)
            }.onSuccess { ok ->
                runOnUiThread {
                    // 接続成功後に Known を更新。接続ハンドラ内の同期 I/O でメインが詰まると GATT/SDK と競合しやすい
                    if (ok) scheduleRememberReaderDevice(name, address)
                    result.success(ok)
                }
            }.onFailure { e ->
                runOnUiThread {
                    result.error("connect_failed", e.message, null)
                }
            }
        }
    }

    private fun handleStartInventory(call: MethodCall, result: MethodChannel.Result) {
        if (!rfidUtil.isConnect()) {
            result.error(
                "inventory_failed",
                "Tag reader is not connected.",
                null,
            )
            return
        }

        val dateTime = call.argument<Boolean>("dateTime") ?: true
        val radioPower = call.argument<Boolean>("radioPower") ?: true
        // iOS TSS_SDK は setInventoryReportMode が reportTime / RSSI のみ。channel/temp/phase は無視して同一挙動にする。
        val noRepeat = call.argument<Boolean>("noRepeat") ?: false

        runCatching {
            rfidUtil.setNoRepeat(noRepeat)
            // 読取セッション開始のたびにクリア。noRepeat=true でも前回の EPC が残ると再通知されない。
            rfidUtil.clearAccessEPCList()
            rfidUtil.setInventoryReportMode(dateTime, radioPower, false, false, false)
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

    /// EPC（UII）書込み。公式 WriteTag サンプルに合わせ、マスクなし・Q=0・継続試行。
    private fun handleWriteTag(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureConnected(result)) return
        val currentEpc = (call.argument<String>("currentEpc") ?: "").trim().lowercase(Locale.US)
        val newEpc = (call.argument<String>("newEpc") ?: "").trim().lowercase(Locale.US)
        val useMask = call.argument<Boolean>("useMask") ?: false
        if (currentEpc.isEmpty() || newEpc.isEmpty()) {
            result.error("write_tag_failed", "currentEpc and newEpc are required.", null)
            return
        }
        if (newEpc.length % 4 != 0) {
            result.error("write_tag_failed", "newEpc length must be a multiple of 4 hex chars.", null)
            return
        }

        runCatching {
            // 進行中の読取を止めてから書込（少し間を空ける）
            runCatching { rfidUtil.stop() }
            Thread.sleep(150)
            rfidUtil.clearAccessEPCList()

            // 単票書込み向け（公式サンプルも接続時に Q=0）
            runCatching { rfidUtil.setQValue(0) }

            // 前回マスクが残っていると書けないことがあるためクリア
            runCatching {
                rfidUtil.setTagAccessMask(EnMemoryBank.EPC, 0, 0, hexToBytes("0000"))
            }

            val maskFlag: EnMaskFlag
            if (useMask) {
                val maskBits = currentEpc.length * 4
                rfidUtil.setTagAccessMask(EnMemoryBank.EPC, 32, maskBits, hexToBytes(currentEpc))
                maskFlag = EnMaskFlag.SelectMask
            } else {
                // 公式サンプルどおりマスクなし（密着＋低〜中出力で誤書込を抑える）
                maskFlag = EnMaskFlag.None
            }

            val param = TagAccessParameter()
            param.setMemoryBank(EnMemoryBank.EPC)
            // CRC(1word)+PC(1word) の次から UII を書く（iOS サンプルと同じ）
            param.setWordOffset(2)
            param.setWordCount(newEpc.length / 4)

            // timeout=0: 成功か stop まで継続（公式サンプルと同じ）
            // singleTag=true: 1枚書けたら終了
            val ok = rfidUtil.writeTag(param, newEpc, true, maskFlag, 0)
            emitEvent(
                mapOf(
                    "type" to "write_tag_started",
                    "ok" to ok,
                    "newEpc" to newEpc,
                    "useMask" to useMask,
                    "wordCount" to (newEpc.length / 4),
                ),
            )
            if (!ok) {
                emitEvent(mapOf("type" to "write_tag_failed", "message" to "writeTag returned false"))
            }
            ok
        }.onSuccess { ok ->
            result.success(ok)
        }.onFailure { e ->
            emitEvent(mapOf("type" to "write_tag_failed", "message" to (e.message ?: "error")))
            result.error("write_tag_failed", e.message, null)
        }
    }

    private fun hexToBytes(hex: String): ByteArray {
        val clean = hex.replace("\\s".toRegex(), "")
        require(clean.length % 2 == 0) { "hex length must be even" }
        return ByteArray(clean.length / 2) { i ->
            clean.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
    }

    // iOS の MethodChannel setBeeperVolumeMin / setGoodReadBeepOff はプラグインでスタブ（true）だが、
    // 接続時のビープ低減は onConnected と同様の目的でここで反射呼び出しする（方針 A）。

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
        emitEvent(mapOf("type" to "disconnected"))
    }

    override fun onLinkLost() {
        emitEvent(mapOf("type" to "link_lost"))
    }

    override fun onTriggerChaned(trigger: Boolean) {
        emitEvent(mapOf("type" to "trigger_changed", "trigger" to trigger))
    }

    override fun onInventoryEPC(epc: String) {
        val trim = epc.trim()
        if (trim.isEmpty()) return
        emitEvent(mapOf("type" to "inventory_epc", "raw" to trim))
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
