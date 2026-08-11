import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class StockService {
  Future<List<String>> getTids() async {
    final response = await http
        .get(Uri.parse('$apiBaseUrl/api/stock'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to load stock data (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    final tids = data
        .map((item) => (item as Map<String, dynamic>)['tid'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    return tids;
  }
}
