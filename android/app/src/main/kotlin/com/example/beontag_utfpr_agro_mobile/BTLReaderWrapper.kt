package com.example.beontag_utfpr_agro_mobile

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.uk.tsl.rfid.asciiprotocol.AsciiCommander
import com.uk.tsl.rfid.asciiprotocol.commands.AbortCommand
import com.uk.tsl.rfid.asciiprotocol.commands.ReadTransponderCommand
import com.uk.tsl.rfid.asciiprotocol.commands.SwitchActionCommand
import com.uk.tsl.rfid.asciiprotocol.device.Reader
import com.uk.tsl.rfid.asciiprotocol.device.ReaderManager
import com.uk.tsl.rfid.asciiprotocol.enumerations.Databank
import com.uk.tsl.rfid.asciiprotocol.enumerations.SwitchState
import com.uk.tsl.rfid.asciiprotocol.enumerations.TriState
import com.uk.tsl.rfid.asciiprotocol.responders.ICommandResponseLifecycleDelegate
import com.uk.tsl.rfid.asciiprotocol.responders.ISwitchStateReceivedDelegate
import com.uk.tsl.rfid.asciiprotocol.responders.ITransponderReceivedDelegate
import com.uk.tsl.rfid.asciiprotocol.responders.LoggerResponder
import com.uk.tsl.rfid.asciiprotocol.responders.SwitchResponder
import java.math.BigInteger
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Wraps the TSL 2128P (Acura BTL2128p) UHF RFID reader via Bluetooth SPP.
 * Uses TSL ASCII Protocol SDK. Mirrors the structure of C72ReaderWrapper for Flutter channel integration.
 */
class BTLReaderWrapper(private val context: Context) {

    private val commander: AsciiCommander get() = AsciiCommander.sharedInstance()

    private var mReader: Reader? = null
    private val mReadCommand = ReadTransponderCommand()
    private val mReadResponder = ReadTransponderCommand()
    private val isInventorying = AtomicBoolean(false)
    private var mContinuousScanEnabled = false
    private var readPower: Int = 29

    /** Called on the main thread by MainActivity to forward tag events to Flutter. */
    var onTagRead: ((Map<String, Any>) -> Unit)? = null

    /** Called on any thread when the physical trigger is pressed (true) or released (false). */
    var onTriggerChanged: ((Boolean) -> Unit)? = null

    init {
        AsciiCommander.createSharedInstance(context.applicationContext)
        ReaderManager.create(context.applicationContext)
        setupReadCommand()
    }

    // ── Device detection ─────────────────────────────────────────────────────

    fun hasBTLDevice(): Boolean {
        return try {
            if (!hasBluetoothPermission()) {
                Log.w(TAG, "hasBTLDevice: BLUETOOTH_CONNECT permission not granted")
                return false
            }
            ReaderManager.sharedInstance().updateList()
            ReaderManager.sharedInstance().getReaderList().list()
                .any { isBTLReader(it.displayName) }
        } catch (e: Exception) {
            Log.e(TAG, "hasBTLDevice error: ${e.message}")
            false
        }
    }

    private fun isBTLReader(name: String?): Boolean {
        if (name == null) return false
        return name.contains("2128", ignoreCase = true) || name.contains("1128", ignoreCase = true)
    }

    // ── Connection ────────────────────────────────────────────────────────────

    @Throws(Exception::class)
    fun connect() {
        if (!hasBluetoothPermission()) throw Exception("BLUETOOTH_CONNECT permission not granted")

        ReaderManager.sharedInstance().updateList()
        val target = ReaderManager.sharedInstance().getReaderList().list()
            .firstOrNull { isBTLReader(it.displayName) }
            ?: throw Exception("BTL reader not found in paired Bluetooth devices")

        target.connect()

        val deadline = System.currentTimeMillis() + 10_000
        while (!target.isConnected && System.currentTimeMillis() < deadline) {
            Thread.sleep(100)
        }
        if (!target.isConnected) throw Exception("BTL connection timed out")

        mReader = target

        // Re-initialise commander for this reader
        val cmd = commander
        cmd.clearResponders()
        cmd.addResponder(LoggerResponder())
        cmd.addSynchronousResponder()
        cmd.setReader(target)

        // Physical trigger: SwitchState.SINGLE/DOUBLE = pressed, OFF = released
        val switchResponder = SwitchResponder()
        switchResponder.setSwitchStateReceivedDelegate(
            ISwitchStateReceivedDelegate { state ->
                val pressed = state == SwitchState.SINGLE || state == SwitchState.DOUBLE
                Log.d(TAG, "Trigger: ${if (pressed) "PRESSED" else "RELEASED"} ($state)")
                onTriggerChanged?.invoke(pressed)
            }
        )
        cmd.addResponder(switchResponder)

        // Enable asynchronous switch state reporting so SwitchResponder receives trigger events
        val switchActionCmd = SwitchActionCommand.synchronousCommand()
        switchActionCmd.setAsynchronousReportingEnabled(TriState.YES)
        cmd.executeCommand(switchActionCmd)
        Log.d(TAG, "Async switch reporting enabled")

        Log.i(TAG, "BTL reader connected: ${target.displayName}")
    }

    fun disconnect() {
        stopScan()
        try {
            commander.clearResponders()
        } catch (e: Exception) {
            Log.w(TAG, "clearResponders warning: ${e.message}")
        }
        try {
            mReader?.disconnect()
        } catch (e: Exception) {
            Log.w(TAG, "disconnect warning: ${e.message}")
        }
        mReader = null
        Log.d(TAG, "BTL reader disconnected")
    }

    fun isConnected(): Boolean = mReader?.isConnected == true

    // ── Power ─────────────────────────────────────────────────────────────────

    fun setPower(power: Int): Boolean {
        readPower = power.coerceIn(1, 29)
        mReadCommand.setOutputPower(readPower)
        return true
    }

    fun getPower(): IntArray = intArrayOf(readPower, readPower)

    // ── Scanning ──────────────────────────────────────────────────────────────

    fun startScan() {
        if (isInventorying.getAndSet(true)) return
        if (!isConnected()) { isInventorying.set(false); return }

        mContinuousScanEnabled = true
        mReadCommand.setTakeNoAction(TriState.NO)
        commander.addResponder(mReadResponder)
        commander.executeCommand(mReadCommand)
    }

    fun stopScan() {
        if (!isInventorying.getAndSet(false)) return
        mContinuousScanEnabled = false
        if (isConnected()) {
            try {
                mReadCommand.setTakeNoAction(TriState.YES)
                commander.executeCommand(AbortCommand())
            } catch (e: Exception) {
                Log.w(TAG, "stopScan warning: ${e.message}")
            }
        }
        try {
            commander.removeResponder(mReadResponder)
        } catch (e: Exception) {
            Log.w(TAG, "removeResponder warning: ${e.message}")
        }
    }

    // ── Internal setup ────────────────────────────────────────────────────────

    private fun setupReadCommand() {
        // Command parameters: read TID bank along with EPC and RSSI
        mReadCommand.setResetParameters(TriState.YES)
        mReadCommand.setIncludeTransponderRssi(TriState.YES)
        mReadCommand.setIncludeChecksum(TriState.YES)
        mReadCommand.setIncludePC(TriState.YES)
        mReadCommand.setIncludeDateTime(TriState.YES)
        mReadCommand.setIncludeEpc(TriState.YES)
        mReadCommand.setUseAlert(TriState.NO)
        mReadCommand.setOutputPower(readPower)
        mReadCommand.setBank(Databank.TRANSPONDER_IDENTIFIER)
        mReadCommand.setOffset(0)
        mReadCommand.setLength(6)  // 6 words = 12 bytes of TID

        // Responder: fires for each tag read
        mReadResponder.setCaptureNonLibraryResponses(true)
        mReadResponder.setTransponderReceivedDelegate(
            ITransponderReceivedDelegate { transponderData, _ ->
                if (!isInventorying.get()) return@ITransponderReceivedDelegate
                val readDataBytes = transponderData.readData ?: return@ITransponderReceivedDelegate
                val tid = BigInteger(1, readDataBytes).toString(16).uppercase()
                val epc = transponderData.epc ?: ""
                val rssi = transponderData.rssi ?: 0
                val timestamp = SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale.US).format(Date())
                val map: Map<String, Any> = mapOf(
                    "epc" to epc,
                    "tid" to tid,
                    "rssi" to rssi,
                    "readCount" to 1,
                    "timestamp" to timestamp,
                    "model" to "BTL2128p"
                )
                onTagRead?.invoke(map)
            }
        )

        // Lifecycle: re-issue command for continuous scan loop
        mReadResponder.setResponseLifecycleDelegate(object : ICommandResponseLifecycleDelegate {
            override fun responseEnded() {
                if (mContinuousScanEnabled && isInventorying.get()) {
                    commander.executeCommand(mReadCommand)
                }
            }
            override fun responseBegan() {}
        })
    }

    // ── Permissions ───────────────────────────────────────────────────────────

    private fun hasBluetoothPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    companion object {
        private const val TAG = "BTLReaderWrapper"
    }
}
