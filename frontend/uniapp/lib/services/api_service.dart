// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  static Future<http.Response> postAuthenticated(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = Uri.parse(baseUrl + _ensureTrailingSlash(endpoint));
    return await http.post(
      url,
      body: jsonEncode(data),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
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
