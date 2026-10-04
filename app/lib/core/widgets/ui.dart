// lib/core/widgets/ui.dart
//
// Redesign (Sep 2026) ke common widgets — har naya screen inhi se bane,
// taaki poora app ek jaisa dikhe. Rang DT (descriptive_theme.dart) se.

import 'package:flutter/material.dart';

import '../../presentation/screens/descriptive/descriptive_theme.dart';
import '../shop.dart';

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

/// List screens ka ek jaisa card — course, mock series, descriptive series.
/// Bayen poster, dayen naam, chhoti jaankari, daam / ENROLLED.
class ProductCard extends StatelessWidget {
  final String img;
  final String title;
  final String meta;
  final num price;
  final num original;
  final bool owned;
  final IconData fallbackIcon;
  final String? highlight; // jaise "2 free tests" — hara
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.img,
    required this.title,
    required this.meta,
    required this.price,
    required this.original,
    required this.owned,
    required this.fallbackIcon,
    required this.onTap,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final shop = context.shopOn;
    final free = price <= 0;
    final off = (!free && original > price)
        ? ((1 - price / original) * 100).round()
        : 0;

    Widget fallback() => Container(
        color: t.chip, child: Icon(fallbackIcon, color: t.muted, size: 30));

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 96,
              height: 96,
              child: img.isEmpty
                  ? fallback()
                  : Container(
                      color: t.chip,
                      child: Image.network(img,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => fallback()),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            // Fixed height nahi, sirf minimum - title 2 line + free tests + lock
            // aane par card apne aap badhta hai (pehle 16px overflow hota tha)
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: t.text)),
                  const SizedBox(height: 4),
                  if (meta.isNotEmpty)
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.muted)),
                  if (highlight != null && !owned) ...[
                    const SizedBox(height: 2),
                    Text(highlight!,
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kDGreen)),
                  ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (owned)
                        const Tag('ENROLLED', color: kDGreen)
                      else if (free)
                        const Text('FREE',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: kDGreen))
                      else if (!shop)
                        // Purchase band: price nahi, sirf lock
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.lock_rounded, size: 15, color: t.muted),
                          const SizedBox(width: 5),
                          Text('Locked',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: t.muted)),
                        ])
                      else ...[
                        Text('₹${price.toInt()}',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: t.text)),
                        if (off > 0) ...[
                          const SizedBox(width: 6),
                          Text('₹${original.toInt()}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: t.muted,
                                  decoration: TextDecoration.lineThrough)),
                          const SizedBox(width: 6),
                          Tag('$off% OFF', color: const Color(0xFFB47F00)),
                        ],
                      ],
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, color: t.muted),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Upar ke filter chips — All / Enrolled / Free
class FilterChips extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  const FilterChips(
      {super.key,
      required this.options,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final on = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? t.primary : t.card,
                border: Border.all(color: on ? t.primary : t.line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(options[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: on
                          ? (t.dark ? const Color(0xFF0F1115) : Colors.white)
                          : t.text2)),
            ),
          );
        },
      ),
    );
  }
}

/// Loading / error / khaali — list screens ka common hissa
class ListStateView extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool empty;
  final String emptyText;
  final IconData emptyIcon;
  final VoidCallback onRetry;
  const ListStateView({
    super.key,
    required this.loading,
    required this.error,
    required this.empty,
    required this.emptyText,
    required this.emptyIcon,
    required this.onRetry,
  });

  /// true ho to list ki jagah ye dikhao
  bool get show => loading || error != null || empty;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return EmptyState(
          icon: Icons.wifi_off_rounded,
          text: error!,
          actionLabel: 'Retry',
          onAction: onRetry);
    }
    return EmptyState(icon: emptyIcon, text: emptyText);
  }
}
