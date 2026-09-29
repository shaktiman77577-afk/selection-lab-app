// lib/presentation/screens/descriptive/descriptive_theme.dart
//
// Shared colour tokens + widgets. Poora app inhi tokens se rang leta hai.
//
// Redesign (Sep 2026): Testbook jaisa clean — halka grey background, safed
// card, patli border, shadow nahi. Pehle ye website ke beige/brown rang the.
// Navy aur gold waise hi hain (brand).

import 'package:flutter/material.dart';
import '../checkout/checkout_screen.dart';

// brand accent colours
const kDNavy = Color(0xFF1A2F55);
const kDNavy2 = Color(0xFF2C4A85);
const kDGold = Color(0xFFFFAB00);
const kDGreen = Color(0xFF2E8B4A);
const kDPurchasedBg = Color(0x335DD97C); // rgba(93,217,124,0.2)
const kDPurchasedFg = Color(0xFFC8F7D4);

/// Theme-aware neutral tokens.
class DT {
  final bool dark;
  const DT(this.dark);

  Color get bg => dark ? const Color(0xFF0F1115) : const Color(0xFFF5F6FA);
  Color get card => dark ? const Color(0xFF181B22) : Colors.white;
  Color get text => dark ? Colors.white : const Color(0xFF1B2331);
  Color get text2 => dark ? const Color(0xFFC9CED8) : const Color(0xFF3D4656);
  Color get muted => dark ? const Color(0xFF8C93A3) : const Color(0xFF6B7385);
  Color get line =>
      dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08);
  Color get chip =>
      dark ? Colors.white.withOpacity(0.07) : const Color(0xFFEEF0F5);
  /// Khule (unlocked) item ki border — halka navy
  Color get border => dark
      ? const Color(0xFF7C9BE0).withOpacity(0.30)
      : kDNavy.withOpacity(0.22);
  /// Link / primary rang — dark me navy dikhta nahi, isliye halka neela
  Color get primary => dark ? const Color(0xFF7C9BE0) : kDNavy;

  /// Clean look: shadow nahi, sirf border
  List<BoxShadow> get shadow => const [];
}

/// The navy gradient hero with a soft gold circle.
class DescriptiveHero extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? footer;
  const DescriptiveHero(
      {super.key, required this.title, this.subtitle, this.footer});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kDNavy, kDNavy2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kDGold.withOpacity(0.12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.3)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13.5,
                            height: 1.55)),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: 14),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gold pill button — navy hero ke upar CTA ke liye.
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double fontSize;
  const GoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: onTap == null ? kDGold.withOpacity(0.6) : kDGold,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w800,
                fontSize: fontSize)),
      ),
    );
  }
}
