// lib/presentation/screens/courses/course_list_screen.dart
//
// Redesign (Sep 2026): clean list, ProductCard. Kharide hue course par
// ENROLLED. Purana nakli "4.8 rating" hata diya — backend ye deta hi nahi tha.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import 'course_detail_screen.dart';

class CourseListScreen extends StatefulWidget {
  final String title;
  final String courseType;
  const CourseListScreen(
      {super.key, required this.title, required this.courseType});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  List<Map<String, dynamic>> _courses = [];
  Set<String> _mine = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  List<Map<String, dynamic>> _list(dynamic d) {
    final l = d is List ? d : (d is Map ? d['courses'] : null);
    if (l is! List) return [];
    return l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _courses.isEmpty;
      _error = null;
    });
    try {
      final uid = _uid;
      final res = await Future.wait([
        http
            .get(Uri.parse(
                '${AppConstants.apiUrl}/courses?course_type=${Uri.encodeComponent(widget.courseType)}'))
            .timeout(const Duration(seconds: 12)),
        if (uid != null)
          http
              .get(Uri.parse('${AppConstants.apiUrl}/courses/my/$uid'))
              .timeout(const Duration(seconds: 12)),
      ]);
      if (res[0].statusCode != 200) throw Exception('status');
      final courses = _list(jsonDecode(res[0].body));
      var mine = <String>{};
      if (res.length > 1 && res[1].statusCode == 200) {
        mine = _list(jsonDecode(res[1].body)).map((c) => '${c['id']}').toSet();
      }
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _mine = mine;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load courses. Check your internet.';
        _loading = false;
      });
    }
  }

  num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

  void _open(Map<String, dynamic> c) {
    HapticFeedback.lightImpact();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => CourseDetailScreen(course: c)));
  }

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final state = ListStateView(
      loading: _loading,
      error: _error,
      empty: _courses.isEmpty,
      emptyText: 'No ${widget.title.toLowerCase()} available yet.',
      emptyIcon: Icons.school_outlined,
      onRetry: _load,
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          children: [
            if (state.show)
              state
            else
              for (final c in _courses)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ProductCard(
                    img:
                        '${c['thumbnail_url_mobile'] ?? c['thumbnail_url'] ?? ''}',
                    title: '${c['title'] ?? c['name'] ?? 'Course'}',
                    meta: _num(c['students_count']) > 0
                        ? '${_num(c['students_count']).toInt()}+ students'
                        : '${c['course_type'] ?? ''}',
                    price: _num(c['price']),
                    original: _num(c['original_price']),
                    owned: _mine.contains('${c['id']}'),
                    fallbackIcon: Icons.school_rounded,
                    onTap: () => _open(c),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
