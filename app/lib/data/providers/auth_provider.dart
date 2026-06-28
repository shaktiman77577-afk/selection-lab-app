import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
  serverClientId: '912827115397-qm98tra9srdsl4o58bab6v1b9d6rsg8g.apps.googleusercontent.com',
);
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

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

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        _isLoading = false;
        _error = 'Google Sign In failed. Try again.';
        notifyListeners();
        return false;
      }

      // Save user data locally
      _user = {
        'name': firebaseUser.displayName ?? googleUser.displayName ?? 'User',
        'email': firebaseUser.email ?? googleUser.email,
        'phone': firebaseUser.phoneNumber ?? '',
        'photo_url': firebaseUser.photoURL ?? googleUser.photoUrl ?? '',
        'has_membership': false,
        'points': 0,
        'streak_days': 0,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(_user));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Google Sign In error: ${e.toString()}';
      notifyListeners();
      return false;
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
      await _firebaseAuth.signOut();
    } catch (_) {}
    _user = null;
    notifyListeners();
  }
}
