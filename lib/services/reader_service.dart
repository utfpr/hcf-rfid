import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'c72_reader_plugin.dart';
import 'btl_reader_plugin.dart';
import 'urovo_reader_plugin.dart';

/// Model representing a RFID reader device
class ReaderDevice {
  final String id;
  final String manufacturer;
  final String model;
  final String? nickname;

  const ReaderDevice({
    required this.id,
    required this.manufacturer,
    required this.model,
    this.nickname,
  });

  /// Display name: nickname if set, otherwise model
  String get displayName => nickname?.isNotEmpty == true ? nickname! : model;

  Map<String, dynamic> toJson() => {
        'id': id,
        'manufacturer': manufacturer,
        'model': model,
        'nickname': nickname,
      };

  factory ReaderDevice.fromJson(Map<String, dynamic> json) => ReaderDevice(
        id: json['id'] as String,
        manufacturer: json['manufacturer'] as String,
        model: json['model'] as String,
        nickname: json['nickname'] as String?,
      );
}

/// Model representing reader configuration settings
class ReaderConfiguration {
  final double readPower;
  final double writePower;

  const ReaderConfiguration({
    this.readPower = 0,
    this.writePower = 0,
  });

  static const double minPower = -100;
  static const double maxPower = 100;
  /// C72 reader power range (single value for read and write).
  static const double minPowerC72 = 5;
  static const double maxPowerC72 = 30;
  /// Acura BTL reader power range (1–29 dBm).
  static const double minPowerBTL = 1;
  static const double maxPowerBTL = 29;
  /// Urovo integrated reader power range. The actual maximum comes from the module
  /// ([ReaderService.urovoMaxPower]); 33 dBm is the Impinj E710 default.
  static const double minPowerUrovo = 5;
  static const double maxPowerUrovo = 33;

  Map<String, dynamic> toJson() => {
        'readPower': readPower,
        'writePower': writePower,
      };

  factory ReaderConfiguration.fromJson(Map<String, dynamic> json) =>
      ReaderConfiguration(
        readPower: (json['readPower'] as num?)?.toDouble() ?? 0,
        writePower: (json['writePower'] as num?)?.toDouble() ?? 0,
      );

  ReaderConfiguration copyWith({
    double? readPower,
    double? writePower,
  }) {
    return ReaderConfiguration(
      readPower: readPower ?? this.readPower,
      writePower: writePower ?? this.writePower,
    );
  }
}

/// C72 embedded reader (Chainway) - no Bluetooth, init-only connection.
const String c72ReaderId = 'c72_internal';
const String chainwayManufacturer = 'Chainway';
const String c72Model = 'C72';

/// Acura BTL2128p / TSL 2128P - Bluetooth SPP connection.
const String btlReaderId = 'btl_bluetooth';
const String acuraManufacturer = 'Acura';
const String btlModel = 'BTL2128p';

/// Urovo integrated UHF reader (DT50P and other Urovo devices) - no Bluetooth, init-only connection.
const String urovoReaderId = 'urovo_internal';
const String urovoManufacturer = 'Urovo';
const String urovoModel = 'DT50P';

/// Available manufacturers and their reader models
class ReaderCatalog {
  static const Map<String, List<String>> manufacturerModels = {
    'Chainway': ['C72'],
    'Acura': ['BTL2128p'],
    'Urovo': ['DT50P'],
  };

  static List<String> get manufacturers => manufacturerModels.keys.toList();

  static List<String> getModelsForManufacturer(String manufacturer) {
    return manufacturerModels[manufacturer] ?? [];
  }
}

/// Service to manage reader connections and state
class ReaderService extends ChangeNotifier {
  static final ReaderService _instance = ReaderService._internal();
  factory ReaderService() => _instance;
  ReaderService._internal() {
    _loadFromStorage();
  }

  static const String _readersKey = 'saved_readers';
  static const String _connectedReaderKey = 'connected_reader_id';
  static const String _configurationKey = 'reader_configuration';

  List<ReaderDevice> _availableReaders = [];
  ReaderDevice? _connectedReader;
  String? _selectedReaderId;
  ReaderConfiguration _configuration = const ReaderConfiguration();
  bool _physicallyConnected = false;
  bool _isLoaded = false;
  double _urovoMaxPower = ReaderConfiguration.maxPowerUrovo;

  List<ReaderDevice> get availableReaders => List.unmodifiable(_availableReaders);
  ReaderDevice? get connectedReader => _connectedReader;
  String? get selectedReaderId => _selectedReaderId;
  ReaderConfiguration get configuration => _configuration;
  bool get isLoaded => _isLoaded;
  bool get isPhysicallyConnected => _physicallyConnected;

  /// Maximum output power reported by the connected Urovo module (updated by [refreshPowerFromDevice]).
  double get urovoMaxPower => _urovoMaxPower;

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Load saved readers
    final readersJson = prefs.getString(_readersKey);
    if (readersJson != null) {
      final List<dynamic> readersList = jsonDecode(readersJson);
      _availableReaders = readersList
          .map((json) => ReaderDevice.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      // No readers configured yet - leave list empty so user goes to config
      _availableReaders = [];
    }

    // Load connected reader
    final connectedId = prefs.getString(_connectedReaderKey);
    if (connectedId != null && _availableReaders.isNotEmpty) {
      _connectedReader = _availableReaders.firstWhere(
        (r) => r.id == connectedId,
        orElse: () => _availableReaders.first,
      );
      _selectedReaderId = connectedId;
    }

    // Load configuration
    final configJson = prefs.getString(_configurationKey);
    if (configJson != null) {
      _configuration = ReaderConfiguration.fromJson(
        jsonDecode(configJson) as Map<String, dynamic>,
      );
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final readersJson = jsonEncode(_availableReaders.map((r) => r.toJson()).toList());
    await prefs.setString(_readersKey, readersJson);
  }

  Future<void> _saveConnectedReader() async {
    final prefs = await SharedPreferences.getInstance();
    if (_connectedReader != null) {
      await prefs.setString(_connectedReaderKey, _connectedReader!.id);
    } else {
      await prefs.remove(_connectedReaderKey);
    }
  }

  void selectReader(String? readerId) {
    _selectedReaderId = readerId;
    notifyListeners();
  }

  Future<void> connectSelectedReader() async {
    if (_selectedReaderId != null) {
      _connectedReader = _availableReaders.firstWhere(
        (reader) => reader.id == _selectedReaderId,
        orElse: () => _availableReaders.first,
      );
      // The reader may already be connected (e.g. BTL paired in BluetoothConnectionScreen).
      _physicallyConnected = await isDeviceConnected();
      await _saveConnectedReader();
      notifyListeners();
    }
  }

  /// Whether the given reader is the C72 (Chainway) embedded device.
  bool isC72Reader(ReaderDevice? reader) {
    return reader != null &&
        reader.manufacturer == chainwayManufacturer &&
        reader.model == c72Model;
  }

  /// Whether the given reader is an Acura Bluetooth reader (any Acura model).
  bool isAcuraBTLReader(ReaderDevice? reader) {
    return reader != null &&
        reader.manufacturer == acuraManufacturer;
  }

  /// Whether the given reader is the integrated reader of a Urovo device (any Urovo model).
  bool isUrovoReader(ReaderDevice? reader) {
    return reader != null && reader.manufacturer == urovoManufacturer;
  }

  /// Connect to a specific reader by ID. Routes to the appropriate platform plugin.
  Future<void> connectToReader(String readerId) async {
    final reader = _availableReaders.firstWhere(
      (r) => r.id == readerId,
      orElse: () => _availableReaders.isNotEmpty ? _availableReaders.first : throw Exception('No readers available'),
    );
    if (isC72Reader(reader)) {
      await C72ReaderPlugin.initReader();
    } else if (isAcuraBTLReader(reader)) {
      await BTLReaderPlugin.connectReader();
    } else if (isUrovoReader(reader)) {
      await UrovoReaderPlugin.initReader();
    }
    _connectedReader = reader;
    _selectedReaderId = readerId;
    _physicallyConnected = true;
    await _saveConnectedReader();
    notifyListeners();
  }

  Future<void> addReader(ReaderDevice reader) async {
    _availableReaders.add(reader);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> removeReader(String readerId) async {
    _availableReaders.removeWhere((r) => r.id == readerId);
    if (_connectedReader?.id == readerId) {
      _connectedReader = null;
      _selectedReaderId = null;
      await _saveConnectedReader();
    }
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (isC72Reader(_connectedReader)) {
      await C72ReaderPlugin.disconnectReader();
    } else if (isAcuraBTLReader(_connectedReader)) {
      await BTLReaderPlugin.disconnectReader();
    } else if (isUrovoReader(_connectedReader)) {
      await UrovoReaderPlugin.disconnectReader();
    }
    _connectedReader = null;
    _selectedReaderId = null;
    _physicallyConnected = false;
    await _saveConnectedReader();
    notifyListeners();
  }

  bool get isConnected => _physicallyConnected;

  /// Check if the physical device is actually connected (Bluetooth/hardware).
  Future<bool> isDeviceConnected() async {
    if (_connectedReader == null) return false;
    if (isC72Reader(_connectedReader)) {
      return await C72ReaderPlugin.isConnected();
    } else if (isAcuraBTLReader(_connectedReader)) {
      return await BTLReaderPlugin.isConnected();
    } else if (isUrovoReader(_connectedReader)) {
      return await UrovoReaderPlugin.isConnected();
    }
    return false;
  }

  /// Refresh power from the physical device and update configuration.
  Future<void> refreshPowerFromDevice() async {
    if (isC72Reader(_connectedReader)) {
      final powers = await C72ReaderPlugin.getPower();
      if (powers.length >= 2) {
        _configuration = _configuration.copyWith(
          readPower: powers[0].toDouble(),
          writePower: powers[1].toDouble(),
        );
        await _saveConfiguration();
        notifyListeners();
      }
    } else if (isAcuraBTLReader(_connectedReader)) {
      final powers = await BTLReaderPlugin.getPower();
      if (powers.length >= 2) {
        _configuration = _configuration.copyWith(
          readPower: powers[0].toDouble(),
          writePower: powers[1].toDouble(),
        );
        await _saveConfiguration();
        notifyListeners();
      }
    } else if (isUrovoReader(_connectedReader)) {
      final maxPower = await UrovoReaderPlugin.getMaxPower();
      if (maxPower != null && maxPower >= ReaderConfiguration.minPowerUrovo) {
        _urovoMaxPower = maxPower.toDouble();
      }
      final powers = await UrovoReaderPlugin.getPower();
      if (powers.length >= 2) {
        _configuration = _configuration.copyWith(
          readPower: powers[0].toDouble(),
          writePower: powers[1].toDouble(),
        );
        await _saveConfiguration();
        notifyListeners();
      }
    }
  }

  // Configuration methods
  Future<void> updateReadPower(double value) async {
    if (isC72Reader(_connectedReader)) {
      final clamped = value.clamp(ReaderConfiguration.minPowerC72, ReaderConfiguration.maxPowerC72);
      await C72ReaderPlugin.setPower(clamped.round());
      _configuration = _configuration.copyWith(readPower: clamped, writePower: clamped);
    } else if (isAcuraBTLReader(_connectedReader)) {
      final clamped = value.clamp(ReaderConfiguration.minPowerBTL, ReaderConfiguration.maxPowerBTL);
      await BTLReaderPlugin.setPower(clamped.round());
      _configuration = _configuration.copyWith(readPower: clamped, writePower: clamped);
    } else if (isUrovoReader(_connectedReader)) {
      final clamped = value.clamp(ReaderConfiguration.minPowerUrovo, _urovoMaxPower);
      await UrovoReaderPlugin.setPower(clamped.round());
      _configuration = _configuration.copyWith(readPower: clamped, writePower: clamped);
    } else {
      _configuration = _configuration.copyWith(readPower: value);
    }
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> updateWritePower(double value) async {
    if (isC72Reader(_connectedReader)) {
      final clamped = value.clamp(ReaderConfiguration.minPowerC72, ReaderConfiguration.maxPowerC72);
      await C72ReaderPlugin.setPower(clamped.round());
      _configuration = _configuration.copyWith(readPower: clamped, writePower: clamped);
    } else if (isUrovoReader(_connectedReader)) {
      final clamped = value.clamp(ReaderConfiguration.minPowerUrovo, _urovoMaxPower);
      await UrovoReaderPlugin.setPower(clamped.round());
      _configuration = _configuration.copyWith(readPower: clamped, writePower: clamped);
    } else {
      _configuration = _configuration.copyWith(writePower: value);
    }
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> updateConfiguration(ReaderConfiguration config) async {
    _configuration = config;
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> _saveConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = jsonEncode(_configuration.toJson());
    await prefs.setString(_configurationKey, configJson);
  }
}
