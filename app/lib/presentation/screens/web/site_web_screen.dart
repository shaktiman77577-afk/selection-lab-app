// lib/presentation/screens/web/site_web_screen.dart
//
// Website ka koi bhi page app ke andar — student ko dobara login nahi karna
// padta.
//
// Login kaise pahunchta hai: website user ko localStorage ki `sl_user` key
// me rakhti hai. Pehle usi domain ka ek chhota page (robots.txt) khulta hai,
// wahan app apna user aur theme localStorage me likh deta hai, phir asli page
// par location.replace() — isliye robots.txt back-history me nahi rehta.
//
// Login token bhi "sl_token" me jata hai — website har API call me bhejti hai.
//
// App mode: sessionStorage "sl-app" bhi set hota hai — website us tab me
// apna side menu chhupa kar sirf "Back to app" dikhati hai, jo /__app/close
// kholta hai; yahan wo URL pakad kar screen band hoti hai.
//
// Payment website ke apne Razorpay se hi hoti hai. UPI apps (upi://,
// intent://) aur bahar ke links phone ke apps/browser me khulte hain,
// PDF download bhi browser se.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';

class SiteWebScreen extends StatefulWidget {
  /// Website ka path, jaise '/tier2' ya '/nbems-mock?s=4'
  final String path;
  const SiteWebScreen({super.key, required this.path});

  @override
  State<SiteWebScreen> createState() => _SiteWebScreenState();
}

class _SiteWebScreenState extends State<SiteWebScreen> {
  static const _site = 'https://www.selectionlab.in';
  static const _gold = Color(0xFFFFAB00);

  late final WebViewController _c;
  bool _booted = false;
  bool _failed = false;
  bool _needLogin = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: _onFinished,
        onNavigationRequest: _onNav,
        onWebResourceError: (e) {
          if (e.isForMainFrame == true && mounted) {
            setState(() => _failed = true);
          }
        },
      ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  void _start() {
    final raw = context.read<AuthProvider>().user?['id'];
    final uid = raw is int ? raw : int.tryParse('${raw ?? ''}');
    if (uid == null) {
      setState(() => _needLogin = true);
      return;
    }
    _c.setBackgroundColor(
        _dark ? const Color(0xFF0D0B08) : const Color(0xFFF6F4EE));
    _booted = false;
    _c.loadRequest(Uri.parse('$_site/robots.txt'));
  }

  /// App ka user website ke format me (website `profile_pic` padhti hai,
  /// app `photo_url` rakhta hai).
  Map<String, dynamic> _webUser() {
    final u = context.read<AuthProvider>().user ?? {};
    final raw = u['id'];
    return {
      'id': raw is int ? raw : int.tryParse('${raw ?? ''}'),
      'name': u['name'],
      'email': u['email'],
      'phone': u['phone'],
      'profile_pic': u['photo_url'],
      'points': u['points'],
      'streak_days': u['streak_days'],
      'target_exam': u['target_exam'],
      'profile_completed': u['profile_completed'] ?? true,
    };
  }

  Future<void> _onFinished(String url) async {
    if (_booted) return;
    _booted = true;
    final sep = widget.path.contains('?') ? '&' : '?';
    final target = '${widget.path}${sep}app=1';
    // App ka login token bhi — website har API call me isse bhejti hai.
    // Token na ho to purana hata do, taaki kisi aur account ka na chala jaye.
    String? token;
    try {
      token = (await SharedPreferences.getInstance())
          .getString(AppConstants.tokenKey);
    } catch (_) {}
    if (!mounted) return;
    final tokenJs = (token == null || token.isEmpty)
        ? "localStorage.removeItem('sl_token');"
        : "localStorage.setItem('sl_token', ${jsonEncode(token)});";
    final js = '''
try {
  localStorage.setItem('sl_user', ${jsonEncode(jsonEncode(_webUser()))});
  $tokenJs
  localStorage.setItem('sl-theme', ${jsonEncode(_dark ? 'dark' : 'light')});
  sessionStorage.setItem('sl-app', '1');
} catch (e) {}
location.replace(location.origin + ${jsonEncode(target)});
''';
    try {
      await _c.runJavaScript(js);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  NavigationDecision _onNav(NavigationRequest r) {
    final uri = Uri.tryParse(r.url);
    if (uri == null) return NavigationDecision.prevent;
    final s = uri.scheme;

    if (s == 'about' || s == 'data' || s == 'blob' || s == 'javascript') {
      return NavigationDecision.navigate;
    }
    // upi://, intent://, tel:, mailto:, whatsapp: — phone ke apps
    if (s != 'http' && s != 'https') {
      _external(r.url);
      return NavigationDecision.prevent;
    }
    // iframes (Razorpay, YouTube embed) apni jagah chalne do
    if (!r.isMainFrame) return NavigationDecision.navigate;

    final h = uri.host;
    // Website ka "Back to app" (app mode menu) — WebView band
    if (h.endsWith('selectionlab.in') && uri.path.startsWith('/__app/close')) {
      if (mounted) Navigator.of(context).pop();
      return NavigationDecision.prevent;
    }
    // API par seedha jaana = PDF/file download → browser
    if (h.endsWith('api.selectionlab.online')) {
      _external(r.url);
      return NavigationDecision.prevent;
    }
    if (h.endsWith('selectionlab.in') || h.contains('razorpay')) {
      return NavigationDecision.navigate;
    }
    // YouTube, Telegram, baaki sab bahar
    _external(r.url);
    return NavigationDecision.prevent;
  }

  Future<void> _external(String url) async {
    var target = url;
    // Android intent URL ko asli scheme me badlo:
    // intent://pay?pa=..#Intent;scheme=upi;package=..;end  →  upi://pay?pa=..
    if (url.startsWith('intent://')) {
      final body = url.substring('intent://'.length).split('#Intent;').first;
      final tail = RegExp(r'#Intent;(.*);end').firstMatch(url)?.group(1) ?? '';
      String? scheme;
      String? fallback;
      for (final p in tail.split(';')) {
        if (p.startsWith('scheme=')) scheme = p.substring(7);
        if (p.startsWith('S.browser_fallback_url=')) {
          fallback = Uri.decodeComponent(p.substring(23));
        }
      }
      if (scheme != null) {
        target = '$scheme://$body';
      } else if (fallback != null) {
        target = fallback;
      }
    }
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(target),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app found to open this.')),
      );
    }
  }

  Future<void> _back() async {
    if (await _c.canGoBack()) {
      await _c.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _retry() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    if (_booted) {
      _c.reload();
    } else {
      _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _dark ? const Color(0xFF0D0B08) : const Color(0xFFF6F4EE);
    final text = _dark ? Colors.white : const Color(0xFF221C10);

    Widget body;
    if (_needLogin) {
      body = _message(text, 'Please log in to the app first.', null);
    } else if (_failed) {
      body = _message(text, 'Could not load this page. Check your internet.',
          _retry);
    } else {
      body = WebViewWidget(controller: _c);
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: body),
              if (!_failed && !_needLogin && _progress < 100)
                LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 2,
                  color: _gold,
                  backgroundColor: Colors.transparent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(Color text, String msg, VoidCallback? onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(color: text, fontSize: 15, height: 1.5)),
            const SizedBox(height: 16),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: const Color(0xFF1A1A1A)),
                child: const Text('Try again'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Go back', style: TextStyle(color: text)),
            ),
          ],
        ),
      ),
    );
  }
}
