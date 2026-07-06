// lib/presentation/screens/descriptive/descriptive_player_screen.dart
//
// Descriptive exam player — sections (by q_type), timer, choose-one-per-section,
// write, paste-blocked answer box, submit -> result. Follows app theme.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/descriptive_api.dart';
import 'descriptive_theme.dart';
import 'descriptive_result_screen.dart';

const _sectionOrder = ['Essay', 'Letter', 'Precis', 'Translation'];

class DescriptivePlayerScreen extends StatefulWidget {
  final int testId;
  final int seriesId;
  const DescriptivePlayerScreen(
      {super.key, required this.testId, required this.seriesId});

  @override
  State<DescriptivePlayerScreen> createState() =>
      _DescriptivePlayerScreenState();
}

class _DescriptivePlayerScreenState extends State<DescriptivePlayerScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _test = {};

  List<Map<String, dynamic>> _sections = [];
  int _activeSection = 0;

  final Map<int, TextEditingController> _controllers = {};
  final Map<int, int> _chosen = {};

  Timer? _timer;
  int _secondsLeft = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?['id'] as int?;
    try {
      final res = await DescriptiveApi.test(widget.testId, uid);
      if (res['test'] == null || res['questions'] == null) {
        setState(() {
          _error = (res['detail'] ?? 'This test is locked or unavailable.')
              .toString();
          _loading = false;
        });
        return;
      }
      final test = Map<String, dynamic>.from(res['test'] as Map);
      final questions = (res['questions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final q in questions) {
        final ty = (q['q_type'] ?? 'Essay').toString();
        grouped.putIfAbsent(ty, () => []).add(q);
      }
      final sections = <Map<String, dynamic>>[];
      for (final ty in _sectionOrder) {
        if (grouped.containsKey(ty)) {
          sections.add({'type': ty, 'questions': grouped[ty]});
        }
      }
      for (final entry in grouped.entries) {
        if (!_sectionOrder.contains(entry.key)) {
          sections.add({'type': entry.key, 'questions': entry.value});
        }
      }

      for (var i = 0; i < sections.length; i++) {
        final qs = sections[i]['questions'] as List;
        if (qs.isNotEmpty) _chosen[i] = qs.first['id'] as int;
        for (final q in qs) {
          final id = q['id'] as int;
          _controllers.putIfAbsent(id, () => TextEditingController());
        }
      }

      final dur = (test['duration_min'] ?? 30);
      final durMin = dur is num ? dur.toInt() : int.tryParse('$dur') ?? 30;

      setState(() {
        _test = test;
        _sections = sections;
        _secondsLeft = durMin * 60;
        _loading = false;
      });
      _startTimer();
    } catch (e) {
      setState(() {
        _error = 'Could not load the test. Check your connection.';
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
        _submit(auto: true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _timeStr {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _answeredCount {
    var n = 0;
    for (var i = 0; i < _sections.length; i++) {
      final id = _chosen[i];
      if (id != null && (_controllers[id]?.text.trim().isNotEmpty ?? false)) {
        n++;
      }
    }
    return n;
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _sections.length - _answeredCount;
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Submit test?', style: TextStyle(color: t.text)),
        content: Text(
          unanswered > 0
              ? '$unanswered section(s) not answered. Submit anyway?'
              : 'You answered all sections. Submit now?',
          style: TextStyle(color: t.text2),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep writing')),
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
    setState(() => _submitting = true);
    final uid = context.read<AuthProvider>().user?['id'] as int?;
    if (uid == null) {
      setState(() {
        _submitting = false;
        _error = 'Please log in again.';
      });
      return;
    }

    final answers = <Map<String, dynamic>>[];
    for (var i = 0; i < _sections.length; i++) {
      final id = _chosen[i];
      if (id == null) continue;
      final txt = _controllers[id]?.text.trim() ?? '';
      if (txt.isNotEmpty) {
        answers.add({'question_id': id, 'answer_text': txt});
      }
    }

    try {
      final res = await DescriptiveApi.submit(uid, widget.testId, answers);
      if (!mounted) return;
      if (res['success'] == true) {
        final results = (res['results'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DescriptiveResultScreen(
              testTitle: (_test['title'] ?? 'Descriptive Test').toString(),
              results: results,
              grandTotal: (res['grand_total'] ?? 0),
              grandMax: (res['grand_max'] ?? 0),
            ),
          ),
        );
      } else {
        setState(() {
          _submitting = false;
          _error = (res['detail'] ?? 'Submit failed. Try again.').toString();
        });
      }
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
        appBar: AppBar(backgroundColor: t.bg, elevation: 0),
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

    final section = _sections[_activeSection];
    final type = section['type'] as String;
    final qs = (section['questions'] as List).cast<Map<String, dynamic>>();
    final chosenId = _chosen[_activeSection];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: kDNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_test['title']?.toString() ?? 'Descriptive Test',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: _secondsLeft < 60
                      ? const Color(0xFFC0392B)
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined,
                    color: Colors.white, size: 16),
                const SizedBox(width: 5),
                Text(_timeStr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ]),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: kDNavy,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _sections.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final active = i == _activeSection;
                  final id = _chosen[i];
                  final answered = id != null &&
                      (_controllers[id]?.text.trim().isNotEmpty ?? false);
                  return GestureDetector(
                    onTap: () => setState(() => _activeSection = i),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color:
                            active ? kDGold : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (answered) ...[
                          Icon(Icons.check_circle,
                              size: 14,
                              color: active
                                  ? const Color(0xFF1A1A1A)
                                  : kDGold),
                          const SizedBox(width: 4),
                        ],
                        Text(_sections[i]['type'] as String,
                            style: TextStyle(
                                color: active
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text('$type Writing',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: t.text)),
                const SizedBox(height: 4),
                if (qs.length > 1)
                  Text('Choose ONE topic to attempt:',
                      style: TextStyle(fontSize: 13, color: t.muted)),
                const SizedBox(height: 12),
                ...qs.map((q) {
                  final id = q['id'] as int;
                  final selected = chosenId == id;
                  final wl = q['word_limit'];
                  return GestureDetector(
                    onTap: qs.length > 1
                        ? () => setState(() => _chosen[_activeSection] = id)
                        : null,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.card,
                        border: Border.all(
                            color: selected ? kDGold : t.line,
                            width: selected ? 1.6 : 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (qs.length > 1)
                                Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: selected ? kDGold : t.muted,
                                    size: 20),
                              if (qs.length > 1) const SizedBox(width: 8),
                              Expanded(
                                child: Text(q['question']?.toString() ?? '',
                                    style: TextStyle(
                                        fontSize: 14.5,
                                        height: 1.5,
                                        color: t.text,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          if (wl != null && '$wl' != '0') ...[
                            const SizedBox(height: 6),
                            Text('Suggested length: ~$wl words',
                                style:
                                    TextStyle(fontSize: 12, color: t.muted)),
                          ],
                          if (selected) ...[
                            const SizedBox(height: 12),
                            _answerBox(t, id),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(color: t.card, boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -3)),
              ]),
              child: Row(
                children: [
                  Text('$_answeredCount / ${_sections.length} answered',
                      style: TextStyle(color: t.muted, fontSize: 13)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _submitting ? null : _confirmSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDGold,
                      foregroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_submitting ? 'Submitting…' : 'Submit Test',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerBox(DT t, int id) {
    final ctrl = _controllers[id]!;
    final words = ctrl.text.trim().isEmpty
        ? 0
        : ctrl.text.trim().split(RegExp(r'\s+')).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: ctrl,
          maxLines: 10,
          minLines: 6,
          enableInteractiveSelection: false,
          contextMenuBuilder: (context, editableState) =>
              const SizedBox.shrink(),
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: t.text, fontSize: 14, height: 1.5),
          decoration: InputDecoration(
            hintText: 'Write your answer here…',
            hintStyle: TextStyle(color: t.muted),
            filled: true,
            fillColor: t.dark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.02),
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kDGold, width: 1.5)),
          ),
        ),
        const SizedBox(height: 4),
        Text('$words words', style: TextStyle(fontSize: 12, color: t.muted)),
      ],
    );
  }
}
