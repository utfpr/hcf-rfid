import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class Conference {
  final int id;
  final String name;
  final DateTime createDate;
  final int totalItems;

  const Conference({
    required this.id,
    required this.name,
    required this.createDate,
    required this.totalItems,
  });

  factory Conference.fromJson(Map<String, dynamic> json) => Conference(
        id: json['id'] as int,
        name: json['name'] as String,
        createDate: DateTime.parse(json['create_date'] as String),
        totalItems: json['total_items'] as int,
      );

  String get displayName => '#$id - $name ($totalItems items)';
}

class ConferenceDetail {
  final int id;
  final String name;
  final List<String> epcs;

  const ConferenceDetail({
    required this.id,
    required this.name,
    required this.epcs,
  });

  factory ConferenceDetail.fromJson(Map<String, dynamic> json) =>
      ConferenceDetail(
        id: json['id'] as int,
        name: json['name'] as String,
        epcs: (json['items'] as List<dynamic>)
            .map((i) => (i as Map<String, dynamic>)['tid_tag'] as String)
            .toList(),
      );
}

class ConferenceService {
  Future<List<Conference>> getAll() async {
    final response = await http
        .get(Uri.parse('$apiBaseUrl/api/conference'), headers: apiHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => Conference.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load conferences (${response.statusCode})');
  }

  Future<ConferenceDetail> getById(int id) async {
    final response = await http
        .get(Uri.parse('$apiBaseUrl/api/conference/$id'), headers: apiHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return ConferenceDetail.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load conference $id (${response.statusCode})');
  }

  /// Submits an inventory run for [conferenceId].
  /// Compares [scannedEpcs] against [conferenceEpcs] to compute found/not_found.
  Future<void> submitInventory({
    required int conferenceId,
    required Set<String> scannedEpcs,
    required List<String> conferenceEpcs,
  }) async {
    final items = conferenceEpcs
        .map((epc) => {
              'tid_tag': epc,
              'status': scannedEpcs.contains(epc) ? 'found' : 'not_found',
            })
        .toList();

    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/api/conference/$conferenceId/inventory'),
          headers: apiHeaders(extra: {'Content-Type': 'application/json'}),
          body: jsonEncode({'items': items}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to submit inventory (${response.statusCode})');
    }
  }
}
