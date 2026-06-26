import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
      const DashboardTab(),
      const ExamCategoriesScreen(),
      ProfileScreen(onToggleTheme: widget.onToggleTheme),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
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
            Icon(icon, color: selected ? AppColors.primary : Colors.white54, size: 24),
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

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0F0F0F),
            floating: true,
            snap: true,
          title: Text("Hello, ${user?['name'] ?? 'Student'}!", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () { HapticFeedback.lightImpact(); },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!auth.hasMembership) _PremiumBanner(),
                  const SizedBox(height: 24),
                  const Text("Quick Practice", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _Card(icon: Icons.subject_rounded, title: "Subject Wise", subtitle: "By subject", color: const Color(0xFFFF6C63), onTap: () { HapticFeedback.lightImpact(); }),
                      _Card(icon: Icons.assignment_rounded, title: "Mock Tests", subtitle: "Full tests", color: const Color(0xFF00BFA5), onTap: () { HapticFeedback.lightImpact(); }),
                      _Card(icon: Icons.shuffle_rounded, title: "Mix Quiz", subtitle: "Random", color: const Color(0xFFFF6B6B), onTap: () { HapticFeedback.lightImpact(); }),
                      _Card(icon: Icons.bookmark_rounded, title: "Bookmarks", subtitle: "Saved", color: const Color(0xFFFFD700), onTap: () { HapticFeedback.lightImpact(); }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("Your Stats", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
              Expanded(child: _Stat(title: "Points", value: "${user?['points'] ?? 0}", icon: Icons.stars_rounded, color: AppColors.warning)),
                      const SizedBox(width: 12),
              Expanded(child: _Stat(title: "Streak", value: "${user?['streak_days'] ?? 0} days", icon: Icons.local_fire_department_rounded, color: AppColors.primary)),
                    ],
                  ),
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

class _PremiumBanner extends StatefulWidget {
  @override
  State<_PremiumBanner> createState() => _PremiumBannerState();
}

class _PremiumBannerState extends State<_PremiumBanner> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Get Premium!',
      'subtitle': 'Unlock all exams for just Rs.99/month',
      'colors': [Color(0xFFFF6B00), Color(0xFFFF8E53), Color(0xFFFF4E7A)],
      'btnText': 'Get Now',
    },
    {
      'title': 'Mock Tests',
      'subtitle': 'Practice with real exam pattern questions',
      'colors': [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
      'btnText': 'Start Now',
    },
    {
      'title': 'Study Material',
      'subtitle': 'Access notes & PDFs for all exams',
      'colors': [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
      'btnText': 'Explore',
    },
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;
    final next = (_currentPage + 1) % _banners.length;
    _pageController.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    Future.delayed(const Duration(seconds: 3), _autoScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 110,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
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
                  boxShadow: [BoxShadow(color: (b['colors'] as List<Color>)[0].withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(b['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(b['subtitle'] as String, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () { HapticFeedback.lightImpact(); },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: (b['colors'] as List<Color>)[0], minimumSize: const Size(80, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: Text(b['btnText'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _currentPage == i ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: _currentPage == i ? AppColors.primary : Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        ),
      ],
    );
  }
}

class _Card extends StatefulWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _Card({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withOpacity(0.25)),
            boxShadow: [BoxShadow(color: widget.color.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: widget.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.color)),
                  Text(widget.subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _Stat({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }
}
