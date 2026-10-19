// lib/core/secure_screen.dart
//
// Paid content wali screen par screenshot / screen recording band (Oct 2026).
// Android ka FLAG_SECURE — recording me ye screen kaali aati hai.
//
// Use:  initState me SecureScreen.enter(),  dispose me SecureScreen.exit().
// Ginti rakhte hain — video ke upar PDF khuli ho aur ek band ho, to doosri
// screen khuli rehte hue flag nahi hatta.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SecureScreen {
  static const _ch = MethodChannel('selectionlab/secure');
  static int _open = 0;

  static Future<void> _set(bool on) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    try {
      await _ch.invokeMethod('setSecure', {'on': on});
    } catch (_) {
      // Purane build / koi aur platform — chupchap chhod do
    }
  }

  static void enter() {
    _open++;
    if (_open == 1) _set(true);
  }

  static void exit() {
    if (_open == 0) return;
    _open--;
    if (_open == 0) _set(false);
  }
}

/// Kisi bhi screen ko lapet do — jab tak ye dikhe, screenshot band.
/// (StatelessWidget screens ke liye aasan tareeka.)
class SecureArea extends StatefulWidget {
  final Widget child;
  const SecureArea({super.key, required this.child});

  @override
  State<SecureArea> createState() => _SecureAreaState();
}

class _SecureAreaState extends State<SecureArea> {
  @override
  void initState() {
    super.initState();
    SecureScreen.enter();
  }

  @override
  void dispose() {
    SecureScreen.exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
