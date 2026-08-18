import 'dart:async';
import 'dart:ui' show FontFeature;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';

/// Live test banner — website ke LiveTestBanner jaisa hi.
///
/// Kuch bhi hardcoded nahi: sab `/mock-tests/live` se aata hai.
/// Backend hi phase batata hai (upcoming / running / ended / published),
/// counts bhejta hai, aur bata deta hai ki user ne register kiya ya test diya.
///
/// Koi live test na ho to widget kuch render nahi karta (SizedBox.shrink).
class LiveTestBanner extends StatefulWidget {
  final Color gold;
  final Color navy;
  final Color navy2;

  /// Test kholne ke liye — parent screen decide karti hai kaunsi screen par jaana hai.
  final void Function(int testId)? onStartTest;
  final void Function(int testId)? onViewResult;
  final void Function(int testId)? onViewSolutions;
  final void Function(String url)? onOpenLink;

  const LiveTestBanner({
    super.key,
    required this.gold,
    required this.navy,
    required this.navy2,
    this.onStartTest,
    this.onViewResult,
    this.onViewSolutions,
    this.onOpenLink,
  });

  @override
  State<LiveTestBanner> createState() => _LiveTestBannerState();
}

class _LiveTestBannerState extends State<LiveTestBanner> {
  Map<String, dynamic>? _test;
  int _left = 0;
  bool _busy = false;
  bool _justRegistered = false;

  Timer? _tick;      // har second countdown
  Timer? _refresh;   // har minute data refresh

  static const _red = Color(0xFFC62828);
  static const _redDark = Color(0xFF8C1C1C);

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 60), (_) => _load());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _left <= 0) return;
      setState(() => _left--);
      if (_left <= 0) _load();   // phase badal gaya hoga
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  /// Test ka id — JSON se kabhi int, kabhi string aa sakta hai.
  /// `as int` karne par string aayi to crash ho jata, isliye parse karte hain.
  int get _testId {
    final raw = _test?['id'];
    if (raw is int) return raw;
    return int.tryParse('${raw ?? ''}') ?? 0;
  }

  int? get _userId {
    // home_screen wahi pattern use karta hai: user?['id']
    final raw = context.read<AuthProvider>().user?['id'];
    if (raw is int) return raw;
    return int.tryParse('${raw ?? ''}');
  }

  Future<void> _load() async {
    try {
      final uid = _userId;
      final url = '${AppConstants.apiUrl}/mock-tests/live'
          '${uid != null ? '?user_id=$uid' : ''}';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return;

      final data = jsonDecode(r.body);
      final list = (data['live_tests'] as List?) ?? [];
      if (!mounted) return;

      if (list.isEmpty) {
        setState(() => _test = null);
        return;
      }
      final t = Map<String, dynamic>.from(list.first);
      setState(() {
        _test = t;
        _left = t['phase'] == 'upcoming'
            ? (t['seconds_to_start'] ?? 0)
            : (t['seconds_to_end'] ?? 0);
      });
    } catch (_) {
      // Chup-chaap — banner na dikhe to home screen normal chalti rahe
    }
  }

  Future<void> _register() async {
    final uid = _userId;
    if (uid == null || _test == null) return;
    setState(() => _busy = true);
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiUrl}/mock-tests/$_testId/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': uid}),
      );
      if (r.statusCode == 200 && mounted) {
        setState(() => _justRegistered = true);
        _load();
      }
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  String _dhms(int s) {
    final d = s ~/ 86400;
    final h = (s % 86400) ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    two(int n) => n.toString().padLeft(2, '0');
    return d > 0 ? '${d}d ${two(h)}:${two(m)}:${two(sec)}' : '${two(h)}:${two(m)}:${two(sec)}';
  }

  String _when(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h24 = d.hour;
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      final ap = h24 < 12 ? 'am' : 'pm';
      return '${d.day} ${months[d.month - 1]}, $h12:${d.minute.toString().padLeft(2, '0')} $ap';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _test;
    if (t == null) return const SizedBox.shrink();

    final phase = (t['phase'] ?? '').toString();
    final running = phase == 'running';
    final ended = phase == 'ended';
    final published = phase == 'published' || t['results_published'] == true;
    final attempted = t['already_attempted'] == true;
    final registered = t['already_registered'] == true || _justRegistered;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: running ? const [_redDark, _red] : [widget.navy, widget.navy2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top strip ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                if (running) ...[
                  Container(
                    width: 9, height: 9,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFF5252), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  running
                      ? 'LIVE NOW'
                      : published
                          ? '🏆 YOUR RESULT IS OUT'
                          : ended
                              ? '⏳ RESULT AWAITED'
                              : '🔴 UPCOMING LIVE TEST',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2),
                ),
                const Spacer(),
                if (t['is_free'] == true)
                  const Text('FREE',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (t['title'] ?? '').toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.3),
                ),
                const SizedBox(height: 8),

                // Meta
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (t['total_questions'] != null)
                      _meta('📝 ${t['total_questions']} questions'),
                    if (t['duration_minutes'] != null)
                      _meta('⏱ ${t['duration_minutes']} min'),
                    if (t['total_marks'] != null)
                      _meta('🎯 ${t['total_marks']} marks'),
                  ],
                ),

                if ((t['starts_at'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('${_when(t['starts_at'])} — ${_when(t['ends_at'])}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85), fontSize: 12.5)),
                ],

                // Countdown — published me nahi
                if (_left > 0 && !published) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(running ? 'Ends in' : 'Starts in',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85), fontSize: 12)),
                        const Spacer(),
                        Text(_dhms(_left),
                            style: TextStyle(
                                color: widget.gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                      ],
                    ),
                  ),
                ],

                // Counts — backend se aate hain
                const SizedBox(height: 12),
                if (running && t['live_count'] != null)
                  _count('🟢 ${t['live_count']} students live')
                else if (!running &&
                    !published &&
                    (t['registered_count'] ?? 0) > 0)
                  _count('👥 ${t['registered_count']} registered'),

                const SizedBox(height: 14),

                // ── Actions ──
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (running && !attempted)
                      _primary('▶ Start Test Now',
                          () => widget.onStartTest?.call(_testId)),

                    if (running && attempted)
                      _note('✓ Submitted — your result will be out soon'),

                    if (phase == 'upcoming')
                      registered
                          ? _note('✓ You are registered — see you at test time')
                          : _primary(_busy ? 'Please wait…' : '🔔 Register Free',
                              _busy ? null : _register),

                    if (ended) _note('Results are being prepared — check back shortly'),

                    if (published) ...[
                      _primary('🏆 View your Result & Rank',
                          () => widget.onViewResult?.call(_testId)),
                      _secondary('📖 View solutions',
                          () => widget.onViewSolutions?.call(_testId)),
                    ],

                    if (!published &&
                        (t['telegram_group'] ?? '').toString().isNotEmpty)
                      _secondary('✈️ Join Telegram for reminders',
                          () => widget.onOpenLink?.call(t['telegram_group'].toString())),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(String s) => Text(s,
      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5));

  Widget _count(String s) => Text(s,
      style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700));

  Widget _note(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(s,
            style: const TextStyle(
                color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
      );

  Widget _primary(String label, VoidCallback? onTap) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.gold,
          foregroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
      );

  Widget _secondary(String label, VoidCallback? onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.14),
          side: BorderSide(color: Colors.white.withOpacity(0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      );
}
