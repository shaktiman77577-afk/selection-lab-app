// lib/presentation/screens/exams/exam_list_screen.dart
//
// Saare exams (Nov 2026) — website ke /exams jaisa. Category chips, upar
// search box, neeche 2-2 ke grid me exam tiles. Tile dabao to exam page.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ui.dart';
import 'exam_widgets.dart';

class ExamListScreen extends StatefulWidget {
  /// Home ne pehle se mangwa liya ho to wahi data (turant dikhe)
  final Map<String, dynamic>? initial;
  const ExamListScreen({super.key, this.initial});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _cat = 0;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
    _loading = examMaps(_data?['exams']).isEmpty;
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await http
          .get(Uri.parse('${AppConstants.apiUrl}/exam-pages/?platform=app'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) throw Exception('status');
      final d = jsonDecode(r.body);
      if (!mounted) return;
      setState(() {
        _data = d is Map ? Map<String, dynamic>.from(d) : null;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (examMaps(_data?['exams']).isEmpty) {
          _error = 'Could not load exams. Check your internet.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final exams = examMaps(_data?['exams']);

    final cats = <String>[];
    for (final e in exams) {
      final s = '${e['category'] ?? ''}';
      if (s.isNotEmpty && !cats.contains(s)) cats.add(s);
    }
    final options = ['All', ...cats];
    final sel = _cat.clamp(0, options.length - 1);
    final q = _q.trim().toLowerCase();
    final shown = exams.where((e) {
      if (sel > 0 && '${e['category']}' != options[sel]) return false;
      if (q.isEmpty) return true;
      return '${e['name'] ?? ''} ${e['short_name'] ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();

    final state = ListStateView(
      loading: _loading,
      error: _error,
      empty: shown.isEmpty,
      emptyText: q.isNotEmpty
          ? 'No exam found for "$_q".'
          : 'Exam pages are coming soon.',
      emptyIcon: Icons.school_outlined,
      onRetry: () {
        setState(() {
          _loading = true;
          _error = null;
        });
        _load();
      },
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('All Exams')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                    'Pick your exam to see every mock test, course, '
                    'descriptive and typing test for it in one place.',
                    style:
                        TextStyle(fontSize: 13, height: 1.5, color: t.muted)),
              ),
            ),
            if (exams.length > 6)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      onChanged: (s) => setState(() => _q = s),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(color: t.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search exam',
                        contentPadding: EdgeInsets.zero,
                        prefixIcon: Icon(Icons.search_rounded,
                            color: t.muted, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            if (options.length > 2)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilterChips(
                    options: options,
                    selected: sel,
                    onChanged: (i) => setState(() => _cat = i),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            if (state.show)
              SliverToBoxAdapter(child: state)
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisExtent: 168,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => ExamTile(exam: shown[i]),
                    childCount: shown.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
