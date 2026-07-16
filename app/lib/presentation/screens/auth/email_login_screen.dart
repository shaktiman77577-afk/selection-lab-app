import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'profile_setup_screen.dart';

/// Phone + password login / register screen.
/// Complements Google Sign-In (needed so Play Store reviewers can log in
/// with test credentials).
class EmailLoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const EmailLoginScreen({super.key, required this.onToggleTheme});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  bool _isRegister = false;
  bool _obscure = true;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthProvider>();
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text;

    if (phone.isEmpty || pass.isEmpty) {
      _snack('Please enter phone and password.');
      return;
    }
    if (phone.length < 10) {
      _snack('Please enter a valid 10-digit phone number.');
      return;
    }
    if (pass.length < 4) {
      _snack('Password must be at least 4 characters.');
      return;
    }

    bool ok;
    if (_isRegister) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        _snack('Please enter your name.');
        return;
      }
      ok = await auth.register(name, phone, pass,
          referralCode: _refCtrl.text.trim());
    } else {
      ok = await auth.login(phone, pass);
    }

    if (!mounted) return;

    if (ok) {
      final completed = auth.user?['profile_completed'] == true;
      if (_isRegister || !completed) {
        // New users go to profile setup; if that screen needs Google fields,
        // send phone-based users straight home instead.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HomeScreen(onToggleTheme: widget.onToggleTheme),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HomeScreen(onToggleTheme: widget.onToggleTheme),
          ),
        );
      }
    } else {
      _snack(auth.error ?? 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFFF8EC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
            IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset('assets/images/logo.png',
                    width: 84, height: 84),
              ),
              const SizedBox(height: 20),
              Text(_isRegister ? 'Create Account' : 'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 6),
              Text(
                  _isRegister
                      ? 'Sign up to start your preparation'
                      : 'Log in to continue your preparation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(height: 28),

              if (_isRegister) ...[
                _field(isDark,
                    controller: _nameCtrl,
                    hint: 'Full Name',
                    icon: Icons.person_outline_rounded),
                const SizedBox(height: 14),
              ],

              _field(isDark,
                  controller: _phoneCtrl,
                  hint: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 10),
              const SizedBox(height: 14),

              _field(isDark,
                  controller: _passCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.black38),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )),

              if (_isRegister) ...[
                const SizedBox(height: 14),
                _field(isDark,
                    controller: _refCtrl,
                    hint: 'Referral Code (optional)',
                    icon: Icons.card_giftcard_rounded),
              ],

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF1A1A1A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Color(0xFF1A1A1A)))
                      : Text(_isRegister ? 'Sign Up' : 'Log In',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      _isRegister
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white54 : Colors.black54)),
                  GestureDetector(
                    onTap: () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister ? 'Log In' : 'Sign Up',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(bool isDark,
      {required TextEditingController controller,
      required String hint,
      required IconData icon,
      bool obscure = false,
      TextInputType? keyboardType,
      int? maxLength,
      Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white24 : Colors.black.withOpacity(0.12)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          counterText: '',
          prefixIcon: Icon(icon,
              size: 20, color: isDark ? Colors.white38 : Colors.black38),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontWeight: FontWeight.w500),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        ),
      ),
    );
  }
}
