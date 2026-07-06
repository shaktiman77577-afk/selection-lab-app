// lib/presentation/screens/home/home_screen.dart
//
// Home rebuilt to match the website (selectionlab.in) home page:
// navy hero, quick-nav chips, banners, "Why", faculty, exams, featured
// courses, mock CTA, community. Bottom nav kept (Home / My Learning / Profile).
// Quiz removed.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../courses/course_detail_screen.dart';
import '../courses/course_list_screen.dart';
import '../learning/my_learning_screen.dart';
import '../profile/profile_screen.dart';
import '../descriptive/descriptive_series_list_screen.dart';
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

  final List<Map<String, String>> _why = const [
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

  final List<Map<String, String>> _faculty = const [
    {'name': "Nikki Ma'am", 'subject': 'English & Interview', 'img': '/nikki_maam.png'},
    {'name': 'Ravi Sir', 'subject': 'GK/GS & Current Affairs', 'img': '/ravi_sir.jpg'},
    {'name': 'Ashutosh Sir', 'subject': 'Maths', 'img': '/ashutosh_sir.jpg'},
  ];

  final List<String> _exams = const [
    'SSC CGL',
    'SSC CHSL',
    'IB Security Assistant',
    'Railways RRB',
    'UP Police SI',
    'Allahabad High Court',
    'CISF / CRPF',
    'UPSC CAPF',
  ];

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('${AppConstants.apiUrl}/courses/'))
            .timeout(const Duration(seconds: 12)),
        http
            .get(Uri.parse('${AppConstants.apiUrl}/banners/'))
            .timeout(const Duration(seconds: 12)),
      ]);
      List<Map<String, dynamic>> courses = [];
      List<Map<String, dynamic>> banners = [];
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
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _banners = banners;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── data helpers (mirror website's supabase.ts) ──
  String _courseTitle(Map c) =>
      (c['title'] ?? c['name'] ?? 'Course').toString();
  String _courseImage(Map c) =>
      (c['thumbnail_url'] ?? c['thumbnail'] ?? c['image_url'] ?? '').toString();
  String _bannerImage(Map b) =>
      (b['image_url'] ?? b['banner_url'] ?? b['image'] ?? '').toString();
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
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _header(t, name),
              const SizedBox(height: 14),
              _quickNav(t),
              const SizedBox(height: 16),
              _hero(t),
              if (_banners.isNotEmpty) ...[
                const SizedBox(height: 16),
                _bannerStrip(t),
              ],
              _h2(t, 'Why Selection Lab?'),
              Text("We're new — and that's exactly why we do things differently.",
                  style: TextStyle(fontSize: 13, color: t.muted)),
              const SizedBox(height: 12),
              _whyGrid(t),
              _h2(t, 'Meet Our Faculty'),
              _facultyGrid(t),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: () => _open('https://youtube.com/@selection_lab'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF0000),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('▶ Watch Free Classes on YouTube',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                  ),
                ),
              ),
              _h2(t, 'Exams We Cover'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _exams
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              color: t.chip,
                              border: Border.all(color: t.line),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(e,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: t.text)),
                        ))
                    .toList(),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: _h2(t, 'Featured Courses')),
                  GestureDetector(
                    onTap: _courseCategories,
                    child: const Text('View all →',
                        style: TextStyle(
                            color: kDGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              if (_loading)
                Text('Loading courses...',
                    style: TextStyle(color: t.muted, fontSize: 14))
              else if (featured.isEmpty)
                Text(
                    'New courses launching soon — join our Telegram for updates!',
                    style: TextStyle(color: t.muted, fontSize: 14))
              else
                _coursesGrid(t, featured),
              const SizedBox(height: 26),
              _mockCta(t),
              _h2(t, 'Learn Free, Every Day'),
              _community(t),
            ],
          ),
        ),
      ),
    );
  }

  // ── sections ──
  Widget _header(DT t, String name) {
    return Row(
      children: [
        Image.asset('assets/images/logo.png',
            height: 32,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.school, color: kDGold)),
        const SizedBox(width: 8),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: 'Selection ',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: t.text)),
          const TextSpan(
              text: 'Lab',
              style:
                  TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kDGold)),
        ])),
        const Spacer(),
        IconButton(
          onPressed: widget.onToggleTheme,
          icon: Icon(t.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: t.text),
        ),
      ],
    );
  }

  Widget _quickNav(DT t) {
    final items = [
      ['Courses', () => _courseCategories()],
      ['Descriptive', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DescriptiveSeriesListScreen()))],
      ['Mock Tests', () => _open('$_site/mock-tests')],
      ['Blog', () => _open('$_site/blog')],
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => GestureDetector(
          onTap: items[i][1] as VoidCallback,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: t.chip,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(20)),
            child: Text(items[i][0] as String,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: t.text)),
          ),
        ),
      ),
    );
  }

  Widget _hero(DT t) {
    return ClipRRect(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Crack SSC, IB & Railway Exams',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.3,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(
                    'Courses, real exam-interface mock tests and daily practice — in Hindi + English, guided by Nikki Ma\'am.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.6),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      GoldButton(
                          label: '🎯 Try Free Mock Test',
                          onTap: () => _open('$_site/mock-tests'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12)),
                      GestureDetector(
                        onTap: _courseCategories,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.4)),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Text('Explore Courses',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerStrip(DT t) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _banners.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final img = _bannerImage(_banners[i]);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: img.isEmpty
                ? const SizedBox.shrink()
                : Image.network(img,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          );
        },
      ),
    );
  }

  Widget _whyGrid(DT t) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemCount: _why.length,
      itemBuilder: (_, i) {
        final w = _why[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(14),
              boxShadow: t.shadow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w['icon']!, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(w['title']!,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: t.text)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(w['desc']!,
                    style: TextStyle(
                        fontSize: 12, color: t.muted, height: 1.5),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _facultyGrid(DT t) {
    return Row(
      children: _faculty.map((f) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: f == _faculty.last ? 0 : 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(16),
                boxShadow: t.shadow),
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.chip,
                    border: Border.all(color: kDGold, width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network('$_site${f['img']}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Text(f['name']!.substring(0, 1),
                              style: TextStyle(
                                  color: t.text,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)))),
                ),
                const SizedBox(height: 8),
                Text(f['name']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: t.text)),
                const SizedBox(height: 2),
                Text(f['subject']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11,
                        color: kDGold,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _coursesGrid(DT t, List<Map<String, dynamic>> courses) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.74,
      ),
      itemCount: courses.length,
      itemBuilder: (_, i) {
        final c = courses[i];
        final img = _courseImage(c);
        final price = _num(c['price']);
        final orig = _num(c['original_price']);
        final buyers = _num(c['recent_buyers']);
        return GestureDetector(
          onTap: () => _openCourse(c),
          child: Container(
            decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(14),
                boxShadow: t.shadow),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: img.isEmpty
                      ? Container(color: t.chip)
                      : Image.network(img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: t.chip)),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 36,
                        child: Text(_courseTitle(c),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                                color: t.text)),
                      ),
                      const SizedBox(height: 6),
                      price == 0
                          ? const Text('FREE',
                              style: TextStyle(
                                  color: kDGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5))
                          : Row(children: [
                              Text('₹${price.toInt()}',
                                  style: const TextStyle(
                                      color: kDGold,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5)),
                              if (orig > price) ...[
                                const SizedBox(width: 5),
                                Text('₹${orig.toInt()}',
                                    style: TextStyle(
                                        color: t.muted,
                                        fontSize: 11.5,
                                        decoration:
                                            TextDecoration.lineThrough)),
                              ],
                            ]),
                      if (buyers > 0) ...[
                        const SizedBox(height: 3),
                        Text('🔥 ${buyers.toInt()} enrolled recently',
                            style: const TextStyle(
                                fontSize: 10.5, color: Color(0xFFE07B00))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mockCta(DT t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: kDGold, width: 1.5, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('📝', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Experience the real exam — free',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: t.text)),
                const SizedBox(height: 2),
                Text(
                    'Attempt free mock tests on the same interface as the actual SSC/TCS exam.',
                    style: TextStyle(fontSize: 12.5, color: t.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GoldButton(label: 'Start Now', onTap: () => _open('$_site/mock-tests')),
        ],
      ),
    );
  }

  Widget _community(DT t) {
    Widget card(String icon, String title, String sub, String url) {
      return GestureDetector(
        onTap: () => _open(url),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(14),
              boxShadow: t.shadow),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 30)),
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
                    Text(sub, style: TextStyle(fontSize: 12, color: t.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        card('▶️', 'YouTube — Selection Lab',
            'Free lessons, strategy videos and exam updates',
            'https://youtube.com/@selection_lab'),
        card('✈️', 'Telegram Community',
            'Daily quizzes, PDFs, doubts and announcements',
            'https://t.me/Selection_Lab'),
      ],
    );
  }

  Widget _h2(DT t, String text) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 10),
        child: Text(text,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
      );
}
