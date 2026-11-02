// lib/presentation/screens/descriptive/descriptive_player_screen.dart
//
// Descriptive exam player — sections (by q_type), timer, choose-one-per-section,
// write, paste-blocked answer box, submit -> result. Follows app theme.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/secure_screen.dart';
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

class _DescriptivePlayerScreenState extends State<DescriptivePlayerScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  bool _loadFailed = false; // network / server wajah se — Retry button dikhta hai
  Map<String, dynamic> _test = {};

  List<Map<String, dynamic>> _sections = [];
  int _activeSection = 0;

  final Map<int, TextEditingController> _controllers = {};
  final Map<int, int> _chosen = {};

  Timer? _timer;
  int _secondsLeft = 0;
  bool _submitting = false;
  bool _done = false; // submit ho gaya — ab kuch save nahi
  bool _started = false; // resume / start-over chun liya, timer chal gaya
  int? _uidForKey;
  int _dbgQ = 0; // diagnostic: questions loaded

  @override
  void initState() {
    super.initState();
    SecureScreen.enter(); // paid questions — screenshot band
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    // Back dabaya to bhi likha hua save (text controllers band hone se PEHLE)
    _autosave();
    WidgetsBinding.instance.removeObserver(this);
    SecureScreen.exit();
    _timer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── AUTOSAVE (Nov 2026) ──
  // Pehle kuch save nahi hota tha: app band / back / call aaye to poora likha
  // hua essay-letter gaya. Submit fail hone par bhi error page aata tha aur
  // wapas jaate hi sab khatam. Ab likha hua har 5 sec, section badalne par,
  // app background me jaate hi aur back par phone me save hota hai; dobara
  // kholne par Resume. Sirf submit safal hone ke baad mitta hai.
  String get _progKey => 'desc_progress_${_uidForKey ?? 0}_${widget.testId}';

  bool get _canAutosave =>
      _started && !_loading && !_done && _sections.isNotEmpty;

  void _autosave() {
    if (_canAutosave) _saveProgress();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _autosave();
    }
  }

  Future<void> _saveProgress() async {
    // Data PEHLE (bina await) — dispose me controllers band hone se pehle padh lo
    final texts = <String, String>{};
    _controllers.forEach((id, c) {
      if (c.text.isNotEmpty) texts['$id'] = c.text;
    });
    final data = jsonEncode({
      'texts': texts,
      'chosen': _chosen.map((k, v) => MapEntry('$k', v)),
      'secondsLeft': _secondsLeft,
      'active': _activeSection,
    });
    final key = _progKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, data);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_progKey);
      if (raw == null || raw.isEmpty) return null;
      final d = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final texts = d['texts'];
      // Kuch likha hi nahi tha to resume poochhne ka matlab nahi
      if (texts is! Map || texts.values.every((v) => '$v'.trim().isEmpty)) {
        return null;
      }
      return d;
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
    (d['texts'] as Map?)?.forEach((k, v) {
      final id = int.tryParse('$k');
      final c = id == null ? null : _controllers[id];
      if (c != null) c.text = '$v';
    });
    (d['chosen'] as Map?)?.forEach((k, v) {
      final sec = int.tryParse('$k');
      final id = int.tryParse('$v');
      if (sec != null && id != null && sec < _sections.length &&
          _controllers.containsKey(id)) {
        _chosen[sec] = id;
      }
    });
    final left = (d['secondsLeft'] as num?)?.toInt();
    if (left != null && left > 0 && left <= _secondsLeft) _secondsLeft = left;
    final active = (d['active'] as num?)?.toInt() ?? 0;
    _activeSection = (active >= 0 && active < _sections.length) ? active : 0;
  }

  void _retryLoad() {
    setState(() {
      _error = null;
      _loadFailed = false;
      _loading = true;
    });
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?['id'] as int?;
    _uidForKey = uid;
    try {
      final res = await DescriptiveApi.test(widget.testId, uid);
      if (!mounted) return;
      if (res['test'] == null || res['questions'] == null) {
        // Timeout / server down par "locked or unavailable" nahi — asli baat + Retry
        final serverIssue = res['error'] != null && res['detail'] == null;
        setState(() {
          _loadFailed = serverIssue;
          _error = serverIssue
              ? 'The server is taking too long to respond. Please try again.'
              : (res['detail'] ?? 'This test is locked or unavailable.')
                  .toString();
          _loading = false;
        });
        return;
      }
      final test = Map<String, dynamic>.from(res['test'] as Map);
      final questions = (res['questions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // No questions yet — show a friendly message instead of a blank screen.
      _dbgQ = questions.length;
      if (questions.isEmpty) {
        setState(() {
          _error =
              'This test has no questions yet. Please try another test or check back soon.';
          _loading = false;
        });
        return;
      }

      // Normalize q_type so case/spelling differences still group correctly.
      String norm(dynamic raw) {
        final v = (raw ?? '').toString().trim();
        final l = v.toLowerCase();
        if (l.startsWith('essay')) return 'Essay';
        if (l.startsWith('letter')) return 'Letter';
        if (l.startsWith('prec') || l.startsWith('préc') || l.startsWith('pré')) {
          return 'Precis';
        }
        if (l.startsWith('trans')) return 'Translation';
        return v.isEmpty ? 'Essay' : v;
      }

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final q in questions) {
        grouped.putIfAbsent(norm(q['q_type']), () => []).add(q);
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
      // Absolute fallback — never leave sections empty if we have questions.
      if (sections.isEmpty) {
        sections.add({'type': 'Section', 'questions': questions});
      }

      for (var i = 0; i < sections.length; i++) {
        final qs = sections[i]['questions'] as List;
        if (qs.isNotEmpty) _chosen[i] = _qid(qs.first as Map);
        for (final q in qs) {
          final id = _qid(q);
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

      // Pichhli baar ka likha hua bacha hai? (app band / back / submit fail)
      final saved = await _readSaved();
      if (saved != null && mounted) {
        final resume = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Resume test?'),
            content: const Text(
                'Your unsubmitted answers for this test are saved on this phone. Continue where you left off, or start over?'),
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
        if (!mounted) return;
        if (resume == true) {
          setState(() => _restoreFrom(saved));
        } else {
          await _clearProgress();
        }
      }
      if (!mounted) return;
      _started = true; // ab se autosave — resume dialog ke dauraan purana na mite
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _error = 'Could not load the test. Please check your connection and try again.';
        _loading = false;
      });
    }
  }

  int _qid(Map q) => int.tryParse('${q['id']}') ?? 0;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
        _submit(auto: true);
      } else {
        setState(() => _secondsLeft--);
        if (_secondsLeft % 5 == 0) _autosave();
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

  // Submit (Nov 2026): fail hone par pehle poori screen error page ban jaati thi
  // aur likha hua sab chala jaata tha. Ab pehle save, fail par test wahin +
  // Retry; saved draft sirf safal submit ke baad mitta hai.
  Future<void> _submit({bool auto = false}) async {
    if (_submitting || _done) return;
    _timer?.cancel();
    await _saveProgress();
    if (!mounted) return;
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
        _done = true;
        await _clearProgress();
        if (!mounted) return;
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
        await _submitFailed(
            res['detail'] != null
                ? '${res['detail']}\n\nYour answers are saved on this phone.'
                : 'The server is slow or your connection dropped. Your answers are saved on this phone. Please try again.',
            auto);
      }
    } catch (e) {
      if (!mounted) return;
      await _submitFailed(
          'Submit failed. Check your connection and try again. Your answers are saved on this phone.',
          auto);
    }
  }

  Future<void> _submitFailed(String msg, bool auto) async {
    if (!mounted) return;
    setState(() => _submitting = false);
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit failed'),
        content: Text(msg),
        actions: [
          if (!auto && _secondsLeft > 0)
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Back to test')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retry submit')),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == true) {
      _submit(auto: auto);
    } else {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);

    if (_loading) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(backgroundColor: t.bg, elevation: 0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Loading test…',
                  style: TextStyle(color: t.muted, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
            backgroundColor: t.bg,
            elevation: 0,
            iconTheme: IconThemeData(color: t.text)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.muted, fontSize: 15)),
              if (_loadFailed) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _retryLoad,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kDGold,
                      foregroundColor: const Color(0xFF1A1A1A)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_activeSection >= _sections.length) _activeSection = 0;
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
      body: SafeArea(
        child: Column(
          children: [
            // section tabs
            Container(
              width: double.infinity,
              color: kDNavy,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final active = i == _activeSection;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _activeSection = i);
                        _autosave();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: active ? kDGold : Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${_sections[i]['type']}',
                            style: TextStyle(
                                color: active ? const Color(0xFF1A1A1A) : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    for (final q in qs) _questionCard(t, q, qs.length > 1, chosenId),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _confirmSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDGold,
                          foregroundColor: const Color(0xFF1A1A1A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                            _submitting
                                ? 'Submitting…'
                                : 'Submit Test  ($_answeredCount/${_sections.length})',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
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

  Widget _questionCard(DT t, Map<String, dynamic> q, bool multi, int? chosenId) {
    final id = _qid(q);
    final selected = !multi || chosenId == id;
    final wl = q['word_limit'];
    return GestureDetector(
      onTap: multi
          ? () {
              setState(() => _chosen[_activeSection] = id);
              _autosave();
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(
              color: selected ? kDGold : t.line, width: selected ? 1.6 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (multi)
                  Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? kDGold : t.muted,
                      size: 20),
                if (multi) const SizedBox(width: 8),
                Expanded(
                  child: Text(q['question']?.toString() ?? '(no text)',
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
                  style: TextStyle(fontSize: 12, color: t.muted)),
            ],
            if (selected) ...[
              const SizedBox(height: 12),
              _answerBox(t, id),
            ],
          ],
        ),
      ),
    );
  }

  Widget _answerBox(DT t, int id) {
    final ctrl = _controllers.putIfAbsent(id, () => TextEditingController());
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
          autocorrect: false,           // no spelling hints — real exam
          enableSuggestions: false,     // no keyboard word suggestions
          enableInteractiveSelection: false,
          contextMenuBuilder: (context, editableState) =>
              const SizedBox.shrink(),
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.done, // Enter blocked (same as web)
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\n')), // no new lines
          ],
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
