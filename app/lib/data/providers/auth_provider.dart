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
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(AppConstants.userKey);
    if (userData != null) {
      _user = jsonDecode(userData);
      notifyListeners();
    }
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await ApiService.post(AppConstants.login, {
      'phone': phone,
      'password': password,
    });
    _isLoading = false;
    if (res['success'] == true) {
      _user = res['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, res['token']);
      await prefs.setString(AppConstants.userKey, jsonEncode(res['user']));
      notifyListeners();
      return true;
    } else {
      _error = res['detail'] ?? 'Login failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String phone, String password, {String? referralCode}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await ApiService.post(AppConstants.register, {
      'name': name,
      'phone': phone,
      'password': password,
      if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
    });
    _isLoading = false;
    if (res['success'] == true) {
      _user = res['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, res['token']);
      await prefs.setString(AppConstants.userKey, jsonEncode(res['user']));
      notifyListeners();
      return true;
    } else {
      _error = res['detail'] ?? 'Registration failed';
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
