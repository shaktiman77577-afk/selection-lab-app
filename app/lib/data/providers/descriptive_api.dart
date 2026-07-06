// lib/data/providers/descriptive_api.dart
//
// Thin wrapper over ApiService for the Descriptive Writing Tests feature.
// Talks to the SAME backend the website uses: /descriptive/* endpoints.

import '../../core/network/api_service.dart';

class DescriptiveApi {
  static String _uidQ(int? userId) => userId != null ? '?user_id=$userId' : '';

  /// GET /descriptive/series  ->  list of series (with is_purchased, test_count)
  static Future<List<Map<String, dynamic>>> series(int? userId) async {
    final res = await ApiService.get('/descriptive/series${_uidQ(userId)}');
    final list = res['series'];
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// GET /descriptive/series/{id}  ->  { series, is_purchased, tests:[...] }
  static Future<Map<String, dynamic>> seriesDetail(int seriesId, int? userId) {
    return ApiService.get('/descriptive/series/$seriesId${_uidQ(userId)}');
  }

  /// GET /descriptive/test/{id}  ->  { test, questions:[...] }  OR  { detail } if 403 locked
  static Future<Map<String, dynamic>> test(int testId, int? userId) {
    return ApiService.get('/descriptive/test/$testId${_uidQ(userId)}');
  }

  /// POST /descriptive/submit  ->  { results:[...], grand_total, grand_max }
  static Future<Map<String, dynamic>> submit(
    int userId,
    int testId,
    List<Map<String, dynamic>> answers,
  ) {
    return ApiService.post('/descriptive/submit', {
      'user_id': userId,
      'test_id': testId,
      'answers': answers,
    });
  }
}
