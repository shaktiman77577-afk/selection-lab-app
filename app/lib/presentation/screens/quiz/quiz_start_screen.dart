import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import 'quiz_play_screen.dart';

class QuizStartScreen extends StatefulWidget {
  final int examId;
  final int subjectId;
  final int? topicId;
  final String quizTitle;
  const QuizStartScreen({super.key, required this.examId, required this.subjectId, this.topicId, required this.quizTitle});

  @override
  State<QuizStartScreen> createState() => _QuizStartScreenState();
}

class _QuizStartScreenState extends State<QuizStartScreen> {
  int _selectedTimer = 45; // default 45 sec
  int _questionCount = 10;

  final List<Map<String, dynamic>> _timerOptions = [
    {'label': '30 sec', 'value': 30, 'desc': 'Fast'},
    {'label': '45 sec', 'value': 45, 'desc': 'Normal'},
    {'label': '60 sec', 'value': 60, 'desc': 'Relaxed'},
    {'label': 'No Timer', 'value': 0, 'desc': 'Practice'},
  ];

  final List<int> _countOptions = [5, 10, 15, 20];

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
        title: Text('Quiz Setup', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Quiz title card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFFFF8E00)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.quizTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
                      const SizedBox(height: 2),
                      const Text('Configure and start', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── TIMER SELECTION ──
          Text('Timer Per Question', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
            ),
            itemCount: _timerOptions.length,
            itemBuilder: (context, i) {
              final opt = _timerOptions[i];
              final selected = _selectedTimer == opt['value'];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedTimer = opt['value']);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12), width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(opt['label'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: selected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                      Text(opt['desc'], style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : (isDark ? Colors.white38 : Colors.black38))),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),

          // ── QUESTION COUNT ──
          Text('Number of Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Row(
            children: _countOptions.map((count) {
              final selected = _questionCount == count;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _questionCount = count);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12), width: 2),
                    ),
                    child: Center(
                      child: Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: selected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),

          // ── START BUTTON ──
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => QuizPlayScreen(
                  examId: widget.examId,
                  subjectId: widget.subjectId,
                  topicId: widget.topicId,
                  timerSeconds: _selectedTimer,
                  questionCount: _questionCount,
                  quizTitle: widget.quizTitle,
                ),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: const Text('Start Quiz', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
