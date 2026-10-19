// lib/presentation/screens/auth/login_screen.dart
//
// UI matched to the website login (selectionlab.in/login):
// soft gradient, logo, "Welcome to Selection Lab", white card, trust badges.
//
// Oct 2026 — login bina OTP (website jaisa, har SMS ~₹5):
//   Google  ->  ya mobile/email + password ("Forgot password?")
//   Naya account -> "Create account with mobile OTP" (sirf yahin OTP).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'profile_setup_screen.dart';
import 'forgot_password_screen.dart';
import 'phone_login_screen.dart';

const _navy = Color(0xFF1A2F55);
const _gold = Color(0xFFFFAB00);

class LoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const LoginScreen({super.key, required this.onToggleTheme});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Login ke baad: profile adhoori ho to setup, warna home.
  void _routeAfterLogin(String result) {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (result == 'home') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => HomeScreen(onToggleTheme: widget.onToggleTheme)),
        (_) => false,
      );
    } else if (result == 'profile_setup') {
      final u = auth.user ?? {};
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            onToggleTheme: widget.onToggleTheme,
            googleId: (u['google_id'] ?? '').toString(),
            email: (u['email'] ?? '').toString(),
            displayName: (u['name'] ?? '').toString(),
          ),
        ),
      );
    }
  }

  Future<void> _passwordLogin() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final id = _idCtrl.text.trim();
    if (id.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter your mobile number (or email) and password')));
      return;
    }
    HapticFeedback.mediumImpact();
    final res = await auth.loginWithPassword(id, _passCtrl.text);
    _routeAfterLogin(res);
  }

  InputDecoration _field(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA1AD)),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF8A919D)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E5EA), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold, width: 1.5),
        ),
      );

  // FUNCTION PRESERVED — Google Sign-In + routing.
  Future<void> _googleSignIn() async {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthProvider>();
    final result = await auth.signInWithGoogle();
    if (!mounted) return;

    if (result == 'home') {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) =>
              HomeScreen(onToggleTheme: widget.onToggleTheme),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else if (result == 'profile_setup') {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => ProfileSetupScreen(
            onToggleTheme: widget.onToggleTheme,
            googleId: auth.googleId!,
            email: auth.googleEmail!,
            displayName: auth.googleDisplayName!,
          ),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF7E6), Color(0xFFF6F4EE), Color(0xFFEEF2FA)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // soft decorative circles
            Positioned(
              top: -80,
              right: -60,
              child: _circle(220, const Color(0xFFFFAB00).withOpacity(0.18)),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: _circle(240, const Color(0xFF1A2F55).withOpacity(0.10)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // logo
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6)),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset('assets/images/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                      color: _navy,
                                      child: const Icon(Icons.school,
                                          color: Colors.white, size: 40))),
                            ),
                            const SizedBox(height: 16),
                            Text.rich(
                              TextSpan(children: const [
                                TextSpan(
                                    text: 'Welcome to ',
                                    style: TextStyle(color: _navy)),
                                TextSpan(
                                    text: 'Selection Lab',
                                    style: TextStyle(color: _gold)),
                              ]),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 4),
                            const Text('Sign in to continue your preparation',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14, color: Color(0xFF5C6472))),
                            const SizedBox(height: 22),

                            // white card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.black.withOpacity(0.05)),
                                boxShadow: [
                                  BoxShadow(
                                      color: _navy.withOpacity(0.12),
                                      blurRadius: 34,
                                      offset: const Offset(0, 10)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Google button
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed:
                                          auth.isLoading ? null : _googleSignIn,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(
                                            color: Color(0xFFDCDFE4),
                                            width: 1.5),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      child: auth.isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.black54))
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: const [
                                                _GoogleG(),
                                                SizedBox(width: 10),
                                                Text('Continue with Google',
                                                    style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            Color(0xFF1F1F1F))),
                                              ],
                                            ),
                                    ),
                                  ),

                                  // ── OR ──
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    child: Row(
                                      children: const [
                                        Expanded(child: Divider(color: Color(0xFFE6E8EC), height: 1)),
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 12),
                                          child: Text('OR',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF9AA1AD),
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        Expanded(child: Divider(color: Color(0xFFE6E8EC), height: 1)),
                                      ],
                                    ),
                                  ),

                                  // Mobile/email + password — OTP nahi lagta
                                  TextField(
                                    controller: _idCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.username],
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(
                                        color: Color(0xFF1F1F1F),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600),
                                    decoration: _field('Mobile number or email',
                                        Icons.person_outline_rounded),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _passCtrl,
                                    obscureText: _obscure,
                                    autofillHints: const [AutofillHints.password],
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _passwordLogin(),
                                    style: const TextStyle(
                                        color: Color(0xFF1F1F1F),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600),
                                    decoration: _field(
                                      'Password',
                                      Icons.lock_outline_rounded,
                                      suffix: IconButton(
                                        icon: Icon(
                                            _obscure
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 20,
                                            color: const Color(0xFF8A919D)),
                                        onPressed: () =>
                                            setState(() => _obscure = !_obscure),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed:
                                          auth.isLoading ? null : _passwordLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _gold,
                                        foregroundColor: const Color(0xFF1A1A1A),
                                        disabledBackgroundColor:
                                            _gold.withOpacity(0.5),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 15),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                          auth.isLoading
                                              ? 'Please wait...'
                                              : 'Sign In',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: auth.isLoading
                                          ? null
                                          : () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ForgotPasswordScreen(
                                                    onToggleTheme:
                                                        widget.onToggleTheme,
                                                    initialIdentifier:
                                                        _idCtrl.text.trim(),
                                                  ),
                                                ),
                                              ),
                                      child: const Text('Forgot password?',
                                          style: TextStyle(
                                              color: _navy,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),

                                  const Divider(color: Color(0xFFEEF0F3), height: 20),
                                  const SizedBox(height: 6),
                                  const Text('New to Selection Lab?',
                                      style: TextStyle(
                                          fontSize: 13, color: Color(0xFF5C6472))),
                                  const SizedBox(height: 10),

                                  // Naya account — sirf yahin OTP (SMS ka kharcha)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: auth.isLoading
                                          ? null
                                          : () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PhoneLoginScreen(
                                                    onToggleTheme:
                                                        widget.onToggleTheme,
                                                  ),
                                                ),
                                              );
                                            },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        side: const BorderSide(
                                            color: Color(0xFFD6DAE2),
                                            width: 1.5),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.phone_android_rounded,
                                              size: 20, color: _navy),
                                          SizedBox(width: 10),
                                          Text('Create account with mobile OTP',
                                              style: TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _navy)),
                                        ],
                                      ),
                                    ),
                                  ),

                                  if (auth.error != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFDECEB),
                                        border: Border.all(
                                            color: const Color(0xFFF3C2BE)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(auth.error!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Color(0xFFC0392B),
                                              fontSize: 13)),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),
                            // trust badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                _Badge(icon: '🔒', label: 'Secure & Safe'),
                                SizedBox(width: 22),
                                _Badge(icon: '⚡', label: 'Easy & Fast'),
                                SizedBox(width: 22),
                                _Badge(icon: '🏅', label: 'Trusted by Aspirants'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text.rich(
                              TextSpan(
                                text: 'By continuing, you agree to our\n',
                                style: const TextStyle(
                                    color: Color(0xFF8A919D), fontSize: 12),
                                children: const [
                                  TextSpan(
                                      text: 'Terms of Service',
                                      style: TextStyle(
                                          color: _navy,
                                          fontWeight: FontWeight.w600)),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                          color: _navy,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text('G',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4285F4))),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _gold, width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF5C6472),
                  fontWeight: FontWeight.w600,
                  height: 1.3)),
        ],
      ),
    );
  }
}
