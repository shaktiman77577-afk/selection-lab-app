import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import 'quiz_topics_screen.dart';

class QuizSubjectsScreen extends StatefulWidget {
  final int examId;
  final String examName;
  const QuizSubjectsScreen({super.key, required this.examId, required this.examName});

  @override
  State<QuizSubjectsScreen> createState() => _QuizSubjectsScreenState();
}

class _QuizSubjectsScreenState extends State<QuizSubjectsScreen> {
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.apiUrl}/exams/${widget.examId}/subjects')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _subjects = List<Map<String, dynamic>>.from(data['subjects'] ?? []);
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  final List<IconData> _icons = [
    Icons.menu_book_rounded, Icons.public_rounded, Icons.calculate_rounded,
    Icons.science_rounded, Icons.history_edu_rounded, Icons.lightbulb_rounded,
  ];
  final List<Color> _colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(widget.examName, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? Center(child: Text('No subjects yet', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _subjects.length,
                  itemBuilder: (context, i) {
                    final s = _subjects[i];
                    final color = _colors[i % _colors.length];
                    final icon = _icons[i % _icons.length];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => QuizTopicsScreen(
                            examId: widget.examId,
                            subjectId: s['id'],
                            subjectName: s['name'] ?? 'Subject',
                          ),
                        ));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                              child: Icon(icon, color: color, size: 32),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                s['name'] ?? '',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
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
