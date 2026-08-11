package com.example.beontag_utfpr_agro_mobile

import android.os.Build
import android.util.Log
import com.rscja.deviceapi.RFIDWithUHFUART
import com.rscja.deviceapi.entity.UHFTAGInfo
import com.rscja.deviceapi.exception.ConfigurationException
import com.rscja.deviceapi.interfaces.ConnectionStatus
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Wraps the Chainway C72 UHF RFID reader (DeviceAPI AAR) for use via Flutter platform channels.
 * Mirrors the logic of oldCode C72Reader: init, setPower, getPower, start/stop inventory, tag stream.
 */
class C72ReaderWrapper(private val context: android.content.Context) {

    private var mReader: RFIDWithUHFUART? = null
    private val isInventorying = AtomicBoolean(false)
    private var outputPower: Int = 30
    private var readThread: Thread? = null

    /** Callback to emit tag maps to Flutter (invoke on main thread from MainActivity). */
    var onTagRead: ((Map<String, Any>) -> Unit)? = null

    fun isC72Device(): Boolean {
        val model = Build.MODEL ?: ""
        val manufacturer = Build.MANUFACTURER ?: ""
        Log.d(TAG, "Device check — manufacturer=$manufacturer model=$model")
        // Match any Chainway C72 variant (C72, C72e, C72W, etc.)
        if (model.contains("c72", ignoreCase = true)) return true
        if (manufacturer.contains("chainway", ignoreCase = true)) return true
        return false
    }

    @Throws(Exception::class)
    fun initReader() {
        val reader = RFIDWithUHFUART.getInstance()

        // If already connected, skip
        if (mReader != null && reader.getConnectStatus() == ConnectionStatus.CONNECTED) {
            Log.d(TAG, "initReader: already connected, skipping")
            return
        }

        // Free stale UART from previous session (e.g. app restart, hot-reload)
        try {
            reader.free()
            Log.d(TAG, "initReader: called free() to release previous UART")
        } catch (e: Exception) {
            Log.w(TAG, "initReader: free() warning: ${e.message}")
        }
        mReader = null

        // Wait for UHF module to fully power down after free()
        Thread.sleep(1500)

        try {
            reader.init()
            outputPower = 30
            reader.setPower(outputPower)
            mReader = reader
            Log.i(TAG, "initReader: C72 reader initialized successfully")
        } catch (e: ConfigurationException) {
            Log.e(TAG, "initReader: ${e.message}", e)
            mReader = null
            throw Exception("C72_INITIALIZE_ERROR: ${e.message}")
        }
    }

    fun disconnectReader() {
        stopScan()
        try {
            mReader?.free()
            Log.d(TAG, "disconnectReader: free() called")
        } catch (e: Exception) {
            Log.w(TAG, "disconnectReader: free() warning: ${e.message}")
        }
        mReader = null
    }

    fun isConnected(): Boolean {
        val reader = mReader ?: return false
        return reader.getConnectStatus() == ConnectionStatus.CONNECTED
    }

    fun setPower(power: Int): Boolean {
        val reader = mReader ?: return false
        val p = power.coerceIn(5, 30)
        return if (reader.setPower(p)) {
            outputPower = p
            true
        } else {
            Log.d(TAG, "setPower failed: ${reader.getErrCode()}")
            false
        }
    }

    fun getPower(): IntArray {
        val reader = mReader ?: return intArrayOf(outputPower, outputPower)
        val p = reader.getPower()
        return intArrayOf(p, p)
    }

    fun startScan() {
        if (isInventorying.getAndSet(true)) return
        // Auto-init reader if not yet initialized (e.g. after app restart)
        if (mReader == null) {
            try {
                initReader()
            } catch (e: Exception) {
                Log.e(TAG, "Auto-init in startScan failed: ${e.message}")
                isInventorying.set(false)
                return
            }
        }
        val reader = mReader ?: run {
            isInventorying.set(false)
            return
        }
        resetFilters(reader)
        reader.setEPCAndTIDMode()
        if (!reader.startInventoryTag()) {
            isInventorying.set(false)
            return
        }
        readThread = Thread {
            var receivedTag: UHFTAGInfo?
            while (isInventorying.get()) {
                receivedTag = reader.readTagFromBuffer()
                if (receivedTag != null) {
                    val map = tagInfoToMap(receivedTag)
                    onTagRead?.invoke(map)
                }
            }
        }.apply { start() }
    }

    fun stopScan() {
        if (!isInventorying.getAndSet(false)) return
        mReader?.let {
            it.stopInventory()
            resetFilters(it)
        }
        readThread?.join(500)
        readThread = null
    }

    private fun resetFilters(reader: RFIDWithUHFUART) {
        reader.setFilter(0, 0, 0, "")
    }

    private fun tagInfoToMap(tag: UHFTAGInfo): Map<String, Any> {
        val rssiStr = tag.getRssi() ?: "0"
        val doubleRssi = rssiStr.toDoubleOrNull() ?: 0.0
        val intRssi = BigDecimal.valueOf(doubleRssi).setScale(0, BigDecimal.ROUND_HALF_UP).toInt()
        val timestamp = SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale.US).format(Date())
        return mapOf(
            "epc" to (tag.getEPC() ?: ""),
            "tid" to (tag.getTid() ?: ""),
            "rssi" to intRssi,
            "readCount" to (tag.getCount() ?: 1),
            "timestamp" to timestamp,
            "model" to "C72"
        )
    }

    companion object {
        private const val TAG = "C72ReaderWrapper"
    }
}
