package com.example.beontag_utfpr_agro_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val C72_METHOD_CHANNEL = "com.example.beontag_utfpr_agro_mobile/c72"
        private const val C72_EVENT_CHANNEL = "com.example.beontag_utfpr_agro_mobile/c72_tags"
        private const val C72_TRIGGER_EVENT_CHANNEL = "com.example.beontag_utfpr_agro_mobile/c72_trigger"

        private const val BTL_METHOD_CHANNEL = "com.example.beontag_utfpr_agro_mobile/btl"
        private const val BTL_EVENT_CHANNEL = "com.example.beontag_utfpr_agro_mobile/btl_tags"
        private const val BTL_TRIGGER_EVENT_CHANNEL = "com.example.beontag_utfpr_agro_mobile/btl_trigger"

        private const val BT_PERMISSION_REQUEST_CODE = 1001

        // Chainway C72 trigger key codes (varies by firmware)
        private val TRIGGER_KEY_CODES = setOf(
            KeyEvent.KEYCODE_F1,  // 131
            KeyEvent.KEYCODE_F2,  // 132
            KeyEvent.KEYCODE_F3,  // 133
            KeyEvent.KEYCODE_F4,  // 134
            KeyEvent.KEYCODE_F5,  // 135
            293,                   // KEYCODE_SCAN_TRIGGER (some Chainway firmware)
        )
    }

    private var c72Wrapper: C72ReaderWrapper? = null
    private var btlWrapper: BTLReaderWrapper? = null

    private var c72TagEventSink: EventChannel.EventSink? = null
    private var c72TriggerEventSink: EventChannel.EventSink? = null

    private var btlTagEventSink: EventChannel.EventSink? = null
    private var btlTriggerEventSink: EventChannel.EventSink? = null

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode in TRIGGER_KEY_CODES) {
            c72TriggerEventSink?.success(true)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode in TRIGGER_KEY_CODES) {
            c72TriggerEventSink?.success(false)
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    override fun onStart() {
        super.onStart()
        requestBluetoothPermissionsIfNeeded()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        c72Wrapper = C72ReaderWrapper(applicationContext)
        btlWrapper = BTLReaderWrapper(applicationContext)

        setupC72Channels(flutterEngine)
        setupBTLChannels(flutterEngine)
    }

    // ── C72 channels ──────────────────────────────────────────────────────────

    private fun setupC72Channels(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, C72_TRIGGER_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    c72TriggerEventSink = events
                }
                override fun onCancel(arguments: Any?) { c72TriggerEventSink = null }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, C72_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isC72Device" -> result.success(c72Wrapper?.isC72Device() == true)
                "initReader" -> {
                    try {
                        c72Wrapper?.initReader()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", e.message ?: "C72 init failed", null)
                    }
                }
                "disconnectReader" -> { c72Wrapper?.disconnectReader(); result.success(null) }
                "setPower" -> {
                    val power = (call.arguments as? Number)?.toInt() ?: 30
                    result.success(c72Wrapper?.setPower(power) == true)
                }
                "getPower" -> {
                    val arr = c72Wrapper?.getPower() ?: intArrayOf(30, 30)
                    result.success(listOf(arr[0], arr[1]))
                }
                "startScan" -> { c72Wrapper?.startScan(); result.success(null) }
                "stopScan" -> { c72Wrapper?.stopScan(); result.success(null) }
                "isConnected" -> result.success(c72Wrapper?.isConnected() == true)
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, C72_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    c72TagEventSink = events
                    c72Wrapper?.onTagRead = { map -> runOnUiThread { c72TagEventSink?.success(map) } }
                }
                override fun onCancel(arguments: Any?) {
                    c72Wrapper?.onTagRead = null
                    c72Wrapper?.stopScan()
                    c72TagEventSink = null
                }
            }
        )
    }

    // ── BTL channels ──────────────────────────────────────────────────────────

    private fun setupBTLChannels(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BTL_TRIGGER_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    btlTriggerEventSink = events
                    btlWrapper?.onTriggerChanged = { pressed ->
                        runOnUiThread { btlTriggerEventSink?.success(pressed) }
                    }
                }
                override fun onCancel(arguments: Any?) {
                    btlWrapper?.onTriggerChanged = null
                    btlTriggerEventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BTL_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasBTLDevice" -> result.success(btlWrapper?.hasBTLDevice() == true)
                "connectReader" -> {
                    Thread {
                        try {
                            btlWrapper?.connect()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BTL_CONNECT_ERROR", e.message ?: "BTL connect failed", null)
                        }
                    }.start()
                }
                "disconnectReader" -> { btlWrapper?.disconnect(); result.success(null) }
                "setPower" -> {
                    val power = (call.arguments as? Number)?.toInt() ?: 29
                    result.success(btlWrapper?.setPower(power) == true)
                }
                "getPower" -> {
                    val arr = btlWrapper?.getPower() ?: intArrayOf(29, 29)
                    result.success(listOf(arr[0], arr[1]))
                }
                "startScan" -> { btlWrapper?.startScan(); result.success(null) }
                "stopScan" -> { btlWrapper?.stopScan(); result.success(null) }
                "isConnected" -> result.success(btlWrapper?.isConnected() == true)
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BTL_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    btlTagEventSink = events
                    btlWrapper?.onTagRead = { map -> runOnUiThread { btlTagEventSink?.success(map) } }
                }
                override fun onCancel(arguments: Any?) {
                    btlWrapper?.onTagRead = null
                    btlWrapper?.stopScan()
                    btlTagEventSink = null
                }
            }
        )
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onDestroy() {
        c72Wrapper?.disconnectReader()
        btlWrapper?.disconnect()
        super.onDestroy()
    }

    override fun onStop() {
        c72Wrapper?.disconnectReader()
        btlWrapper?.disconnect()
        super.onStop()
    }

    // ── Bluetooth permissions ─────────────────────────────────────────────────

    private fun requestBluetoothPermissionsIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val needed = arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN
            ).filter {
                ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
            }
            if (needed.isNotEmpty()) {
                ActivityCompat.requestPermissions(this, needed.toTypedArray(), BT_PERMISSION_REQUEST_CODE)
            }
        }
    }
}
