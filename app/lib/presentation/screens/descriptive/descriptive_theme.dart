// lib/presentation/screens/descriptive/descriptive_theme.dart
//
// Shared colour tokens + widgets so every Descriptive screen matches the
// website (selectionlab.in) exactly.

import 'package:flutter/material.dart';
import '../checkout/checkout_screen.dart';

// website accent colours
const kDNavy = Color(0xFF1A2F55);
const kDNavy2 = Color(0xFF2C4A85);
const kDGold = Color(0xFFFFAB00);
const kDGreen = Color(0xFF2E8B4A);
const kDPurchasedBg = Color(0x335DD97C); // rgba(93,217,124,0.2)
const kDPurchasedFg = Color(0xFFC8F7D4);

/// Theme-aware neutral tokens (map the website's CSS variables).
class DT {
  final bool dark;
  const DT(this.dark);

  // Exact values from the website theme (layout.tsx :root / [data-theme=dark]).
  Color get bg => dark ? const Color(0xFF0D0B08) : const Color(0xFFF6F4EE);
  Color get card => dark ? const Color(0xFF16130E) : Colors.white;
  Color get text => dark ? Colors.white : const Color(0xFF221C10);
  Color get text2 => dark ? const Color(0xFFCFC6B3) : const Color(0xFF4C4536);
  Color get muted => dark ? const Color(0xFF9A917F) : const Color(0xFF776F5C);
  Color get line =>
      dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.10);
  Color get chip =>
      dark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05);
  Color get border => dark
      ? const Color(0xFFFFAB00).withOpacity(0.25)
      : const Color(0xFFB48200).withOpacity(0.4);

  List<BoxShadow> get shadow => dark
      ? const []
      : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 1))];
}

/// The navy gradient hero with a soft gold circle, exactly like the website.
class DescriptiveHero extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? footer;
  const DescriptiveHero(
      {super.key, required this.title, this.subtitle, this.footer});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
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
                    color: kDGold.withOpacity(0.15)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.3)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13.5,
                            height: 1.6)),
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

/// Gold pill button (the website's `goldBtn`).
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
