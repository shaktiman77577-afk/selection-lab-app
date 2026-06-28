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
          // ── LIBRARY BACKGROUND ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/library_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ── NIKKI PHOTO — middle, fading at bottom ──
          Positioned(
            top: size.height * 0.16,
            left: 0,
            right: 0,
            height: size.height * 0.50,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.75, 1.0],
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
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.35, 0.75],
                ),
              ),
            ),
          ),

          // ── CONTENT ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Stack(
                  children: [
                    // ── TRUSTED BADGE ──
                    Positioned(
                      top: 12,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
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

                    Column(
                      children: [
                        const SizedBox(height: 20),

                        // ── LOGO golden glow ──
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFAB00).withOpacity(0.5),
                                blurRadius: 35,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: const Color(0xFFFFAB00).withOpacity(0.25),
                                blurRadius: 70,
                                spreadRadius: 12,
                              ),
                            ],
                          ),
                          child: Image.asset('assets/images/logo.png'),
                        ),

                        const SizedBox(height: 12),

                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'WELCOME ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              TextSpan(
                                text: 'BACK!',
                                style: TextStyle(
                                  color: Color(0xFFFFAB00),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Sign in to continue your\nlearning journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),

                        const Spacer(),

                        // ── BOTTOM CARD ──
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          padding:
                              const EdgeInsets.fromLTRB(24, 22, 24, 22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D0D).withOpacity(0.94),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  const Color(0xFFFFAB00).withOpacity(0.25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.7),
                                blurRadius: 40,
                                offset: const Offset(0, -8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Sign in with',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 16),

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
                                height: 56,
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
                                              width: 24,
                                              height: 24,
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'G',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color: Color(0xFF4285F4),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Continue with Google',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              Row(
                                children: [
                                  Expanded(
                                      child: Container(
                                          height: 1,
                                          color: Colors.white12)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text('OR',
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            letterSpacing: 1)),
                                  ),
                                  Expanded(
                                      child: Container(
                                          height: 1,
                                          color: Colors.white12)),
                                ],
                              ),

                              const SizedBox(height: 18),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: const [
                                  _Feature(
                                      icon: Icons.shield_outlined,
                                      label: 'Secure\n& Safe'),
                                  _Feature(
                                      icon: Icons.groups_outlined,
                                      label: 'Easy\n& Fast'),
                                  _Feature(
                                      icon: Icons.workspace_premium_outlined,
                                      label: 'Trusted by\nAspirants'),
                                ],
                              ),

                              const SizedBox(height: 18),

                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  text: 'By continuing, you agree to our\n',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 11),
                                  children: const [
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: TextStyle(
                                          color: Color(0xFFFFAB00),
                                          fontSize: 11),
                                    ),
                                    TextSpan(
                                      text: ' and ',
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11),
                                    ),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                          color: Color(0xFFFFAB00),
                                          fontSize: 11),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFFFFAB00).withOpacity(0.5), width: 1.5),
          ),
          child: Icon(icon, color: const Color(0xFFFFAB00), size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
