import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import 'mock_test_player_screen.dart';

class MockTestInstructionsScreen extends StatefulWidget {
  final Map<String, dynamic> mockTest;
  const MockTestInstructionsScreen({super.key, required this.mockTest});

  @override
  State<MockTestInstructionsScreen> createState() => _MockTestInstructionsScreenState();
}

class _MockTestInstructionsScreenState extends State<MockTestInstructionsScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final t = widget.mockTest;

    final totalQ = t['total_questions'] ?? 0;
    final duration = t['duration_minutes'] ?? 0;
    final totalMarks = t['total_marks'] ?? 0;
    final negMark = t['negative_marking'] ?? 0;
    final posMarks = totalQ > 0 ? (totalMarks / totalQ) : 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Test title
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFFFF8E00)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _headerStat('$totalQ', 'Questions'),
                    _headerStat('$duration', 'Minutes'),
                    _headerStat('$totalMarks', 'Marks'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Marking scheme
          Text('Marking Scheme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _markRow('Correct Answer', '+$posMarks', Colors.green, isDark),
                const Divider(height: 20),
                _markRow('Wrong Answer', '-$negMark', Colors.red, isDark),
                const Divider(height: 20),
                _markRow('Unattempted', '0', Colors.grey, isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Instructions
          Text('Important Instructions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _instr('The test duration is $duration minutes. Timer starts as soon as you begin.', isDark),
                _instr('The test will auto-submit when time runs out.', isDark),
                _instr('You can navigate between questions using the question palette.', isDark),
                _instr('Use "Mark for Review" to flag questions to revisit later.', isDark),
                _instr('"Save & Next" saves your answer and moves forward.', isDark),
                _instr('"Clear Response" removes your selected answer.', isDark, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Color legend
          Text('Question Palette Legend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _legend(Colors.grey.shade400, 'Not Visited', isDark),
                _legend(Colors.red, 'Not Answered', isDark),
                _legend(Colors.green, 'Answered', isDark),
                _legend(Colors.purple, 'Marked for Review', isDark),
                _legend(Colors.purple, 'Answered & Marked', isDark, hasTick: true, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Agree checkbox
          GestureDetector(
            onTap: () => setState(() => _agreed = !_agreed),
            child: Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: Text('I have read and understood all the instructions.',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Start button
          ElevatedButton(
            onPressed: _agreed
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (_) => MockTestPlayerScreen(mockTest: t),
                    ));
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Start Test', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _markRow(String label, String marks, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(marks, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _instr(String text, bool isDark, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white70 : Colors.black54))),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, bool isDark, {bool hasTick = false, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
              ),
              if (hasTick)
                Positioned(
                  bottom: -3, right: -3,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }
}
