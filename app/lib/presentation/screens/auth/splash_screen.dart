import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const SplashScreen({super.key, required this.onToggleTheme});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOut)),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => auth.isLoggedIn
            ? HomeScreen(onToggleTheme: widget.onToggleTheme)
            : LoginScreen(onToggleTheme: widget.onToggleTheme),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background dot pattern
          Positioned.fill(
            child: CustomPaint(painter: _DotPatternPainter()),
          ),

          // Decorative icons top corners
          Positioned(
            top: 48, left: 24,
            child: Icon(Icons.school_outlined, color: Colors.white.withOpacity(0.08), size: 48),
          ),
          Positioned(
            top: 36, right: 32,
            child: Icon(Icons.menu_book_outlined, color: Colors.white.withOpacity(0.08), size: 44),
          ),
          Positioned(
            top: 110, right: 16,
            child: Icon(Icons.emoji_events_outlined, color: Colors.white.withOpacity(0.06), size: 36),
          ),

          // Main content
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
                    const SizedBox(height: 40),

                    // Logo with golden glow
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFAB00).withOpacity(0.6),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFAB00).withOpacity(0.3),
                            blurRadius: 80,
                            spreadRadius: 16,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 130,
                        height: 130,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SELECTION LAB text
                    const Text(
                      'SELECTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        height: 1.1,
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

                    const SizedBox(height: 10),

                    // Tagline
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dot(),
                        const Text(' LEARN ', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.5)),
                        _dot(),
                        const Text(' PRACTICE ', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.5)),
                        _dot(),
                        const Text(' SUCCEED ', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.5)),
                        _dot(),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Gold underline
                    Container(
                      width: 60,
                      height: 2,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFAB00),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Nikki Ma'am photo — below text, not overlapping
                    Expanded(
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Decorative side icons
                          Positioned(
                            left: 20,
                            top: 20,
                            child: Icon(Icons.assignment_outlined, color: Colors.white.withOpacity(0.07), size: 52),
                          ),
                          Positioned(
                            right: 20,
                            top: 30,
                            child: Icon(Icons.emoji_events_outlined, color: Colors.white.withOpacity(0.07), size: 48),
                          ),

                          // Photo with bottom fade
                          ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Colors.white, Colors.transparent],
                              stops: [0.0, 0.65, 1.0],
                            ).createShader(rect),
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              'assets/images/nikki_maam.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Feature list
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          _featureRow(Icons.menu_book_outlined, 'EXPERT GUIDANCE', 'Learn from the best'),
                          const SizedBox(height: 12),
                          _featureRow(Icons.assignment_turned_in_outlined, 'PRACTICE TESTS', 'Mock tests & PYQs'),
                          const SizedBox(height: 12),
                          _featureRow(Icons.track_changes_outlined, 'SMART ANALYSIS', 'Track your progress'),
                          const SizedBox(height: 12),
                          _featureRow(Icons.verified_outlined, 'TRUSTED BY ASPIRANTS', 'Your success, our mission'),
                        ],
                      ),
                    ),

                    // GET STARTED button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(onToggleTheme: widget.onToggleTheme),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFAB00), Color(0xFFFF6B00)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFAB00).withOpacity(0.4),
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

                    // Footer
                    RichText(
                      text: const TextSpan(
                        text: 'Step closer to your ',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'dream job',
                            style: TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(
    width: 5, height: 5,
    decoration: const BoxDecoration(color: Color(0xFFFFAB00), shape: BoxShape.circle),
  );

  Widget _featureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFAB00).withOpacity(0.5), width: 1.5),
          ),
          child: Icon(icon, color: const Color(0xFFFFAB00), size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

// Dot pattern background painter
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) => false;
}
