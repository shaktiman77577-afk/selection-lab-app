import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 30);

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer \$token',
    };
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final headers = await getHeaders();
      final uri = Uri.parse("${AppConstants.apiUrl}$endpoint");
      debugPrint('GET: \$uri');
      final res = await http.get(uri, headers: headers).timeout(_timeout);
      debugPrint('Response \${res.statusCode}: \${res.body}');
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on SocketException {
      return {'error': 'No internet connection'};
    } catch (e) {
      debugPrint('GET error: \$e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await getHeaders();
      final uri = Uri.parse("${AppConstants.apiUrl}$endpoint");
      debugPrint('POST: \$uri');
      debugPrint('Body: \${jsonEncode(body)}');
      final res = await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(_timeout);
      debugPrint('Response \${res.statusCode}: \${res.body}');
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on SocketException {
      return {'error': 'No internet connection'};
    } catch (e) {
      debugPrint('POST error: \$e');
      return {'error': e.toString()};
    }
  }
}
