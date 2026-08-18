// lib/presentation/screens/home/home_screen.dart
//
// Home rebuilt to match the website (selectionlab.in) home page:
// navy hero, quick-nav chips, banners, "Why", faculty, exams, featured
// courses, mock CTA, community. Bottom nav kept (Home / My Learning / Profile).

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/app_config_provider.dart';
import '../courses/course_detail_screen.dart';
import '../courses/course_list_screen.dart';
import '../learning/my_learning_screen.dart';
import '../profile/profile_screen.dart';
import '../descriptive/descriptive_series_list_screen.dart';
import '../mock/mock_series_list_screen.dart';
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
    final t = DT(Theme.of(context).brightness == Brightness.dark);

    final screens = [
      DashboardTab(onToggleTheme: widget.onToggleTheme),
      const MyLearningScreen(),
      ProfileScreen(onToggleTheme: widget.onToggleTheme),
    ];

    return Scaffold(
      backgroundColor: t.bg,
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: t.card,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: _index == 0,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _index = 0);
                    }),
                _NavItem(
                    icon: Icons.menu_book_rounded,
                    label: 'My Learning',
                    selected: _index == 1,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _index = 1);
                    }),
                _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    selected: _index == 2,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _index = 2);
                    }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kDGold.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected
                    ? kDGold
                    : (isDark ? Colors.white38 : Colors.black38),
                size: 22),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: kDGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── DASHBOARD (website-style) ───────────────────────────────────────────────

class DashboardTab extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const DashboardTab({super.key, required this.onToggleTheme});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  static const _site = 'https://selectionlab.in';

  final List<Map<String, String>> _whyFallback = const [
    {
      'icon': '🖥️',
      'title': 'Real Exam Interface',
      'desc':
          "Mock tests on the same TCS/SSC-pattern screen you'll face on exam day — palette, timer, sections, everything."
    },
    {
      'icon': '🌐',
      'title': 'Hindi + English',
      'desc':
          'Every question, option and explanation available in both languages. Switch anytime during the test.'
    },
    {
      'icon': '👩‍🏫',
      'title': 'Expert Guidance',
      'desc':
          "Courses and strategy by Nikki Ma'am — trusted by thousands of aspirants on YouTube."
    },
    {
      'icon': '💰',
      'title': 'Honest Pricing',
      'desc':
          "Serious preparation shouldn't cost thousands. Full test series and courses at affordable prices."
    },
  ];

  final List<Map<String, String>> _facultyFallback = const [
    {'name': "Nikki Ma'am", 'subject': 'English & Interview', 'img': '/nikki_maam.png'},
    {'name': 'Ravi Sir', 'subject': 'GK/GS & Current Affairs', 'img': '/ravi_sir.jpg'},
    {'name': 'Ashutosh Sir', 'subject': 'Maths', 'img': '/ashutosh_sir.jpg'},
  ];

  final List<String> _examsFallback = const [
    'SSC CGL',
    'SSC CHSL',
    'IB Security Assistant',
    'Railways RRB',
    'UP Police SI',
    'Allahabad High Court',
    'CISF / CRPF',
    'UPSC CAPF',
  ];

  // ── Config-driven (admin panel) with safe fallbacks ──
  List<Map<String, String>> get _why {
    final c = context.watch<AppConfigProvider>().whyUs;
    if (c.isEmpty) return _whyFallback;
    return c
        .map((w) => {
              'icon': (w['emoji'] ?? '').toString(),
              'title': (w['title'] ?? '').toString(),
              'desc': (w['text'] ?? '').toString(),
            })
        .toList();
  }

  List<Map<String, String>> get _faculty {
    final c = context.watch<AppConfigProvider>().faculty;
    if (c.isEmpty) return _facultyFallback;
    return c
        .map((f) => {
              'name': (f['name'] ?? '').toString(),
              'subject': (f['subject'] ?? '').toString(),
              'img': (f['image_url'] ?? '').toString(),
            })
        .toList();
  }

  List<String> get _exams {
    final c = context.watch<AppConfigProvider>().exams;
    return c.isEmpty ? _examsFallback : c;
  }

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> _liveClasses = [];

  // hero carousel
  final PageController _heroCtrl = PageController();
  int _heroPage = 0;
  Timer? _heroTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_heroCtrl.hasClients) return;
      final total = (context.read<AppConfigProvider>().heroSlides.length) + _banners.length;
      if (total == 0) return;
      final next = (_heroPage + 1) % total;
      _heroCtrl.animateToPage(next,
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
  Future<void> _load() async {
    final rawId = context.read<AuthProvider>().user?['id'];
    final uid = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final liveQ = uid != null ? '?user_id=$uid' : '';

    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('${AppConstants.apiUrl}/courses/'))
            .timeout(const Duration(seconds: 12)),
        http
            .get(Uri.parse('${AppConstants.apiUrl}/banners/'))
            .timeout(const Duration(seconds: 12)),
        http
            .get(Uri.parse('${AppConstants.apiUrl}/live/classes$liveQ'))
            .timeout(const Duration(seconds: 12)),
      ]);
      List<Map<String, dynamic>> courses = [];
      List<Map<String, dynamic>> banners = [];
      List<Map<String, dynamic>> live = [];
      if (results[0].statusCode == 200) {
        final d = jsonDecode(results[0].body);
        final list = d is List ? d : (d['courses'] ?? []);
        courses = List<Map<String, dynamic>>.from(list);
      }
      if (results[1].statusCode == 200) {
        final d = jsonDecode(results[1].body);
        final list = d is List ? d : (d['banners'] ?? []);
        banners = List<Map<String, dynamic>>.from(list);
      }
      if (results[2].statusCode == 200) {
        final d = jsonDecode(results[2].body);
        live = List<Map<String, dynamic>>.from(d['classes'] ?? []);
      }
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _banners = banners;
        _liveClasses = live;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _courseTitle(Map c) =>
      (c['title'] ?? c['name'] ?? 'Course').toString();
  // App hamesha phone par chalta hai, isliye mobile wali image pehle.
  // Admin me mobile image na di ho to desktop wali apne aap chal jati hai —
  // kuch tootega nahi.
  String _courseImage(Map c) => (c['thumbnail_url_mobile'] ??
          c['thumbnail_url'] ??
          c['thumbnail'] ??
          c['image_url'] ??
          '')
      .toString();

  String _bannerImage(Map b) => (b['image_url_mobile'] ??
          b['image_url'] ??
          b['banner_url'] ??
          b['image'] ??
          '')
      .toString();

  /// Mobile image di gayi hai ya nahi — isse card ka shape decide hota hai.
  /// Mobile poster 1080x1080 (square) hota hai, desktop wala 16:9.
  bool _hasMobileImage(Map m) =>
      ((m['thumbnail_url_mobile'] ?? m['image_url_mobile'] ?? '').toString()).isNotEmpty;
  num _num(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString()) ?? 0;

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openCourse(Map<String, dynamic> c) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => CourseDetailScreen(course: c)));
  }

  void _courseCategories() {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    showModalBottomSheet(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final cats = const [
          ['Free Courses', 'Free Batch', Icons.book_rounded],
          ['Paid Courses', 'Paid Batch', Icons.lock_open_rounded],
          ['Video Courses', 'Video Course', Icons.play_circle_rounded],
          ['Previous Year Papers', 'PYQ', Icons.history_edu_rounded],
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              ...cats.map((c) => ListTile(
                    leading: Icon(c[2] as IconData, color: kDGold),
                    title: Text(c[0] as String,
                        style: TextStyle(
                            color: t.text, fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseListScreen(
                              title: c[0] as String, courseType: c[1] as String),
                        ),
                      );
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final user = context.watch<AuthProvider>().user;
    final name = (user?['name'] ?? 'Student').toString();
    final featured = _courses.take(6).toList();

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: kDGold,
                          borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: const Text('SL',
                          style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Selection Lab',
                          style: TextStyle(
                              color: t.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ),
                    IconButton(
                      icon: Icon(
                          Theme.of(context).brightness == Brightness.dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: t.text2),
                      onPressed: widget.onToggleTheme,
                    ),
                  ],
                ),
              ),

              // quick-nav chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    ['Courses', _courseCategories],
                    [
                      'Live Classes',
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LiveClassesScreen()))
                    ],
                    [
                      'Descriptive',
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const DescriptiveSeriesListScreen()))
                    ],
                    [
                      'Mock Tests',
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MockSeriesListScreen()))
                    ],
                    ['Blog', () => _open('$_site/blog')],
                  ].map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(e[0] as String),
                        labelStyle: TextStyle(
                            color: t.text, fontWeight: FontWeight.w700),
                        backgroundColor: t.card,
                        side: BorderSide(color: t.line),
                        onPressed: e[1] as VoidCallback,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Live test banner — hero se pehle, bilkul website ki tarah.
              // Koi live test na ho to ye khud chhup jata hai.
              LiveTestBanner(
                gold: kDGold,
                navy: kDNavy,
                navy2: kDNavy2,
                onStartTest: (_) => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MockSeriesListScreen())),
                onViewResult: (id) => _open('$_site/mock-test/$id/result'),
                onViewSolutions: (id) => _open('$_site/mock-test/$id?review=1'),
                onOpenLink: (url) => _open(url),
              ),

              // hero carousel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _hero(t),
              ),

              // Banner strip hata di gayi — banners ab hero carousel me hi
              // aate hain (website par bhi yahi hota hai). Do jagah dikhne se
              // wahi image dobara dikhti thi.

              // Live classes
              if (_liveClasses.isNotEmpty) ...[
                const SizedBox(height: 24),
                _liveSection(t),
              ],

              // Why us
              const SizedBox(height: 24),
              _sectionTitle(t, 'Why Selection Lab?'),
              _whyGrid(t),

              // Faculty
              const SizedBox(height: 24),
              _sectionTitle(t, 'Learn from the Best'),
              _facultyGrid(t),

              // Exams
              const SizedBox(height: 24),
              _sectionTitle(t, 'Exams We Cover'),
              _examsWrap(t),

              // Featured courses
              if (featured.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionTitle(t, 'Featured Courses'),
                _featuredCourses(t, featured),
              ],

              // Mock CTA
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _mockCta(t),
              ),

              // Community
              const SizedBox(height: 24),
              _sectionTitle(t, 'Join Our Community'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _community(t),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
  Widget _sectionTitle(DT t, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(title,
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w900, color: t.text)),
      );

  // ── HERO CAROUSEL ──
  Widget _hero(DT t) {
    final cfg = context.watch<AppConfigProvider>();
    final slideData = cfg.heroSlides;

    Widget actionBtn(String label, String action, {bool ghost = false}) {
      if (label.trim().isEmpty) return const SizedBox.shrink();
      final onTap = _heroAction(action);
      return ghost
          ? _ghostBtn(label, onTap)
          : GoldButton(
              label: label,
              onTap: onTap,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12));
    }

    // Website jaisa hi: carousel me SIRF wahi dikhta hai jo admin upload karta
    // hai — pehle Banners, phir Featured courses ke poster. App Content ke
    // text slides yahan nahi aate (website se hata diye gaye the), sirf uske
    // image-type slides chalte hain.
    final slides = <Widget>[
      for (final sd in slideData)
        if ((sd['type'] ?? 'content').toString() == 'image')
          _adSlide(
            imageUrl: (sd['image_url'] ?? '').toString(),
            action: (sd['primary_action'] ?? '').toString(),
          ),
    ];

    // Mobile banner 1080x1080 (square) hota hai — agar wo diya gaya ho to
    // carousel ko square rakhte hain, warna wide patti phone par patli dikhti hai.
    var anyMobileBanner = false;
    for (final b in _banners) {
      final img = _bannerImage(b);
      if (img.isEmpty) continue;
      if (_hasMobileImage(b)) anyMobileBanner = true;
      final link = (b['link_url'] ?? b['link'] ?? b['url'] ?? '').toString();
      slides.add(_bannerSlide(img, link));
    }

    // Featured courses ke poster bhi carousel me — website par bhi yahi hota hai.
    for (final c in _courses) {
      if (c['is_featured'] != true) continue;
      final img = _courseImage(c);
      if (img.isEmpty) continue;
      if (_hasMobileImage(c)) anyMobileBanner = true;
      slides.add(_courseSlide(c, img));
    }

    // Kuch bhi na ho to purana default hero dikha do — screen khali na lage.
    if (slides.isEmpty) {
      for (final sd in slideData) {
        if ((sd['type'] ?? 'content').toString() == 'image') continue;
        slides.add(_heroSlide(
          title: (sd['title'] ?? '').toString(),
          subtitle: (sd['subtitle'] ?? '').toString(),
          emoji: (sd['emoji'] ?? '').toString(),
          buttons: [
            actionBtn((sd['primary_label'] ?? '').toString(),
                (sd['primary_action'] ?? '').toString()),
            actionBtn((sd['secondary_label'] ?? '').toString(),
                (sd['secondary_action'] ?? '').toString(),
                ghost: true),
          ],
        ));
      }
    }

    final heroH = anyMobileBanner
        ? MediaQuery.of(context).size.width - 32   // square, padding minus
        : 290.0;

    return Column(
      children: [
        SizedBox(
          height: heroH,
          child: PageView(
            controller: _heroCtrl,
            onPageChanged: (i) => setState(() => _heroPage = i),
            children: slides,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final active = i == _heroPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? kDGold : t.muted.withOpacity(0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  VoidCallback _heroAction(String action) {
    switch (action) {
      case 'mock':
        return () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MockSeriesListScreen()));
      case 'descriptive':
        return () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const DescriptiveSeriesListScreen()));
      case 'courses':
        return _courseCategories;
      default:
        if (action.startsWith('http')) {
          final url = action;
          return () => _open(url);
        }
        return () {};
    }
  }

  Widget _ghostBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      ),
    );
  }

  Widget _adSlide({required String imageUrl, required String action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: action.trim().isEmpty ? null : _heroAction(action),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            color: Colors.white,
            child: imageUrl.trim().isEmpty
                ? const SizedBox.shrink()
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain, // shows full image, no cropping
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
        ),
      ),
    );
  }
  Widget _heroSlide({
    required String title,
    required String subtitle,
    required String emoji,
    required List<Widget> buttons,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [kDNavy, kDNavy2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: Stack(
            children: [
              Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kDGold.withOpacity(0.15)))),
              Positioned(
                  right: 14,
                  bottom: 10,
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 44))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.25,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13.5,
                            height: 1.55),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 10, runSpacing: 10, children: buttons),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Featured course ka poster carousel me — tap karo to course khulta hai.
  Widget _courseSlide(Map<String, dynamic> c, String img) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () => _openCourse(c),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            color: kDNavy,
            child: Image.network(
              img,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerSlide(String img, String link) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: link.isEmpty ? null : () => _open(link),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            color: kDNavy,
            child: Image.network(
              img,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _whyGrid(DT t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // Mobile poster square hota hai to card thoda lamba chahiye
        childAspectRatio: _courses.any(_hasMobileImage) ? 0.72 : 0.95,
        children: _why.map((w) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w['icon'] ?? '', style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 8),
                Text(w['title'] ?? '',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: t.text)),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(w['desc'] ?? '',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, height: 1.4, color: t.muted)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _facultyGrid(DT t) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _faculty.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final f = _faculty[i];
          return Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                      (f['img'] ?? '').startsWith('http')
                          ? f['img']!
                          : '$_site${f['img']}',
                      height: 90,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          height: 90,
                          color: kDGold.withOpacity(0.15),
                          child: const Icon(Icons.person,
                              color: kDGold, size: 40))),
                ),
                const SizedBox(height: 8),
                Text(f['name'] ?? '',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: t.text)),
                const SizedBox(height: 2),
                Text(f['subject'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: t.muted)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _examsWrap(DT t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _exams.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(e,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.text2)),
          );
        }).toList(),
      ),
    );
  }

  // ── Live classes strip ─────────────────────────────────────────────────────
  Widget _liveSection(DT t) {
    final items = _liveClasses.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.videocam_rounded,
                    color: Colors.red, size: 16),
              ),
              const SizedBox(width: 9),
              Text('Live Classes',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: t.text)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LiveClassesScreen())),
                child: Text('See all',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kDGold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, i) => _liveCard(t, items[i]),
          ),
        ),
      ],
    );
  }

  Widget _liveCard(DT t, Map<String, dynamic> c) {
    final liveNow = c['can_join'] == true;
    final isFree = c['is_free'] == true;
    final unlocked = c['is_unlocked'] == true;

    DateTime? start;
    try {
      start = DateTime.parse(c['scheduled_at'].toString()).toLocal();
    } catch (_) {}

    String when = '';
    if (start != null) {
      final diff = start.difference(DateTime.now());
      final time =
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      if (liveNow) {
        when = 'Live now';
      } else if (!diff.isNegative && diff.inMinutes < 60) {
        when = 'In ${diff.inMinutes} min';
      } else {
        final now = DateTime.now();
        final sameDay = start.year == now.year &&
            start.month == now.month &&
            start.day == now.day;
        when = sameDay ? 'Today · $time' : '${start.day}/${start.month} · $time';
      }
    }

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LiveClassesScreen())),
      child: Container(
        width: 230,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: liveNow ? Colors.red.withOpacity(0.55) : t.line,
              width: liveNow ? 1.3 : 1),
          boxShadow: t.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (liveNow)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(5)),
                    child: const Text('LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  )
                else if (isFree)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: kDGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5)),
                    child: const Text('FREE',
                        style: TextStyle(
                            color: kDGreen,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800)),
                  )
                else if (unlocked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: kDGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5)),
                    child: const Text('ENROLLED',
                        style: TextStyle(
                            color: kDGreen,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
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
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: t.muted),
                const SizedBox(width: 5),
                Text(when,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: liveNow ? Colors.red : t.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _featuredCourses(DT t, List<Map<String, dynamic>> featured) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: featured.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = featured[i];
          final img = _courseImage(c);
          final price = _num(c['price']);
          // Mobile poster square hota hai — usko 110px me thoosne se poster kat
          // jata hai, isliye height card ki chaudai ke barabar rakhte hain.
          const cardW = 190.0;
          final imgH = _hasMobileImage(c) ? cardW : 110.0;
          return GestureDetector(
            onTap: () => _openCourse(c),
            child: Container(
              width: cardW,
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    child: img.isEmpty
                        ? Container(
                            height: imgH,
                            color: kDGold.withOpacity(0.12),
                            child: const Icon(Icons.school,
                                color: kDGold, size: 40))
                        : Image.network(img,
                            height: imgH,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                height: imgH,
                                color: kDGold.withOpacity(0.12),
                                child: const Icon(Icons.school,
                                    color: kDGold, size: 40))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_courseTitle(c),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: t.text)),
                        const SizedBox(height: 6),
                        Text(price <= 0 ? 'FREE' : '₹${price.toInt()}',
                            style: const TextStyle(
                                color: kDGold,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mockCta(DT t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [kDNavy, kDNavy2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ready for the real thing?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Take a full-length mock test on the real exam interface.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 13)),
          const SizedBox(height: 14),
          GoldButton(
              label: 'Start Now',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MockSeriesListScreen()))),
        ],
      ),
    );
  }

  Widget _community(DT t) {
    Widget card(String emoji, String title, String desc, String url) {
      return GestureDetector(
        onTap: () => _open(url),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: t.text)),
                    const SizedBox(height: 2),
                    Text(desc,
                        style: TextStyle(fontSize: 12, color: t.muted)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: t.muted),
            ],
          ),
        ),
      );
    }

    final comm = context.watch<AppConfigProvider>().community;
    String link(String k, String d) {
      final v = (comm[k] ?? '').toString();
      return v.isEmpty ? d : v;
    }

    final cards = <Widget>[];
    final yt = link('youtube', 'https://youtube.com/@selection_lab');
    final tg = link('telegram', 'https://t.me/Selection_Lab');
    final ig = (comm['instagram'] ?? '').toString();
    final wa = (comm['whatsapp'] ?? '').toString();
    if (yt.isNotEmpty) {
      cards.add(card('▶️', 'YouTube — Selection Lab',
          'Free lessons, strategy videos and exam updates', yt));
    }
    if (tg.isNotEmpty) {
      cards.add(card('✈️', 'Telegram Community',
          'Daily quizzes, PDFs, doubts and announcements', tg));
    }
    if (ig.isNotEmpty) {
      cards.add(card('📸', 'Instagram', 'Reels, tips and updates', ig));
    }
    if (wa.isNotEmpty) {
      cards.add(card('💬', 'WhatsApp', 'Join our WhatsApp community', wa));
    }
    return Column(children: cards);
  }
}
