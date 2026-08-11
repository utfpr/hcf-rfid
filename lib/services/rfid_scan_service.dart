import 'dart:convert';
import 'package:http/http.dart' as http;
import 'reader_service.dart';

import 'api_config.dart';

class RfidTagRead {
  final String epc;
  final String? tid;
  final int rssi;
  final int readCount;
  final int antenna;
  final DateTime time;

  const RfidTagRead({
    required this.epc,
    this.tid,
    required this.rssi,
    required this.readCount,
    required this.antenna,
    required this.time,
  });

  factory RfidTagRead.fromJson(Map<String, dynamic> json) => RfidTagRead(
        epc: json['epc'] as String,
        tid: json['tid'] as String?,
        rssi: json['rssi'] as int,
        readCount: json['readCount'] as int,
        antenna: json['antenna'] as int,
        time: DateTime.parse(json['time'] as String),
      );
}

class RfidScanService {
  final ReaderService _readerService;

  RfidScanService(this._readerService);

  String get _readerPath {
    final manufacturer =
        _readerService.connectedReader?.manufacturer.toLowerCase() ?? '';
    if (manufacturer.contains('acura')) return 'acura';
    return 'impinj';
  }

  Future<void> startReading() async {
    await http
        .post(
          Uri.parse('$apiBaseUrl/api/$_readerPath/start-reading'),
          headers: {'Content-Type': 'application/json'},
          body: '{}',
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<List<RfidTagRead>> getTags() async {
    final response = await http
        .get(Uri.parse('$apiBaseUrl/api/$_readerPath/tags'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => RfidTagRead.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> stopReading() async {
    final path = _readerPath;
    await http
        .post(Uri.parse('$apiBaseUrl/api/$path/stop-reading'))
        .timeout(const Duration(seconds: 10));
    await http
        .delete(Uri.parse('$apiBaseUrl/api/$path/tags'))
        .timeout(const Duration(seconds: 5));
  }
}
