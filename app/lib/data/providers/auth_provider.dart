import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../core/constants/app_constants.dart';
import '../../core/network/api_service.dart';
import 'package:http/http.dart' as http;

/// Account wale API ka jawab (login bina OTP, forgot, merge — Oct 2026).
class AccountResult {
  final int status;
  final Map<String, dynamic> data;
  AccountResult(this.status, this.data);
  bool get ok => status >= 200 && status < 300;
  String get detail {
    final d = data['detail'];
    return d is String && d.isNotEmpty ? d : 'Something went wrong. Please try again.';
  }
}

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

      // SECURITY: backend ab Google login tabhi maanta hai jab Firebase ka ID
      // token saath ho (usse verify hota hai ki email sach me isi insaan ka
      // hai — pehle koi bhi sirf email bhej kar kisi ka account le sakta tha).
      // Google credential se Firebase me sign-in karke token lete hain.
      String? firebaseIdToken;
      try {
        final ga = await googleUser.authentication;
        if (ga.idToken != null) {
          final cred = fb.GoogleAuthProvider.credential(
            idToken: ga.idToken,
            accessToken: ga.accessToken,
          );
          final r = await fb.FirebaseAuth.instance.signInWithCredential(cred);
          firebaseIdToken = await r.user?.getIdToken();
        }
      } catch (e) {
        _syncDebug = 'FIREBASE TOKEN: $e';
      }

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
            'id_token': firebaseIdToken,
          }),
        ).timeout(const Duration(seconds: 15));
        _syncDebug = 'STATUS ${syncRes.statusCode}';
        if (syncRes.statusCode != 200) {
          // Verify fail (jaise purana token) — aadha login mat chhodo
          String msg = 'Google sign-in failed. Please try again.';
          try {
            msg = (jsonDecode(syncRes.body)['detail'] ?? msg).toString();
          } catch (_) {}
          try {
            await _googleSignIn.signOut();
          } catch (_) {}
          _isLoading = false;
          _error = msg;
          notifyListeners();
          return 'error';
        }
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
  // Android ne OTP khud padh liya (Firebase session ban chuka) — tab code nahi chahiye
  bool _autoVerified = false;

  /// OTP bhejta hai. Success par null, warna error message.
  /// [onAutoVerified] tab chalta hai jab Android khud OTP padh leta hai.
  Future<String?> sendOtp(
    String phone10, {
    void Function()? onAutoVerified,
  }) async {
    _error = null;
    _autoVerified = false;
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
            _autoVerified = true;
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
    if (_verificationId == null && !_autoVerified) return 'Please request a new OTP.';

    _isLoading = true;
    notifyListeners();

    try {
      final String token;
      try {
        token = await otpIdToken(code);
      } on fb.FirebaseAuthException {
        rethrow;
      } catch (e) {
        _isLoading = false;
        notifyListeners();
        return otpErrorText(e);
      }

      final r = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}/users/login-phone'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': token}),
          )
          .timeout(const Duration(seconds: 20));

      if (r.statusCode != 200) {
        String msg = 'Login failed (${r.statusCode})';
        try {
          final d = jsonDecode(r.body)['detail'];
          if (d is String && d.isNotEmpty) msg = d;
        } catch (_) {}
        _isLoading = false;
        _error = msg;
        notifyListeners();
        return msg;
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

  /// OTP check karke sirf Firebase ka ID token — backend login nahi.
  /// Forgot password (SMS) aur account merge me saboot ke liye.
  Future<String> otpIdToken(String code) async {
    final cur = fb.FirebaseAuth.instance.currentUser;
    if (_autoVerified && cur != null) {
      final t = await cur.getIdToken(true);
      if (t != null) return t;
    }
    if (_verificationId == null) throw Exception('Please request a new OTP.');
    final cred = fb.PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code.trim(),
    );
    final res = await fb.FirebaseAuth.instance.signInWithCredential(cred);
    final t = await res.user?.getIdToken();
    if (t == null) throw Exception('Verification failed. Please try again.');
    return t;
  }

  /// Firebase / koi bhi error -> student ke samajhne layak line
  String otpErrorText(Object e) {
    if (e is fb.FirebaseAuthException) return _otpError(e.code, e.message);
    final s = e.toString().replaceFirst('Exception: ', '');
    return s.isEmpty ? 'Something went wrong. Please try again.' : s;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  LOGIN BINA OTP + ACCOUNT MERGE (Oct 2026) — website jaisa.
  //  Backend: routers/account.py. Har SMS ~₹5 ka hai, isliye login ab
  //  mobile/email + password (ya Google) se; OTP sirf naye account, forgot
  //  password (jab email na ho) aur merge ke saboot ke liye.
  //  Token har call me AuthClient (main.dart) khud jodta hai.
  // ══════════════════════════════════════════════════════════════════════

  Future<AccountResult> accountCall(String method, String path,
      [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('${AppConstants.apiUrl}$path');
      const headers = {'Content-Type': 'application/json'};
      final res = method == 'GET'
          ? await http.get(uri, headers: headers).timeout(const Duration(seconds: 25))
          : await http
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 25));
      Map<String, dynamic> data = {};
      try {
        final d = jsonDecode(res.body);
        if (d is Map<String, dynamic>) data = d;
      } catch (_) {}
      if (res.statusCode >= 400 && data['detail'] is! String) {
        data['detail'] = 'Something went wrong (${res.statusCode}). Please try again.';
      }
      return AccountResult(res.statusCode, data);
    } catch (_) {
      return AccountResult(0, {'detail': 'Cannot reach server. Please check your internet.'});
    }
  }

  Map<String, dynamic> _userFromBackend(Map<String, dynamic> u) {
    final rawId = u['id'];
    return {
      'id': rawId is int ? rawId : int.tryParse('${rawId ?? ''}'),
      'google_id': u['google_id'],
      'name': u['name'] ?? 'Student',
      'email': u['email'] ?? '',
      'phone': u['phone'] ?? '',
      'photo_url': u['profile_pic'] ?? '',
      'nickname': u['nickname'],
      'city': u['city'],
      'target_exam': u['target_exam'],
      'has_membership': u['has_membership'] ?? false,
      'points': u['points'] ?? 0,
      'streak_days': u['streak_days'] ?? 0,
      'profile_completed': u['profile_completed'] ?? false,
    };
  }

  /// Login wala jawab (token + user) save karo. 'home' | 'profile_setup'.
  Future<String> _applyLogin(Map<String, dynamic> data) async {
    final raw = data['user'];
    final u = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    await _saveToken(data['token']);
    _user = _userFromBackend(u);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode(_user));
    await prefs.setInt(_refreshKey, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
    return u['profile_completed'] == true ? 'home' : 'profile_setup';
  }

  /// Mobile ya email + password. 'home' | 'profile_setup' | 'error' (error me message).
  Future<String> loginWithPassword(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final r = await accountCall('POST', '/users/login-password', {
      'identifier': identifier.trim(),
      'password': password,
    });
    _isLoading = false;
    if (!r.ok) {
      _error = r.detail;
      notifyListeners();
      return 'error';
    }
    return _applyLogin(r.data);
  }

  /// Forgot password: pehle email par code (free), SMS sirf jab zaroori.
  Future<AccountResult> forgotStart(String identifier, {String? via}) =>
      accountCall('POST', '/users/forgot/start', {
        'identifier': identifier.trim(),
        'via': via,
      });

  /// Naya password + code (email) ya id_token (SMS). 'home' | 'profile_setup' | error message.
  Future<String> forgotReset({
    required String identifier,
    required String newPassword,
    String? code,
    String? idToken,
  }) async {
    final r = await accountCall('POST', '/users/forgot/reset', {
      'identifier': identifier.trim(),
      'new_password': newPassword,
      'code': code,
      'id_token': idToken,
    });
    if (!r.ok) return r.detail;
    return _applyLogin(r.data);
  }

  static const _refreshKey = 'session_refreshed_at';

  /// Sliding session: din me ek baar naya token (roz aane wala kabhi logout
  /// nahi hota). 'ok' | 'skip' | 'expired' | 'merged' | 'no_token'.
  Future<String> refreshSession() async {
    if (_user == null) return 'skip';
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey) ?? '';
    // Token hi nahi (bahut purana login) — PDF wagairah ab token maangte hain
    if (token.isEmpty) return 'no_token';
    final last = prefs.getInt(_refreshKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < 20 * 3600 * 1000) return 'skip';
    final r = await accountCall('POST', '/users/refresh-token');
    if (r.ok) {
      await _saveToken(r.data['token']);
      final raw = r.data['user'];
      if (raw is Map) {
        final fresh = _userFromBackend(Map<String, dynamic>.from(raw));
        // photo khaali aaye to purani rakho
        if ((fresh['photo_url'] ?? '') == '') fresh.remove('photo_url');
        _user = {...?_user, ...fresh};
        await prefs.setString(AppConstants.userKey, jsonEncode(_user));
        notifyListeners();
      }
      await prefs.setInt(_refreshKey, now);
      return 'ok';
    }
    if (r.status == 401) {
      return r.detail.toLowerCase().contains('merged') ? 'merged' : 'expired';
    }
    return 'skip'; // internet / server ki gadbad — kuch mat chhedo
  }

  Future<AccountResult> accountStatus() => accountCall('GET', '/users/account-status');

  Future<AccountResult> setPassword(String password) =>
      accountCall('POST', '/users/set-password', {'password': password});

  /// Ye number/email kisi doosre account par to nahi? status: free | mine | other
  Future<AccountResult> accountCheck({String? phone, String? email}) =>
      accountCall('POST', '/users/account-check', {'phone': phone, 'email': email});

  /// Merge ka saboot shuru. email -> server code bhejta hai; sms -> hum Firebase se.
  Future<AccountResult> mergeStart({String? phone, String? email}) =>
      accountCall('POST', '/users/merge/start', {'phone': phone, 'email': email});

  /// Saboot ke saath merge. Jo account bacha, uska token + user save. null = ho gaya.
  Future<String?> mergeConfirm(
      {String? phone, String? email, String? idToken, String? code}) async {
    final r = await accountCall('POST', '/users/merge/confirm', {
      'phone': phone,
      'email': email,
      'id_token': idToken,
      'code': code,
    });
    if (!r.ok) return r.detail;
    await _applyLogin(r.data);
    return null;
  }

  /// Naya number/email is account par jodo (jab kisi aur ka na ho). null = ho gaya.
  Future<String?> addContact({String? phone, String? email}) async {
    final u = _user;
    if (u == null || u['id'] == null) return 'Please sign in again';
    final r = await accountCall('POST', '/users/complete-profile', {
      'user_id': u['id'],
      'name': u['name'] ?? 'Student',
      'phone': phone,
      'email': email,
    });
    if (!r.ok) return r.detail;
    final raw = r.data['user'];
    _user = {
      ...u,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (raw is Map) ..._userFromBackend(Map<String, dynamic>.from(raw)),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode(_user));
    notifyListeners();
    return null;
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
    await prefs.remove(_refreshKey);
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
