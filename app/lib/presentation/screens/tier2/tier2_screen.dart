// lib/presentation/screens/tier2/tier2_screen.dart
//
// Typing/Skill Test ab website ke page se chalta hai (WebView).
// Typing levels, 10-finger drill, Excel, Word/PowerPoint simulators aur
// NBEMS full mocks — sab ek hi jagah (website) maintain hote hain.
//
// Purane native screens (typing_test_screen.dart, excel_hub_screen.dart,
// excel_test_screen.dart) ab kahin se nahi khulte. WebView test ho jaye,
// phir unhe hata denge.

import 'package:flutter/material.dart';

import '../web/site_web_screen.dart';

class Tier2Screen extends StatelessWidget {
  const Tier2Screen({super.key});

  @override
  Widget build(BuildContext context) => const SiteWebScreen(path: '/tier2');
}
