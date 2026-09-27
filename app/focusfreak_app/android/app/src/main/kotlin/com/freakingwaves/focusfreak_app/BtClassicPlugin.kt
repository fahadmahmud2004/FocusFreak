package com.freakingwaves.focusfreak_app

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import kotlin.concurrent.thread

/**
 * Bluetooth Classic SPP, hand-written.
 *
 * There is no maintained Flutter plugin for Bluetooth Classic — `flutter_
 * bluetooth_serial` is dead and its forks lag the Android permission model —
 * and this app needs exactly one socket to one HC-05. That is a few hundred
 * lines of well-understood Android, so it is written here rather than taken as
 * a dependency. See `docs/PROTOCOL.md` §1.
 *
 * The Dart side sees bytes, not frames: framing belongs to `FrameParser`, one
 * implementation shared by every transport.
 */
class BtClassicPlugin(
    private val context: Context,
    private val activities: ActivityHolder,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    /**
     * Null when no UI is on screen.
     *
     * The engine outlives the activity ([MainActivity]), so this is read fresh
     * rather than captured. Only the two calls that put something in front of
     * the user — the permission dialog and the enable-Bluetooth prompt — need
     * it; the socket itself does not care whether anyone is looking.
     */
    private val activity: Activity?
        get() = activities.activity

    companion object {
        private const val METHOD_CHANNEL = "focusfreak/bt"
        private const val EVENT_CHANNEL = "focusfreak/bt/events"

        /** Serial Port Profile. `docs/PROTOCOL.md` §1. */
        private val SPP_UUID: UUID =
            UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        private const val PERMISSION_REQUEST = 0x0B7C
        private const val ENABLE_REQUEST = 0x0B7D

        /**
         * The PIN every bot is flashed with at assembly.
         *
         * This is what makes connecting feel like connecting a Bluetooth
         * speaker rather than like configuring a serial module: the app answers
         * the pairing challenge itself, so the system PIN dialog never reaches
         * the user. It works because every unit is provisioned identically —
         * see `docs/BOT_PROVISIONING.md`.
         *
         * It is not a secret and is not treated as one. Bluetooth Classic
         * pairing on an HC-05 is not a security boundary, and the thing on the
         * other end is a desk toy that reports whether a chair is occupied.
         * Pretending otherwise would mean asking every customer to type a code
         * that protects nothing.
         */
        private const val BOT_PIN = "1234"

        /** How long a scan runs before it gives up on its own. */
        private const val DISCOVERY_TIMEOUT_MS = 20_000L
    }

    private val main = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    private var events: EventChannel.EventSink? = null
    private var socket: BluetoothSocket? = null
    private var output: OutputStream? = null
    private var reader: Thread? = null

    @Volatile
    private var running = false

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    private val adapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE)
                as? android.bluetooth.BluetoothManager)?.adapter

    // -- Permissions ----------------------------------------------------------

    /**
     * API 31 split BLUETOOTH_CONNECT out of the old location permission. Both
     * paths are needed: the phones this ships to run 10 through 15.
     */
    private fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN,
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        }

    private fun hasPermissions(): Boolean = requiredPermissions().all {
        ContextCompat.checkSelfPermission(context, it) ==
            PackageManager.PERMISSION_GRANTED
    }

    // -- Method channel -------------------------------------------------------

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "isSupported" -> result.success(adapter != null)

            "isEnabled" -> result.success(adapter?.isEnabled == true)

            "hasPermissions" -> result.success(hasPermissions())

            "requestPermissions" -> {
                val host = activity
                if (hasPermissions()) {
                    result.success(true)
                } else if (host == null) {
                    // No UI to show a dialog on. Saying "not granted" is the
                    // truth; inventing a grant would not be.
                    result.success(false)
                } else {
                    ActivityCompat.requestPermissions(
                        host, requiredPermissions(), PERMISSION_REQUEST
                    )
                    // Deliberately optimistic: the grant arrives on the
                    // activity callback, and the app re-checks with
                    // `hasPermissions` rather than blocking here.
                    result.success(false)
                }
            }

            "bondedDevices" -> {
                if (!hasPermissions()) {
                    result.error("permission", "Bluetooth permission not granted", null)
                    return
                }
                val adapter = this.adapter
                if (adapter == null) {
                    result.error("unsupported", "No Bluetooth adapter", null)
                    return
                }
                try {
                    result.success(adapter.bondedDevices.map { device ->
                        mapOf(
                            "name" to (device.name ?: "Unknown"),
                            "address" to device.address,
                            "type" to device.type,
                        )
                    })
                } catch (e: SecurityException) {
                    result.error("permission", e.message, null)
                }
            }

            "requestEnable" -> {
                val host = activity
                when {
                    adapter == null ->
                        result.error("unsupported", "No Bluetooth adapter", null)
                    adapter?.isEnabled == true -> result.success(true)
                    host == null -> result.success(false)
                    else -> {
                        // The system dialog, rather than enabling the radio
                        // behind the user's back — which newer Android does not
                        // allow anyway, and should not.
                        host.startActivityForResult(
                            Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
                            ENABLE_REQUEST,
                        )
                        result.success(false)
                    }
                }
            }

            "startDiscovery" -> startDiscovery(result)

            "stopDiscovery" -> {
                stopDiscovery()
                result.success(null)
            }

            "bond" -> {
                val address = call.argument<String>("address")
                if (address == null) {
                    result.error("args", "address is required", null)
                } else {
                    bond(address, result)
                }
            }

            "connect" -> {
                val address = call.argument<String>("address")
                if (address == null) {
                    result.error("args", "address is required", null)
                    return
                }
                connect(address, result)
            }

            "write" -> {
                val bytes = call.argument<ByteArray>("bytes")
                val out = output
                if (bytes == null || out == null) {
                    result.error("state", "Not connected", null)
                    return
                }
                // Writes go off the main thread: a stalled HC-05 must never
                // freeze the UI.
                thread(name = "ff-bt-write") {
                    try {
                        out.write(bytes)
                        out.flush()
                        main.post { result.success(null) }
                    } catch (e: IOException) {
                        main.post { result.error("io", e.message, null) }
                        dropLink("write failed: ${e.message}")
                    }
                }
            }

            "disconnect" -> {
                closeSocket()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun connect(address: String, result: MethodChannel.Result) {
        if (!hasPermissions()) {
            result.error("permission", "Bluetooth permission not granted", null)
            return
        }
        val adapter = this.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("disabled", "Bluetooth is off", null)
            return
        }
        closeSocket()

        thread(name = "ff-bt-connect") {
            var device: BluetoothDevice? = null
            try {
                device = adapter.getRemoteDevice(address)
                // Discovery and a connect attempt fight for the radio; the
                // Android docs are explicit that discovery must be cancelled
                // first, and skipping it is the classic "connects one time in
                // three" bug.
                adapter.cancelDiscovery()

                val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
                this.socket = socket
                output = socket.outputStream
                startReader(socket.inputStream)
                main.post {
                    result.success(mapOf(
                        "name" to (device.name ?: address),
                        "address" to address,
                    ))
                    emitState("connected")
                }
            } catch (e: IOException) {
                closeSocket()
                main.post {
                    result.error("io", e.message ?: "Could not connect", null)
                }
            } catch (e: SecurityException) {
                closeSocket()
                main.post { result.error("permission", e.message, null) }
            }
        }
    }

    /**
     * One reader thread per socket.
     *
     * Reads whatever is available and forwards it unchanged — chunk boundaries
     * are meaningless and the Dart parser reassembles frames. At 9600 baud a
     * blocking read is cheap; the thread exists so nothing touches the main
     * looper.
     */
    private fun startReader(input: InputStream) {
        running = true
        reader = thread(name = "ff-bt-read") {
            val buffer = ByteArray(256)
            while (running) {
                try {
                    val read = input.read(buffer)
                    if (read < 0) {
                        dropLink("stream closed by the device")
                        break
                    }
                    if (read > 0) {
                        val chunk = buffer.copyOf(read)
                        main.post { events?.success(chunk) }
                    }
                } catch (e: IOException) {
                    if (running) dropLink("read failed: ${e.message}")
                    break
                }
            }
        }
    }

    private fun dropLink(why: String) {
        closeSocket()
        main.post { emitState("disconnected", why) }
    }

    /**
     * Every map this plugin emits carries a `kind`.
     *
     * The event channel now carries three things — raw bytes, link state, and
     * scan results — and without a discriminator the Dart side's `linkEvents`
     * would start seeing every discovered device as a link state change.
     */
    private fun emitState(state: String, detail: String? = null) {
        events?.success(
            mapOf("kind" to "link", "state" to state, "detail" to detail)
        )
    }

    private fun emitDiscovery(payload: Map<String, Any?>) {
        events?.success(payload + ("kind" to "discovery"))
    }

    private fun describe(device: BluetoothDevice, rssi: Int? = null):
        Map<String, Any?> = try {
        mapOf(
            "name" to (device.name ?: ""),
            "address" to device.address,
            "type" to device.type,
            "bonded" to (device.bondState == BluetoothDevice.BOND_BONDED),
            "rssi" to rssi,
        )
    } catch (_: SecurityException) {
        // The permission was revoked between the scan starting and this
        // callback. An address with no name is still a usable result.
        mapOf(
            "name" to "",
            "address" to device.address,
            "bonded" to false,
            "rssi" to rssi,
        )
    }

    private fun closeSocket() {
        running = false
        try {
            output?.close()
        } catch (_: IOException) {
        }
        try {
            socket?.close()
        } catch (_: IOException) {
        }
        output = null
        socket = null
        reader = null
    }

    // -- Discovery ------------------------------------------------------------

    private var discovering = false

    private val discoveryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                BluetoothDevice.ACTION_FOUND -> {
                    val device = intent.deviceExtra() ?: return
                    val rssi = intent
                        .getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE)
                        .toInt()
                    emitDiscovery(
                        describe(device, if (rssi == Short.MIN_VALUE.toInt()) null else rssi)
                            + ("event" to "found")
                    )
                }

                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    discovering = false
                    emitDiscovery(mapOf("event" to "finished"))
                }
            }
        }
    }

    /**
     * The pairing challenge, answered by the app.
     *
     * This receiver is the entire reason a customer never types a code. The
     * HC-05 asks for a PIN; Android would ordinarily put that question in front
     * of the user, and here it is answered from [BOT_PIN] instead. Registered
     * only while a bond is actually in progress, so nothing is auto-confirming
     * pairing requests the app did not start.
     */
    private val pairingReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != BluetoothDevice.ACTION_PAIRING_REQUEST) return
            val device = intent.deviceExtra() ?: return
            if (device.address != bondingAddress) return
            try {
                device.setPin(BOT_PIN.toByteArray())
                // Variant 3 ("just works") never asks for a PIN at all; this is
                // the other half of the same job.
                device.setPairingConfirmation(true)
                abortBroadcast()
            } catch (_: SecurityException) {
                // Fall through to the system dialog rather than failing: the
                // user can still type the PIN, which is a worse experience but
                // not a broken one.
            } catch (_: IllegalArgumentException) {
                // Some ROMs refuse setPairingConfirmation outside their own
                // flow. Same fallback.
            }
        }
    }

    private var bondingAddress: String? = null
    private var bondResult: MethodChannel.Result? = null

    private val bondStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return
            val device = intent.deviceExtra() ?: return
            if (device.address != bondingAddress) return

            when (intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, -1)) {
                BluetoothDevice.BOND_BONDED -> finishBond(true, null)
                BluetoothDevice.BOND_NONE -> finishBond(
                    false, "The bot refused pairing. Turn it off and on again."
                )
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun Intent.deviceExtra(): BluetoothDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(
                BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java
            )
        } else {
            getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }

    private fun startDiscovery(result: MethodChannel.Result) {
        if (!hasPermissions()) {
            result.error("permission", "Bluetooth permission not granted", null)
            return
        }
        val adapter = this.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("disabled", "Bluetooth is off", null)
            return
        }

        if (!discovering) {
            ContextCompat.registerReceiver(
                context,
                discoveryReceiver,
                IntentFilter().apply {
                    addAction(BluetoothDevice.ACTION_FOUND)
                    addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
                },
                ContextCompat.RECEIVER_EXPORTED,
            )
        }

        try {
            adapter.cancelDiscovery()
            discovering = adapter.startDiscovery()
        } catch (e: SecurityException) {
            result.error("permission", e.message, null)
            return
        }

        // Already-bonded bots do not show up in a scan, and a returning user's
        // bot is exactly that. Emitting them alongside the scan is what lets
        // the screen show one list instead of asking the user to understand the
        // difference.
        try {
            for (device in adapter.bondedDevices) {
                emitDiscovery(describe(device) + ("event" to "found"))
            }
        } catch (_: SecurityException) {
        }

        // A scan that never ends is a radio that never sleeps.
        main.postDelayed({ if (discovering) stopDiscovery() }, DISCOVERY_TIMEOUT_MS)
        result.success(discovering)
    }

    private fun stopDiscovery() {
        if (!discovering) return
        discovering = false
        try {
            adapter?.cancelDiscovery()
        } catch (_: SecurityException) {
        }
        try {
            context.unregisterReceiver(discoveryReceiver)
        } catch (_: IllegalArgumentException) {
        }
        emitDiscovery(mapOf("event" to "finished"))
    }

    // -- Bonding --------------------------------------------------------------

    private fun bond(address: String, result: MethodChannel.Result) {
        if (!hasPermissions()) {
            result.error("permission", "Bluetooth permission not granted", null)
            return
        }
        val adapter = this.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("disabled", "Bluetooth is off", null)
            return
        }
        if (bondResult != null) {
            result.error("busy", "Already pairing with another bot", null)
            return
        }

        val device = try {
            adapter.getRemoteDevice(address)
        } catch (e: IllegalArgumentException) {
            result.error("args", e.message, null)
            return
        }

        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            result.success(true)
            return
        }

        // Discovery and bonding fight for the radio for the same reason
        // discovery and connecting do.
        stopDiscovery()

        bondingAddress = address
        bondResult = result
        ContextCompat.registerReceiver(
            context, bondStateReceiver,
            IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED),
            ContextCompat.RECEIVER_EXPORTED,
        )
        ContextCompat.registerReceiver(
            context, pairingReceiver,
            IntentFilter(BluetoothDevice.ACTION_PAIRING_REQUEST).apply {
                // Above the system dialog's own receiver, so the PIN is
                // supplied before the user is ever asked for it.
                priority = IntentFilter.SYSTEM_HIGH_PRIORITY
            },
            ContextCompat.RECEIVER_EXPORTED,
        )

        val started = try {
            device.createBond()
        } catch (e: SecurityException) {
            finishBond(false, e.message)
            return
        }
        if (!started) {
            finishBond(false, "The bot did not answer. Check it is powered on.")
        }
    }

    private fun finishBond(ok: Boolean, error: String?) {
        val pending = bondResult ?: return
        bondResult = null
        bondingAddress = null
        try {
            context.unregisterReceiver(bondStateReceiver)
        } catch (_: IllegalArgumentException) {
        }
        try {
            context.unregisterReceiver(pairingReceiver)
        } catch (_: IllegalArgumentException) {
        }
        main.post {
            if (ok) pending.success(true) else pending.error("bond", error, null)
        }
    }

    // -- Event channel --------------------------------------------------------

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    fun dispose() {
        stopDiscovery()
        finishBond(false, "Cancelled")
        closeSocket()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
