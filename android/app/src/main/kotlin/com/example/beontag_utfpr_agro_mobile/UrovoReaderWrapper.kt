package com.example.beontag_utfpr_agro_mobile

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ubx.usdk.RFIDSDKManager
import com.ubx.usdk.bean.ReadTag
import com.ubx.usdk.bean.enums.QueryMemBank
import com.ubx.usdk.bean.enums.RssiUnitType
import com.ubx.usdk.listener.DataCallback
import com.ubx.usdk.listener.InitListener
import com.ubx.usdk.rfid.RfidManager
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Wraps the integrated UHF RFID reader of Urovo devices (DT50P and others) using the official URFIDLibrary AAR,
 * for use via Flutter platform channels. Mirrors C72ReaderWrapper: init, power, start/stop inventory, tag stream.
 *
 * SDK calls block and must run in sequence (RFID Development Documentation v2.25, §1.3), so they all go through a
 * single background thread. The SDK depends on classes that only exist in the Urovo ROM, so nothing here touches it
 * unless [isUrovoDevice] is true, and SDK calls catch Throwable (NoClassDefFoundError on other devices).
 */
class UrovoReaderWrapper(context: Context) {

    private val appContext = context.applicationContext
    private val executorLazy = lazy<ExecutorService> { Executors.newSingleThreadExecutor() }
    private val executor by executorLazy
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()

    /** True after a successful init, until [disconnectReader]. The link itself may drop (e.g. screen off). */
    @Volatile private var initialized = false
    /** False after [disconnectReader], so late SDK callbacks don't bring the reader back. */
    @Volatile private var connectionWanted = false
    @Volatile private var maxPower = DEFAULT_MAX_POWER
    @Volatile private var outputPower = DEFAULT_POWER
    @Volatile private var rssiUnitType: RssiUnitType? = null
    private val isInventorying = AtomicBoolean(false)

    // Guarded by [lock].
    private var initInProgress = false
    private val pendingInitCallbacks = mutableListOf<(String?) -> Unit>()
    private var pendingPower: Int? = null
    private var powerTaskQueued = false
    private val pendingPowerCallbacks = mutableListOf<(Boolean) -> Unit>()

    /** Callback to emit tag maps to Flutter (MainActivity forwards it on the main thread). */
    @Volatile var onTagRead: ((Map<String, Any>) -> Unit)? = null

    val isUrovoDevice: Boolean by lazy { detectUrovoDevice() }

    private fun detectUrovoDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER ?: ""
        val brand = Build.BRAND ?: ""
        val model = Build.MODEL ?: ""
        Log.d(TAG, "Device check — manufacturer=$manufacturer brand=$brand model=$model")
        val looksLikeUrovo = manufacturer.contains("urovo", ignoreCase = true) ||
            brand.contains("urovo", ignoreCase = true) ||
            manufacturer.equals("ubx", ignoreCase = true) ||
            brand.equals("ubx", ignoreCase = true) ||
            model.startsWith("DT50", ignoreCase = true)
        if (!looksLikeUrovo) return false
        // android.device.* is provided only by the Urovo ROM and the RFID SDK cannot run without it.
        return try {
            Class.forName("android.device.DeviceManager")
            true
        } catch (t: Throwable) {
            Log.w(TAG, "Urovo-like device without android.device.DeviceManager: ${t.message}")
            false
        }
    }

    // ── Connection ────────────────────────────────────────────────────────────

    private val initTimeout = Runnable {
        Log.w(TAG, "initReader: no answer from the RFID module after ${INIT_TIMEOUT_MS}ms")
        finishInit("UROVO_INIT_TIMEOUT: RFID module did not respond")
    }

    private val initListener by lazy {
        InitListener { status ->
            Log.i(TAG, "InitListener.onStatus($status)")
            runOnSdkThread { onInitStatus(status) }
        }
    }

    private val dataCallback by lazy {
        object : DataCallback {
            override fun onInventoryTag(readTag: ReadTag?) {
                if (readTag == null || !isInventorying.get()) return
                onTagRead?.invoke(tagToMap(readTag))
            }

            override fun onInventoryTagEnd() {}
        }
    }

    /**
     * Initializes the RFID module. [callback] runs on the main thread with null on success or an error message.
     * Idempotent: if the module is already connected it only answers success.
     */
    fun initReader(callback: (String?) -> Unit) {
        if (!isUrovoDevice) {
            callback("UROVO_NOT_SUPPORTED: not a Urovo device")
            return
        }
        connectionWanted = true
        synchronized(lock) {
            pendingInitCallbacks += callback
            if (initInProgress) return
            initInProgress = true
        }
        val queued = runOnSdkThread {
            try {
                if (isSdkConnected()) {
                    // Already connected, or the SDK singleton survived an Activity re-creation.
                    if (!initialized) onConnected()
                    finishInit(null)
                    return@runOnSdkThread
                }
                mainHandler.postDelayed(initTimeout, INIT_TIMEOUT_MS)
                RFIDSDKManager.getInstance().init(appContext, initListener)
            } catch (t: Throwable) {
                Log.e(TAG, "initReader failed", t)
                finishInit("UROVO_INIT_ERROR: ${t.message}")
            }
        }
        if (!queued) finishInit("UROVO_INIT_ERROR: reader shut down")
    }

    /** Runs on the executor. Also called when the SDK reconnects by itself (e.g. after the screen turns on). */
    private fun onInitStatus(status: Boolean) {
        val initPending = synchronized(lock) { initInProgress }
        if (status) {
            if (!connectionWanted) {
                Log.d(TAG, "Reader connected after disconnectReader(); releasing it again")
                safeRelease()
                finishInit("UROVO_INIT_ERROR: reader was disconnected")
                return
            }
            try {
                onConnected()
                finishInit(null)
            } catch (t: Throwable) {
                Log.e(TAG, "Configuring the reader failed", t)
                finishInit("UROVO_INIT_ERROR: ${t.message}")
            }
        } else {
            isInventorying.set(false)
            if (initPending) {
                initialized = false
                safeRelease()
                finishInit("UROVO_INIT_ERROR: RFID module not available")
            } else {
                Log.w(TAG, "RFID link lost; the SDK reconnects when the module powers up again")
            }
        }
    }

    private fun onConnected() {
        val manager = RFIDSDKManager.getInstance().rfidManager
            ?: throw IllegalStateException("RfidManager not available")
        manager.addDataCallback(dataCallback)
        applyTidMode(manager)
        val max = manager.supportMaxOutputPower
        if (max >= MIN_POWER) maxPower = max
        rssiUnitType = try { manager.rssiUnitType } catch (t: Throwable) { null }
        initialized = true
        Log.i(TAG, "Urovo reader ready: deviceType=${manager.readerDeviceType} maxPower=$maxPower")
    }

    /** EPC+TID inventory: the TID (6 words = 96 bits, same as the C72) comes in ReadTag.memId. */
    private fun applyTidMode(manager: RfidManager) {
        val ret = manager.setQueryMemoryBank(QueryMemBank.EPC_TID, 0, TID_WORDS)
        if (ret == SUCCESS) return
        Log.w(TAG, "setQueryMemoryBank(EPC_TID) failed: $ret, trying FASTTID")
        val fastTid = manager.setQueryMemoryBank(QueryMemBank.FASTTID, 0, 0)
        if (fastTid != SUCCESS) Log.e(TAG, "setQueryMemoryBank(FASTTID) failed: $fastTid, tags will have no TID")
    }

    private fun finishInit(error: String?) {
        mainHandler.removeCallbacks(initTimeout)
        val callbacks = synchronized(lock) {
            initInProgress = false
            pendingInitCallbacks.toList().also { pendingInitCallbacks.clear() }
        }
        if (callbacks.isNotEmpty()) mainHandler.post { callbacks.forEach { it(error) } }
    }

    /**
     * Stops reading, gives the grip trigger back to the barcode scanner and releases the module.
     * Waits up to [waitMs] for the release when the app is closing.
     */
    fun disconnectReader(waitMs: Long = 0) {
        connectionWanted = false
        if (!initialized) return
        initialized = false
        isInventorying.set(false)
        try {
            val task = executor.submit(Runnable {
                try {
                    val sdk = RFIDSDKManager.getInstance()
                    sdk.rfidManager?.stopInventory()
                    sdk.enableScanHead(true)
                } catch (t: Throwable) {
                    Log.w(TAG, "disconnectReader warning: ${t.message}")
                }
                safeRelease()
            })
            if (waitMs > 0) task.get(waitMs, TimeUnit.MILLISECONDS)
        } catch (t: Throwable) {
            Log.w(TAG, "disconnectReader: ${t.message}")
        }
    }

    private fun safeRelease() {
        try {
            RFIDSDKManager.getInstance().release()
            Log.d(TAG, "release() called")
        } catch (t: Throwable) {
            Log.w(TAG, "release() warning: ${t.message}")
        }
    }

    /** Queues [block] on the SDK thread; returns false if the thread was already shut down. */
    private fun runOnSdkThread(block: () -> Unit): Boolean = try {
        executor.execute { block() }
        true
    } catch (e: RejectedExecutionException) {
        Log.w(TAG, "SDK thread stopped, ignoring call")
        false
    }

    /** Stops the SDK thread, waiting briefly for queued calls (e.g. release()) to finish. */
    fun shutdown() {
        if (!executorLazy.isInitialized()) return
        executor.shutdown()
        try {
            executor.awaitTermination(SHUTDOWN_WAIT_MS, TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
        }
    }

    fun isConnected(): Boolean = initialized && isSdkConnected()

    private fun isSdkConnected(): Boolean = try {
        RFIDSDKManager.getInstance().isConnected
    } catch (t: Throwable) {
        false
    }

    /**
     * Enables or disables the barcode scan engine on the grip trigger (key 523). Urovo stores this in persistent
     * system properties, so it must be turned back on whenever the app leaves the foreground.
     */
    fun setBarcodeOnTriggerEnabled(enabled: Boolean) {
        if (!initialized) return
        runOnSdkThread {
            try {
                RFIDSDKManager.getInstance().enableScanHead(enabled)
            } catch (t: Throwable) {
                Log.w(TAG, "enableScanHead($enabled) warning: ${t.message}")
            }
        }
    }

    // ── Power ─────────────────────────────────────────────────────────────────

    /**
     * Sets the output power (clamped to [MIN_POWER]..max supported). Rapid calls (slider drags) are coalesced so
     * only the latest value reaches the serial port; [callback] runs on the main thread.
     */
    fun setPower(power: Int, callback: (Boolean) -> Unit) {
        if (!initialized) {
            callback(false)
            return
        }
        val schedule = synchronized(lock) {
            pendingPower = power
            pendingPowerCallbacks += callback
            (!powerTaskQueued).also { powerTaskQueued = true }
        }
        if (!schedule) return
        val queued = runOnSdkThread {
            val (value, callbacks) = takePendingPower()
            val ok = value != null && applyPower(value)
            mainHandler.post { callbacks.forEach { it(ok) } }
        }
        if (!queued) takePendingPower().second.forEach { it(false) }
    }

    private fun takePendingPower(): Pair<Int?, List<(Boolean) -> Unit>> = synchronized(lock) {
        powerTaskQueued = false
        val requested = pendingPower
        pendingPower = null
        requested to pendingPowerCallbacks.toList().also { pendingPowerCallbacks.clear() }
    }

    private fun applyPower(power: Int): Boolean {
        val p = power.coerceIn(MIN_POWER, maxPower)
        return try {
            val ret = RFIDSDKManager.getInstance().rfidManager?.setOutputPower(p) ?: -1
            if (ret == SUCCESS) {
                outputPower = p
                true
            } else {
                Log.w(TAG, "setOutputPower($p) failed: $ret")
                false
            }
        } catch (t: Throwable) {
            Log.e(TAG, "setOutputPower($p) error", t)
            false
        }
    }

    /** Returns [readPower, writePower] (the same value) on the main thread. */
    fun getPower(callback: (IntArray) -> Unit) {
        if (!initialized) {
            callback(intArrayOf(outputPower, outputPower))
            return
        }
        val queued = runOnSdkThread {
            try {
                val p = RFIDSDKManager.getInstance().rfidManager?.outputPower ?: -1
                if (p >= 0) outputPower = p
            } catch (t: Throwable) {
                Log.w(TAG, "getOutputPower warning: ${t.message}")
            }
            val p = outputPower
            mainHandler.post { callback(intArrayOf(p, p)) }
        }
        if (!queued) callback(intArrayOf(outputPower, outputPower))
    }

    fun getMaxPower(): Int = maxPower

    // ── Scanning ──────────────────────────────────────────────────────────────

    fun startScan() {
        if (!isUrovoDevice || isInventorying.getAndSet(true)) return
        if (!initialized) {
            // Auto-init (e.g. after the module was released), then start if the trigger is still held.
            initReader { error ->
                if (error != null) {
                    Log.e(TAG, "Auto-init in startScan failed: $error")
                    isInventorying.set(false)
                } else if (!runOnSdkThread { startInventoryNow() }) {
                    isInventorying.set(false)
                }
            }
            return
        }
        if (!runOnSdkThread { startInventoryNow() }) isInventorying.set(false)
    }

    private fun startInventoryNow() {
        if (!isInventorying.get()) return
        try {
            val ret = RFIDSDKManager.getInstance().rfidManager?.startInventory() ?: -1
            if (ret != SUCCESS) {
                Log.w(TAG, "startInventory failed: $ret")
                isInventorying.set(false)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "startInventory error", t)
            isInventorying.set(false)
        }
    }

    fun stopScan() {
        if (!isInventorying.getAndSet(false)) return
        runOnSdkThread {
            try {
                RFIDSDKManager.getInstance().rfidManager?.stopInventory()
            } catch (t: Throwable) {
                Log.w(TAG, "stopInventory warning: ${t.message}")
            }
        }
    }

    private fun tagToMap(tag: ReadTag): Map<String, Any> {
        val timestamp = SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale.US).format(Date())
        return mapOf(
            "epc" to normalizeHex(tag.epcId),
            "tid" to normalizeHex(tag.memId),
            "rssi" to rssiDbm(tag),
            "readCount" to 1,
            "timestamp" to timestamp,
            "model" to MODEL_NAME
        )
    }

    private fun normalizeHex(value: String?): String =
        value?.filterNot { it.isWhitespace() }?.uppercase(Locale.US) ?: ""

    /** dBm like the C72. Falls back to the RELATIVE (31–110) → dBm table (doc Appendix 3) if rssidBm is missing. */
    private fun rssiDbm(tag: ReadTag): Int {
        if (tag.rssidBm != 0) return tag.rssidBm
        val relative = tag.rssi
        if (rssiUnitType != RssiUnitType.RELATIVE || relative !in 31..110) return DEFAULT_RSSI
        return if (relative >= 90) relative - 129 else relative - 130
    }

    companion object {
        private const val TAG = "UrovoReaderWrapper"
        private const val MODEL_NAME = "DT50P"
        private const val SUCCESS = 0
        private const val TID_WORDS = 6
        private const val MIN_POWER = 5
        private const val DEFAULT_MAX_POWER = 33
        private const val DEFAULT_POWER = 30
        private const val DEFAULT_RSSI = -80
        private const val INIT_TIMEOUT_MS = 15_000L
        private const val SHUTDOWN_WAIT_MS = 2_000L
    }
}
