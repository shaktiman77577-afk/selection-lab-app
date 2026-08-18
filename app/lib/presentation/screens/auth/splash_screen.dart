// Splash — sirf logo, aur turant aage.
//
// Pehle yahan "Get Started" button tha jise user ko dabana padta tha, isliye
// app khulne me time lagta tha. Ab logo dikhte hi user load hota hai aur
// seedha home (ya login) khul jati hai — aksar 600ms me.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

const _navy = Color(0xFF1A2F55);
const _navy2 = Color(0xFF2C4A85);
const _gold = Color(0xFFFFAB00);

class SplashScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const SplashScreen({super.key, required this.onToggleTheme});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _c.forward();
    _go();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final auth = context.read<AuthProvider>();

    // User load karna aur minimum dikhne ka time saath-saath chalte hain,
    // isliye jo lamba ho utna hi lagta hai.
    await Future.wait([
      auth.loadUser(),
      Future.delayed(const Duration(milliseconds: 600)),
    ]);

    if (!mounted) return;
    final next = auth.isLoggedIn
        ? HomeScreen(onToggleTheme: widget.onToggleTheme)
        : LoginScreen(onToggleTheme: widget.onToggleTheme);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => next,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_navy, _navy2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo — asset na mile to gold "SL" tile dikh jata hai
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: const Text('SL',
                            style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w900,
                                fontSize: 40)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: 'Selection ',
                          style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'Lab', style: TextStyle(color: _gold)),
                    ]),
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
