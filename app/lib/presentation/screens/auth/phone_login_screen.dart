// Phone OTP login — website ke login page jaisa hi.
//
// Do step: number daalo -> OTP daalo. Firebase OTP verify karta hai, phir
// backend /users/login-phone se asli user aata hai. Purane accounts bhi mil
// jate hain kyunki backend aakhri 10 digit se match karta hai.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'profile_setup_screen.dart';

const _gold = Color(0xFFFFAB00);
const _navy = Color(0xFF1A2F55);

class PhoneLoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const PhoneLoginScreen({super.key, required this.onToggleTheme});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();

  bool _sent = false;
  bool _busy = false;
  String _error = '';
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
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

  Future<void> _send() async {
    final p = _phone.text.trim();
    if (p.length != 10) {
      setState(() => _error = 'Please enter your 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    HapticFeedback.lightImpact();

    final err = await context.read<AuthProvider>().sendOtp(
          p,
          onAutoVerified: () {
            // Android ne OTP khud padh liya — seedha aage
            if (mounted) _verify(auto: true);
          },
        );

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err == null) {
        _sent = true;
        _error = '';
      } else {
        _error = err;
      }
    });
    if (err == null) _startResendTimer();
  }

  Future<void> _verify({bool auto = false}) async {
    if (!auto && _otp.text.trim().length < 6) {
      setState(() => _error = 'Please enter the 6-digit OTP.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });

    final res = await context.read<AuthProvider>().verifyOtp(_otp.text);
    if (!mounted) return;

    if (res == 'home') {
      HapticFeedback.mediumImpact();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => HomeScreen(onToggleTheme: widget.onToggleTheme)),
        (_) => false,
      );
    } else if (res == 'profile_setup') {
      final auth = context.read<AuthProvider>();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            onToggleTheme: widget.onToggleTheme,
            googleId: '',
            email: (auth.user?['email'] ?? '').toString(),
            displayName: (auth.user?['name'] ?? '').toString(),
          ),
        ),
      );
    } else {
      setState(() {
        _busy = false;
        _error = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF221C10);
    final muted = dark ? const Color(0xFF9A917F) : const Color(0xFF776F5C);
    final card = dark ? const Color(0xFF16130E) : Colors.white;
    final line = dark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.10);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0D0B08) : const Color(0xFFF6F4EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: text),
        title: Text('Login with mobile',
            style: TextStyle(
                color: text, fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sent ? 'Enter the OTP' : 'What is your mobile number?',
                style: TextStyle(
                    color: text, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _sent
                    ? 'We sent a 6-digit code to +91 ${_phone.text.trim()}'
                    : 'We will send you a one-time password to verify it.',
                style: TextStyle(color: muted, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 24),

              if (!_sent) ...[
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('+91',
                            style: TextStyle(
                                color: text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ),
                      Container(width: 1, height: 26, color: line),
                      Expanded(
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          autofocus: true,
                          style: TextStyle(
                              color: text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            hintText: '9876543210',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 10),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    filled: true,
                    fillColor: card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: line),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.length == 6) _verify();
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _sent = false;
                        _otp.clear();
                        _error = '';
                      }),
                      child: Text('Change number',
                          style: TextStyle(color: muted, fontSize: 13)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _resendIn > 0 || _busy ? null : _send,
                      child: Text(
                        _resendIn > 0 ? 'Resend in $_resendIn s' : 'Resend OTP',
                        style: TextStyle(
                            color: _resendIn > 0 ? muted : _gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
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

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : (_sent ? _verify : _send),
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
                      : Text(_sent ? 'Verify & Sign In' : 'Send OTP',
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
              ),

              const SizedBox(height: 18),
              Center(
                child: Text(
                  'By continuing you agree to our Terms and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 11.5, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
