import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

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

  void _getStarted() {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthProvider>();
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // ── LIBRARY BACKGROUND ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/library_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ── NIKKI PHOTO — bottom anchored ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.52,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white, Colors.white],
                stops: [0.0, 0.25, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/images/nikki_maam.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),

          // ── DARK OVERLAY ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.45),
                    Colors.black.withOpacity(0.75),
                    Colors.black.withOpacity(0.95),
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // ── CONTENT ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: AnimatedBuilder(
                animation: _slideAnim,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: child,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // ── LOGO golden glow ──
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFAB00).withOpacity(0.55),
                            blurRadius: 38,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFAB00).withOpacity(0.28),
                            blurRadius: 75,
                            spreadRadius: 14,
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/logo.png'),
                    ),

                    const SizedBox(height: 14),

                    // ── SELECTION LAB ──
                    const Text(
                      'SELECTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        height: 1.0,
                      ),
                    ),
                    const Text(
                      'LAB',
                      style: TextStyle(
                        color: Color(0xFFFFAB00),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        height: 1.1,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── TAGLINE ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('LEARN',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 1.5)),
                        _Dot(),
                        Text('PRACTICE',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 1.5)),
                        _Dot(),
                        Text('SUCCEED',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 1.5)),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFAB00),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    const Spacer(),

                    // ── FEATURES LIST ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
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
                    ),

                    const SizedBox(height: 18),

                    // ── GET STARTED BUTTON ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: _getStarted,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFAB00), Color(0xFFFF8E00)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFFFFAB00).withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'GET STARTED',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    RichText(
                      text: TextSpan(
                        text: 'Step closer to your ',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13),
                        children: const [
                          TextSpan(
                            text: 'dream job',
                            style: TextStyle(
                                color: Color(0xFFFFAB00),
                                fontWeight: FontWeight.w700),
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
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
          color: Color(0xFFFFAB00), shape: BoxShape.circle),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFAB00).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFFFAB00).withOpacity(0.5), width: 1.5),
            ),
            child: Icon(icon, color: const Color(0xFFFFAB00), size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
