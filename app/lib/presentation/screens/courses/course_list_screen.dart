import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import 'course_detail_screen.dart';

class CourseListScreen extends StatefulWidget {
  final String title;
  final String courseType;
  const CourseListScreen({super.key, required this.title, required this.courseType});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.selectionlab.online/api/courses?course_type=${Uri.encodeComponent(widget.courseType)}'))
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
        backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          widget.title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 56, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Text(
                        'No ${widget.title} available yet',
                        style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _courses.length,
                  itemBuilder: (context, i) {
                    final c = _courses[i];
                    final price = c['price']?.toString() ?? '0';
                    final originalPrice = c['original_price']?.toString();
                    final isFree = price == '0' || price == '0.0';
                    final hasDiscount = !isFree && originalPrice != null && originalPrice != price && double.tryParse(originalPrice) != null;
                    final discount = hasDiscount
                        ? ((1 - double.parse(price) / double.parse(originalPrice!)) * 100).round()
                        : 0;

                    return GestureDetector(
                      onTap: () => _openCourse(c),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Stack(
                                children: [
                                  c['thumbnail_url'] != null
                                      ? Image.network(
                                          c['thumbnail_url'],
                                          width: double.infinity,
                                          height: 160,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            height: 160,
                                            color: AppColors.primary.withOpacity(0.15),
                                            child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 48),
                                          ),
                                        )
                                      : Container(
                                          height: 160,
                                          color: AppColors.primary.withOpacity(0.15),
                                          child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 48),
                                        ),
                                  if (isFree)
                                    Positioned(
                                      top: 10, left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('FREE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    )
                                  else if (hasDiscount)
                                    Positioned(
                                      top: 10, left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                                        child: Text('$discount% OFF', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['title'] ?? '',
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                                      const SizedBox(width: 3),
                                      Text('4.8', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 4),
                                      Text('(1250+ Students)', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                                      const Spacer(),
                                      if (isFree)
                                        Text('FREE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))
                                      else ...[
                                        Text('₹$price', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        if (hasDiscount) ...[
                                          const SizedBox(width: 6),
                                          Text('₹$originalPrice', style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                        ],
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _openCourse(c),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: Text(isFree ? 'Start Learning' : 'View Course', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ),
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
    );
  }
}
