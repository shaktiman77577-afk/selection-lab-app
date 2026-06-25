import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

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
      debugPrint('loadUser error: \$e');
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
        _error = res['detail']?.toString() ?? 'Registration failed. Try again.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Connection error. Please check internet.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    _user = null;
    notifyListeners();
  }
}
