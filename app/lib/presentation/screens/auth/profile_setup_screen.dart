// lib/presentation/screens/auth/profile_setup_screen.dart
//
// UI matched to the website (light gradient + white card + gold button),
// same family as the new login screen.
// FUNCTION UNCHANGED — same validation + /users/setup-profile + Home nav.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../home/home_screen.dart';

const _navy = Color(0xFF1A2F55);
const _gold = Color(0xFFFFAB00);

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final String googleId;
  final String email;
  final String displayName;

  const ProfileSetupScreen({
    super.key,
    required this.onToggleTheme,
    required this.googleId,
    required this.email,
    required this.displayName,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
    _nameController.text = widget.displayName;
  }

  @override
  void dispose() {
    _c.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // FUNCTION PRESERVED — same validation + endpoint + navigation.
  Future<void> _submitProfile() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }
    if (_mobileController.text.trim().length != 10) {
      setState(() => _errorMessage = 'Enter a valid 10-digit mobile number');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/users/setup-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'google_id': widget.googleId,
          'email': widget.email,
          'name': _nameController.text.trim(),
          'phone': _mobileController.text.trim(),
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
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
      } else {
        setState(() =>
            _errorMessage = data['detail'] ?? 'Something went wrong. Try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Positioned(
                top: -80,
                right: -60,
                child: _circle(220, _gold.withOpacity(0.18))),
            Positioned(
                bottom: -90,
                left: -70,
                child: _circle(240, _navy.withOpacity(0.10))),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 24),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
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
                                          color: Colors.white, size: 36))),
                            ),
                            const SizedBox(height: 14),
                            Text.rich(
                              TextSpan(children: const [
                                TextSpan(
                                    text: 'Complete your ',
                                    style: TextStyle(color: _navy)),
                                TextSpan(
                                    text: 'Profile',
                                    style: TextStyle(color: _gold)),
                              ]),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 4),
                            const Text('Set up your account to get started',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14, color: Color(0xFF5C6472))),
                            const SizedBox(height: 22),

                            // white form card
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_errorMessage != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFDECEB),
                                        border: Border.all(
                                            color: const Color(0xFFF3C2BE)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(_errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Color(0xFFC0392B),
                                              fontSize: 13)),
                                    ),
                                  ],
                                  _label('Full Name'),
                                  _field(
                                      controller: _nameController,
                                      hint: 'Enter your full name',
                                      icon: Icons.person_outline_rounded),
                                  const SizedBox(height: 16),
                                  _label('Mobile Number'),
                                  _field(
                                    controller: _mobileController,
                                    hint: '10-digit mobile number',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _label('Password'),
                                  _field(
                                    controller: _passwordController,
                                    hint: 'At least 6 characters',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: _obscurePassword,
                                    suffix: IconButton(
                                      icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.black38,
                                          size: 20),
                                      onPressed: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _label('Confirm Password'),
                                  _field(
                                    controller: _confirmController,
                                    hint: 'Re-enter your password',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: _obscureConfirm,
                                    suffix: IconButton(
                                      icon: Icon(
                                          _obscureConfirm
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.black38,
                                          size: 20),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                      'You can use this email & password to login on our website too.',
                                      style: TextStyle(
                                          color: Color(0xFF8A919D),
                                          fontSize: 11,
                                          height: 1.4)),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _submitProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _gold,
                                        foregroundColor: const Color(0xFF1A1A1A),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                  color: Colors.black54,
                                                  strokeWidth: 2.5))
                                          : const Text('Get Started 🚀',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: _navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle:
            const TextStyle(color: Color(0xFF9AA1AD), fontSize: 13),
        prefixIcon: Icon(icon, color: _gold, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E5EA), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold, width: 1.5),
        ),
      ),
    );
  }
}
