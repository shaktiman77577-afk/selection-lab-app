// lib/presentation/screens/auth/email_login_screen.dart
//
// Phone + password LOGIN (sirf login — naye user Google/OTP se aate hain).
// Play Store reviewers isi se test credentials se login karte hain.
//
// Redesign (Sep 2026): theme ke rang (navy button, clean inputs). Logic same.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import '../home/home_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const EmailLoginScreen({super.key, required this.onToggleTheme});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  bool _obscure = true;
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _login() async {
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

    final ok = await auth.login(phone, pass);
    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(onToggleTheme: widget.onToggleTheme),
        ),
      );
    } else {
      _snack(auth.error ?? 'Invalid phone or password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        shape: const Border(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/logo.png',
                      width: 76, height: 76),
                ),
              ),
              const SizedBox(height: 20),
              Text('Welcome back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w800, color: t.text)),
              const SizedBox(height: 6),
              Text('Log in to continue your preparation',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: t.muted)),
              const SizedBox(height: 28),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: TextStyle(color: t.text, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Phone number',
                  prefixIcon:
                      Icon(Icons.phone_outlined, size: 20, color: t.muted),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: TextStyle(color: t.text, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon:
                      Icon(Icons.lock_outline_rounded, size: 20, color: t.muted),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: t.muted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton('Log in',
                  onTap: _login, loading: auth.isLoading, expanded: true),
              const SizedBox(height: 20),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: t.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'New user? Go back and '),
                          TextSpan(
                              text: 'sign up with Google or Mobile OTP',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: t.primary)),
                          const TextSpan(text: '.'),
                        ]),
                        style: TextStyle(fontSize: 13, color: t.text2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
