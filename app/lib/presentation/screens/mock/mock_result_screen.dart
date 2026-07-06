// lib/presentation/screens/mock/mock_result_screen.dart
//
// Mock result — score, correct/wrong/skipped, accuracy, pass/fail,
// plus per-question solutions (your answer vs correct + explanation).

import 'package:flutter/material.dart';
import '../descriptive/descriptive_theme.dart';

class MockResultScreen extends StatelessWidget {
  final String title;
  final Map<String, dynamic> result;
  final List<Map<String, dynamic>> questions;
  final Map<int, String> answers;

  const MockResultScreen({
    super.key,
    required this.title,
    required this.result,
    required this.questions,
    required this.answers,
  });

  double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final score = _d(result['score']);
    final totalMarks = _d(result['total_marks']);
    final correct = result['correct'] ?? 0;
    final wrong = result['wrong'] ?? 0;
    final skipped = result['skipped'] ?? 0;
    final accuracy = _d(result['accuracy']);
    final passed = result['passed'] == true;
    final pct = totalMarks > 0 ? (score / totalMarks) : 0.0;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Result',
            style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text('Done',
                style: TextStyle(
                    color: kDGold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // score card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [kDNavy, kDNavy2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: CircularProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          strokeWidth: 11,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              passed ? kDGreen : kDGold),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_fmt(score),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0)),
                          Text('of ${_fmt(totalMarks)}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                      color: (passed ? kDGreen : const Color(0xFFC0392B))
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(passed ? '✓ Passed' : 'Not passed',
                      style: TextStyle(
                          color: passed ? kDPurchasedFg : const Color(0xFFFFB3AB),
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // stats row
          Row(
            children: [
              _stat(t, 'Correct', '$correct', kDGreen),
              const SizedBox(width: 10),
              _stat(t, 'Wrong', '$wrong', const Color(0xFFC0392B)),
              const SizedBox(width: 10),
              _stat(t, 'Skipped', '$skipped', t.muted),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat(t, 'Accuracy', '${_fmt(accuracy)}%', kDGold),
              const SizedBox(width: 10),
              _stat(t, 'Total Qs', '${result['total'] ?? questions.length}',
                  t.text2),
            ],
          ),
          const SizedBox(height: 22),
          Text('Solutions',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
          const SizedBox(height: 12),
          ...questions.asMap().entries.map((e) => _solution(e.key + 1, e.value, t)),
        ],
      ),
    );
  }

  Widget _stat(DT t, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(14),
            boxShadow: t.shadow),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: t.muted)),
          ],
        ),
      ),
    );
  }

  Widget _solution(int index, Map<String, dynamic> q, DT t) {
    final qid = q['id'] as int;
    final your = answers[qid];
    final correct = (q['correct_answer'] ?? '').toString();
    final isCorrect = your != null && your == correct;
    final isSkipped = your == null || your.isEmpty;

    final letters = ['A', 'B', 'C', 'D'];
    final keys = ['option_a', 'option_b', 'option_c', 'option_d'];

    Color statusColor = isSkipped
        ? t.muted
        : (isCorrect ? kDGreen : const Color(0xFFC0392B));
    String statusText =
        isSkipped ? 'Skipped' : (isCorrect ? 'Correct' : 'Wrong');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(14),
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Q$index',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: t.muted)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(q['question']?.toString() ?? '',
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: t.text)),
          const SizedBox(height: 12),
          // options with correct/your highlight
          ...List.generate(4, (i) {
            final letter = letters[i];
            final text = (q[keys[i]] ?? '').toString();
            if (text.isEmpty) return const SizedBox.shrink();
            final isRight = letter == correct;
            final isYour = letter == your;
            Color? bg;
            Color border = t.line;
            if (isRight) {
              bg = kDGreen.withOpacity(0.12);
              border = kDGreen;
            } else if (isYour && !isCorrect) {
              bg = const Color(0xFFC0392B).withOpacity(0.10);
              border = const Color(0xFFC0392B);
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: bg ?? t.card,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$letter. ',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: t.text2)),
                  Expanded(
                      child: Text(text,
                          style: TextStyle(fontSize: 13.5, color: t.text))),
                  if (isRight)
                    const Icon(Icons.check_circle,
                        color: kDGreen, size: 18),
                  if (isYour && !isCorrect)
                    const Icon(Icons.cancel,
                        color: Color(0xFFC0392B), size: 18),
                ],
              ),
            );
          }),
          if ((q['explanation']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: kDGold.withOpacity(0.10),
                  border: Border.all(color: kDGold.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 Explanation',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: t.text)),
                  const SizedBox(height: 5),
                  Text(q['explanation'].toString(),
                      style: TextStyle(
                          fontSize: 13, height: 1.5, color: t.text2)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
