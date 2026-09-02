// lib/presentation/screens/mock/mock_player_screen.dart
//
// Mock exam player — TCS/SSC-style: sections, timer, MCQ options,
// mark-for-review, question palette, EN/HI toggle, auto-submit.

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/mock_api.dart';
import '../descriptive/descriptive_theme.dart';
import 'mock_result_screen.dart';

class MockPlayerScreen extends StatefulWidget {
  final int testId;
  final String title;
  const MockPlayerScreen({super.key, required this.testId, required this.title});

  @override
  State<MockPlayerScreen> createState() => _MockPlayerScreenState();
}

class _MockPlayerScreenState extends State<MockPlayerScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _test = {};
  List<Map<String, dynamic>> _questions = [];
  List<String> _sections = [];

  int _current = 0; // index into _questions
  final Map<int, String> _answers = {}; // qid -> "A".."D"
  final Set<int> _marked = {};
  final Set<int> _visited = {};

  // Har question par kitne second lage. Timer ke har tick par jis question par
  // student hai usi ka counter badhta hai — isliye pause/resume apne aap sahi
  // rehta hai aur total hamesha _elapsed se match karta hai.
  final Map<int, int> _qTimes = {};

  bool _hindi = false;
  Timer? _timer;
  int _secondsLeft = 0;
  int _elapsed = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Pause / Resume (save progress locally) ──
  int? _uidForKey;
  String get _progKey => 'mock_progress_${_uidForKey ?? 0}_${widget.testId}';

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'marked': _marked.toList(),
        'visited': _visited.toList(),
        'current': _current,
        'secondsLeft': _secondsLeft,
        'elapsed': _elapsed,
        'qTimes': _qTimes.map((k, v) => MapEntry(k.toString(), v)),
        'hindi': _hindi,
      };
      await prefs.setString(_progKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_progKey);
      if (raw == null || raw.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_progKey);
    } catch (_) {}
  }

  void _restoreFrom(Map<String, dynamic> d) {
    _answers.clear();
    (d['answers'] as Map?)?.forEach((k, v) {
      final id = int.tryParse(k.toString());
      if (id != null) _answers[id] = v.toString();
    });
    _marked
      ..clear()
      ..addAll(((d['marked'] as List?) ?? []).map((e) => e as int));
    _visited
      ..clear()
      ..addAll(((d['visited'] as List?) ?? []).map((e) => e as int));
    _current = (d['current'] as num?)?.toInt() ?? 0;
    if (_current >= _questions.length) _current = 0;
    _secondsLeft = (d['secondsLeft'] as num?)?.toInt() ?? _secondsLeft;
    _elapsed = (d['elapsed'] as num?)?.toInt() ?? 0;
    _qTimes.clear();
    (d['qTimes'] as Map?)?.forEach((k, v) {
      final id = int.tryParse(k.toString());
      final sec = (v as num?)?.toInt();
      if (id != null && sec != null) _qTimes[id] = sec;
    });
    _hindi = d['hindi'] == true;
  }

  Future<void> _pauseAndExit() async {
    _timer?.cancel();
    await _saveProgress();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?['id'] as int?;
    _uidForKey = uid;
    try {
      final res = await MockApi.test(widget.testId, uid);
      if (res['mock_test'] == null || res['questions'] == null) {
        setState(() {
          _error = (res['detail'] ?? 'This test is locked or unavailable.')
              .toString();
          _loading = false;
        });
        return;
      }
      final test = Map<String, dynamic>.from(res['mock_test'] as Map);
      final questions = (res['questions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final sections = <String>[];
      for (final q in questions) {
        final sec = (q['section'] ?? 'General').toString();
        if (!sections.contains(sec)) sections.add(sec);
      }

      final dur = test['duration_minutes'] ?? 30;
      final durMin = dur is num ? dur.toInt() : int.tryParse('$dur') ?? 30;

      setState(() {
        _test = test;
        _questions = questions;
        _sections = sections;
        _secondsLeft = durMin * 60;
        _loading = false;
        if (questions.isNotEmpty) _visited.add(questions.first['id'] as int);
      });

      // resume if a paused attempt exists
      final saved = await _readSaved();
      if (saved != null && mounted) {
        final resume = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Resume test?'),
            content: const Text(
                'You have a paused attempt for this test. Resume from where you left off, or start over?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Start over')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Resume')),
            ],
          ),
        );
        if (resume == true) {
          setState(() => _restoreFrom(saved));
        } else {
          await _clearProgress();
        }
      }
      _startTimer();
    } catch (e) {
      setState(() {
        _error = 'Could not load the test. Check your connection.';
        _loading = false;
      });
    }
  }

  int? get _currentQid {
    if (_current < 0 || _current >= _questions.length) return null;
    final raw = _questions[_current]['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
        _submit(auto: true);
      } else {
        setState(() {
          _secondsLeft--;
          _elapsed++;
          // Jis question par abhi hain uska time badhao
          final qid = _currentQid;
          if (qid != null) _qTimes[qid] = (_qTimes[qid] ?? 0) + 1;
        });
      }
    });
  }

  String get _timeStr {
    final h = _secondsLeft ~/ 3600;
    final m = (_secondsLeft % 3600) ~/ 60;
    final s = _secondsLeft % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  void _goTo(int index) {
    if (index < 0 || index >= _questions.length) return;
    setState(() {
      _current = index;
      _visited.add(_questions[index]['id'] as int);
    });
  }

  Future<void> _confirmSubmit() async {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final answered = _answers.length;
    final left = _questions.length - answered;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Submit test?', style: TextStyle(color: t.text)),
        content: Text(
            'Answered: $answered\nNot answered: $left\n\nSubmit now?',
            style: TextStyle(color: t.text2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kDGold,
                foregroundColor: const Color(0xFF1A1A1A)),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    _timer?.cancel();
    await _clearProgress();
    setState(() => _submitting = true);
    final uid = context.read<AuthProvider>().user?['id'] as int?;

    final answersMap = <String, dynamic>{};
    for (final e in _answers.entries) {
      answersMap['${e.key}'] = e.value;
    }

    try {
      final res = await MockApi.submit(
        uid,
        widget.testId,
        answersMap,
        _elapsed,
        questionTimes: _qTimes.map((k, v) => MapEntry(k.toString(), v)),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MockResultScreen(
            title: widget.title,
            result: res,
            questions: _questions,
            answers: Map<int, String>.from(_answers),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Submit failed. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);

    if (_loading) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(backgroundColor: kDNavy, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
            backgroundColor: t.bg,
            elevation: 0,
            iconTheme: IconThemeData(color: t.text)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.muted, fontSize: 15)),
          ),
        ),
      );
    }

    final q = _questions[_current];
    final qid = q['id'] as int;
    final section = (q['section'] ?? 'General').toString();

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          backgroundColor: kDNavy,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          actions: [
            // pause & exit (saves progress, timer stops)
            Center(
              child: GestureDetector(
                onTap: _pauseAndExit,
                child: Container(
                  margin: const EdgeInsets.only(left: 4, right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 3),
                      Text('Pause',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            // language toggle
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _hindi = !_hindi),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_hindi ? 'हिं' : 'EN',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: _secondsLeft < 60
                        ? const Color(0xFFC0392B)
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_outlined,
                      color: Colors.white, size: 15),
                  const SizedBox(width: 4),
                  Text(_timeStr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ]),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // section tabs
            Container(
              color: kDNavy,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final active = _sections[i] == section;
                    return GestureDetector(
                      onTap: () {
                        final idx = _questions.indexWhere((x) =>
                            (x['section'] ?? 'General').toString() ==
                            _sections[i]);
                        if (idx >= 0) _goTo(idx);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                            color: active
                                ? kDGold
                                : Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(_sections[i],
                            style: TextStyle(
                                color: active
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5)),
                      ),
                    );
                  },
                ),
              ),
            ),

            // question meta row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: t.card,
              child: Row(
                children: [
                  Text('Q ${_current + 1} / ${_questions.length}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: t.text,
                          fontSize: 13.5)),
                  const Spacer(),
                  Text(
                      '+${q['marks'] ?? 2}${_num(_test['negative_marking']) > 0 ? '  −${_test['negative_marking']}' : ''}',
                      style: TextStyle(fontSize: 12.5, color: t.muted)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() {
                      if (_marked.contains(qid)) {
                        _marked.remove(qid);
                      } else {
                        _marked.add(qid);
                      }
                    }),
                    child: Icon(
                        _marked.contains(qid)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: _marked.contains(qid)
                            ? const Color(0xFF8B5CF6)
                            : t.muted,
                        size: 22),
                  ),
                ],
              ),
            ),

            // question + options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                children: [
                  Text(_qText(q),
                      style: TextStyle(
                          fontSize: 15.5,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                          color: t.text)),
                  const SizedBox(height: 16),
                  ..._optionTiles(q, qid, t),
                ],
              ),
            ),

            // bottom controls
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(color: t.card, boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, -3)),
                ]),
                child: Row(
                  children: [
                    _ctrlBtn(t, 'Palette', Icons.grid_view_rounded,
                        () => _openPalette(t)),
                    const SizedBox(width: 8),
                    _ctrlBtn(t, 'Clear', Icons.clear, () {
                      setState(() => _answers.remove(qid));
                    }),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _current < _questions.length - 1
                          ? () => _goTo(_current + 1)
                          : _confirmSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDGold,
                        foregroundColor: const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                          _current < _questions.length - 1
                              ? 'Save & Next'
                              : 'Submit',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  num _num(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString()) ?? 0;

  String _qText(Map<String, dynamic> q) {
    if (_hindi && (q['question_hi']?.toString().isNotEmpty ?? false)) {
      return q['question_hi'].toString();
    }
    return q['question']?.toString() ?? '';
  }

  List<Widget> _optionTiles(Map<String, dynamic> q, int qid, DT t) {
    final letters = ['A', 'B', 'C', 'D'];
    final enKeys = ['option_a', 'option_b', 'option_c', 'option_d'];
    final hiKeys = ['option_a_hi', 'option_b_hi', 'option_c_hi', 'option_d_hi'];
    final tiles = <Widget>[];
    for (var i = 0; i < 4; i++) {
      final letter = letters[i];
      String text = (q[enKeys[i]] ?? '').toString();
      if (_hindi && (q[hiKeys[i]]?.toString().isNotEmpty ?? false)) {
        text = q[hiKeys[i]].toString();
      }
      if (text.isEmpty) continue;
      final selected = _answers[qid] == letter;
      tiles.add(GestureDetector(
        onTap: () => setState(() => _answers[qid] = letter),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected ? kDGold.withOpacity(0.12) : t.card,
            border: Border.all(
                color: selected ? kDGold : t.line,
                width: selected ? 1.6 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? kDGold : Colors.transparent,
                  border: Border.all(
                      color: selected ? kDGold : t.muted, width: 1.5),
                ),
                child: Text(letter,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: selected ? const Color(0xFF1A1A1A) : t.muted)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 14.5, height: 1.4, color: t.text)),
              ),
            ],
          ),
        ),
      ));
    }
    return tiles;
  }

  Widget _ctrlBtn(DT t, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: t.chip, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: t.text2),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: t.text2)),
        ]),
      ),
    );
  }

  void _openPalette(DT t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Question Palette',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: t.text)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 14, runSpacing: 6, children: [
                    _legend(t, kDGreen, 'Answered'),
                    _legend(t, const Color(0xFF8B5CF6), 'Marked'),
                    _legend(t, const Color(0xFFC0392B), 'Not answered'),
                    _legend(t, t.chip, 'Not visited'),
                  ]),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            List.generate(_questions.length, (i) {
                          final id = _questions[i]['id'] as int;
                          final answered = _answers.containsKey(id);
                          final marked = _marked.contains(id);
                          final visited = _visited.contains(id);
                          Color bg;
                          Color fg = Colors.white;
                          if (marked) {
                            bg = const Color(0xFF8B5CF6);
                          } else if (answered) {
                            bg = kDGreen;
                          } else if (visited) {
                            bg = const Color(0xFFC0392B);
                          } else {
                            bg = t.chip;
                            fg = t.text;
                          }
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _goTo(i);
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      color: fg,
                                      fontWeight: FontWeight.w800)),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmSubmit();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDGold,
                        foregroundColor: const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Submit Test',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _legend(DT t, Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: t.muted)),
        ],
      );
}
