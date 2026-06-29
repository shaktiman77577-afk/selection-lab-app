import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../courses/course_detail_screen.dart';

class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({super.key});

  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _MyLearningScreenState extends State<MyLearningScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyCourses();
  }

  Future<void> _loadMyCourses() async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?['id'];
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }
      final res = await http
          .get(Uri.parse('https://api.selectionlab.online/api/users/$userId/courses'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _courses = List<Map<String, dynamic>>.from(data['courses']);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _openCourse(Map<String, dynamic> c) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: c)));
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
        title: Text('My Learning', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? _emptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadMyCourses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _courses.length,
                    itemBuilder: (context, i) => _courseCard(_courses[i], isDark, cardBg),
                  ),
                ),
    );
  }

  Widget _courseCard(Map<String, dynamic> c, bool isDark, Color cardBg) {
    return GestureDetector(
      onTap: () => _openCourse(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: c['thumbnail_url'] != null
                  ? Image.network(c['thumbnail_url'], width: double.infinity, height: 150, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 150, color: AppColors.primary.withOpacity(0.15),
                          child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 40)))
                  : Container(height: 150, color: AppColors.primary.withOpacity(0.15),
                      child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 40)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text('ENROLLED', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text('Continue', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 16),
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

  Widget _emptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.school_rounded, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No courses yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text('Your enrolled courses will appear here.\nExplore and start learning today!',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}
