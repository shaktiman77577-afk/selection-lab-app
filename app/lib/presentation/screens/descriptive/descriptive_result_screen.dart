// lib/presentation/screens/descriptive/descriptive_result_screen.dart
//
// Auto-score result — score ring, per-question bars (word/spelling/grammar),
// grammar feedback, your answer, model answer, examiner's tips. Follows app theme.

import 'package:flutter/material.dart';
import 'descriptive_theme.dart';

class DescriptiveResultScreen extends StatelessWidget {
  final String testTitle;
  final List<Map<String, dynamic>> results;
  final dynamic grandTotal;
  final dynamic grandMax;

  const DescriptiveResultScreen({
    super.key,
    required this.testTitle,
    required this.results,
    required this.grandTotal,
    required this.grandMax,
  });

  double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final total = _d(grandTotal);
    final max = _d(grandMax);
    final pct = max > 0 ? (total / max) : 0.0;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text('Result',
            style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // overall score card
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
                Text(testTitle,
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
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(kDGold),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_fmt(total),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0)),
                          Text('of ${_fmt(max)}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('${(pct * 100).round()}% score',
                    style: const TextStyle(
                        color: kDGold,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'This is an automated score (length, spelling & grammar). '
                  'Use the model answer & tips to improve.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...results.map((r) => _questionCard(t, r)),
        ],
      ),
    );
  }

  Widget _questionCard(DT t, Map<String, dynamic> r) {
    final score = Map<String, dynamic>.from(r['score'] as Map? ?? {});
    final qType = (r['q_type'] ?? '').toString();
    final total = _d(score['total_score']);
    final max = _d(score['total_max']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: kDGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(qType,
                    style: const TextStyle(
                        color: Color(0xFFB47F00),
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              const Spacer(),
              Text('${_fmt(total)} / ${_fmt(max)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: t.text)),
            ],
          ),
          const SizedBox(height: 12),
          Text(r['question']?.toString() ?? '',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: t.text)),
          const SizedBox(height: 14),

          // score bars
          _bar(t, 'Length', _d(score['word_count_score']),
              _d(score['max_word_marks']),
              sub: _lengthSub(score)),
          _bar(t, 'Spelling', _d(score['spelling_score']),
              _d(score['max_spelling_marks'])),
          _bar(t, 'Grammar', _d(score['grammar_score']),
              _d(score['max_grammar_marks']),
              sub: score['grammar_checked'] == false
                  ? 'Grammar check unavailable (given full marks)'
                  : null),

          // letter-format flag
          if (score['letter_format'] != null)
            _letterFormatNote(t,
                Map<String, dynamic>.from(score['letter_format'] as Map)),
          if (score['untranslated_hindi'] == true)
            _warn(t, 'Some Hindi text was left untranslated.'),

          // grammar issues
          _grammarFeedback(t, score),

          const SizedBox(height: 14),
          _block(t, 'Your Answer', r['your_answer']?.toString() ?? '',
              muted: true),
          if ((r['sample_answer']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _block(t, 'Model Answer', r['sample_answer'].toString(),
                accent: true),
          ],
          if ((r['explanation']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _block(t, "💡 Examiner's Tips", r['explanation'].toString(),
                tip: true),
          ],
        ],
      ),
    );
  }

  String? _lengthSub(Map<String, dynamic> score) {
    final label = score['length_label']?.toString();
    final note = score['length_note']?.toString();
    if (note != null && note.isNotEmpty) return note;
    if (label != null && label.isNotEmpty) return label;
    final wc = score['word_count'];
    return wc != null ? '$wc words written' : null;
  }

  Widget _bar(DT t, String label, double val, double max, {String? sub}) {
    final frac = max > 0 ? (val / max).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.text)),
              const Spacer(),
              Text('${_fmt(val)} / ${_fmt(max)}',
                  style: TextStyle(fontSize: 12.5, color: t.muted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: t.chip,
              valueColor: AlwaysStoppedAnimation<Color>(
                  frac >= 0.66 ? kDGreen : (frac >= 0.33 ? kDGold : const Color(0xFFE07B00))),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 11.5, color: t.muted)),
          ],
        ],
      ),
    );
  }

  Widget _grammarFeedback(DT t, Map<String, dynamic> score) {
    final issues = (score['grammar_issues'] as List? ?? []);
    if (issues.isEmpty) return const SizedBox.shrink();
    final show = issues.take(8).toList();
    Color badgeColor(String kind) {
      switch (kind) {
        case 'punctuation':
          return const Color(0xFFE07B00);
        case 'capitalization':
          return const Color(0xFF3B82F6);
        default:
          return const Color(0xFFC0392B);
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: t.chip, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Grammar & spelling notes',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: t.text)),
          const SizedBox(height: 8),
          ...show.map((raw) {
            final m = Map<String, dynamic>.from(raw as Map);
            final kind = (m['kind'] ?? 'grammar').toString();
            final msg = (m['message'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: badgeColor(kind).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(kind,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor(kind))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(msg,
                        style: TextStyle(fontSize: 12, color: t.text2)),
                  ),
                ],
              ),
            );
          }),
          if (issues.length > show.length)
            Text('+ ${issues.length - show.length} more',
                style: TextStyle(fontSize: 11.5, color: t.muted)),
        ],
      ),
    );
  }

  Widget _letterFormatNote(DT t, Map<String, dynamic> fmt) {
    final missing = <String>[];
    if (fmt['salutation'] == false) missing.add('salutation');
    if (fmt['subject'] == false) missing.add('subject line');
    if (fmt['closing'] == false) missing.add('closing');
    if (missing.isEmpty) return const SizedBox.shrink();
    return _warn(t, 'Letter format missing: ${missing.join(', ')}.');
  }

  Widget _warn(DT t, String text) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            border: Border.all(color: const Color(0xFFFFCC80)),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Text('⚠️ ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9A6600))),
          ),
        ]),
      );

  Widget _block(DT t, String title, String body,
      {bool muted = false, bool accent = false, bool tip = false}) {
    final bg = accent
        ? kDGreen.withOpacity(0.10)
        : tip
            ? kDGold.withOpacity(0.10)
            : t.chip;
    final border = accent
        ? kDGreen.withOpacity(0.4)
        : tip
            ? kDGold.withOpacity(0.4)
            : t.line;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: t.text)),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: muted ? t.text2 : t.text)),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
