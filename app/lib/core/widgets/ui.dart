// lib/core/widgets/ui.dart
//
// Redesign (Sep 2026) ke common widgets — har naya screen inhi se bane,
// taaki poora app ek jaisa dikhe. Rang DT (descriptive_theme.dart) se.

import 'package:flutter/material.dart';

import '../../presentation/screens/descriptive/descriptive_theme.dart';

DT dtOf(BuildContext context) =>
    DT(Theme.of(context).brightness == Brightness.dark);

/// Section ka heading + "View all"
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final EdgeInsets padding;
  const SectionHeader(this.title,
      {super.key,
      this.onViewAll,
      this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 10)});

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: t.text)),
          ),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Text('View all',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.primary)),
            ),
        ],
      ),
    );
  }
}

/// Safed card, patli border, tap par ripple
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;
  final double radius;
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final r = BorderRadius.circular(radius);
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
          borderRadius: r, side: BorderSide(color: borderColor ?? t.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Navy button (dark mode me halka neela)
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool expanded;
  final bool loading;
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onTap,
    this.icon,
    this.expanded = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label),
            ],
          );
    final btn = ElevatedButton(
        onPressed: loading ? null : onTap, child: child);
    return expanded ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Chhota rangeen tag — FREE, LIVE, ENROLLED, level wagairah
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const Tag(this.text, {super.key, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(
              color: filled ? Colors.white : color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3)),
    );
  }
}

/// Khaali list / error ke liye
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.text,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: t.muted.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.muted, fontSize: 14, height: 1.5)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              PrimaryButton(actionLabel!, onTap: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
