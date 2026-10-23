import 'dart:async';
import 'package:flutter/services.dart';

/// Platform plugin for the integrated UHF RFID reader of Urovo devices (DT50P and similar, Android only).
/// Mirrors C72ReaderPlugin: MethodChannel for commands, EventChannels for tags and the grip trigger.
class UrovoReaderPlugin {
  static const MethodChannel _channel =
      MethodChannel('com.example.beontag_utfpr_agro_mobile/urovo');
  static const EventChannel _eventChannel =
      EventChannel('com.example.beontag_utfpr_agro_mobile/urovo_tags');
  static const EventChannel _triggerEventChannel =
      EventChannel('com.example.beontag_utfpr_agro_mobile/urovo_trigger');

  /// Returns true if the app is running on a Urovo device (manufacturer/brand + Urovo ROM classes).
  static Future<bool> isUrovoDevice() async {
    try {
      final result = await _channel.invokeMethod<bool>('isUrovoDevice');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Initializes the integrated RFID module. Throws on failure (no module, timeout, etc.).
  static Future<void> initReader() async {
    try {
      await _channel.invokeMethod('initReader');
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Urovo init failed');
    }
  }

  /// Releases the RFID module.
  static Future<void> disconnectReader() async {
    try {
      await _channel.invokeMethod('disconnectReader');
    } on PlatformException {
      // ignore on non-Android or if channel not available
    }
  }

  /// Sets the output power in dBm (clamped natively to 5..max supported by the module).
  static Future<bool> setPower(int power) async {
    try {
      final result = await _channel.invokeMethod<bool>('setPower', power);
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Returns [readPower, writePower] (both the same for Urovo).
  static Future<List<int>> getPower() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getPower');
      if (result == null || result.length < 2) return [30, 30];
      return [
        (result[0] as num).toInt(),
        (result[1] as num).toInt(),
      ];
    } on PlatformException {
      return [30, 30];
    }
  }

  /// Maximum output power (dBm) supported by the module, or null if unavailable.
  static Future<int?> getMaxPower() async {
    try {
      return await _channel.invokeMethod<int>('getMaxPower');
    } on PlatformException {
      return null;
    }
  }

  /// Starts inventory; tags will be emitted on [tagStream].
  static Future<void> startScan() async {
    try {
      await _channel.invokeMethod('startScan');
    } on PlatformException {
      rethrow;
    }
  }

  /// Stops inventory.
  static Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } on PlatformException {
      // ignore
    }
  }

  /// Returns true if the RFID module is connected.
  static Future<bool> isConnected() async {
    try {
      final result = await _channel.invokeMethod<bool>('isConnected');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stream of tag events. Each event is a map: epc, tid, rssi, readCount, timestamp, model.
  static Stream<Map<String, dynamic>>? _tagStreamCache;
  static Stream<Map<String, dynamic>> get tagStream {
    _tagStreamCache ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    }).asBroadcastStream();
    return _tagStreamCache!;
  }

  /// Stream of grip trigger events: true = pressed, false = released.
  static Stream<bool>? _triggerStreamCache;
  static Stream<bool> get triggerStream {
    _triggerStreamCache ??= _triggerEventChannel
        .receiveBroadcastStream()
        .map((event) => event == true)
        .asBroadcastStream();
    return _triggerStreamCache!;
  }
}
