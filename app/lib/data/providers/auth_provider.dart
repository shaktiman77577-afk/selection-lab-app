import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  // After Google Sign In, these hold Google account info
  // so login_screen can pass them to ProfileSetupScreen
  String? googleId;
  String? googleEmail;
  String? googleDisplayName;
  bool profileCompleted = false;

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
        // Restore profile completed flag
        profileCompleted = prefs.getBool('profile_completed') ?? false;
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

  // Returns: 'home' | 'profile_setup' | 'error'
  Future<String> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return 'error';
      }

      // Store Google info
      googleId = googleUser.id;
      googleEmail = googleUser.email;
      googleDisplayName = googleUser.displayName ?? 'User';

      // Check profile on backend
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/users/check-profile/${googleUser.id}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['exists'] == true && data['profile_completed'] == true) {
          // Returning user — load their data
          final u = data['user'];
          _user = {
            'name': u['name'] ?? googleDisplayName,
            'email': u['email'] ?? googleEmail,
            'phone': '',
            'photo_url': googleUser.photoUrl ?? '',
            'has_membership': false,
            'points': 0,
            'streak_days': 0,
            'nickname': u['nickname'] ?? '',
            'city': u['city'] ?? '',
            'target_exam': u['target_exam'] ?? '',
          };
          profileCompleted = true;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.userKey, jsonEncode(_user));
          await prefs.setBool('profile_completed', true);

          _isLoading = false;
          notifyListeners();
          return 'home';
        } else {
          // New user — needs profile setup
          _user = {
            'name': googleDisplayName,
            'email': googleEmail,
            'phone': '',
            'photo_url': googleUser.photoUrl ?? '',
            'has_membership': false,
            'points': 0,
            'streak_days': 0,
          };
          profileCompleted = false;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.userKey, jsonEncode(_user));
          await prefs.setBool('profile_completed', false);

          _isLoading = false;
          notifyListeners();
          return 'profile_setup';
        }
      } else {
        // Backend error — still let them set up profile
        _user = {
          'name': googleDisplayName,
          'email': googleEmail,
          'phone': '',
          'photo_url': googleUser.photoUrl ?? '',
          'has_membership': false,
          'points': 0,
          'streak_days': 0,
        };
        profileCompleted = false;
        _isLoading = false;
        notifyListeners();
        return 'profile_setup';
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Google Sign In error: ${e.toString()}';
      notifyListeners();
      return 'error';
    }
  }

  // Called after profile setup completes
  Future<void> markProfileCompleted() async {
    profileCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_completed', true);
    notifyListeners();
  }

  Future<bool> register(String name, String phone, String password,
      {String? referralCode}) async {
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
    await prefs.remove('profile_completed');
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _user = null;
    googleId = null;
    googleEmail = null;
    googleDisplayName = null;
    profileCompleted = false;
    notifyListeners();
  }
}
