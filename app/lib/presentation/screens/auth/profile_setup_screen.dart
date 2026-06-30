import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../home/home_screen.dart';

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
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
    _nameController.text = widget.displayName;
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    // Validation
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

    setState(() { _isLoading = true; _errorMessage = null; });
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
            pageBuilder: (_, a, __) => HomeScreen(onToggleTheme: widget.onToggleTheme),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        setState(() => _errorMessage = data['detail'] ?? 'Something went wrong. Try again.');
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
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Logo
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 24, spreadRadius: 4)],
                        ),
                        child: Image.asset('assets/images/logo.png'),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(children: [
                          TextSpan(text: 'COMPLETE YOUR\n', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          TextSpan(text: 'PROFILE', style: TextStyle(color: Color(0xFFFFAB00), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Text('Set up your account to get started', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                      const SizedBox(height: 28),

                      // Form card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414).withOpacity(0.97),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFFAB00).withOpacity(0.2)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
                              ),
                            ],

                            _label('Full Name'),
                            _field(controller: _nameController, hint: 'Enter your full name', icon: Icons.person_outline_rounded),
                            const SizedBox(height: 16),

                            _label('Mobile Number'),
                            _field(
                              controller: _mobileController,
                              hint: '10-digit mobile number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                            const SizedBox(height: 16),

                            _label('Password'),
                            _field(
                              controller: _passwordController,
                              hint: 'At least 6 characters',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
                              suffix: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white38, size: 20),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white38, size: 20),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text('You can use this email & password to login on our website too.',
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4)),
                            const SizedBox(height: 24),

                            // Submit button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFAB00),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 2.5))
                                    : const Text('GET STARTED 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFFFAB00), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
        ),
      ),
    );
  }
}

// Dot pattern background
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03);
    const spacing = 28.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
