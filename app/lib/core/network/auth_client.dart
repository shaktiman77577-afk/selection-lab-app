// lib/core/network/auth_client.dart
//
// SECURITY PHASE 2 (Sep 2026): har API call me login token apne aap.
//
// App me sau se zyada jagah seedha http.get / http.post chalta hai. Har jagah
// header jodne ki jagah main.dart me http.runWithClient() se ye client poore
// app ka default bana diya hai — saare http.get/post isi se jaate hain.
//
// Sirf hamare API (api.selectionlab.online) par token jata hai, kisi aur site
// par kabhi nahi. Jis call me pehle se Authorization hai, use nahi chhedte.
// Token na ho (purana login) to request waisi hi jati hai — backend abhi
// bina token bhi chalta hai (Phase 1), bas log karta hai.

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class AuthClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  static const _apiHost = 'api.selectionlab.online';

  Future<String?> _token() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(AppConstants.tokenKey);
      return (t == null || t.isEmpty) ? null : t;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == _apiHost &&
        !request.headers.keys.any((k) => k.toLowerCase() == 'authorization')) {
      final token = await _token();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
