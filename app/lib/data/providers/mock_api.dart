// lib/data/providers/mock_api.dart
//
// Wrapper over ApiService for the Mock Test feature (same backend as website).
// Endpoints under /mock-tests.

import '../../core/network/api_service.dart';

class MockApi {
  static String _uidQ(int? userId) => userId != null ? '?user_id=$userId' : '';

  /// GET /mock-tests/series  -> { success, series:[{..., tests_count, free_count, is_purchased}] }
  static Future<List<Map<String, dynamic>>> series(int? userId) async {
    final res = await ApiService.get('/mock-tests/series${_uidQ(userId)}');
    final list = res['series'];
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// GET /mock-tests/series/{id} -> { series:{...}, tests:[{..., is_unlocked}] }
  static Future<Map<String, dynamic>> seriesDetail(int seriesId, int? userId) {
    return ApiService.get('/mock-tests/series/$seriesId${_uidQ(userId)}');
  }

  /// GET /mock-tests/{id}?exam=1 -> { mock_test, questions:[...], total }  OR 403 { detail }
  ///
  /// SECURITY (Oct 2026): exam=1 — test ke dauraan sahi jawab phone par aate
  /// hi nahi (pehle poori answer key aa jaati thi, mod use dikha sakta tha).
  /// Jawab submit ke baad [solutions] se.
  static Future<Map<String, dynamic>> test(int testId, int? userId) {
    final q = userId != null ? '?user_id=$userId&exam=1' : '?exam=1';
    return ApiService.get('/mock-tests/$testId$q');
  }

  /// GET /mock-tests/{id}/solutions -> { solutions:[{id, correct_answer,
  /// explanation, explanation_hi, explanation_image_url, ...}] }
  /// Sirf apna test submit karne ke baad milta hai (live test: result ke baad).
  static Future<Map<String, dynamic>> solutions(int testId, int? userId) {
    return ApiService.get('/mock-tests/$testId/solutions${_uidQ(userId)}');
  }

  /// POST /mock-tests/submit
  /// answers = { "questionId": "A"/"B"/"C"/"D" or null }
  /// questionTimes = { "questionId": seconds } — har question par kitna time laga.
  ///
  /// Backend ye pehle se accept karta tha, par app bhejta nahi tha. Isliye
  /// result screen ke "You: 42s" / "Avg: 31s" wale tags app se aaye attempts
  /// par hamesha khaali rehte the, aur speed analysis me sirf website users
  /// ginti me aate the.
  static Future<Map<String, dynamic>> submit(
    int? userId,
    int testId,
    Map<String, dynamic> answers,
    int timeTakenSeconds, {
    Map<String, dynamic>? questionTimes,
  }) {
    return ApiService.post('/mock-tests/submit', {
      'user_id': userId,
      'mock_test_id': testId,
      'answers': answers,
      'time_taken_seconds': timeTakenSeconds,
      'question_times': questionTimes ?? const <String, dynamic>{},
    });
  }
}
