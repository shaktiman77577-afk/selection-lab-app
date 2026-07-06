// lib/presentation/screens/mock/mock_instructions_screen.dart
//
// Pre-exam instructions, then Start -> player.

import 'package:flutter/material.dart';
import '../descriptive/descriptive_theme.dart';
import 'mock_player_screen.dart';

class MockInstructionsScreen extends StatelessWidget {
  final Map<String, dynamic> test;
  const MockInstructionsScreen({super.key, required this.test});

  num _num(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final q = test['total_questions'] ?? 0;
    final dur = test['duration_minutes'] ?? 0;
    final marks = test['total_marks'] ?? 0;
    final neg = _num(test['negative_marking']);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text('Instructions',
            style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(test['title']?.toString() ?? 'Mock Test',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: t.text)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(14),
                boxShadow: t.shadow),
            child: Column(
              children: [
                _row(t, 'Questions', '$q'),
                _row(t, 'Duration', '$dur minutes'),
                _row(t, 'Total marks', '$marks'),
                _row(t, 'Negative marking',
                    neg > 0 ? '−$neg per wrong answer' : 'None'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Please read:',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: t.text)),
          const SizedBox(height: 8),
          ..._points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ',
                        style: TextStyle(
                            color: kDGold, fontWeight: FontWeight.bold)),
                    Expanded(
                        child: Text(p,
                            style: TextStyle(
                                fontSize: 13.5, color: t.text2, height: 1.5))),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'Start Test →',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MockPlayerScreen(
                    testId: test['id'] as int,
                    title: test['title']?.toString() ?? 'Mock Test',
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  static const _points = [
    'The timer starts as soon as you begin and the test auto-submits when time ends.',
    'You can switch between sections and questions freely using the palette.',
    'Each correct answer adds marks; wrong answers may deduct marks (negative marking).',
    'Use "Mark for Review" to flag questions you want to revisit.',
    'Language can be switched between English and Hindi during the test.',
    'Do not press back or close the app during the test.',
  ];

  Widget _row(DT t, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(k, style: TextStyle(fontSize: 13.5, color: t.muted)),
            const Spacer(),
            Text(v,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: t.text)),
          ],
        ),
      );
}
