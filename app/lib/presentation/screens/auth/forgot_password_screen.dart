// Forgot password (Oct 2026) — website ke /forgot-password jaisa.
//
// Pehle EMAIL par code (free). SMS (Firebase, ~₹5) sirf tab jab account me
// email na ho ya student khud "SMS bhejo" chune. Naya password set hote hi
// login ho jaata hai. Backend: /users/forgot/start, /users/forgot/reset.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'profile_setup_screen.dart';

const _gold = Color(0xFFFFAB00);
const _navy = Color(0xFF1A2F55);

class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final String initialIdentifier;
  const ForgotPasswordScreen({
    super.key,
    required this.onToggleTheme,
    this.initialIdentifier = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _id;
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  // Code kahan gaya: 'email' | 'sms'. null = abhi bheja nahi.
  String? _method;
  String _sentTo = '';
  bool _smsAvailable = false;
  bool _emailAvailable = false;
  bool _busy = false;
  bool _obscure = true;
  String _error = '';
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _id = TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _id.dispose();
    _code.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _send([String? via]) async {
    FocusScope.of(context).unfocus();
    final ident = _id.text.trim();
    if (ident.isEmpty) {
      setState(() => _error = 'Please enter your mobile number or email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final auth = context.read<AuthProvider>();
    final r = await auth.forgotStart(ident, via: via);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _busy = false;
        _error = r.detail;
      });
      return;
    }
    final method = (r.data['method'] ?? 'email').toString();
    if (method == 'sms') {
      // SMS Firebase se — server ne number bataya
      final phone = (r.data['phone'] ?? '').toString();
      final err = await auth.sendOtp(phone);
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _busy = false;
          _error = err;
        });
        return;
      }
    }
    setState(() {
      _busy = false;
      _method = method;
      _sentTo = (r.data['sent_to'] ?? '').toString();
      _smsAvailable = r.data['sms_available'] == true;
      _emailAvailable = r.data['email_available'] == true;
      _code.clear();
    });
    _startResendTimer();
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Please enter the 6-digit code.');
      return;
    }
    if (_pass.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_pass.text != _pass2.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final auth = context.read<AuthProvider>();
    String res;
    try {
      if (_method == 'sms') {
        final idToken = await auth.otpIdToken(code);
        res = await auth.forgotReset(
            identifier: _id.text, newPassword: _pass.text, idToken: idToken);
      } else {
        res = await auth.forgotReset(
            identifier: _id.text, newPassword: _pass.text, code: code);
      }
    } catch (e) {
      res = auth.otpErrorText(e);
    }
    if (!mounted) return;

    if (res == 'home' || res == 'profile_setup') {
      HapticFeedback.mediumImpact();
      final u = auth.user ?? {};
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => res == 'home'
              ? HomeScreen(onToggleTheme: widget.onToggleTheme)
              : ProfileSetupScreen(
                  onToggleTheme: widget.onToggleTheme,
                  googleId: (u['google_id'] ?? '').toString(),
                  email: (u['email'] ?? '').toString(),
                  displayName: (u['name'] ?? '').toString(),
                ),
        ),
        (_) => false,
      );
      return;
    }
    setState(() {
      _busy = false;
      _error = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF221C10);
    final muted = dark ? const Color(0xFF9A917F) : const Color(0xFF776F5C);
    final card = dark ? const Color(0xFF16130E) : Colors.white;
    final line =
        dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.10);

    InputDecoration deco(String hint, IconData icon, {Widget? suffix}) =>
        InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: muted),
          suffixIcon: suffix,
          filled: true,
          fillColor: card,
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _gold, width: 1.5),
          ),
        );
    final fieldStyle =
        TextStyle(color: text, fontSize: 15.5, fontWeight: FontWeight.w600);
    final sent = _method != null;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0D0B08) : const Color(0xFFF6F4EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: text),
        title: Text('Reset password',
            style: TextStyle(
                color: text, fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sent ? 'Enter the code' : 'Forgot your password?',
                style: TextStyle(
                    color: text, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                sent
                    ? 'Enter the code and choose a new password.'
                    : 'Enter your mobile number or email. We will send you a verification code.',
                style: TextStyle(color: muted, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 22),
              if (!sent) ...[
                TextField(
                  controller: _id,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: widget.initialIdentifier.isEmpty,
                  style: fieldStyle,
                  decoration:
                      deco('Mobile number or email', Icons.person_outline_rounded),
                  onSubmitted: (_) => _send(),
                ),
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _navy.withOpacity(dark ? 0.35 : 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: _method == 'email'
                              ? '📧 Code sent to '
                              : '📱 OTP sent to '),
                      TextSpan(
                          text: _sentTo,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (_method == 'email')
                        const TextSpan(text: ' — check Spam too'),
                    ]),
                    style: TextStyle(color: text, fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                      color: text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8),
                  decoration: deco('6-digit code', Icons.pin_outlined),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _obscure,
                  style: fieldStyle,
                  decoration: deco(
                    'New password (min 6 characters)',
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: muted),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass2,
                  obscureText: _obscure,
                  style: fieldStyle,
                  decoration:
                      deco('Confirm new password', Icons.lock_outline_rounded),
                  onSubmitted: (_) => _reset(),
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFD64545), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error,
                          style: const TextStyle(
                              color: Color(0xFFD64545),
                              fontSize: 13,
                              height: 1.5)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : (sent ? _reset : () => _send()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: const Color(0xFF1A1A1A),
                  disabledBackgroundColor: _gold.withOpacity(0.5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF1A1A1A)),
                      )
                    : Text(sent ? 'Save password & sign in' : 'Send code',
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w800)),
              ),
              if (sent) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed:
                      _resendIn > 0 || _busy ? null : () => _send(_method),
                  child: Text(
                    _resendIn > 0 ? 'Resend in $_resendIn s' : 'Resend code',
                    style: TextStyle(
                        color: _resendIn > 0 ? muted : _gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (_method == 'email' && _smsAvailable)
                  TextButton(
                    onPressed: _busy ? null : () => _send('sms'),
                    child: Text("Didn't get the email? Send OTP by SMS",
                        style: TextStyle(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                if (_method == 'sms' && _emailAvailable)
                  TextButton(
                    onPressed: _busy ? null : () => _send('email'),
                    child: Text('Send the code to my email instead',
                        style: TextStyle(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _method = null;
                            _error = '';
                          }),
                  child: Text('Use a different number or email',
                      style: TextStyle(color: muted, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
