import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import 'quiz_start_screen.dart';

class QuizTopicsScreen extends StatefulWidget {
  final int examId;
  final int subjectId;
  final String subjectName;
  const QuizTopicsScreen({super.key, required this.examId, required this.subjectId, required this.subjectName});

  @override
  State<QuizTopicsScreen> createState() => _QuizTopicsScreenState();
}

class _QuizTopicsScreenState extends State<QuizTopicsScreen> {
  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.apiUrl}/exams/subjects/${widget.subjectId}/topics')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _topics = List<Map<String, dynamic>>.from(data['topics'] ?? []);
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _startQuiz({int? topicId, required String title}) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => QuizStartScreen(
        examId: widget.examId,
        subjectId: widget.subjectId,
        topicId: topicId,
        quizTitle: title,
      ),
    ));
  }

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
        title: Text(widget.subjectName, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── MIX QUIZ (all topics) ──
                GestureDetector(
                  onTap: () => _startQuiz(title: 'Mix ${widget.subjectName} Quiz'),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFFFF8E00)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mix ${widget.subjectName} Quiz', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text('Random questions from all topics', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── TOPIC WISE ──
                Text('Topic Wise Practice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 12),

                if (_topics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Text('No topics available', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38))),
                  )
                else
                  ..._topics.asMap().entries.map((entry) {
                    final t = entry.value;
                    return GestureDetector(
                      onTap: () => _startQuiz(topicId: t['id'], title: t['name'] ?? 'Topic'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                              child: Center(child: Text('${entry.key + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(t['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                            ),
                            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black38),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
