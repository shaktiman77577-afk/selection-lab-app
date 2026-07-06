import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'data/providers/auth_provider.dart';
import 'presentation/screens/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── ERROR DISPLAY: shows actual error on screen instead of grey/black ──
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF8B0000),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⚠️ ERROR', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('${details.exception}', style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 16),
              const Text('STACK TRACE:', style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${details.stack}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  };

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp();
  runApp(const SelectionLabApp());
}

class SelectionLabApp extends StatefulWidget {
  const SelectionLabApp({super.key});

  @override
  State<SelectionLabApp> createState() => _SelectionLabAppState();
}

class _SelectionLabAppState extends State<SelectionLabApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(AppConstants.themeKey) ?? false;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final willBeDark = _themeMode != ThemeMode.dark; // flip current
    setState(() => _themeMode = willBeDark ? ThemeMode.dark : ThemeMode.light);
    await prefs.setBool(AppConstants.themeKey, willBeDark); // persist choice
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadUser()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        home: SplashScreen(onToggleTheme: toggleTheme),
      ),
    );
  }
}
