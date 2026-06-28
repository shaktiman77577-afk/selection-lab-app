import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../quiz/exam_categories_screen.dart';
import '../profile/profile_screen.dart';
import '../courses/course_detail_screen.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      DashboardTab(onToggleTheme: widget.onToggleTheme),
      const _PlaceholderScreen(label: 'My Learning'),
      const _PlaceholderScreen(label: 'Downloads'),
      ProfileScreen(onToggleTheme: widget.onToggleTheme),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
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
                _NavItem(icon: Icons.home_rounded, label: 'Home', selected: _index == 0, onTap: () { HapticFeedback.lightImpact(); setState(() => _index = 0); }),
                _NavItem(icon: Icons.menu_book_rounded, label: 'My Learning', selected: _index == 1, onTap: () { HapticFeedback.lightImpact(); setState(() => _index = 1); }),
                _NavItem(icon: Icons.download_rounded, label: 'Downloads', selected: _index == 2, onTap: () { HapticFeedback.lightImpact(); setState(() => _index = 2); }),
                _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: _index == 3, onTap: () { HapticFeedback.lightImpact(); setState(() => _index = 3); }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA),
      body: Center(
        child: Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 18)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? AppColors.primary : (isDark ? Colors.white38 : Colors.black38), size: 22),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
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
  List<Map<String, dynamic>> _banners = [];
  bool _loadingCourses = true;
  bool _loadingBanners = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadBanners(), _loadFeaturedCourses()]);
  }

  Future<void> _loadBanners() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.selectionlab.online/api/banners'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _banners = List<Map<String, dynamic>>.from(data['banners']);
          _loadingBanners = false;
        });
      } else {
        setState(() => _loadingBanners = false);
      }
    } catch (_) {
      setState(() => _loadingBanners = false);
    }
  }

  Future<void> _loadFeaturedCourses() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.selectionlab.online/api/courses/featured'))
          .timeout(const Duration(seconds: 10));
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openCourse(Map<String, dynamic> c) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: c)));
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
                // Logo — no white box
                Image.asset('assets/images/logo.png', height: 34),
                const SizedBox(width: 8),
                Text(
                  'Selection Lab',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search_rounded, color: isDark ? Colors.white70 : Colors.black54),
                onPressed: () => HapticFeedback.lightImpact(),
              ),
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                onPressed: widget.onToggleTheme,
              ),
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white70 : Colors.black54),
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
                  const SizedBox(height: 3),
                  Text(
                    "Let's learn something new today!",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── BANNER ──
                  if (_loadingBanners)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    )
                  else if (_banners.isEmpty)
                    _StaticBannerSlider(onLaunchUrl: _launchUrl)
                  else
                    _DynamicBannerSlider(banners: _banners, onLaunchUrl: _launchUrl),

                  const SizedBox(height: 24),

                  // ── EXPLORE SECTION HEADER ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text('Explore', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('View All', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── QUICK GRID ──
                  _QuickGrid(cardBg: cardBg, isDark: isDark),

                  const SizedBox(height: 24),

                  // ── FEATURED COURSES HEADER ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text('Featured Courses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Text('See All →', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── FEATURED COURSES — horizontal card style ──
                  if (_loadingCourses)
                    _shimmerCard(isDark)
                  else if (_featuredCourses.isEmpty)
                    Center(child: Text('No featured courses yet', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)))
                  else
                    Column(
                      children: _featuredCourses.map((c) {
                        final price = c['price']?.toString() ?? '0';
                        final originalPrice = c['original_price']?.toString();
                        final hasDiscount = originalPrice != null && originalPrice != price && double.tryParse(originalPrice) != null;
                        final discount = hasDiscount
                            ? ((1 - double.parse(price) / double.parse(originalPrice!)) * 100).round()
                            : 0;

                        return GestureDetector(
                          onTap: () => _openCourse(c),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black26 : Colors.black.withOpacity(0.07),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                                  child: Stack(
                                    children: [
                                      c['thumbnail_url'] != null
                                          ? Image.network(
                                              c['thumbnail_url'],
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 120, height: 120,
                                                color: AppColors.primary.withOpacity(0.15),
                                                child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 36),
                                              ),
                                            )
                                          : Container(
                                              width: 120, height: 120,
                                              color: AppColors.primary.withOpacity(0.15),
                                              child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 36),
                                            ),
                                      if (hasDiscount)
                                        Positioned(
                                          top: 8, left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                                            child: Text('$discount% OFF', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Details
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['title'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                        ),
                                        const SizedBox(height: 6),
                                        // Rating row
                                        Row(
                                          children: [
                                            Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                            const SizedBox(width: 3),
                                            Text('4.8', style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600)),
                                            const SizedBox(width: 4),
                                            Text('(1250+ Students)', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text('₹$price', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                            if (hasDiscount) ...[
                                              const SizedBox(width: 6),
                                              Text('₹$originalPrice', style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () => _openCourse(c),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(0, 32),
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: const Text('Get this course', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),

                  // ── CONNECT WITH US ──
                  Row(
                    children: [
                      Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Text('Connect With Us', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ConnectSection(cardBg: cardBg, onLaunchUrl: _launchUrl),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerCard(bool isDark) {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ── STATIC BANNER SLIDER ──────────────────────────────────────────────────────

class _StaticBannerSlider extends StatefulWidget {
  final Future<void> Function(String) onLaunchUrl;
  const _StaticBannerSlider({required this.onLaunchUrl});

  @override
  State<_StaticBannerSlider> createState() => _StaticBannerSliderState();
}

class _StaticBannerSliderState extends State<_StaticBannerSlider> {
  final PageController _ctrl = PageController();
  int _current = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Go Premium!',
      'subtitle': 'Unlock all exams for\njust ₹99/month',
      'colors': [Color(0xFFFF6B00), Color(0xFFFF8E53)],
      'btnText': 'Get Now',
      'icon': Icons.workspace_premium_rounded,
    },
    {
      'title': 'Mock Tests',
      'subtitle': 'Practice with real\nexam pattern questions',
      'colors': [Color(0xFF1A237E), Color(0xFF3949AB)],
      'btnText': 'Start Now',
      'icon': Icons.assignment_rounded,
    },
    {
      'title': 'Study Material',
      'subtitle': 'Access notes & PDFs\nfor all exams',
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
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
          height: 160,
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final b = _banners[index];
              final colors = b['colors'] as List<Color>;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: colors[0].withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      right: -20, top: -20,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                    Positioned(
                      right: 30, bottom: -30,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)),
                      ),
                    ),
                    // Big icon right side
                    Positioned(
                      right: 16, top: 0, bottom: 0,
                      child: Icon(b['icon'] as IconData, color: Colors.white.withOpacity(0.25), size: 80),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(b['title'] as String,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(b['subtitle'] as String,
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, height: 1.4)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => HapticFeedback.lightImpact(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: colors[0],
                              minimumSize: const Size(80, 30),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(b['btnText'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

// ── DYNAMIC BANNER SLIDER ─────────────────────────────────────────────────────

class _DynamicBannerSlider extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  final Future<void> Function(String) onLaunchUrl;
  const _DynamicBannerSlider({required this.banners, required this.onLaunchUrl});

  @override
  State<_DynamicBannerSlider> createState() => _DynamicBannerSliderState();
}

class _DynamicBannerSliderState extends State<_DynamicBannerSlider> {
  final PageController _ctrl = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_current + 1) % widget.banners.length;
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
          height: 160,
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final b = widget.banners[index];
              final startColor = Color(int.parse((b['gradient_start'] ?? '#FF6B00').replaceAll('#', '0xFF')));
              final endColor = Color(int.parse((b['gradient_end'] ?? '#FF8E53').replaceAll('#', '0xFF')));
              return GestureDetector(
                onTap: () { if (b['redirect_url'] != null) widget.onLaunchUrl(b['redirect_url']); },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [startColor, endColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: startColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20, top: -20,
                        child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08))),
                      ),
                      if (b['image_url'] != null)
                        Positioned(
                          right: 0, top: 0, bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                            child: Image.network(b['image_url'], width: 140, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(b['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                            if (b['subtitle'] != null) ...[
                              const SizedBox(height: 4),
                              Text(b['subtitle'], style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                            ],
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () { if (b['redirect_url'] != null) widget.onLaunchUrl(b['redirect_url']); },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: startColor,
                                minimumSize: const Size(80, 30),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text(b['btn_text'] ?? 'Know More', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.banners.length,
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
      {'icon': Icons.book_rounded, 'label': 'Free Course', 'sub': 'Learn for free', 'colors': [Color(0xFF2E7D32), Color(0xFF4CAF50)]},
      {'icon': Icons.lock_open_rounded, 'label': 'Paid Course', 'sub': 'Premium content', 'colors': [Color(0xFFBF360C), Color(0xFFFF6B00)]},
      {'icon': Icons.assignment_rounded, 'label': 'Mock Test', 'sub': 'Test your skills', 'colors': [Color(0xFF0D47A1), Color(0xFF2196F3)]},
      {'icon': Icons.play_circle_rounded, 'label': 'Videos', 'sub': 'Watch lectures', 'colors': [Color(0xFF880E4F), Color(0xFFE91E63)]},
      {'icon': Icons.history_edu_rounded, 'label': "PYQ's", 'sub': 'Previous year papers', 'colors': [Color(0xFF4A148C), Color(0xFF9C27B0)]},
      {'icon': Icons.quiz_rounded, 'label': 'Free Quiz', 'sub': 'Practice & improve', 'colors': [Color(0xFF006064), Color(0xFF00BCD4)]},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final colors = item['colors'] as List<Color>;
        return GestureDetector(
          onTap: () => HapticFeedback.lightImpact(),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors[0].withOpacity(isDark ? 0.7 : 0.85), colors[1].withOpacity(isDark ? 0.5 : 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item['icon'] as IconData, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  item['label'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  item['sub'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.75)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── CONNECT SECTION ───────────────────────────────────────────────────────────

class _ConnectSection extends StatelessWidget {
  final Color cardBg;
  final Future<void> Function(String) onLaunchUrl;
  const _ConnectSection({required this.cardBg, required this.onLaunchUrl});

  @override
  Widget build(BuildContext context) {
    final links = [
      {'icon': Icons.play_circle_filled_rounded, 'label': 'YouTube', 'sub': 'Subscribe', 'color': const Color(0xFFFF0000), 'url': 'https://youtube.com/@selection_lab'},
      {'icon': Icons.chat_rounded, 'label': 'WhatsApp', 'sub': 'Join Channel', 'color': const Color(0xFF25D366), 'url': 'https://whatsapp.com/channel/0029Vb6Z3mEEawdkjDg60a1w'},
      {'icon': Icons.send_rounded, 'label': 'Telegram', 'sub': 'Join Channel', 'color': const Color(0xFF0088CC), 'url': 'https://t.me/englishbynikki07'},
    ];
    return Row(
      children: List.generate(links.length, (i) {
        final l = links[i];
        final color = l['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => onLaunchUrl(l['url'] as String),
            child: Container(
              margin: EdgeInsets.only(right: i < links.length - 1 ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(l['icon'] as IconData, color: color, size: 26),
                  const SizedBox(height: 4),
                  Text(l['label'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                  Text(l['sub'] as String, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7))),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
                                         
