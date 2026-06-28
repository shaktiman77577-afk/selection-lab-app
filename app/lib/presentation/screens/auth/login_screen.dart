import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const LoginScreen({super.key, required this.onToggleTheme});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [

          // ── BACKGROUND DOT PATTERN ──
          Positioned.fill(
            child: CustomPaint(painter: _DotPatternPainter()),
          ),

          // ── NIKKI MA'AM PHOTO — centered ──
          Positioned(
            top: size.height * 0.22,
            left: 0,
            right: 0,
            height: size.height * 0.42,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.55, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/images/nikki_maam.png',
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          // ── SIDE FADES ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF0A0A0A),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xFF0A0A0A),
                  ],
                  stops: [0.0, 0.2, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // ── MAIN CONTENT ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Stack(
                  children: [

                    // ── "Trusted by Aspirants" badge — absolute top right ──
                    Positioned(
                      top: 12,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFFAB00).withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified_outlined,
                                color: Color(0xFFFFAB00), size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Trusted by\nAspirants',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── COLUMN CONTENT ──
                    Column(
                      children: [

                        const SizedBox(height: 16),

                        // ── LOGO with white glow ──
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.2),
                                blurRadius: 30,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.08),
                                blurRadius: 60,
                                spreadRadius: 14,
                              ),
                            ],
                          ),
                          child: Image.asset('assets/images/logo.png'),
                        ),

                        const SizedBox(height: 12),

                        // ── WELCOME BACK ──
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'WELCOME ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              TextSpan(
                                text: 'BACK!',
                                style: TextStyle(
                                  color: Color(0xFFFFAB00),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Sign in to continue your learning journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),

                        const Spacer(),

                        // ── BOTTOM CARD ──
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          padding:
                              const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414).withOpacity(0.97),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  const Color(0xFFFFAB00).withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 40,
                                offset: const Offset(0, -8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [

                              // "Sign in with" label
                              Text(
                                'Sign in with',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 13,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ── ERROR MESSAGE ──
                              if (auth.error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  margin:
                                      const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                        color:
                                            Colors.red.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    auth.error!,
                                    style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],

                              // ── GOOGLE BUTTON ──
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : _googleSignIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.black54,
                                              strokeWidth: 2.5),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration:
                                                  const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'G',
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blue.shade600,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Continue with Google',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ── OR DIVIDER ──
                              Row(
                                children: [
                                  Expanded(
                                      child: Container(
                                          height: 1,
                                          color: Colors.white12)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                          letterSpacing: 1),
                                    ),
                                  ),
                                  Expanded(
                                      child: Container(
                                          height: 1,
                                          color: Colors.white12)),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // ── TRUST BADGES ──
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _Feature(
                                      icon: Icons.security_rounded,
                                      label: 'Secure\n& Safe'),
                                  _divider(),
                                  _Feature(
                                      icon: Icons.person_outline_rounded,
                                      label: 'Easy\n& Fast'),
                                  _divider(),
                                  _Feature(
                                      icon: Icons.verified_rounded,
                                      label: 'Trusted by\nAspirants'),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // ── TERMS ──
                              RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  text: 'By continuing, you agree to our\n',
                                  style: TextStyle(
                                      color: Colors.white30, fontSize: 10),
                                  children: [
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: TextStyle(
                                          color: Color(0xFFFFAB00),
                                          fontSize: 10),
                                    ),
                                    TextSpan(
                                      text: ' and ',
                                      style: TextStyle(
                                          color: Colors.white30,
                                          fontSize: 10),
                                    ),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                          color: Color(0xFFFFAB00),
                                          fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: Colors.white12);
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFAB00).withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFFFFAB00).withOpacity(0.35)),
          ),
          child: Icon(icon, color: const Color(0xFFFFAB00), size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
          color: Colors.white54, fontSize: 10, height: 1.3),
        ),
      ],
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
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
