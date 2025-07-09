// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uniapp/screens/app_constants.dart';

class ApiService {
  static const String baseUrl = AppConstants.baseUrl;

  static String _ensureTrailingSlash(String endpoint) {
    if (!endpoint.endsWith('/')) {
      return endpoint + '/';
    }
    return endpoint;
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse(baseUrl + _ensureTrailingSlash(endpoint));
    return await http.post(
      url,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Map<String, dynamic>> postAndDecode(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await post(endpoint, data);
    return {
      'statusCode': response.statusCode,
      'body': jsonDecode(utf8.decode(response.bodyBytes)),
    };
  }
}
