// lib/presentation/screens/live/live_classes_screen.dart
//
// Redesign (Sep 2026): clean cards (DT tokens + ui.dart). Logic waisa hi:
// live ho aur access ho to Join, enrolled ho to "link 10 min pehle",
// warna Enroll → checkout (live par coupon nahi).
// Purchase band (admin switch) ho to Enroll/price nahi, sirf lock.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/shop.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import '../checkout/checkout_screen.dart';
import '../descriptive/descriptive_theme.dart';

class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key});

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _batches = [];
  bool _loading = true;
  String? _error;

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(dynamic d, String key) {
    final l = d is Map ? d[key] : null;
    if (l is! List) return [];
    return l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _classes.isEmpty && _batches.isEmpty;
      _error = null;
    });
    final uid = _uid;
    final q = uid != null ? '?user_id=$uid' : '';
    try {
      final r = await Future.wait([
        http
            .get(Uri.parse('${AppConstants.apiUrl}/live/classes$q'))
            .timeout(const Duration(seconds: 12)),
        http
            .get(Uri.parse('${AppConstants.apiUrl}/live/batches$q'))
            .timeout(const Duration(seconds: 12)),
      ]);
      if (!mounted) return;
      setState(() {
        _classes = r[0].statusCode == 200
            ? _list(jsonDecode(r[0].body), 'classes')
            : [];
        _batches = r[1].statusCode == 200
            ? _list(jsonDecode(r[1].body), 'batches')
            : [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load live classes. Check your internet.';
        _loading = false;
      });
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _join(String url) async {
    HapticFeedback.mediumImpact();
    try {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok) _snack('Could not open the meeting link.');
    } catch (_) {
      _snack('Could not open the meeting link.');
    }
  }

  Future<void> _buy(Map<String, dynamic> item, String kind) async {
    if (!context.shopOnRead) {
      _snack(kNotInAppMsg); // purchase band hai
      return;
    }
    if (_uid == null) {
      _snack('Please log in to continue.');
      return;
    }
    final id = item['id'] is int ? item['id'] as int : int.tryParse('${item['id']}');
    if (id == null) return;
    final price = _num(item['price']);
    final orig = _num(item['original_price']);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          productType: kind == 'batch' ? 'live_batch' : 'live_class',
          productId: id,
          title: item['title']?.toString() ?? 'Live Class',
          price: price,
          originalPrice: orig > price ? orig : price,
          onSuccess: () {},
        ),
      ),
    );
    if (result == true && mounted) {
      _snack('Enrolled! You can join when the class starts.');
      _load();
    }
  }

  num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

  DateTime? _startOf(Map<String, dynamic> c) {
    try {
      return DateTime.parse(c['scheduled_at'].toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _whenLabel(DateTime t) {
    final now = DateTime.now();
    final diff = t.difference(now);
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (diff.isNegative && diff.inMinutes > -120) return 'Live now · started $time';
    if (!diff.isNegative && diff.inMinutes < 60) {
      return 'Starts in ${diff.inMinutes} min';
    }
    bool same(DateTime a) =>
        a.year == t.year && a.month == t.month && a.day == t.day;
    if (same(now)) return 'Today · $time';
    if (same(now.add(const Duration(days: 1)))) return 'Tomorrow · $time';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${t.day} ${months[t.month - 1]} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final state = ListStateView(
      loading: _loading,
      error: _error,
      empty: _classes.isEmpty && _batches.isEmpty,
      emptyText:
          'No live classes yet.\nLive doubt sessions and classes will appear here.',
      emptyIcon: Icons.videocam_outlined,
      onRetry: _load,
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Live Classes')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(top: 14, bottom: 32),
          children: [
            if (state.show)
              state
            else ...[
              if (_classes.isNotEmpty) ...[
                const SectionHeader('Upcoming classes'),
                for (final c in _classes)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _classCard(t, c),
                  ),
                const SizedBox(height: 12),
              ],
              if (_batches.isNotEmpty) ...[
                const SectionHeader('Live batches'),
                for (final b in _batches)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _batchCard(t, b),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _classCard(DT t, Map<String, dynamic> c) {
    final start = _startOf(c);
    final isFree = c['is_free'] == true;
    final unlocked = c['is_unlocked'] == true;
    final liveNow = c['can_join'] == true;
    final faculty = '${c['faculty'] ?? ''}';

    return AppCard(
      borderColor: liveNow ? Colors.red.withOpacity(0.55) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (liveNow || isFree || (unlocked && !isFree))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(spacing: 6, children: [
                if (liveNow) const Tag('● LIVE', color: Colors.red, filled: true),
                if (isFree) const Tag('FREE', color: kDGreen),
                if (unlocked && !isFree) const Tag('ENROLLED', color: kDGreen),
              ]),
            ),
          Text('${c['title'] ?? ''}',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: t.text)),
          if (faculty.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(faculty, style: TextStyle(fontSize: 12.5, color: t.muted)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: t.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(start != null ? _whenLabel(start) : '',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: liveNow ? Colors.red : t.text2)),
              ),
              Text('${c['duration_min'] ?? 60} min',
                  style: TextStyle(fontSize: 12, color: t.muted)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _classButton(t, c, unlocked, liveNow),
          ),
        ],
      ),
    );
  }

  Widget _classButton(
      DT t, Map<String, dynamic> c, bool unlocked, bool liveNow) {
    if (liveNow && c['meet_url'] != null) {
      return ElevatedButton.icon(
        onPressed: () => _join(c['meet_url'].toString()),
        icon: const Icon(Icons.videocam_rounded, size: 18),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red, foregroundColor: Colors.white),
        label: const Text('Join live class'),
      );
    }
    if (unlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kDGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Enrolled · link opens 10 min before',
            style: TextStyle(
                color: kDGreen, fontWeight: FontWeight.w700, fontSize: 13)),
      );
    }
    if (!context.shopOn) {
      // Purchase band: Enroll/price nahi
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.chip,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('🔒 Not available in the app yet',
            style: TextStyle(
                color: t.muted, fontWeight: FontWeight.w700, fontSize: 13)),
      );
    }
    return ElevatedButton(
      onPressed: () => _buy(c, 'class'),
      child: Text('Enroll · ₹${_num(c['price']).toInt()}'),
    );
  }

  Widget _batchCard(DT t, Map<String, dynamic> b) {
    final enrolled = b['is_purchased'] == true || b['is_free'] == true;
    final price = _num(b['price']);
    final orig = _num(b['original_price']);
    final count = _num(b['class_count']).toInt();
    final faculty = '${b['faculty'] ?? ''}';
    final thumb = '${b['thumbnail_url_mobile'] ?? b['thumbnail_url'] ?? ''}';

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thumb.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 8,
              child: Container(
                color: t.chip,
                child: Image.network(thumb,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${b['title'] ?? ''}',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: t.text)),
                if (faculty.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(faculty,
                      style: TextStyle(fontSize: 12.5, color: t.muted)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.video_call_rounded, size: 16, color: t.muted),
                  const SizedBox(width: 5),
                  Text('$count live class${count == 1 ? '' : 'es'}',
                      style: TextStyle(fontSize: 12.5, color: t.text2)),
                ]),
                const SizedBox(height: 12),
                if (enrolled)
                  const Tag('ENROLLED', color: kDGreen)
                else if (!context.shopOn)
                  Text('🔒 Not available in the app yet',
                      style: TextStyle(
                          color: t.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13))
                else
                  Row(
                    children: [
                      Text('₹${price.toInt()}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: t.text)),
                      if (orig > price) ...[
                        const SizedBox(width: 7),
                        Text('₹${orig.toInt()}',
                            style: TextStyle(
                                fontSize: 13,
                                color: t.muted,
                                decoration: TextDecoration.lineThrough)),
                      ],
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => _buy(b, 'batch'),
                        child: const Text('Enroll'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
