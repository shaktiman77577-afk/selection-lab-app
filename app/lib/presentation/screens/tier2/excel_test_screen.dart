// lib/presentation/screens/tier2/excel_test_screen.dart
//
// Excel mock test — 10 formula question + bonus MCQ, timer ke saath.
//
// Practice se do farq hain, aur dono jaanbujh kar hain:
//   - Hints nahi. Backend test mode me _public_q(with_hints=False) bhejta hai.
//   - Auto-suggest nahi. Exam me formula list samne nahi hoti.
//
// Bonus MCQ qualifying me nahi ginte — score sirf formula questions ka hai.
// Ye backend ka niyam hai, isliye result me bhi alag dikhaya hai, warna
// student ko lagega ki uske marks kam ho gaye.
//
// Sahi jawab test khatam hone tak app tak aata hi nahi — submit ke baad
// backend `correct_formula` aur `expected_value` bhejta hai, tab dikhate hain.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/providers/tier2_api.dart';
import '../descriptive/descriptive_theme.dart';
import 'excel_hub_screen.dart';

enum _Phase { loading, running, submitting, result, error }

class ExcelTestScreen extends StatefulWidget {
  final int testId;
  final int userId;
  final bool hindi;

  const ExcelTestScreen({
    super.key,
    required this.testId,
    required this.userId,
    this.hindi = false,
  });

  @override
  State<ExcelTestScreen> createState() => _ExcelTestScreenState();
}

class _ExcelTestScreenState extends State<ExcelTestScreen> {
  _Phase _phase = _Phase.loading;
  String? _error;
  late bool _hindi = widget.hindi;

  Map<String, dynamic> _test = {};
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _bonus = [];

  int _index = 0;
  int _secondsLeft = 0;
  int _elapsed = 0;
  bool _ticking = false;

  // qid -> typed formula, aur qid -> us question par kitne second lage
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, int> _seconds = {};
  final Map<int, String> _bonusPick = {};

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticking = false;
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Tier2Api.excelTest(widget.testId, widget.userId);
      if (!mounted) return;

      final qs = ((d['questions'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final bs = ((d['bonus'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      for (final q in qs) {
        _controllers[q['id'] as int] = TextEditingController();
      }

      setState(() {
        _test = (d['test'] as Map?)?.cast<String, dynamic>() ?? {};
        _questions = qs;
        _bonus = bs;
        _secondsLeft = ((_test['duration_min'] ?? 10) as num).toInt() * 60;
        _phase = _Phase.running;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.toString().contains('403')
            ? 'This test is locked. Purchase the series to attempt it.'
            : 'Could not load this test.';
      });
    }
  }

  void _startTimer() {
    _ticking = true;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_ticking) return false;
      setState(() {
        _secondsLeft--;
        _elapsed++;
        // Jis question par abhi hain uska time badhao — result me per-question
        // seconds isi se banta hai.
        if (_index < _questions.length) {
          final qid = _questions[_index]['id'] as int;
          _seconds[qid] = (_seconds[qid] ?? 0) + 1;
        }
      });
      if (_secondsLeft <= 0) {
        _submit(auto: true);
        return false;
      }
      return true;
    });
  }

  Future<void> _submit({bool auto = false}) async {
    if (_phase != _Phase.running) return;

    if (!auto) {
      final blank = _questions
          .where((q) =>
              (_controllers[q['id'] as int]?.text ?? '').trim().isEmpty)
          .length;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit test?'),
          content: Text(blank > 0
              ? '$blank question(s) are still blank. They will be marked wrong.'
              : 'All questions answered. Submit now?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep working')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit',
                    style: TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
      );
      if (ok != true) return;
    }

    _ticking = false;
    FocusScope.of(context).unfocus();
    setState(() => _phase = _Phase.submitting);

    final answers = _questions.map((q) {
      final qid = q['id'] as int;
      return {
        'question_id': qid,
        'formula': _controllers[qid]?.text.trim() ?? '',
        'seconds': _seconds[qid] ?? 0,
      };
    }).toList();

    final bonusAnswers = _bonus
        .map((b) => {
              'question_id': b['id'],
              'selected': _bonusPick[b['id'] as int] ?? '',
            })
        .toList();

    try {
      final r = await Tier2Api.submitExcelTest(
        userId: widget.userId,
        testId: widget.testId,
        answers: answers,
        bonusAnswers: bonusAnswers,
        secondsTaken: _elapsed,
      );
      if (!mounted) return;
      setState(() {
        _result = Map<String, dynamic>.from(r);
        _phase = _Phase.result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.running;
        _error = 'Could not submit. Check your connection and try again.';
      });
      if (_secondsLeft > 0) _startTimer();
    }
  }

  String get _clock {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _txt(Map<String, dynamic> m, String en, String hi) {
    if (_hindi && (m[hi]?.toString().isNotEmpty ?? false)) {
      return m[hi].toString();
    }
    return (m[en] ?? '').toString();
  }

  Future<bool> _confirmExit() async {
    if (_phase != _Phase.running) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the test?'),
        content: const Text('This attempt will not be saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave',
                  style: TextStyle(color: Color(0xFFC0392B)))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);

    return PopScope(
      canPop: _phase != _Phase.running,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && mounted) {
          _ticking = false;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          backgroundColor: t.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: t.text),
          automaticallyImplyLeading: _phase != _Phase.running,
          title: Text((_test['title'] ?? 'Excel test').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: t.text, fontSize: 16)),
          actions: [
            GestureDetector(
              onTap: () => setState(() => _hindi = !_hindi),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                    color: t.chip,
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(20)),
                child: Center(
                  child: Text(_hindi ? 'हिं' : 'EN',
                      style: TextStyle(
                          color: t.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ),
            ),
            if (_phase == _Phase.running)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _secondsLeft <= 60
                          ? const Color(0xFFC0392B)
                          : kDGold,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_clock,
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                ),
              ),
          ],
        ),
        body: _body(t),
      ),
    );
  }

  Widget _body(DT t) {
    switch (_phase) {
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text2, fontSize: 14)),
          ),
        );
      case _Phase.submitting:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Checking your formulas…',
                  style: TextStyle(color: t.muted, fontSize: 13.5)),
            ],
          ),
        );
      case _Phase.running:
        return _runningView(t);
      case _Phase.result:
        return _resultView(t);
    }
  }

  // ── RUNNING ──

  Widget _runningView(DT t) {
    final total = _questions.length;
    if (total == 0) {
      return Center(
          child: Text('This test has no questions yet.',
              style: TextStyle(color: t.muted)));
    }

    final q = _questions[_index];
    final qid = q['id'] as int;

    return Column(
      children: [
        // Question palette — kaunse ho gaye, kaunse baaki
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: total,
            itemBuilder: (context, i) {
              final id = _questions[i]['id'] as int;
              final filled =
                  (_controllers[id]?.text ?? '').trim().isNotEmpty;
              final on = i == _index;
              return GestureDetector(
                onTap: () => setState(() => _index = i),
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 7, top: 6),
                  decoration: BoxDecoration(
                    color: on
                        ? kDGold
                        : (filled ? kDGreen.withOpacity(0.18) : t.chip),
                    border: Border.all(color: on ? kDGold : t.line),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: on
                                ? const Color(0xFF1A1A1A)
                                : (filled ? kDGreen : t.muted))),
                  ),
                ),
              );
            },
          ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: const Color(0xFFC0392B).withOpacity(0.12),
            child: Text(_error!,
                style: const TextStyle(
                    color: Color(0xFFC0392B), fontSize: 12.5)),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              Row(
                children: [
                  Text('Q${_index + 1} of $total',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: t.muted)),
                  const SizedBox(width: 9),
                  Text((q['concept'] ?? '').toString(),
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: t.muted)),
                ],
              ),
              const SizedBox(height: 9),
              Text(_txt(q, 'instruction_en', 'instruction_hi'),
                  style:
                      TextStyle(fontSize: 15, height: 1.6, color: t.text)),
              const SizedBox(height: 15),
              ExcelGrid(
                gridData: q['grid_data']?.toString(),
                targetCell: q['target_cell']?.toString(),
              ),
              const SizedBox(height: 14),
              FormulaBar(
                controller: _controllers[qid]!,
                targetCell: q['target_cell']?.toString(),
                onChanged: (_) => setState(() {}),
                // Test me check nahi hota — tick dabane par agla question.
                onSubmit: () {
                  if (_index < total - 1) {
                    setState(() => _index++);
                  } else {
                    FocusScope.of(context).unfocus();
                  }
                },
              ),
              const SizedBox(height: 8),
              Text('No hints and no auto-suggest in test mode — same as the exam.',
                  style: TextStyle(fontSize: 11.5, color: t.muted)),

              // Bonus MCQ aakhri question ke baad
              if (_index == total - 1 && _bonus.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Bonus questions',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: t.text)),
                const SizedBox(height: 4),
                Text('These do not count towards qualifying.',
                    style: TextStyle(fontSize: 11.5, color: t.muted)),
                const SizedBox(height: 12),
                ..._bonus.map((b) => _bonusCard(t, b)),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                if (_index > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _index--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.text2,
                        side: BorderSide(color: t.line),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                      child: const Text('Previous',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (_index > 0) const SizedBox(width: 9),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _index < total - 1
                        ? () => setState(() => _index++)
                        : () => _submit(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDGold,
                      foregroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                    ),
                    child: Text(_index < total - 1 ? 'Next' : 'Submit',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bonusCard(DT t, Map<String, dynamic> b) {
    final bid = b['id'] as int;
    final opts = _hindi && (b['options_hi'] is List)
        ? (b['options_hi'] as List)
        : ((b['options'] as List?) ?? []);
    const letters = ['A', 'B', 'C', 'D'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_txt(b, 'question_en', 'question_hi'),
              style: TextStyle(fontSize: 14, height: 1.5, color: t.text)),
          const SizedBox(height: 10),
          ...List.generate(opts.length, (i) {
            final text = (opts[i] ?? '').toString();
            if (text.isEmpty) return const SizedBox.shrink();
            final letter = letters[i];
            final on = _bonusPick[bid] == letter;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _bonusPick[bid] = on ? '' : letter);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(
                  color: on ? kDGold.withOpacity(0.14) : t.chip,
                  border: Border.all(color: on ? kDGold : Colors.transparent),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$letter. ',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: on ? kDGold : t.muted)),
                    Expanded(
                      child: Text(text,
                          style: TextStyle(
                              fontSize: 13.5, height: 1.4, color: t.text2)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── RESULT ──

  Widget _resultView(DT t) {
    final r = _result ?? {};
    final qualified = r['qualified'] == true;
    final score = r['score'] ?? 0;
    final total = r['total'] ?? 0;
    final bonusScore = r['bonus_score'] ?? 0;
    final bonusTotal = r['bonus_total'] ?? 0;
    final weak = (r['weak'] as List?) ?? [];
    final strong = (r['strong'] as List?) ?? [];
    final detail = (r['questions'] as List?) ?? [];
    final bonusDetail = (r['bonus'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: (qualified ? kDGreen : const Color(0xFFC0392B))
                .withOpacity(0.12),
            border: Border.all(
                color: (qualified ? kDGreen : const Color(0xFFC0392B))
                    .withOpacity(0.4)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(qualified ? Icons.verified_rounded : Icons.cancel_outlined,
                  size: 40,
                  color: qualified ? kDGreen : const Color(0xFFC0392B)),
              const SizedBox(height: 8),
              Text('$score / $total',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: qualified ? kDGreen : const Color(0xFFC0392B))),
              const SizedBox(height: 3),
              Text(qualified ? 'Qualified' : 'Not qualified',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: qualified ? kDGreen : const Color(0xFFC0392B))),
              const SizedBox(height: 5),
              Text('Pass mark: ${r['pass_marks'] ?? 4}',
                  style: TextStyle(fontSize: 12, color: t.text2)),
              if (bonusTotal > 0) ...[
                const SizedBox(height: 9),
                Text('Bonus: $bonusScore / $bonusTotal (not counted)',
                    style: TextStyle(fontSize: 12, color: t.muted)),
              ],
            ],
          ),
        ),
        if (weak.isNotEmpty || strong.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (weak.isNotEmpty)
            _chips(t, 'Needs work', weak, const Color(0xFFC0392B)),
          if (strong.isNotEmpty) _chips(t, 'Strong', strong, kDGreen),
        ],
        const SizedBox(height: 22),
        Text('Answers',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: t.text)),
        const SizedBox(height: 12),
        ...detail.asMap().entries.map((e) =>
            _answerCard(t, e.key + 1, Map<String, dynamic>.from(e.value))),
        if (bonusDetail.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Bonus answers',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: t.text)),
          const SizedBox(height: 12),
          ...bonusDetail.map(
              (b) => _bonusAnswerCard(t, Map<String, dynamic>.from(b))),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDGold,
              foregroundColor: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _chips(DT t, String label, List items, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
            spacing: 7,
            runSpacing: 7,
            children: items
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(c.toString(),
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _answerCard(DT t, int n, Map<String, dynamic> d) {
    final ok = d['is_correct'] == true;
    final typed = (d['typed_formula'] ?? '').toString();
    final correctFormula = (d['correct_formula'] ?? '').toString();
    final feedback = (_hindi && (d['feedback_hi'] ?? '').toString().isNotEmpty
            ? d['feedback_hi']
            : d['feedback'] ?? '')
        .toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Q$n',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: t.muted)),
              const SizedBox(width: 8),
              Text((d['concept'] ?? '').toString(),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: t.muted)),
              const Spacer(),
              if ((d['seconds'] ?? 0) > 0)
                Text('${d['seconds']}s',
                    style: TextStyle(fontSize: 11, color: t.muted)),
              const SizedBox(width: 8),
              Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 17,
                  color: ok ? kDGreen : const Color(0xFFC0392B)),
            ],
          ),
          const SizedBox(height: 8),
          Text((d['instruction_en'] ?? '').toString(),
              style: TextStyle(fontSize: 13, height: 1.5, color: t.text2)),
          const SizedBox(height: 10),
          _formulaLine(t, 'You typed', typed.isEmpty ? '— blank —' : typed,
              ok ? kDGreen : const Color(0xFFC0392B)),
          if (!ok && correctFormula.isNotEmpty) ...[
            const SizedBox(height: 7),
            _formulaLine(t, 'Correct', correctFormula, kDGreen),
          ],
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(feedback,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: t.muted)),
          ],
        ],
      ),
    );
  }

  Widget _formulaLine(DT t, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(7)),
            child: SelectableText(value,
                style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        ),
      ],
    );
  }

  Widget _bonusAnswerCard(DT t, Map<String, dynamic> b) {
    final ok = b['is_correct'] == true;
    final explanation =
        (_hindi && (b['explanation_hi'] ?? '').toString().isNotEmpty
                ? b['explanation_hi']
                : b['explanation_en'] ?? '')
            .toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text((b['question_en'] ?? '').toString(),
                    style:
                        TextStyle(fontSize: 13.5, height: 1.5, color: t.text)),
              ),
              const SizedBox(width: 8),
              Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 16, color: ok ? kDGreen : const Color(0xFFC0392B)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
              'You: ${(b['selected'] ?? '').toString().isEmpty ? '—' : b['selected']}'
              '   ·   Correct: ${b['correct_option'] ?? '—'}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: t.muted)),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(explanation,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: t.text2)),
          ],
        ],
      ),
    );
  }
}
