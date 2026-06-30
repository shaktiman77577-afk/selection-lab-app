import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_service.dart';
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;
  String? _syncDebug;
  String? get syncDebug => _syncDebug;

  // Google account info (used by profile setup screen)
  String? _googleId;
  String? _googleEmail;
  String? _googleDisplayName;
  String? get googleId => _googleId;
  String? get googleEmail => _googleEmail;
  String? get googleDisplayName => _googleDisplayName;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get hasMembership => _user?['has_membership'] ?? false;

  Future<void> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(AppConstants.userKey);
      if (userData != null) {
        _user = jsonDecode(userData) as Map<String, dynamic>;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadUser error: $e');
    }
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.post(AppConstants.login, {
        'phone': phone,
        'password': password,
      });
      _isLoading = false;
      if (res['success'] == true && res['token'] != null) {
        _user = res['user'] as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, res['token'] as String);
        await prefs.setString(AppConstants.userKey, jsonEncode(_user));
        notifyListeners();
        return true;
      } else {
        _error = res['detail']?.toString() ?? 'Login failed. Check your credentials.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Connection error. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<String> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return 'cancelled';
      }

      // Store google info for profile setup screen
      _googleId = googleUser.id;
      _googleEmail = googleUser.email;
      _googleDisplayName = googleUser.displayName;

      // Sync with backend to get integer user id (for quiz/mock/courses linking)
      int? backendId;
      Map<String, dynamic> backendUser = {};
      try {
        final syncRes = await http.post(
          Uri.parse('${AppConstants.apiUrl}/users/sync'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'google_id': googleUser.id,
            'email': googleUser.email,
            'name': googleUser.displayName,
            'profile_pic': googleUser.photoUrl,
          }),
        ).timeout(const Duration(seconds: 15));
        _syncDebug = 'STATUS ${syncRes.statusCode}: ${syncRes.body}';
        if (syncRes.statusCode == 200) {
          final data = jsonDecode(syncRes.body);
          backendUser = (data['user'] as Map<String, dynamic>?) ?? {};
          final rawId = backendUser['id'];
          if (rawId is int) {
            backendId = rawId;
          } else if (rawId != null) {
            backendId = int.tryParse(rawId.toString());
          }
        }
      } catch (e) {
        _syncDebug = 'SYNC EXCEPTION: $e';
      }

      _user = {
        'id': backendId,
        'google_id': googleUser.id,
        'name': backendUser['name'] ?? googleUser.displayName ?? 'User',
        'email': googleUser.email,
        'phone': backendUser['phone'] ?? '',
        'photo_url': backendUser['profile_pic'] ?? googleUser.photoUrl ?? '',
        'nickname': backendUser['nickname'],
        'city': backendUser['city'],
        'target_exam': backendUser['target_exam'],
        'has_membership': false,
        'points': backendUser['points'] ?? 0,
        'streak_days': backendUser['streak_days'] ?? 0,
        'profile_completed': backendUser['profile_completed'] ?? false,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(_user));

      _isLoading = false;
      notifyListeners();

      // Route based on profile completion
      final completed = backendUser['profile_completed'] == true;
      return completed ? 'home' : 'profile_setup';
    } catch (e) {
      _isLoading = false;
      _error = 'Google Sign In error: ${e.toString()}';
      notifyListeners();
      return 'error';
    }
  }

  Future<bool> register(String name, String phone, String password, {String? referralCode}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final Map<String, dynamic> body = {
        'name': name,
        'phone': phone,
        'password': password,
      };
      if (referralCode != null && referralCode.isNotEmpty) {
        body['referral_code'] = referralCode;
      }
      final res = await ApiService.post(AppConstants.register, body);
      _isLoading = false;
      if (res['success'] == true && res['token'] != null) {
        _user = res['user'] as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, res['token'] as String);
        await prefs.setString(AppConstants.userKey, jsonEncode(_user));
        notifyListeners();
        return true;
      } else {
        _error = 'DEBUG: ' + res.toString();
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _user = null;
    notifyListeners();
  }
}
