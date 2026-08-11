import 'dart:async';
import 'package:flutter/services.dart';

/// Platform plugin for Acura BTL2128p / TSL 2128P UHF RFID reader (Bluetooth SPP).
/// Mirrors C72ReaderPlugin structure: MethodChannel for commands, EventChannels for streams.
class BTLReaderPlugin {
  static const MethodChannel _channel =
      MethodChannel('com.example.beontag_utfpr_agro_mobile/btl');
  static const EventChannel _eventChannel =
      EventChannel('com.example.beontag_utfpr_agro_mobile/btl_tags');
  static const EventChannel _triggerEventChannel =
      EventChannel('com.example.beontag_utfpr_agro_mobile/btl_trigger');

  /// Returns true if a paired Bluetooth device with "2128" or "1128" in its name is found.
  static Future<bool> hasBTLDevice() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasBTLDevice');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Connects to the first paired BTL reader found. Throws on failure.
  static Future<void> connectReader() async {
    try {
      await _channel.invokeMethod('connectReader');
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'BTL connect failed');
    }
  }

  /// Disconnects the BTL reader.
  static Future<void> disconnectReader() async {
    try {
      await _channel.invokeMethod('disconnectReader');
    } on PlatformException {
      // ignore
    }
  }

  /// Sets read power (1–29 dBm). Returns true if successful.
  static Future<bool> setPower(int power) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('setPower', power.clamp(1, 29));
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Returns [readPower, writePower] (both same for BTL).
  static Future<List<int>> getPower() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getPower');
      if (result == null || result.length < 2) return [29, 29];
      return [(result[0] as num).toInt(), (result[1] as num).toInt()];
    } on PlatformException {
      return [29, 29];
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

  /// Returns true if the reader is connected.
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
      if (event is Map) return Map<String, dynamic>.from(event);
      return <String, dynamic>{};
    }).asBroadcastStream();
    return _tagStreamCache!;
  }

  /// Stream of physical trigger events: true = pressed, false = released.
  static Stream<bool>? _triggerStreamCache;
  static Stream<bool> get triggerStream {
    _triggerStreamCache ??= _triggerEventChannel
        .receiveBroadcastStream()
        .map((event) => event == true)
        .asBroadcastStream();
    return _triggerStreamCache!;
  }
}
