class AppConstants {
  static const String appName = "Selection Lab";
  static const String baseUrl = "https://api.selectionlab.online";
  static const String apiUrl = "$baseUrl/api";

  static const String login = "/auth/login";
  static const String register = "/auth/register";
  static const String profile = "/users/profile";
  static const String categories = "/exams/categories";
  static const String quizStart = "/quiz/start";
  static const String quizSubmit = "/quiz/submit-answer";
  static const String quizFinish = "/quiz/finish";
  static const String mockTests = "/mock-tests/";
  static const String notifications = "/notifications/";
  static const String bookmarks = "/users/bookmarks";
  static const String leaderboard = "/users/leaderboard";

  static const String tokenKey = "auth_token";
  static const String userKey = "user_data";
  static const String themeKey = "theme_mode";
  static const String languageKey = "language";
}
