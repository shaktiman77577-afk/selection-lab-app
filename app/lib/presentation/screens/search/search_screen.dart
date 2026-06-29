import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../courses/course_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _allCourses = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  String _query = '';

  final List<String> _quickFilters = ['Free', 'Paid', 'Mock Test', 'Video', 'PYQ'];

  @override
  void initState() {
    super.initState();
    _loadAllCourses();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAllCourses() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.selectionlab.online/api/courses'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _allCourses = List<Map<String, dynamic>>.from(data['courses']);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _search(String query) {
    setState(() {
      _query = query;
      if (query.trim().isEmpty) {
        _results = [];
        return;
      }
      final q = query.toLowerCase();
      _results = _allCourses.where((c) {
        final title = (c['title'] ?? '').toString().toLowerCase();
        final type = (c['course_type'] ?? '').toString().toLowerCase();
        final desc = (c['description'] ?? '').toString().toLowerCase();
        return title.contains(q) || type.contains(q) || desc.contains(q);
      }).toList();
    });
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
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _search,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search courses, mock tests...',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 22),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Quick filters
          if (_query.isEmpty)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickFilters.length,
                itemBuilder: (context, i) {
                  final f = _quickFilters[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(f),
                      labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      onPressed: () {
                        _controller.text = f;
                        _search(f);
                      },
                    ),
                  );
                },
              ),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _query.isEmpty
                    ? _emptyState(isDark, Icons.search_rounded, 'Search for courses', 'Type a course name, exam, or category')
                    : _results.isEmpty
                        ? _emptyState(isDark, Icons.search_off_rounded, 'No results found', 'Try different keywords')
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            itemBuilder: (context, i) => _resultCard(_results[i], isDark, cardBg),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> c, bool isDark, Color cardBg) {
    final price = c['price']?.toString() ?? '0';
    final isFree = price == '0' || price == '0.0';

    return GestureDetector(
      onTap: () => _openCourse(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: c['thumbnail_url'] != null
                  ? Image.network(c['thumbnail_url'], width: 90, height: 70, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder())
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(c['course_type'] ?? '', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                  const SizedBox(height: 6),
                  Text(isFree ? 'FREE' : 'Rs.$price',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isFree ? Colors.green : AppColors.primary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 90, height: 70,
      color: AppColors.primary.withOpacity(0.15),
      child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 28),
    );
  }

  Widget _emptyState(bool isDark, IconData icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }
}
