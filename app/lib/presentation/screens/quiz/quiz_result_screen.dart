import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class QuizResultScreen extends StatelessWidget {
  final int total;
  final int correct;
  final int wrong;
  final int skipped;
  final String quizTitle;
  const QuizResultScreen({
    super.key,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.quizTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final accuracy = total > 0 ? (correct / total * 100) : 0.0;
    final attempted = correct + wrong;

    String message;
    IconData emoji;
    Color msgColor;
    if (accuracy >= 80) {
      message = 'Excellent!';
      emoji = Icons.emoji_events_rounded;
      msgColor = Colors.amber;
    } else if (accuracy >= 50) {
      message = 'Good Job!';
      emoji = Icons.thumb_up_rounded;
      msgColor = Colors.green;
    } else {
      message = 'Keep Practicing!';
      emoji = Icons.trending_up_rounded;
      msgColor = AppColors.primary;
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            // Trophy/Result icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: msgColor.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(emoji, size: 64, color: msgColor),
              ),
            ),
            const SizedBox(height: 20),
            Center(child: Text(message, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
            const SizedBox(height: 4),
            Center(child: Text(quizTitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45))),
            const SizedBox(height: 30),

            // Accuracy circle
            Center(
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFFFF8E00)]),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${accuracy.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('Accuracy', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Stats grid
            Row(
              children: [
                _statBox('Correct', '$correct', Colors.green, Icons.check_circle_rounded, cardBg, isDark),
                const SizedBox(width: 12),
                _statBox('Wrong', '$wrong', Colors.red, Icons.cancel_rounded, cardBg, isDark),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statBox('Skipped', '$skipped', Colors.orange, Icons.skip_next_rounded, cardBg, isDark),
                const SizedBox(width: 12),
                _statBox('Total', '$total', AppColors.primary, Icons.quiz_rounded, cardBg, isDark),
              ],
            ),
            const SizedBox(height: 30),

            // Buttons
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Try Another Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color, IconData icon, Color cardBg, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}
