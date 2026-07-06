// lib/presentation/screens/auth/splash_screen.dart
//
// Redesigned to match the app's new website-style branding (light cream
// gradient, navy + gold). No dependency on background photos (no missing-asset
// risk). FUNCTION UNCHANGED — same _getStarted auth check + navigation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

const _navy = Color(0xFF1A2F55);
const _gold = Color(0xFFFFAB00);

class SplashScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const SplashScreen({super.key, required this.onToggleTheme});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 0.9, curve: Curves.easeOut)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // FUNCTION UNCHANGED
  Future<void> _getStarted() async {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthProvider>();
    await auth.loadUser();
    if (!mounted) return;
    final nextScreen = auth.isLoggedIn
        ? HomeScreen(onToggleTheme: widget.onToggleTheme)
        : LoginScreen(onToggleTheme: widget.onToggleTheme);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => nextScreen,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
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
              child: FadeTransition(
                opacity: _fadeAnim,
                child: AnimatedBuilder(
                  animation: _slideAnim,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: child,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        // logo with soft gold glow
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: _gold.withOpacity(0.35),
                                  blurRadius: 40,
                                  spreadRadius: 4),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset('assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                  color: _navy,
                                  child: const Icon(Icons.school,
                                      color: Colors.white, size: 50))),
                        ),
                        const SizedBox(height: 18),
                        // SELECTION LAB
                        Text.rich(
                          TextSpan(children: const [
                            TextSpan(
                                text: 'SELECTION ',
                                style: TextStyle(color: _navy)),
                            TextSpan(text: 'LAB', style: TextStyle(color: _gold)),
                          ]),
                          style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2),
                        ),
                        const SizedBox(height: 10),
                        // tagline
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _Tag('LEARN'),
                            _Dot(),
                            _Tag('PRACTICE'),
                            _Dot(),
                            _Tag('SUCCEED'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 60,
                          height: 3,
                          decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        const Spacer(flex: 1),
                        // features
                        Column(
                          children: const [
                            _FeatureRow(
                                icon: Icons.menu_book_outlined,
                                title: 'EXPERT GUIDANCE',
                                subtitle: 'Learn from the best'),
                            SizedBox(height: 10),
                            _FeatureRow(
                                icon: Icons.assignment_turned_in_outlined,
                                title: 'PRACTICE TESTS',
                                subtitle: 'Mock tests & PYQs'),
                            SizedBox(height: 10),
                            _FeatureRow(
                                icon: Icons.track_changes_outlined,
                                title: 'SMART ANALYSIS',
                                subtitle: 'Track your progress'),
                            SizedBox(height: 10),
                            _FeatureRow(
                                icon: Icons.shield_outlined,
                                title: 'TRUSTED BY ASPIRANTS',
                                subtitle: 'Your success, our mission'),
                          ],
                        ),
                        const Spacer(flex: 1),
                        // GET STARTED
                        GestureDetector(
                          onTap: _getStarted,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: _gold.withOpacity(0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: const Center(
                              child: Text('GET STARTED',
                                  style: TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text.rich(
                          TextSpan(
                            text: 'Step closer to your ',
                            style: const TextStyle(
                                color: Color(0xFF5C6472), fontSize: 13),
                            children: const [
                              TextSpan(
                                  text: 'dream job',
                                  style: TextStyle(
                                      color: _navy,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        const Spacer(flex: 1),
                      ],
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

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFF5C6472),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
              color: _navy.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withOpacity(0.12),
              border: Border.all(color: _gold.withOpacity(0.5), width: 1.5),
            ),
            child: Icon(icon, color: _gold, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: _navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xFF776F5C), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
