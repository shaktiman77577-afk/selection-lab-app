import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../courses/course_detail_screen.dart';
import '../mock/mock_series_detail_screen.dart';
import '../descriptive/descriptive_series_detail_screen.dart';

class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({super.key});

  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

/// A single unified item in the My Learning list — can be a course,
/// a mock series, or a descriptive series.
class _Item {
  final String kind; // 'course' | 'mock' | 'descriptive'
  final Map<String, dynamic> data;
  _Item(this.kind, this.data);
}

class _MyLearningScreenState extends State<MyLearningScreen> {
  List<_Item> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final rawId = auth.user?['id'];
    final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    if (userId == null) {
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }

    final base = AppConstants.apiUrl;
    final results = await Future.wait([
      _fetchCourses(base, userId),
      _fetchMock(base, userId),
      _fetchDescriptive(base, userId),
    ]);

    final combined = <_Item>[
      ...results[0],
      ...results[1],
      ...results[2],
    ];

    if (!mounted) return;
    setState(() {
      _items = combined;
      _loading = false;
    });
  }

  Future<List<_Item>> _fetchCourses(String base, int userId) async {
    try {
      final res = await http
          .get(Uri.parse('$base/users/$userId/courses'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(data['courses'] ?? []);
        return list.map((c) => _Item('course', c)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<_Item>> _fetchMock(String base, int userId) async {
    try {
      final res = await http
          .get(Uri.parse('$base/mock-tests/series?user_id=$userId'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(data['series'] ?? []);
        return list
            .where((s) => s['is_purchased'] == true)
            .map((s) => _Item('mock', s))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<_Item>> _fetchDescriptive(String base, int userId) async {
    try {
      final res = await http
          .get(Uri.parse('$base/descriptive/series?user_id=$userId'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(data['series'] ?? []);
        return list
            .where((s) => s['is_purchased'] == true)
            .map((s) => _Item('descriptive', s))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  void _open(_Item item) {
    HapticFeedback.lightImpact();
    Widget screen;
    switch (item.kind) {
      case 'mock':
        screen = MockSeriesDetailScreen(seriesId: item.data['id'] as int);
        break;
      case 'descriptive':
        screen = DescriptiveSeriesDetailScreen(seriesId: item.data['id'] as int);
        break;
      case 'course':
      default:
        screen = CourseDetailScreen(course: item.data);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('My Learning',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: _emptyState(isDark)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, i) =>
                        _card(_items[i], isDark, cardBg),
                  ),
                ),
    );
  }

  // Per-kind label + colour for the badge
  ({String label, Color color}) _badge(String kind) {
    switch (kind) {
      case 'mock':
        return (label: 'MOCK SERIES', color: Colors.blue);
      case 'descriptive':
        return (label: 'DESCRIPTIVE', color: Colors.deepPurple);
      case 'course':
      default:
        return (label: 'COURSE', color: Colors.green);
    }
  }

  Widget _card(_Item item, bool isDark, Color cardBg) {
    final c = item.data;
    final badge = _badge(item.kind);
    final thumb = c['thumbnail_url']?.toString();
    final hasThumb = thumb != null && thumb.isNotEmpty;

    return GestureDetector(
      onTap: () => _open(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: isDark ? Colors.black26 : Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: hasThumb
                  ? Image.network(thumb, width: double.infinity, height: 150,
                      fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumbFallback())
                  : _thumbFallback(),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: badge.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(badge.label,
                            style: TextStyle(
                                color: badge.color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(c['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('ENROLLED',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text('Continue',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Icon(Icons.arrow_forward_rounded,
                          color: AppColors.primary, size: 16),
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

  Widget _thumbFallback() => Container(
        height: 150,
        width: double.infinity,
        color: AppColors.primary.withOpacity(0.15),
        child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 40),
      );

  Widget _emptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle),
              child:
                  Icon(Icons.school_rounded, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No purchases yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(
                'Your enrolled courses, mock series and descriptive series will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}
