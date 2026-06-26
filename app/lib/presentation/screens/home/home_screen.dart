import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../quiz/exam_categories_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardTab(onToggleTheme: widget.onToggleTheme),
      const ExamCategoriesScreen(),
      ProfileScreen(onToggleTheme: widget.onToggleTheme),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: "Home", selected: _index == 0, onTap: () { HapticFeedback.lightImpact(); setState(() => _index = 0); }),
                _NavItem(icon: Icons.menu_book_rounded, label: "Exams", selected: _index == 1, onTap: () { HapticFeedback.lightImpact(); setState(() => _index = 1); }),
                _NavItem(icon: Icons.person_rounded, label: "Profile", selected: _index == 2, onTap: () { HapticFeedback.lightImpact(); setState(() => _index = 2); }),
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
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : (isDark ? Colors.white54 : Colors.black45), size: 24),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── DASHBOARD TAB ─────────────────────────────────────────────────────────────

class DashboardTab extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const DashboardTab({super.key, required this.onToggleTheme});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<Map<String, dynamic>> _featuredCourses = [];
  bool _loadingCourses = true;

  @override
  void initState() {
    super.initState();
    _loadFeaturedCourses();
  }

  Future<void> _loadFeaturedCourses() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.selectionlab.online/api/courses/featured'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _featuredCourses = List<Map<String, dynamic>>.from(data['courses']);
          _loadingCourses = false;
        });
      } else {
        setState(() => _loadingCourses = false);
      }
    } catch (_) {
      setState(() => _loadingCourses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── APP BAR ──
          SliverAppBar(
            backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
            elevation: 0,
            floating: true,
            snap: true,
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', height: 32),
                const SizedBox(width: 8),
                Text(
                  "Selection Lab",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                onPressed: widget.onToggleTheme,
              ),
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    color: isDark ? Colors.white70 : Colors.black54),
                onPressed: () => HapticFeedback.lightImpact(),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── GREETING ──
                  Text(
                    "Hello, ${user?['name'] ?? 'Student'}! 👋",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "What would you like to study today?",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── BANNER ──
                  _BannerSlider(),
                  const SizedBox(height: 24),

                  // ── WHAT ARE YOU LOOKING FOR ──
                  Text(
                    "What are you looking for?",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickGrid(cardBg: cardBg, isDark: isDark),
                  const SizedBox(height: 24),

                  // ── FEATURED COURSES ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Featured Courses",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        "See All →",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _loadingCourses
                      ? _ShimmerCourses(isDark: isDark)
                      : _featuredCourses.isEmpty
                          ? _EmptyCourses(isDark: isDark)
                          : _FeaturedCoursesList(courses: _featuredCourses, cardBg: cardBg, isDark: isDark),
                  const SizedBox(height: 24),

                  // ── CONNECT WITH US ──
                  Text(
                    "Connect With Us",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ConnectSection(cardBg: cardBg),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── BANNER SLIDER ─────────────────────────────────────────────────────────────

class _BannerSlider extends StatefulWidget {
  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  final PageController _ctrl = PageController();
  int _current = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Get Premium!',
      'subtitle': 'Unlock all exams for just ₹99/month',
      'colors': [Color(0xFFFF6B00), Color(0xFFFF8E53)],
      'btnText': 'Get Now',
      'icon': Icons.star_rounded,
    },
    {
      'title': 'Mock Tests',
      'subtitle': 'Practice with real exam pattern questions',
      'colors': [Color(0xFF1A237E), Color(0xFF3949AB)],
      'btnText': 'Start Now',
      'icon': Icons.assignment_rounded,
    },
    {
      'title': 'Study Material',
      'subtitle': 'Access notes & PDFs for all exams',
      'colors': [Color(0xFF1B5E20), Color(0xFF43A047)],
      'btnText': 'Explore',
      'icon': Icons.menu_book_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_current + 1) % _banners.length;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final b = _banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: b['colors'] as List<Color>,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (b['colors'] as List<Color>)[0].withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(b['icon'] as IconData, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(b['title'] as String,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(b['subtitle'] as String,
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => HapticFeedback.lightImpact(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: (b['colors'] as List<Color>)[0],
                              minimumSize: const Size(80, 30),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(b['btnText'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _current == i ? AppColors.primary : Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── QUICK GRID ────────────────────────────────────────────────────────────────

class _QuickGrid extends StatelessWidget {
  final Color cardBg;
  final bool isDark;
  const _QuickGrid({required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.book_rounded, 'label': 'Free Course', 'color': const Color(0xFF4CAF50)},
      {'icon': Icons.lock_open_rounded, 'label': 'Paid Course', 'color': const Color(0xFFFF6B00)},
      {'icon': Icons.assignment_rounded, 'label': 'Mock Test', 'color': const Color(0xFF2196F3)},
      {'icon': Icons.play_circle_rounded, 'label': 'Videos', 'color': const Color(0xFFE91E63)},
      {'icon': Icons.history_edu_rounded, 'label': "PYQ's", 'color': const Color(0xFF9C27B0)},
      {'icon': Icons.quiz_rounded, 'label': 'Free Quiz', 'color': const Color(0xFF00BCD4)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final color = item['color'] as Color;
        return GestureDetector(
          onTap: () => HapticFeedback.lightImpact(),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item['icon'] as IconData, color: color, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  item['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── FEATURED COURSES ──────────────────────────────────────────────────────────

class _FeaturedCoursesList extends StatelessWidget {
  final List<Map<String, dynamic>> courses;
  final Color cardBg;
  final bool isDark;
  const _FeaturedCoursesList({required this.courses, required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: courses.length,
        itemBuilder: (context, i) {
          final c = courses[i];
          final price = c['price']?.toString() ?? '0';
          final originalPrice = c['original_price']?.toString();
          final hasDiscount = originalPrice != null && originalPrice != price;
          final discount = hasDiscount
              ? ((1 - double.parse(price) / double.parse(originalPrice!)) * 100).round()
              : 0;

          return Container(
            width: 180,
            margin: EdgeInsets.only(right: 12, left: i == 0 ? 0 : 0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black.withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    color: AppColors.primary.withOpacity(0.15),
                    image: c['thumbnail_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(c['thumbnail_url']),
  
