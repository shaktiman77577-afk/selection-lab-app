import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import '../courses/course_detail_screen.dart';
import '../courses/course_list_screen.dart';
import '../search/search_screen.dart';
import '../learning/my_learning_screen.dart';
import '../notification/notifications_screen.dart';
import '../quiz/quiz_home_screen.dart';

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
      const MyLearningScreen(),
      const QuizHomeScreen(),
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
                _NavItem(icon: Icons.quiz_rounded, label: 'Quiz', selected: _index == 2, onTap: () { HapticFeedback.lightImpact(); setState(() => _index = 2); }),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_rounded, size: 48, color: AppColors.primary.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('$label\nComing Soon', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 16)),
          ],
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
  bool _loadingCourses = true;

  @override
  void initState() {
    super.initState();
    _loadFeaturedCourses();
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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final name = _capitalize(user?['name'] ?? 'Student');

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
            elevation: 0,
            floating: true,
            snap: true,
            title: Row(
              children: [
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
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                },
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
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                },
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── GREETING ──
                  Text(
                    "Hello, $name! 👋",
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
                  const SizedBox(height: 18),

                  // ── TOP THUMBNAIL CAROUSEL ──
                  if (_loadingCourses)
                    Container(
                      height: 170,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    )
                  else if (_featuredCourses.isEmpty)
                    const SizedBox()
                  else
                    _ThumbnailCarousel(
                      courses: _featuredCourses,
                      onOpen: _openCourse,
                    ),

                  const SizedBox(height: 22),

                  // ── EXPLORE HEADER ──
                  _SectionHeader(
                    title: 'Explore',
                    isDark: isDark,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('View All', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── QUICK GRID ──
                  _QuickGrid(isDark: isDark),

                  const SizedBox(height: 24),

                  // ── FEATURED COURSES HEADER ──
                  _SectionHeader(
                    title: 'Featured Courses',
                    isDark: isDark,
                    trailing: GestureDetector(
                      onTap: () {},
                      child: Text('See All →', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── FEATURED COURSES LIST ──
                  if (_loadingCourses)
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
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
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                                  child: Stack(
                                    children: [
                                      c['thumbnail_url'] != null
                                          ? Image.network(
                                              c['thumbnail_url'],
                                              width: 120, height: 120, fit: BoxFit.cover,
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
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['title'] ?? '',
                                          maxLines: 2, overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
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
                  _SectionHeader(title: 'Connect With Us', isDark: isDark),
                  const SizedBox(height: 14),
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
}

// ── SECTION HEADER ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  final Widget? trailing;
  const _SectionHeader({required this.title, required this.isDark, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── THUMBNAIL CAROUSEL (TOP) ──────────────────────────────────────────────────

class _ThumbnailCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> courses;
  final void Function(Map<String, dynamic>) onOpen;
  const _ThumbnailCarousel({required this.courses, required this.onOpen});

  @override
  State<_ThumbnailCarousel> createState() => _ThumbnailCarouselState();
}

class _ThumbnailCarouselState extends State<_ThumbnailCarousel> {
  final PageController _ctrl = PageController(viewportFraction: 0.92);
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || widget.courses.isEmpty) return;
      final next = (_current + 1) % widget.courses.length;
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
          height: 170,
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.courses.length,
            itemBuilder: (context, index) {
              final c = widget.courses[index];
              return GestureDetector(
                onTap: () => widget.onOpen(c),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        c['thumbnail_url'] != null
                            ? Image.network(
                                c['thumbnail_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.primary.withOpacity(0.2),
                                  child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 48),
                                ),
                              )
                            : Container(
                                color: AppColors.primary.withOpacity(0.2),
                                child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 48),
                              ),
                        // Bottom gradient + title
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 30, 14, 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                              ),
                            ),
                            child: Text(
                              c['title'] ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.courses.length,
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
  final bool isDark;
  const _QuickGrid({required this.isDark});

  void _handleTap(BuildContext context, String label) {
    HapticFeedback.lightImpact();
    String? title;
    String? courseType;
    switch (label) {
      case 'Free Course':
        title = 'Free Courses';
        courseType = 'Free Batch';
        break;
      case 'Paid Course':
        title = 'Paid Courses';
        courseType = 'Paid Batch';
        break;
      case 'Mock Test':
        title = 'Mock Tests';
        courseType = 'Mock Test';
        break;
      case 'Videos':
        title = 'Video Courses';
        courseType = 'Video Course';
        break;
      case "PYQ's":
        title = 'Previous Year Papers';
        courseType = 'PYQ';
        break;
      case 'Free Quiz':
        // Quiz system separate - show coming soon for now
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Free Quiz coming soon!'), duration: Duration(seconds: 1)),
        );
        return;
    }
    if (courseType != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseListScreen(title: title!, courseType: courseType!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.book_rounded, 'label': 'Free Course', 'sub': 'Learn for free', 'colors': [const Color(0xFF2E7D32), const Color(0xFF4CAF50)]},
      {'icon': Icons.lock_open_rounded, 'label': 'Paid Course', 'sub': 'Premium content', 'colors': [const Color(0xFFBF360C), const Color(0xFFFF6B00)]},
      {'icon': Icons.assignment_rounded, 'label': 'Mock Test', 'sub': 'Test your skills', 'colors': [const Color(0xFF0D47A1), const Color(0xFF2196F3)]},
      {'icon': Icons.play_circle_rounded, 'label': 'Videos', 'sub': 'Watch lectures', 'colors': [const Color(0xFF880E4F), const Color(0xFFE91E63)]},
      {'icon': Icons.history_edu_rounded, 'label': "PYQ's", 'sub': 'Previous year papers', 'colors': [const Color(0xFF4A148C), const Color(0xFF9C27B0)]},
      {'icon': Icons.quiz_rounded, 'label': 'Free Quiz', 'sub': 'Practice & improve', 'colors': [const Color(0xFF006064), const Color(0xFF00BCD4)]},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final colors = item['colors'] as List<Color>;
        return GestureDetector(
          onTap: () => _handleTap(context, item['label'] as String),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors[0], colors[1]],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: colors[1].withOpacity(0.45), blurRadius: 12, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item['icon'] as IconData, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 10),
                Text(item['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(item['sub'] as String, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.85))),
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
