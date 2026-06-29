import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class MockTestResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final String testTitle;
  const MockTestResultScreen({super.key, required this.result, required this.testTitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final score = result['score'] ?? 0;
    final totalMarks = result['total_marks'] ?? 0;
    final correct = result['correct'] ?? 0;
    final wrong = result['wrong'] ?? 0;
    final skipped = result['skipped'] ?? 0;
    final total = result['total'] ?? 0;
    final accuracy = result['accuracy'] ?? 0;
    final passed = result['passed'] == true;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            // Pass/Fail badge
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (passed ? Colors.green : Colors.red).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(passed ? Icons.emoji_events_rounded : Icons.replay_rounded, size: 60, color: passed ? Colors.green : Colors.red),
              ),
            ),
            const SizedBox(height: 18),
            Center(child: Text(passed ? 'Congratulations!' : 'Keep Practicing!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
            const SizedBox(height: 4),
            Center(child: Text(testTitle, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45))),
            const SizedBox(height: 24),

            // Score card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: passed ? [Colors.green, Colors.teal] : [AppColors.primary, const Color(0xFFFF8E00)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('Your Score', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('$score / $totalMarks', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                    child: Text(passed ? 'PASSED' : 'FAILED', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats
            Row(children: [
              _statBox('Correct', '$correct', Colors.green, Icons.check_circle_rounded, cardBg, isDark),
              const SizedBox(width: 12),
              _statBox('Wrong', '$wrong', Colors.red, Icons.cancel_rounded, cardBg, isDark),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _statBox('Skipped', '$skipped', Colors.orange, Icons.skip_next_rounded, cardBg, isDark),
              const SizedBox(width: 12),
              _statBox('Accuracy', '$accuracy%', AppColors.primary, Icons.track_changes_rounded, cardBg, isDark),
            ]),
            const SizedBox(height: 30),

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
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}
