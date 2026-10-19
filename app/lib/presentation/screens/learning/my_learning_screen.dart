// lib/presentation/screens/learning/my_learning_screen.dart
//
// "My Learning" — student ki kharidi hui cheezein + live test results.
// Courses /courses/my/{id} se (bundle wale bhi, expired nahi).
//
// Redesign (Sep 2026): clean look, filter (All / Courses / Mock / Descriptive),
// chhote cards. Ye ab bottom tab hai, isliye back button nahi.
//
// Oct 2026 (website jaisa): Typing / Skill Test ki kharidi bhi dikhti hai
// (pehle sirf typing kharidne wale ko "Nothing here yet" dikhta tha), aur
// "Purchase missing?" — doosre login (Google vs mobile) wala account milao.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/account_gate.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import '../courses/course_detail_screen.dart';
import '../descriptive/descriptive_series_detail_screen.dart';
import '../descriptive/descriptive_theme.dart';
import '../mock/mock_review_screen.dart';
import '../mock/mock_series_detail_screen.dart';
import '../web/site_web_screen.dart';

class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({super.key});

  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _Item {
  final String kind; // 'course' | 'mock' | 'descriptive' | 'typing'
  final Map<String, dynamic> data;
  _Item(this.kind, this.data);
}

class _MyLearningScreenState extends State<MyLearningScreen> {
  List<_Item> _items = [];
  List<Map<String, dynamic>> _liveResults = [];
  bool _loading = true;
  int? _userId;
  int _filter = 0; // 0 All, 1 Courses, 2 Mock, 3 Descriptive, 4 Typing

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  List<Map<String, dynamic>> _list(dynamic d, String key) {
    final l = d is Map ? d[key] : null;
    if (l is! List) return [];
    return l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<dynamic> _get(String path) async {
    try {
      final r = await http
          .get(Uri.parse('${AppConstants.apiUrl}$path'))
          .timeout(const Duration(seconds: 12));
      return r.statusCode == 200 ? jsonDecode(r.body) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = _items.isEmpty && _liveResults.isEmpty);
    final raw = context.read<AuthProvider>().user?['id'];
    final uid = raw is int ? raw : int.tryParse('${raw ?? ''}');
    _userId = uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final r = await Future.wait([
      _get('/courses/my/$uid'),
      _get('/mock-tests/series?user_id=$uid'),
      _get('/descriptive/series?platform=app&user_id=$uid'),
      _get('/mock-tests/my-live-results?user_id=$uid'),
      _get('/tier2/series?platform=app&user_id=$uid'),
    ]);
    if (!mounted) return;
    setState(() {
      _items = [
        ..._list(r[0], 'courses').map((c) => _Item('course', c)),
        ..._list(r[1], 'series')
            .where((s) => s['is_purchased'] == true)
            .map((s) => _Item('mock', s)),
        ..._list(r[2], 'series')
            .where((s) => s['is_purchased'] == true)
            .map((s) => _Item('descriptive', s)),
        ..._list(r[4], 'series')
            .where((s) => s['is_purchased'] == true)
            .map((s) => _Item('typing', s)),
      ];
      _liveResults = _list(r[3], 'results');
      _loading = false;
    });
  }

  void _open(_Item item) {
    HapticFeedback.lightImpact();
    final raw = item.data['id'];
    final id = raw is int ? raw : int.tryParse('${raw ?? ''}');
    final Widget screen;
    switch (item.kind) {
      case 'mock':
        if (id == null) return;
        screen = MockSeriesDetailScreen(seriesId: id);
        break;
      case 'descriptive':
        if (id == null) return;
        screen = DescriptiveSeriesDetailScreen(seriesId: id);
        break;
      case 'typing':
        // Typing / Excel simulator website ke WebView me (app me login ke saath)
        screen = SiteWebScreen(path: id == null ? '/tier2' : '/tier2?s=$id');
        break;
      default:
        screen = CourseDetailScreen(course: item.data);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openLive(Map<String, dynamic> r) {
    HapticFeedback.lightImpact();
    final raw = r['mock_test_id'];
    final id = raw is int ? raw : int.tryParse('${raw ?? ''}');
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MockReviewScreen(
            testId: id, userId: _userId, title: '${r['title'] ?? ''}'),
      ),
    );
  }

  String _fmtDate(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}');
    if (d == null) return '';
    final l = d.toLocal();
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${l.day} ${m[l.month - 1]} ${l.year}';
  }

  String _fmtNum(dynamic v) {
    final n = v is num ? v : num.tryParse('${v ?? ''}');
    if (n == null) return '—';
    return n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1);
  }

  List<_Item> get _shown {
    const kinds = ['', 'course', 'mock', 'descriptive', 'typing'];
    if (_filter == 0) return _items;
    return _items.where((i) => i.kind == kinds[_filter]).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final shown = _shown;
    final nothing = _items.isEmpty && _liveResults.isEmpty;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
          title: const Text('My Learning'), automaticallyImplyLeading: false),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.only(top: 14, bottom: 32),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (nothing)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyState(
                  icon: Icons.school_outlined,
                  text:
                      'Nothing here yet.\nCourses, mock series, descriptive and typing series you enroll in will appear here.',
                ),
              )
            else ...[
              if (_liveResults.isNotEmpty) ...[
                const SectionHeader('Live test results'),
                for (final r in _liveResults)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _liveCard(t, r),
                  ),
                const SizedBox(height: 14),
              ],
              if (_items.isNotEmpty) ...[
                const SectionHeader('Enrolled'),
                FilterChips(
                  options: const [
                    'All',
                    'Courses',
                    'Mock tests',
                    'Descriptive',
                    'Typing / Skill'
                  ],
                  selected: _filter,
                  onChanged: (i) => setState(() => _filter = i),
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Nothing in this category yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.muted)),
                  )
                else
                  for (final i in shown)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _card(t, i),
                    ),
              ],
            ],
            if (!_loading)
              Padding(
                padding: EdgeInsets.fromLTRB(16, nothing ? 8 : 18, 16, 0),
                child: _purchaseMissing(t),
              ),
          ],
        ),
      ),
    );
  }

  /// Doosre login se kharida? (Google vs mobile) — wahi merge flow
  Widget _purchaseMissing(DT t) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: t.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.person_search_rounded, size: 20, color: t.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Purchase missing?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.text)),
                const SizedBox(height: 3),
                Text(
                    'If you bought it with a different login (for example Google instead of your '
                    'mobile number), link that account here. Everything moves into one account.',
                    style: TextStyle(fontSize: 12.5, color: t.muted, height: 1.45)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => AccountGate.openLink(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8A5A00),
                    side: const BorderSide(color: Color(0xFFFFAB00)),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Text('Link my other account',
                      style:
                          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveCard(DT t, Map<String, dynamic> r) {
    final published = r['results_published'] == true;
    final total = r['total_marks'];
    final date = _fmtDate(r['attempted_at'] ?? r['live_start_at']);
    final color = published ? const Color(0xFF2C6FD1) : const Color(0xFFB47F00);

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: published ? () => _openLive(r) : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                published
                    ? Icons.emoji_events_rounded
                    : Icons.hourglass_top_rounded,
                size: 20,
                color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['title'] ?? 'Live test'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.text)),
                const SizedBox(height: 3),
                Text(
                  published
                      ? 'Score ${_fmtNum(r['score'])}${total != null ? ' / ${_fmtNum(total)}' : ''}'
                          '${date.isNotEmpty ? ' · $date' : ''}'
                      : 'Result not published yet${date.isNotEmpty ? ' · $date' : ''}',
                  style: TextStyle(fontSize: 12, color: t.muted),
                ),
              ],
            ),
          ),
          if (published) Icon(Icons.chevron_right_rounded, color: t.muted),
        ],
      ),
    );
  }

  Widget _card(DT t, _Item item) {
    final c = item.data;
    final img = '${c['thumbnail_url_mobile'] ?? c['thumbnail_url'] ?? ''}';
    final (String label, Color color, IconData icon) = switch (item.kind) {
      'mock' => ('MOCK SERIES', const Color(0xFF2C6FD1), Icons.assignment_rounded),
      'descriptive' => ('DESCRIPTIVE', const Color(0xFF7B4FD0), Icons.edit_note_rounded),
      'typing' => ('TYPING / SKILL TEST', const Color(0xFF0E9384), Icons.keyboard_rounded),
      _ => ('COURSE', const Color(0xFFD9822B), Icons.school_rounded),
    };

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => _open(item),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: img.isEmpty
                  ? Container(
                      color: color.withOpacity(0.10),
                      child: Icon(icon, color: color))
                  : Container(
                      color: t.chip,
                      child: Image.network(img,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(icon, color: color)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(label, color: color),
                const SizedBox(height: 5),
                Text('${c['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: t.text)),
                const SizedBox(height: 4),
                Text('Continue →',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: t.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
