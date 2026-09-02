// lib/presentation/screens/mock/mock_review_screen.dart
//
// Purana attempt dobara dekhne ki screen — score, rank, percentile, section-wise
// analysis aur poore solutions.
//
// Pehle app me ye tha hi nahi: home screen aur live banner se "View result" /
// "View solutions" dabane par Chrome khul jata tha aur student website par
// chala jata tha (wahan dobara login bhi maangta tha). Ab sab app ke andar.
//
// Teen API lagti hain:
//   GET /mock-tests/{id}/result?user_id=      -> score, rank, %ile, sections
//   GET /mock-tests/{id}?user_id=&exam=0      -> question text + correct answer
//   GET /mock-tests/{id}/solutions?user_id=   -> kitne % ne sahi kiya, avg time
//
// Doosri wali live test khatam hone ke baad 423 deti hai (backend live window
// ke bahar questions nahi bhejta). Us halat me analysis phir bhi dikhta hai —
// bas solutions ki jagah ek saaf message aata hai.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../descriptive/descriptive_theme.dart';

class MockReviewScreen extends StatefulWidget {
  final int testId;
  final int? userId;
  final String? title;

  const MockReviewScreen({
    super.key,
    required this.testId,
    required this.userId,
    this.title,
  });

  @override
  State<MockReviewScreen> createState() => _MockReviewScreenState();
}

class _MockReviewScreenState extends State<MockReviewScreen> {
  Map<String, dynamic>? _analysis;
  List<Map<String, dynamic>> _questions = [];
  Map<String, Map<String, dynamic>> _stats = {};
  Map<String, dynamic> _answers = {};

  bool _loading = true;
  bool _hindi = false;
  String? _error;
  String? _solutionsNote;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _base => AppConstants.apiUrl;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _solutionsNote = null;
    });

    final uid = widget.userId;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Please log in to see your result.';
      });
      return;
    }

    // 1) Result + rank + section analysis
    try {
      final r = await http
          .get(Uri.parse('$_base/mock-tests/${widget.testId}/result?user_id=$uid'))
          .timeout(const Duration(seconds: 20));
      final d = jsonDecode(r.body);

      if (r.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = (d is Map ? d['detail'] : null)?.toString() ??
              'Could not load your result.';
        });
        return;
      }
      if (d['pending'] == true) {
        setState(() {
          _loading = false;
          _error = (d['message'] ?? 'Results are not published yet.').toString();
        });
        return;
      }

      _analysis = Map<String, dynamic>.from(d as Map);
      final ans = (_analysis?['attempt'] ?? {})['answers'];
      if (ans is Map) _answers = Map<String, dynamic>.from(ans);
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Check your connection.';
      });
      return;
    }

    // 2) Questions with answers (exam=0). Live test khatam ho chuka ho to 423.
    try {
      final r = await http
          .get(Uri.parse('$_base/mock-tests/${widget.testId}?user_id=$uid&exam=0'))
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final list = d['questions'];
        if (list is List) {
          _questions =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } else {
        final d = jsonDecode(r.body);
        _solutionsNote = (d is Map ? d['detail'] : null)?.toString() ??
            'Solutions are not available for this test.';
      }
    } catch (_) {
      _solutionsNote = 'Solutions could not be loaded right now.';
    }

    // 3) Community stats — na aayein to bhi screen poori chalti hai
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/mock-tests/${widget.testId}/solutions?user_id=$uid'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final list = d['solutions'];
        if (list is List) {
          for (final s in list) {
            final m = Map<String, dynamic>.from(s as Map);
            _stats['${m['id']}'] = m;
          }
        }
      }
    } catch (_) {
      // stats optional
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _qText(Map<String, dynamic> q) {
    if (_hindi && (q['question_hi']?.toString().isNotEmpty ?? false)) {
      return q['question_hi'].toString();
    }
    return (q['question'] ?? '').toString();
  }

  String _optText(Map<String, dynamic> q, int i) {
    const en = ['option_a', 'option_b', 'option_c', 'option_d'];
    const hi = ['option_a_hi', 'option_b_hi', 'option_c_hi', 'option_d_hi'];
    if (_hindi && (q[hi[i]]?.toString().isNotEmpty ?? false)) {
      return q[hi[i]].toString();
    }
    return (q[en[i]] ?? '').toString();
  }

  String _explain(Map<String, dynamic> q, Map<String, dynamic> s) {
    if (_hindi) {
      final h = (q['explanation_hi'] ?? s['explanation_hi'] ?? '').toString();
      if (h.isNotEmpty) return h;
    }
    return (q['explanation'] ?? s['explanation'] ?? '').toString();
  }

  Future<void> _report(Map<String, dynamic> q) async {
    final controller = TextEditingController();
    final t = DT(Theme.of(context).brightness == Brightness.dark);

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Report this question',
            style: TextStyle(fontSize: 17, color: t.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kya galat hai? (wrong answer, typo, missing image...)',
                style: TextStyle(fontSize: 13, color: t.muted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              style: TextStyle(color: t.text, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: t.chip,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send',
                style: TextStyle(
                    color: kDGold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty || !mounted) return;

    try {
      await http
          .post(
            Uri.parse('$_base/mock-tests/report-question'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': widget.userId,
              'mock_test_id': widget.testId,
              'question_id': q['id'],
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Backend khud bhi kabhi fail nahi karta is call par — student ko
      // network dikkat par bhi dobara type na karwaayein.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks — we will check this question.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final title = widget.title ??
        (_analysis?['test']?['title'] ?? 'Result').toString();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: FontWeight.w800, color: t.text, fontSize: 17)),
        actions: [
          if (_questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => setState(() => _hindi = !_hindi),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: t.chip,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_hindi ? 'हिं' : 'EN',
                      style: TextStyle(
                          color: t.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView(t)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
                      _scoreCard(t),
                      const SizedBox(height: 14),
                      _rankRow(t),
                      const SizedBox(height: 18),
                      _sectionAnalysis(t),
                      _weakStrong(t),
                      const SizedBox(height: 20),
                      Text('Solutions',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: t.text)),
                      const SizedBox(height: 12),
                      if (_questions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: t.card,
                              border: Border.all(color: t.line),
                              borderRadius: BorderRadius.circular(14)),
                          child: Text(
                              _solutionsNote ??
                                  'Solutions are not available for this test.',
                              style:
                                  TextStyle(color: t.text2, fontSize: 13.5)),
                        )
                      else
                        ..._questions
                            .asMap()
                            .entries
                            .map((e) => _solution(e.key + 1, e.value, t)),
                    ],
                  ),
                ),
    );
  }

  Widget _errorView(DT t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 54, color: t.muted),
            const SizedBox(height: 14),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text2, fontSize: 14, height: 1.5)),
            const SizedBox(height: 18),
            TextButton(
                onPressed: _load,
                child: const Text('Try again',
                    style: TextStyle(
                        color: kDGold, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(DT t) {
    final a = _analysis?['attempt'] ?? {};
    final test = _analysis?['test'] ?? {};
    final score = _d(a['score']);
    final total = _d(test['total_marks']);
    final correct = a['correct'] ?? 0;
    final wrong = a['wrong'] ?? 0;
    final skipped = a['skipped'] ?? 0;
    final attempted = _d(correct) + _d(wrong);
    final accuracy = attempted > 0 ? (_d(correct) / attempted) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kDNavy, kDNavy2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text('YOUR SCORE',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: _fmt(score),
                  style: const TextStyle(
                      color: kDGold,
                      fontSize: 40,
                      fontWeight: FontWeight.w900)),
              TextSpan(
                  text: total > 0 ? '  / ${_fmt(total)}' : '',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _mini('Correct', '$correct', const Color(0xFF5DD97C)),
              _mini('Wrong', '$wrong', const Color(0xFFFF7A7A)),
              _mini('Skipped', '$skipped', Colors.white70),
              _mini('Accuracy', '${_fmt(accuracy)}%', kDGold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _rankRow(DT t) {
    final rank = _analysis?['rank'];
    final totalAttempts = _analysis?['total_attempts'];
    final pct = _analysis?['percentile'];
    final topper = _analysis?['topper_score'];
    final avg = _analysis?['average_score'];

    return Row(
      children: [
        _stat(t, 'Rank',
            rank == null ? '—' : '#$rank${totalAttempts != null ? ' / $totalAttempts' : ''}',
            kDGold),
        const SizedBox(width: 10),
        _stat(t, 'Percentile', pct == null ? '—' : '${_fmt(_d(pct))}%', t.text),
        const SizedBox(width: 10),
        _stat(t, 'Topper', topper == null ? '—' : _fmt(_d(topper)), kDGreen),
        const SizedBox(width: 10),
        _stat(t, 'Average', avg == null ? '—' : _fmt(_d(avg)), t.text2),
      ],
    );
  }

  Widget _stat(DT t, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(14),
            boxShadow: t.shadow),
        child: Column(
          children: [
            FittedBox(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color)),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(fontSize: 11, color: t.muted)),
          ],
        ),
      ),
    );
  }

  Widget _sectionAnalysis(DT t) {
    final raw = _analysis?['sections'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();
    final sections =
        raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Section-wise analysis',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(14),
              boxShadow: t.shadow),
          child: Column(
            children: sections.asMap().entries.map((e) {
              final s = e.value;
              final acc = _d(s['accuracy']);
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  border: e.key == sections.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: t.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text((s['section'] ?? '').toString(),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: t.text)),
                        ),
                        Text(
                            '${_fmt(_d(s['score']))} / ${_fmt(_d(s['max_marks']))}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: kDGold)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (acc / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: t.chip,
                        valueColor: AlwaysStoppedAnimation(
                            acc >= 75 ? kDGreen : (acc >= 50 ? kDGold : const Color(0xFFC0392B))),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        '${s['correct'] ?? 0} correct · ${s['wrong'] ?? 0} wrong · '
                        '${s['skipped'] ?? 0} skipped · ${_fmt(acc)}% accuracy',
                        style: TextStyle(fontSize: 11.5, color: t.muted)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _weakStrong(DT t) {
    final weak = (_analysis?['weak_areas'] as List?) ?? [];
    final strong = (_analysis?['strong_areas'] as List?) ?? [];
    if (weak.isEmpty && strong.isEmpty) return const SizedBox.shrink();

    Widget chips(String label, List items, Color color) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: t.muted)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(s.toString(),
                            style: TextStyle(
                                color: color,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                      ))
                  .toList(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        chips('Needs work', weak, const Color(0xFFC0392B)),
        chips('Strong areas', strong, kDGreen),
      ],
    );
  }

  Widget _solution(int index, Map<String, dynamic> q, DT t) {
    final qid = '${q['id']}';
    final s = _stats[qid] ?? const <String, dynamic>{};

    final your = (_answers[qid] ?? '').toString();
    final correct =
        (q['correct_answer'] ?? s['correct_answer'] ?? '').toString();
    final isSkipped = your.isEmpty;
    final isCorrect = !isSkipped && your == correct;

    final statusColor = isSkipped
        ? t.muted
        : (isCorrect ? kDGreen : const Color(0xFFC0392B));
    final statusText =
        isSkipped ? 'Skipped' : (isCorrect ? 'Correct' : 'Wrong');

    const letters = ['A', 'B', 'C', 'D'];
    final explanation = _explain(q, s);
    final qImage = (q['image_url'] ?? '').toString();
    final expImage =
        (q['explanation_image_url'] ?? s['explanation_image_url'] ?? '')
            .toString();

    final correctPct = s['correct_pct'];
    final avgSec = s['avg_seconds'];
    final mySec = s['my_seconds'];

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
              const SizedBox(width: 8),
              if ((q['section'] ?? '').toString().isNotEmpty)
                Flexible(
                  child: Text('· ${q['section']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.muted)),
                ),
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
          const SizedBox(height: 10),
          Text(_qText(q),
              style: TextStyle(
                  fontSize: 14.5, height: 1.45, color: t.text)),
          if (qImage.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(qImage,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ],
          const SizedBox(height: 10),
          ...List.generate(4, (i) {
            final letter = letters[i];
            final text = _optText(q, i);
            if (text.isEmpty) return const SizedBox.shrink();

            final isRight = letter == correct;
            final isYours = letter == your;

            Color bg = t.chip;
            Color fg = t.text2;
            if (isRight) {
              bg = kDGreen.withOpacity(0.16);
              fg = kDGreen;
            } else if (isYours) {
              bg = const Color(0xFFC0392B).withOpacity(0.14);
              fg = const Color(0xFFC0392B);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$letter. ',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: fg,
                          fontSize: 13.5)),
                  Expanded(
                    child: Text(text,
                        style: TextStyle(
                            color: fg, fontSize: 13.5, height: 1.4)),
                  ),
                  if (isYours)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text('you',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: fg.withOpacity(0.8))),
                    ),
                ],
              ),
            );
          }),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: kDGold.withOpacity(0.08),
                  border: Border.all(color: kDGold.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explanation',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: kDGold)),
                  const SizedBox(height: 5),
                  Text(explanation,
                      style: TextStyle(
                          fontSize: 13.5, height: 1.5, color: t.text2)),
                  if (expImage.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(expImage,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (correctPct != null)
                _tag(t, '${correctPct}% got it right'),
              if (mySec != null) _tag(t, 'You: ${mySec}s'),
              if (avgSec != null) _tag(t, 'Avg: ${avgSec}s'),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _report(q);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_outlined, size: 14, color: t.muted),
                      const SizedBox(width: 4),
                      Text('Report',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: t.muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(DT t, String text) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: t.chip, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w600, color: t.muted)),
    );
  }
}
