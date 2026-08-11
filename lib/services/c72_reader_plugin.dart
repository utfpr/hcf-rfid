import 'dart:async';
import 'package:flutter/services.dart';

/// Platform plugin for Chainway C72 UHF RFID reader (Android only).
/// Uses MethodChannel for commands and EventChannel for tag stream.
class C72ReaderPlugin {
  static const MethodChannel _channel =
      MethodChannel('com.example.beontag_utfpr_agro_mobile/c72');
  static const EventChannel _eventChannel =
      EventChannel('com.example.beontag_utfpr_agro_mobile/c72_tags');
  static const EventChannel _triggerEventChannel =
      EventChannel('com.example.beontag_utfpr_agro_mobile/c72_trigger');

  /// Returns true if the current device is a C72 reader (Build.MODEL contains "c72e").
  static Future<bool> isC72Device() async {
    try {
      final result = await _channel.invokeMethod<bool>('isC72Device');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Initializes the C72 reader. Throws on failure.
  static Future<void> initReader() async {
    try {
      await _channel.invokeMethod('initReader');
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'C72 init failed');
    }
  }

  /// Disconnects / cleans up the reader (no-op for C72 hardware).
  static Future<void> disconnectReader() async {
    try {
      await _channel.invokeMethod('disconnectReader');
    } on PlatformException {
      // ignore on non-Android or if channel not available
    }
  }

  /// Sets read/write power (5–30). Returns true if successful.
  static Future<bool> setPower(int power) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('setPower', power.clamp(5, 30));
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Returns [readPower, writePower] (both same for C72).
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

  /// Returns true if the reader is connected (init succeeded).
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

  /// Stream of trigger button events: true = pressed, false = released.
  static Stream<bool>? _triggerStreamCache;
  static Stream<bool> get triggerStream {
    _triggerStreamCache ??= _triggerEventChannel
        .receiveBroadcastStream()
        .map((event) => event == true)
        .asBroadcastStream();
    return _triggerStreamCache!;
  }
}
