import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
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

  /// Backend ka JWT save karta hai.
  ///
  /// Google aur phone-OTP login pehle token save nahi karte the, isliye
  /// DELETE /users/me (Play Store ka account-deletion requirement) hamesha
  /// 403 deta tha — app ke paas bhejne ko Authorization header hi nahi tha.
  /// Backend ab dono flows me token bhejta hai; yahan use rakh lete hain.
  Future<void> _saveToken(dynamic token) async {
    if (token is! String || token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
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
        _syncDebug = 'STATUS ${syncRes.statusCode}';
        if (syncRes.statusCode == 200) {
          final data = jsonDecode(syncRes.body);
          backendUser = (data['user'] as Map<String, dynamic>?) ?? {};
          await _saveToken(data['token']);
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

  // ── PHONE OTP LOGIN ─────────────────────────────────────────────────────
  // Website jaisa hi flow: Firebase se OTP verify hota hai, phir uska ID token
  // backend ko bhejte hain. Backend phone ke aakhri 10 digit se match karta hai,
  // isliye +91 wale aur bina +91 wale dono purane accounts mil jate hain.

  String? _verificationId;
  int? _resendToken;

  /// OTP bhejta hai. Success par null, warna error message.
  /// [onAutoVerified] tab chalta hai jab Android khud OTP padh leta hai.
  Future<String?> sendOtp(
    String phone10, {
    void Function()? onAutoVerified,
  }) async {
    _error = null;
    final completer = Completer<String?>();

    try {
      await fb.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone10',
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (cred) async {
          // Android par OTP apne aap padh liya gaya
          try {
            await fb.FirebaseAuth.instance.signInWithCredential(cred);
            onAutoVerified?.call();
          } catch (_) {}
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) {
            completer.complete(_otpError(e.code, e.message));
          }
        },
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          if (!completer.isCompleted) completer.complete(null);
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete('Could not send the OTP. Please try again.');
      }
    }
    return completer.future;
  }

  /// OTP check karke backend se login. 'home' | 'profile_setup' | error message.
  Future<String> verifyOtp(String code) async {
    if (_verificationId == null) return 'Please request a new OTP.';

    _isLoading = true;
    notifyListeners();

    try {
      final cred = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code.trim(),
      );
      final res = await fb.FirebaseAuth.instance.signInWithCredential(cred);
      final token = await res.user?.getIdToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return 'Verification failed. Please try again.';
      }

      final r = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}/users/login-phone'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': token}),
          )
          .timeout(const Duration(seconds: 20));

      if (r.statusCode != 200) {
        _isLoading = false;
        _error = 'Login failed (${r.statusCode})';
        notifyListeners();
        return _error!;
      }

      final data = jsonDecode(r.body);
      final u = (data['user'] as Map<String, dynamic>?) ?? {};
      await _saveToken(data['token']);
      final rawId = u['id'];

      _user = {
        'id': rawId is int ? rawId : int.tryParse('${rawId ?? ''}'),
        'name': u['name'] ?? 'Student',
        'email': u['email'] ?? '',
        'phone': u['phone'] ?? '',
        'photo_url': u['profile_pic'] ?? '',
        'nickname': u['nickname'],
        'city': u['city'],
        'target_exam': u['target_exam'],
        'has_membership': false,
        'points': u['points'] ?? 0,
        'streak_days': u['streak_days'] ?? 0,
        'profile_completed': u['profile_completed'] ?? false,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(_user));

      _isLoading = false;
      notifyListeners();
      return u['profile_completed'] == true ? 'home' : 'profile_setup';
    } on fb.FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _otpError(e.code, e.message);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Something went wrong. Please try again.';
    }
  }

  /// Firebase ke code ko aam bhasha me — students ko technical error na dikhe
  String _otpError(String code, String? fallback) {
    switch (code) {
      case 'invalid-phone-number':
        return 'That phone number does not look right.';
      case 'invalid-verification-code':
        return 'Wrong OTP. Please check and try again.';
      case 'session-expired':
        return 'The OTP has expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again after some time.';
      case 'quota-exceeded':
        return 'OTP service is busy right now. Please use Google sign-in.';
      default:
        return fallback ?? 'Could not verify the OTP. Please try again.';
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
    try {
      // Phone-OTP wala Firebase session bhi band karo, warna agli baar
      // purana session pada rehta hai.
      await fb.FirebaseAuth.instance.signOut();
    } catch (_) {}
    _user = null;
    notifyListeners();
  }
}
