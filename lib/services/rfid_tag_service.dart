import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class RfidTagService {
  /// Returns the existing tag record, or null if not found.
  Future<Map<String, dynamic>?> getByTagId(String tagId) async {
    final uri = Uri.parse(
      '$apiBaseUrl/api/stock/tid/${Uri.encodeComponent(tagId)}',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to check tag (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> createTag(Map<String, dynamic> dto) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/api/stock'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode([dto]),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      String message = 'Failed to create tag (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
  }
}
