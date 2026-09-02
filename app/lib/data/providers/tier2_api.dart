// lib/data/providers/tier2_api.dart
//
// Tier 2 Practice (typing test + Excel/CPT) ka API wrapper.
//
// Website ke /api/tier2/* aur /api/tier2/excel/* endpoints — wahi backend,
// wahi data. App me ye module tha hi nahi, isliye Tier 2 series app se
// khareedi bhi nahi ja sakti thi.
//
// DHYAN: har series call me platform=app bhejna zaroori hai. Backend
// visible_on dekh kar rows chhaanta hai, aur param na ho to bhi "app" hi
// maanta hai — par saaf likha hona behtar hai, aur website ke saath fark
// dikhta rehta hai.

import '../../core/network/api_service.dart';

class Tier2Api {
  static String _uidQ(int? userId) => userId != null ? '&user_id=$userId' : '';
  static String _uidOnly(int? userId) =>
      userId != null ? '?user_id=$userId' : '';

  // ── SERIES ──

  /// GET /tier2/series -> series list with practice_count, typing_test_count,
  /// is_purchased
  static Future<List<Map<String, dynamic>>> series(int? userId) async {
    final res =
        await ApiService.get('/tier2/series?platform=app${_uidQ(userId)}');
    final list = res['series'];
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// GET /tier2/series/{id} -> { series, is_purchased, practice:[], tests:[] }
  ///
  /// Passage ka text yahan NAHI aata — backend jaanbujh kar nahi bhejta,
  /// warna student list se hi passage padh leta aur test ka matlab khatam.
  static Future<Map<String, dynamic>> seriesDetail(int seriesId, int? userId) {
    return ApiService.get('/tier2/series/$seriesId${_uidOnly(userId)}');
  }

  // ── TYPING ──

  /// GET /tier2/typing/passage/{id} -> meta (duration, target wpm, test numbers)
  ///
  /// practice passages me `passage_text` bhi aata hai (jinke paas printer nahi
  /// hai unke liye). Test mode me text kabhi nahi aata.
  static Future<Map<String, dynamic>> passage(int passageId, int? userId) {
    return ApiService.get('/tier2/typing/passage/$passageId${_uidOnly(userId)}');
  }

  /// POST /tier2/typing/submit
  ///
  /// Checking poori backend par hoti hai — WPM, accuracy, error types, aur
  /// word-by-word diff. App sirf typed text aur time bhejta hai.
  static Future<Map<String, dynamic>> submitTyping({
    required int userId,
    required int passageId,
    required int selectedTestNumber,
    required String typedText,
    required int secondsTaken,
  }) {
    return ApiService.post('/tier2/typing/submit', {
      'user_id': userId,
      'passage_id': passageId,
      'selected_test_number': selectedTestNumber,
      'typed_text': typedText,
      'seconds_taken': secondsTaken,
    });
  }

  /// GET /tier2/typing/progress -> best/avg wpm, accuracy, attempts
  static Future<Map<String, dynamic>> typingProgress(int userId,
      {int days = 30}) {
    return ApiService.get('/tier2/typing/progress?user_id=$userId&days=$days');
  }

  // ── EXCEL / CPT ──

  /// GET /tier2/excel/chart -> formula cards. Locked cards ka syntax/example
  /// backend bhejta hi nahi, isliye blur sirf dikhawa nahi hai.
  static Future<Map<String, dynamic>> excelChart(int seriesId, int? userId) {
    return ApiService.get(
        '/tier2/excel/chart?series_id=$seriesId${_uidQ(userId)}');
  }

  /// GET /tier2/excel/practice -> guided practice questions
  static Future<Map<String, dynamic>> excelPractice(int seriesId, int? userId) {
    return ApiService.get(
        '/tier2/excel/practice?series_id=$seriesId${_uidQ(userId)}');
  }

  /// GET /tier2/excel/practice/{id} -> ek question ka poora data
  static Future<Map<String, dynamic>> excelPracticeQuestion(
      int questionId, int? userId) {
    return ApiService.get(
        '/tier2/excel/practice/$questionId${_uidOnly(userId)}');
  }

  /// POST /tier2/excel/practice/check -> formula sahi hai ya nahi
  ///
  /// Body ki key `formula` hai, `answer` nahi — backend ka PracticeCheck model
  /// wahi maangta hai.
  static Future<Map<String, dynamic>> excelCheck({
    required int? userId,
    required int questionId,
    required String formula,
  }) {
    return ApiService.post('/tier2/excel/practice/check', {
      'user_id': userId,
      'question_id': questionId,
      'formula': formula,
    });
  }

  /// GET /tier2/excel/tests -> mock test list
  static Future<Map<String, dynamic>> excelTests(int seriesId, int? userId) {
    return ApiService.get(
        '/tier2/excel/tests?series_id=$seriesId${_uidQ(userId)}');
  }

  /// GET /tier2/excel/test/{id} -> questions + bonus MCQs
  static Future<Map<String, dynamic>> excelTest(int testId, int? userId) {
    return ApiService.get('/tier2/excel/test/$testId${_uidOnly(userId)}');
  }

  /// POST /tier2/excel/test/submit
  ///
  /// Backend list maangta hai, map nahi:
  ///   answers:       [{question_id, formula, seconds}]
  ///   bonus_answers: [{question_id, selected}]
  static Future<Map<String, dynamic>> submitExcelTest({
    required int userId,
    required int testId,
    required List<Map<String, dynamic>> answers,
    List<Map<String, dynamic>> bonusAnswers = const [],
    int secondsTaken = 0,
  }) {
    return ApiService.post('/tier2/excel/test/submit', {
      'user_id': userId,
      'test_id': testId,
      'answers': answers,
      'bonus_answers': bonusAnswers,
      'seconds_taken': secondsTaken,
    });
  }

  /// GET /tier2/excel/progress -> weak areas, attempts
  static Future<Map<String, dynamic>> excelProgress(int userId) {
    return ApiService.get('/tier2/excel/progress?user_id=$userId');
  }
}
