// lib/presentation/screens/exams/exam_page_screen.dart
//
// Ek exam ka page (Nov 2026) — website ke /exam/<slug> jaisa. Upar navy
// header (logo, naam, ginti), phir tabs (All | Mock Tests | Courses |
// Descriptive | Typing & Skill | Bundles), neeche Testbook jaise cards:
// total / free tests, bhasha, khaas baatein, aur daam.
//
// Play Store niyam (core/shop.dart): app me kharid band ho (shopOn false) to
// daam nahi — paid cheez par sirf "Locked". Kharida hua ho to ENROLLED.
// Card dabane par wahi native detail screen khulti hai jo baaki app me.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/shop.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/descriptive_api.dart';
import '../../../data/providers/mock_api.dart';
import '../../../data/providers/tier2_api.dart';
import '../courses/course_detail_screen.dart';
import '../descriptive/descriptive_series_detail_screen.dart';
import '../descriptive/descriptive_theme.dart';
import '../mock/mock_series_detail_screen.dart';
import '../web/site_web_screen.dart';
import 'exam_widgets.dart';

const _kStatWord = {
  'mock': ['Mock Series', 'Mock Series'],
  'course': ['Course', 'Courses'],
  'descriptive': ['Descriptive Series', 'Descriptive Series'],
  'tier2': ['Typing & Skill', 'Typing & Skill'],
  'bundle': ['Bundle', 'Bundles'],
};

const _kCta = {
  'mock': 'View Test Series',
  'descriptive': 'View Tests',
  'tier2': 'Start Practice',
  'course': 'View Course',
};

class ExamPageScreen extends StatefulWidget {
  final String slug;

  /// List / home wala chhota data — header turant dikhe
  final Map<String, dynamic>? preview;
  const ExamPageScreen({super.key, required this.slug, this.preview});

  @override
  State<ExamPageScreen> createState() => _ExamPageScreenState();
}

class _ExamPageScreenState extends State<ExamPageScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _tab = 'all';
  // "mock:12", "course:5" — jo student ne le rakha hai
  Set<String> _owned = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final r = await http
          .get(Uri.parse('${AppConstants.apiUrl}/exam-pages/'
              '${Uri.encodeComponent(widget.slug)}?platform=app'))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (r.statusCode == 404) {
        setState(() {
          _loading = false;
          _error = 'This exam page is not available right now.';
        });
        return;
      }
      if (r.statusCode != 200) throw Exception('status');
      final d = jsonDecode(r.body);
      setState(() {
        _data = d is Map ? Map<String, dynamic>.from(d) : null;
        _loading = false;
      });
      _loadOwned();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_data == null) {
          _error = 'Could not load this exam. Check your internet.';
        }
      });
    }
  }

  /// Kharide hue products — sirf tab jab koi paid card ho aur login ho
  Future<void> _loadOwned() async {
    final uid = _uid;
    if (uid == null) return;
    final cards = _allCards();
    bool paid(String kind) =>
        cards.any((c) => c['kind'] == kind && !_isFree(c));
    if (!cards.any((c) => !_isFree(c))) return;

    Future<Set<String>> series(
        String kind, Future<List<Map<String, dynamic>>> Function() f) async {
      if (!paid(kind)) return {};
      try {
        final l = await f();
        return l
            .where((s) => s['is_purchased'] == true)
            .map((s) => '$kind:${s['id']}')
            .toSet();
      } catch (_) {
        return {};
      }
    }

    Future<Set<String>> courses() async {
      if (!paid('course')) return {};
      try {
        final r = await http
            .get(Uri.parse('${AppConstants.apiUrl}/courses/my/$uid'))
            .timeout(const Duration(seconds: 12));
        if (r.statusCode != 200) return {};
        final d = jsonDecode(r.body);
        final l = d is List ? d : (d is Map ? d['courses'] : null);
        return examMaps(l).map((c) => 'course:${c['id']}').toSet();
      } catch (_) {
        return {};
      }
    }

    final res = await Future.wait([
      courses(),
      series('mock', () => MockApi.series(uid)),
      series('descriptive', () => DescriptiveApi.series(uid)),
      series('tier2', () => Tier2Api.series(uid)),
    ]);
    if (!mounted) return;
    setState(() => _owned = res.expand((s) => s).toSet());
  }

  // ── helpers ──
  num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
  bool _isFree(Map c) => c['is_free'] == true || _num(c['price']) <= 0;
  bool _isOwned(Map c) => _owned.contains('${c['kind']}:${c['id']}');

  Map<String, dynamic> get _exam {
    final e = _data?['exam'];
    if (e is Map) return Map<String, dynamic>.from(e);
    return widget.preview ?? {'name': '', 'slug': widget.slug};
  }

  List<Map<String, dynamic>> _tabs() => examMaps(_data?['tabs'])
      .where((t) => examInt(t['count']) > 0)
      .toList();

  List<Map<String, dynamic>> _cards(String key) {
    final items = _data?['items'];
    if (items is! Map) return [];
    return examMaps(items[key]);
  }

  /// "All" tab — har kind ke cards, ek baar
  List<Map<String, dynamic>> _allCards() {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final t in _tabs()) {
      for (final c in _cards('${t['key']}')) {
        if (seen.add('${c['kind']}:${c['id']}')) out.add(c);
      }
    }
    return out;
  }

  void _open(Map<String, dynamic> c) {
    HapticFeedback.lightImpact();
    final id = examInt(c['id']);
    if (id == 0) return;
    Widget? w;
    switch ('${c['kind']}') {
      case 'mock':
        w = MockSeriesDetailScreen(seriesId: id);
        break;
      case 'course':
        // CourseDetail khud poora course mangwa leta hai
        w = CourseDetailScreen(course: {
          'id': id,
          'title': c['title'],
          'thumbnail_url': c['thumbnail_url'],
          'thumbnail_url_mobile': c['thumbnail_url_mobile'],
          'price': c['price'],
          'original_price': c['original_price'],
          'exam_over': c['exam_over'],
        });
        break;
      case 'descriptive':
        w = DescriptiveSeriesDetailScreen(seriesId: id);
        break;
      case 'tier2':
        // Typing / Skill app me website se chalta hai (Tier2Screen jaisa)
        w = SiteWebScreen(path: '/tier2?s=$id');
        break;
    }
    if (w == null) return;
    final screen = w;
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (mounted) _loadOwned();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final e = _exam;
    final tabs = _tabs();
    final keys = ['all', ...tabs.map((x) => '${x['key']}')];
    if (!keys.contains(_tab)) _tab = 'all';
    final shown = _tab == 'all' ? _allCards() : _cards(_tab);

    final state = ListStateView(
      loading: _loading,
      error: _error,
      empty: _data != null && shown.isEmpty,
      emptyText:
          'Test series for this exam are coming soon. Check back shortly!',
      emptyIcon: Icons.assignment_outlined,
      onRetry: _load,
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
          title: Text('${e['short_name'] ?? ''}'.trim().isNotEmpty
              ? '${e['short_name']}'
              : 'Exam')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _header(e, tabs),
            if (!_loading && _error == null && tabs.length > 1) ...[
              const SizedBox(height: 14),
              FilterChips(
                options: [
                  'All',
                  for (final x in tabs) '${x['label']} (${examInt(x['count'])})',
                ],
                selected: keys.indexOf(_tab).clamp(0, keys.length - 1),
                onChanged: (i) => setState(() => _tab = keys[i]),
              ),
            ],
            const SizedBox(height: 14),
            if (state.show)
              state
            else
              for (final c in shown)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _ExamCard(
                    card: c,
                    exam: e,
                    owned: _isOwned(c),
                    onTap: () => _open(c),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> e, List<Map<String, dynamic>> tabs) {
    final desc = '${e['description'] ?? ''}'.trim();
    final cat = '${e['category'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kDNavy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExamLogo(exam: e, size: 66, ring: kDGold, ringWidth: 3),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cat.isNotEmpty)
                      Text(cat.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFFC94D))),
                    const SizedBox(height: 3),
                    Text('${e['name'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 19,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(desc,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: Colors.white.withOpacity(0.86))),
          ],
          if (tabs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final x in tabs)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_statText(x),
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statText(Map x) {
    final n = examInt(x['count']);
    final w = _kStatWord['${x['key']}'];
    return '$n ${w == null ? '${x['label']}' : w[n == 1 ? 0 : 1]}';
  }
}

/// Testbook jaisa card
class _ExamCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final Map<String, dynamic> exam;
  final bool owned;
  final VoidCallback onTap;
  const _ExamCard(
      {required this.card,
      required this.exam,
      required this.owned,
      required this.onTap});

  num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
  String _plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';

  List<String> _strings(dynamic l) =>
      l is List ? l.map((x) => '$x').where((x) => x.isNotEmpty).toList() : [];

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final c = card;
    final kind = '${c['kind']}';
    final price = _num(c['price']);
    final original = _num(c['original_price']);
    final free = c['is_free'] == true || price <= 0;
    final over = c['exam_over'] == true;
    final bundle = c['is_bundle'] == true;
    final shop = context.shopOn;
    final off = (!free && original > price)
        ? ((1 - price / original) * 100).round()
        : 0;

    final stats = c['stats'] is Map ? c['stats'] as Map : const {};
    final tests = examInt(stats['tests']);
    final freeCount = examInt(c['free_count']);
    final langs = _strings(c['languages']);
    // Mock / descriptive ki ginti upar summary me — bullets me dobara nahi
    final points = [
      ..._strings(c['highlights']).where((h) => !((kind == 'mock' &&
              h.contains('Mock Test')) ||
          (kind == 'descriptive' && h.contains('Descriptive Test')))),
      ..._strings(c['bundle_includes']).map((b) => 'Includes $b'),
    ];

    final (String, Color)? ribbon = over
        ? ('EXAM OVER', const Color(0xFF3B3B3B))
        : c['is_trending'] == true
            ? ('TRENDING', const Color(0xFFE8590C))
            : c['is_new'] == true
                ? ('NEW', const Color(0xFF2E7D46))
                : null;

    Widget pill(String text, Color bg) => Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(20)),
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w900)),
        );

    Widget lockText(String s) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_rounded, size: 15, color: t.muted),
          const SizedBox(width: 5),
          Text(s,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: t.muted)),
        ]);

    // Neeche bayen: ENROLLED / Exam Over / FREE / Locked / daam
    final Widget priceArea;
    if (owned) {
      priceArea = const Tag('ENROLLED', color: kDGreen);
    } else if (over) {
      priceArea = lockText('Exam Over');
    } else if (free) {
      priceArea = const Text('FREE',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: kDGreen));
    } else if (!shop) {
      priceArea = lockText('Locked');
    } else {
      priceArea = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text('₹${price.toInt()}',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: t.text)),
          if (off > 0) ...[
            Text('₹${original.toInt()}',
                style: TextStyle(
                    fontSize: 12,
                    color: t.muted,
                    decoration: TextDecoration.lineThrough)),
            Tag('$off% OFF', color: const Color(0xFFB47F00)),
          ],
        ],
      );
    }

    final body = AppCard(
      radius: 16,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Upar: logo + tags, halka sunehra
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kDGold.withOpacity(t.dark ? 0.10 : 0.16), t.card],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExamLogo(exam: exam, size: 46),
                const Spacer(),
                if (bundle) pill('BUNDLE', kDNavy),
                if (ribbon != null) pill(ribbon.$1, ribbon.$2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    (bundle
                            ? '${c['kind_label'] ?? ''} bundle'
                            : '${c['kind_label'] ?? ''}')
                        .toUpperCase(),
                    style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w800,
                        color: t.muted)),
                const SizedBox(height: 3),
                Text('${c['title'] ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        color: t.text)),
                if ((kind == 'mock' || kind == 'descriptive') && tests > 0) ...[
                  const SizedBox(height: 8),
                  Text.rich(TextSpan(
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.text),
                    children: [
                      TextSpan(text: _plural(tests, 'Total Test')),
                      if (freeCount > 0)
                        TextSpan(
                            text: '  |  ${_plural(freeCount, 'Free Test')}',
                            style: const TextStyle(color: kDGreen)),
                    ],
                  )),
                ] else if (free) ...[
                  const SizedBox(height: 8),
                  const Text('Free for everyone',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kDGreen)),
                ],
                if (langs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: t.line),
                          bottom: BorderSide(color: t.line)),
                    ),
                    child: Row(children: [
                      Icon(Icons.translate_rounded,
                          size: 16,
                          color: t.dark
                              ? const Color(0xFF6AB8E6)
                              : const Color(0xFF1B76A8)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(langs.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: t.dark
                                    ? const Color(0xFF6AB8E6)
                                    : const Color(0xFF1B76A8))),
                      ),
                    ]),
                  ),
                ],
                if (points.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final p in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7, right: 8),
                            child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: t.muted, shape: BoxShape.circle)),
                          ),
                          Expanded(
                            child: Text(p,
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: t.text2)),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: priceArea),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: kDNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        minimumSize: const Size(0, 38),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(owned
                          ? (kind == 'course' ? 'Continue' : 'Open')
                          : (_kCta[kind] ?? 'View')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return over && !owned ? Opacity(opacity: 0.8, child: body) : body;
  }
}
