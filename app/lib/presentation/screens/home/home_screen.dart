// lib/presentation/screens/home/home_screen.dart
//
// Redesign (Sep 2026) — Testbook jaisa clean home:
//   top bar (logo, search, notifications) → live test → offers (banners +
//   coupons) → quick actions → "continue" (meri courses/series) → live
//   classes → featured courses → test series → community.
// "Why us", faculty aur exams ab About screen me hain.
// Bottom nav: Home / My Learning / Profile.

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/app_config_provider.dart';
import '../about/about_screen.dart';
import '../courses/course_detail_screen.dart';
import '../courses/course_list_screen.dart';
import '../learning/my_learning_screen.dart';
import '../profile/profile_screen.dart';
import '../descriptive/descriptive_series_list_screen.dart';
import '../mock/mock_series_list_screen.dart';
import '../mock/mock_series_detail_screen.dart';
import '../mock/mock_review_screen.dart';
import '../blog/blog_screen.dart';
import '../search/search_screen.dart';
import '../notification/notifications_screen.dart';
import '../tier2/tier2_screen.dart';
import '../../widgets/live_test_banner.dart';
import '../live/live_classes_screen.dart';
import '../descriptive/descriptive_theme.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);

    final screens = [
      DashboardTab(onToggleTheme: widget.onToggleTheme),
      const MyLearningScreen(),
      ProfileScreen(onToggleTheme: widget.onToggleTheme),
    ];

    Widget item(int i, IconData icon, IconData iconSel, String label) {
      final sel = _index == i;
      return Expanded(
        child: InkWell(
          onTap: () {
            if (_index == i) return;
            HapticFeedback.selectionClick();
            setState(() => _index = i);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(sel ? iconSel : icon,
                    size: 24, color: sel ? t.primary : t.muted),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        color: sel ? t.primary : t.muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      // Har tab switch par naya build — My Learning me kharidi hui cheez turant dikhe
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: t.card,
          border: Border(top: BorderSide(color: t.line)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              item(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              item(1, Icons.menu_book_outlined, Icons.menu_book_rounded,
                  'My Learning'),
              item(2, Icons.person_outline_rounded, Icons.person_rounded,
                  'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── DASHBOARD ───────────────────────────────────────────────────────────────

class DashboardTab extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const DashboardTab({super.key, required this.onToggleTheme});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> _liveClasses = [];
  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> _series = [];
  List<Map<String, dynamic>> _myCourses = [];

  final PageController _heroCtrl = PageController();
  int _heroPage = 0;
  int _heroCount = 0;
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_heroCtrl.hasClients || _heroCount < 2) return;
      _heroCtrl.animateToPage((_heroPage + 1) % _heroCount,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut);
    });
    _load();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroCtrl.dispose();
    super.dispose();
  }

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  /// Ek request fail ho to baaki home na ruke
  Future<dynamic> _get(String path) async {
    try {
      final r = await http
          .get(Uri.parse('${AppConstants.apiUrl}$path'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _list(dynamic d, String key) {
    final l = d is List ? d : (d is Map ? d[key] : null);
    if (l is! List) return [];
    return l
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _load() async {
    final uid = _uid;
    final uq = uid != null ? '?user_id=$uid' : '';
    final res = await Future.wait([
      _get('/courses/'),
      _get('/banners/'),
      _get('/live/classes$uq'),
      _get('/coupons/public'),
      _get('/mock-tests/series$uq'),
      uid != null ? _get('/courses/my/$uid') : Future.value(null),
    ]);
    if (!mounted) return;
    setState(() {
      _courses = _list(res[0], 'courses');
      _banners = _list(res[1], 'banners');
      _liveClasses = _list(res[2], 'classes');
      _coupons = _list(res[3], 'coupons')
          .where((c) => (c['scope_type'] ?? 'all').toString() == 'all')
          .toList();
      _series = _list(res[4], 'series');
      _myCourses = _list(res[5], 'courses');
    });
  }

  // ── helpers ──
  num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
  String _courseTitle(Map c) => (c['title'] ?? c['name'] ?? 'Course').toString();
  String _img(Map m) => (m['thumbnail_url_mobile'] ??
          m['image_url_mobile'] ??
          m['thumbnail_url'] ??
          m['image_url'] ??
          m['banner_url'] ??
          m['thumbnail'] ??
          '')
      .toString();
  bool _hasMobileImage(Map m) =>
      '${m['thumbnail_url_mobile'] ?? m['image_url_mobile'] ?? ''}'.isNotEmpty;

  void _push(Widget w) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openCourse(Map<String, dynamic> c) =>
      _push(CourseDetailScreen(course: c));

  void _openSeries(Map<String, dynamic> s) {
    final id = s['id'] is int ? s['id'] as int : int.tryParse('${s['id']}');
    if (id != null) _push(MockSeriesDetailScreen(seriesId: id));
  }

  void _openReview(int testId) =>
      _push(MockReviewScreen(testId: testId, userId: _uid));

  void _courseCategories() {
    final t = dtOf(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        const cats = [
          ['Free Courses', 'Free Batch', Icons.book_rounded],
          ['Paid Courses', 'Paid Batch', Icons.lock_open_rounded],
          ['Video Courses', 'Video Course', Icons.play_circle_rounded],
          ['Previous Year Papers', 'PYQ', Icons.history_edu_rounded],
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: t.line, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              for (final c in cats)
                ListTile(
                  leading: Icon(c[2] as IconData, color: t.primary),
                  title: Text(c[0] as String,
                      style: TextStyle(
                          color: t.text, fontWeight: FontWeight.w700)),
                  trailing: Icon(Icons.chevron_right, color: t.muted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _push(CourseListScreen(
                        title: c[0] as String, courseType: c[1] as String));
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  VoidCallback _heroAction(String action) {
    switch (action) {
      case 'mock':
        return () => _push(const MockSeriesListScreen());
      case 'descriptive':
        return () => _push(const DescriptiveSeriesListScreen());
      case 'courses':
        return _courseCategories;
      default:
        if (action.startsWith('http')) return () => _open(action);
        return () {};
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final user = context.watch<AuthProvider>().user;
    final first =
        (user?['name'] ?? 'Student').toString().trim().split(' ').first;

    final purchasedSeries =
        _series.where((s) => s['is_purchased'] == true).toList();
    final otherSeries =
        _series.where((s) => s['is_purchased'] != true).take(8).toList();
    final featured = _courses.take(8).toList();

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(t),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Text('Hi $first 👋',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: t.text)),
                    ),

                    // 1. Live test (khud chhup jata hai jab koi na ho)
                    LiveTestBanner(
                      gold: kDGold,
                      navy: kDNavy,
                      navy2: kDNavy2,
                      onStartTest: (_) => _push(const MockSeriesListScreen()),
                      onViewResult: _openReview,
                      onViewSolutions: _openReview,
                      onOpenLink: _open,
                    ),

                    // 2. Offers
                    _offersCarousel(t),
                    if (_coupons.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _couponStrip(t),
                    ],

                    // 3. Quick actions
                    const SizedBox(height: 20),
                    const SectionHeader('Explore'),
                    _quickActions(t),

                    // 4. Continue
                    if (_myCourses.isNotEmpty ||
                        purchasedSeries.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const SectionHeader('Continue learning'),
                      _continueStrip(t, purchasedSeries),
                    ],

                    // 5. Live classes
                    if (_liveClasses.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SectionHeader('Live classes',
                          onViewAll: () =>
                              _push(const LiveClassesScreen())),
                      _liveStrip(t),
                    ],

                    // 6. Featured courses
                    if (featured.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SectionHeader('Featured courses',
                          onViewAll: _courseCategories),
                      _courseStrip(t, featured),
                    ],

                    // 7. Test series
                    if (otherSeries.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SectionHeader('Test series',
                          onViewAll: () =>
                              _push(const MockSeriesListScreen())),
                      _seriesStrip(t, otherSeries),
                    ],

                    // 8. Community + About
                    const SizedBox(height: 22),
                    const SectionHeader('Join our community'),
                    _community(t),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(DT t) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget icon(IconData i, VoidCallback onTap) => IconButton(
          icon: Icon(i, color: t.text2, size: 23),
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/logo.png',
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => Container(
                      width: 32,
                      height: 32,
                      color: kDNavy,
                      alignment: Alignment.center,
                      child: const Text('SL',
                          style: TextStyle(
                              color: kDGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 13)),
                    )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Selection Lab',
                style: TextStyle(
                    color: t.text, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          icon(Icons.search_rounded, () => _push(const SearchScreen())),
          icon(Icons.notifications_none_rounded,
              () => _push(const NotificationsScreen())),
          icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              widget.onToggleTheme),
        ],
      ),
    );
  }

  // ── OFFERS: admin image slides + banners + featured posters ──
  Widget _offersCarousel(DT t) {
    final cfg = context.watch<AppConfigProvider>();
    final slides = <Widget>[];
    var square = false;

    for (final sd in cfg.heroSlides) {
      if ((sd['type'] ?? 'content').toString() != 'image') continue;
      final img = (sd['image_url'] ?? '').toString();
      if (img.isEmpty) continue;
      final action = (sd['primary_action'] ?? '').toString();
      slides.add(_poster(img, action.isEmpty ? null : _heroAction(action)));
    }
    for (final b in _banners) {
      final img = _img(b);
      if (img.isEmpty) continue;
      if (_hasMobileImage(b)) square = true;
      final link = (b['link_url'] ?? b['link'] ?? b['url'] ?? '').toString();
      slides.add(_poster(img, link.isEmpty ? null : () => _open(link)));
    }
    for (final c in _courses) {
      if (c['is_featured'] != true) continue;
      final img = _img(c);
      if (img.isEmpty) continue;
      if (_hasMobileImage(c)) square = true;
      slides.add(_poster(img, () => _openCourse(c)));
    }
    _heroCount = slides.length;
    if (slides.isEmpty) return const SizedBox.shrink();

    final w = MediaQuery.of(context).size.width - 32;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: square ? w : w * 9 / 16,
            child: PageView(
              controller: _heroCtrl,
              onPageChanged: (i) => setState(() => _heroPage = i),
              children: slides,
            ),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final on = i == _heroPage % slides.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: on ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: on ? t.primary : t.muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  /// Poster poora dikhe (contain), peeche usi ki blurred copy
  Widget _poster(String img, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: kDNavy,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Image.network(img,
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.3),
                      colorBlendMode: BlendMode.darken,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
                Image.network(img,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Chal rahe public coupons — tap = code copy
  Widget _couponStrip(DT t) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _coupons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = _coupons[i];
          final code = (c['code'] ?? '').toString();
          final off = c['discount_type'] == 'percent'
              ? '${c['discount_value']}% OFF'
              : '₹${c['discount_value']} OFF';
          final min = _num(c['min_amount']);
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderColor: kDGold.withOpacity(0.5),
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Code $code copied — use it at checkout')));
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_offer_rounded, color: kDGold, size: 20),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$off · $code',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: t.text)),
                    Text(min > 0 ? 'On orders above ₹${min.toInt()}' : 'Tap to copy',
                        style: TextStyle(fontSize: 11, color: t.muted)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _quickActions(DT t) {
    final items = <(String, IconData, Color, VoidCallback)>[
      ('Mock Tests', Icons.assignment_rounded, const Color(0xFF2C6FD1),
          () => _push(const MockSeriesListScreen())),
      ('Descriptive', Icons.edit_note_rounded, const Color(0xFF7B4FD0),
          () => _push(const DescriptiveSeriesListScreen())),
      ('Typing / Skill', Icons.keyboard_rounded, const Color(0xFF0E9384),
          () => _push(const Tier2Screen())),
      ('Live Classes', Icons.videocam_rounded, const Color(0xFFD64545),
          () => _push(const LiveClassesScreen())),
      ('Courses', Icons.school_rounded, const Color(0xFFD9822B),
          _courseCategories),
      ('Blog', Icons.article_rounded, const Color(0xFF3E8E4E),
          () => _push(const BlogScreen())),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: [
          for (final it in items)
            AppCard(
              padding: const EdgeInsets.all(8),
              onTap: it.$4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: it.$3.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(it.$2, color: it.$3, size: 23),
                  ),
                  const SizedBox(height: 8),
                  Text(it.$1,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t.text)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumb(DT t, String img, IconData fallback, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: img.isEmpty
          ? Container(
              width: size,
              height: size,
              color: t.chip,
              child: Icon(fallback, color: t.muted))
          : Image.network(img,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: size,
                  height: size,
                  color: t.chip,
                  child: Icon(fallback, color: t.muted))),
    );
  }

  Widget _continueStrip(DT t, List<Map<String, dynamic>> series) {
    final cards = <Widget>[
      for (final c in _myCourses)
        _continueCard(t, _courseTitle(c), 'Course', _img(c),
            Icons.school_rounded, () => _openCourse(c)),
      for (final s in series)
        _continueCard(t, (s['title'] ?? 'Test series').toString(),
            'Test series', _img(s), Icons.assignment_rounded,
            () => _openSeries(s)),
    ];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  Widget _continueCard(DT t, String title, String kind, String img,
      IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 250,
      child: AppCard(
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: Row(
          children: [
            _thumb(t, img, icon, 60),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: t.text)),
                  const SizedBox(height: 4),
                  Text('$kind · Continue →',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: t.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveStrip(DT t) {
    final items = _liveClasses.take(6).toList();
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _liveCard(t, items[i]),
      ),
    );
  }

  Widget _liveCard(DT t, Map<String, dynamic> c) {
    final liveNow = c['can_join'] == true;
    DateTime? start;
    try {
      start = DateTime.parse(c['scheduled_at'].toString()).toLocal();
    } catch (_) {}
    var when = '';
    if (start != null) {
      final diff = start.difference(DateTime.now());
      final time =
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      final sameDay = start.year == now.year &&
          start.month == now.month &&
          start.day == now.day;
      when = liveNow
          ? 'Live now'
          : (!diff.isNegative && diff.inMinutes < 60)
              ? 'In ${diff.inMinutes} min'
              : sameDay
                  ? 'Today · $time'
                  : '${start.day}/${start.month} · $time';
    }

    return SizedBox(
      width: 230,
      child: AppCard(
        borderColor: liveNow ? Colors.red.withOpacity(0.5) : null,
        onTap: () => _push(const LiveClassesScreen()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (liveNow)
                const Tag('LIVE', color: Colors.red, filled: true)
              else if (c['is_free'] == true)
                const Tag('FREE', color: kDGreen)
              else if (c['is_unlocked'] == true)
                const Tag('ENROLLED', color: kDGreen),
            ]),
            const SizedBox(height: 8),
            Text(c['title']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: t.text)),
            const Spacer(),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 13, color: t.muted),
              const SizedBox(width: 5),
              Text(when,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: liveNow ? Colors.red : t.muted)),
            ]),
          ],
        ),
      ),
    );
  }

  /// Poster card — course aur series dono ke liye
  Widget _posterCard(DT t,
      {required String img,
      required String title,
      required String subtitle,
      required num price,
      required bool owned,
      required IconData fallback,
      required VoidCallback onTap}) {
    return SizedBox(
      width: 180,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: img.isEmpty
                  ? Container(
                      color: t.chip, child: Icon(fallback, color: t.muted))
                  : Stack(fit: StackFit.expand, children: [
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Image.network(img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: t.chip)),
                      ),
                      Image.network(img,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(fallback, color: t.muted)),
                    ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: t.text)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: t.muted)),
                  ],
                  const SizedBox(height: 6),
                  owned
                      ? const Tag('ENROLLED', color: kDGreen)
                      : Text(price <= 0 ? 'FREE' : '₹${price.toInt()}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: price <= 0 ? kDGreen : t.text)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strip(List<Widget> cards) {
    return SizedBox(
      height: 232,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  Widget _courseStrip(DT t, List<Map<String, dynamic>> list) {
    final mine = _myCourses.map((c) => '${c['id']}').toSet();
    return _strip([
      for (final c in list)
        _posterCard(t,
            img: _img(c),
            title: _courseTitle(c),
            subtitle: (c['course_type'] ?? '').toString(),
            price: _num(c['price']),
            owned: mine.contains('${c['id']}'),
            fallback: Icons.school_rounded,
            onTap: () => _openCourse(c)),
    ]);
  }

  Widget _seriesStrip(DT t, List<Map<String, dynamic>> list) {
    return _strip([
      for (final s in list)
        _posterCard(t,
            img: _img(s),
            title: (s['title'] ?? 'Test series').toString(),
            subtitle: [
              if (_num(s['tests_count']) > 0) '${s['tests_count']} tests',
              if (_num(s['free_count']) > 0) '${s['free_count']} free',
            ].join(' · '),
            price: _num(s['price']),
            owned: false,
            fallback: Icons.assignment_rounded,
            onTap: () => _openSeries(s)),
    ]);
  }

  Widget _community(DT t) {
    final comm = context.watch<AppConfigProvider>().community;
    String link(String k, String d) {
      final v = (comm[k] ?? '').toString();
      return v.isEmpty ? d : v;
    }

    final rows = <(String, String, String)>[
      ('▶️', 'YouTube', link('youtube', 'https://youtube.com/@selection_lab')),
      ('✈️', 'Telegram', link('telegram', 'https://t.me/Selection_Lab')),
      if ('${comm['instagram'] ?? ''}'.isNotEmpty)
        ('📸', 'Instagram', '${comm['instagram']}'),
      if ('${comm['whatsapp'] ?? ''}'.isNotEmpty)
        ('💬', 'WhatsApp', '${comm['whatsapp']}'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: () => _open(rows[i].$3),
                    child: Column(
                      children: [
                        Text(rows[i].$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(rows[i].$2,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: t.text2)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => _push(const AboutScreen()),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: t.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('About Selection Lab',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: t.text)),
                ),
                Icon(Icons.chevron_right, color: t.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
