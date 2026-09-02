// lib/presentation/screens/tier2/typing_test_screen.dart
//
// Typing test — teen halat ek hi screen me: pehle rules, phir typing, phir
// result.
//
// Asli exam ke do niyam yahan bhi lagoo hain, isliye kuch cheezein
// jaanbujh kar "asaan" nahi rakhi gayi:
//
// 1) Passage kagaz par hota hai, screen par nahi. Test mode me backend
//    passage_text bhejta hi nahi — pehle PDF download karni padti hai. Sirf
//    practice mode me text aata hai (jinke paas printer nahi hai).
//
// 2) Test number khud select karna padta hai. Asli exam me galat number
//    chunne se poora paper chala jata hai, isliye yahan bhi galat chunne par
//    score nahi milta — attempt phir bhi save hota hai taaki student ko dikhe
//    ki ye galti kitni baar hui.
//
// Checking poori backend par hoti hai (typing_diff.py). App sirf typed text
// aur seconds bhejta hai — yahan koi scoring logic nahi hai, warna do jagah
// do alag hisaab ban jate.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers/tier2_api.dart';
import '../descriptive/descriptive_theme.dart';

enum _Phase { loading, ready, typing, submitting, result }

class TypingTestScreen extends StatefulWidget {
  final int passageId;
  final int userId;
  final bool isPractice;

  const TypingTestScreen({
    super.key,
    required this.passageId,
    required this.userId,
    this.isPractice = false,
  });

  @override
  State<TypingTestScreen> createState() => _TypingTestScreenState();
}

class _TypingTestScreenState extends State<TypingTestScreen> {
  _Phase _phase = _Phase.loading;
  Map<String, dynamic>? _meta;
  String? _error;

  final _typed = TextEditingController();
  final _focus = FocusNode();

  int? _selectedTestNo;
  int _secondsLeft = 0;
  int _elapsed = 0;
  bool _ticking = false;

  Map<String, dynamic>? _result;
  String _passageAfter = '';
  bool _wrongSelection = false;
  String _wrongMsg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticking = false;
    _typed.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await Tier2Api.passage(widget.passageId, widget.userId);
      if (!mounted) return;
      setState(() {
        _meta = m;
        _selectedTestNo = null;
        _secondsLeft = ((m['duration_min'] ?? 10) as num).toInt() * 60;
        _phase = _Phase.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.ready;
        _error = e.toString().contains('403')
            ? 'This test is locked. Purchase the series to attempt it.'
            : 'Could not load this test.';
      });
    }
  }

  // ── Timer ──
  // Ek simple loop — har second setState. Screen band hone par _ticking false
  // ho jata hai, isliye Timer object ko alag se cancel karne ki zaroorat nahi.
  void _startTimer() {
    _ticking = true;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_ticking) return false;
      setState(() {
        _secondsLeft--;
        _elapsed++;
      });
      if (_secondsLeft <= 0) {
        _submit(auto: true);
        return false;
      }
      return true;
    });
  }

  void _begin() {
    if (_selectedTestNo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select which test number you are typing.')),
      );
      return;
    }
    setState(() => _phase = _Phase.typing);
    _startTimer();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _submit({bool auto = false}) async {
    if (_phase == _Phase.submitting || _phase == _Phase.result) return;
    _ticking = false;
    FocusScope.of(context).unfocus();
    setState(() => _phase = _Phase.submitting);

    try {
      final res = await Tier2Api.submitTyping(
        userId: widget.userId,
        passageId: widget.passageId,
        selectedTestNumber: _selectedTestNo ?? 0,
        typedText: _typed.text,
        secondsTaken: _elapsed,
      );
      if (!mounted) return;

      if (res['wrong_selection'] == true) {
        setState(() {
          _wrongSelection = true;
          _wrongMsg = (res['message'] ?? '').toString();
          _phase = _Phase.result;
        });
        return;
      }

      setState(() {
        _result = (res['result'] as Map?)?.cast<String, dynamic>();
        _passageAfter = (res['passage_text'] ?? '').toString();
        _phase = _Phase.result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.typing;
        _error = 'Could not submit. Check your connection and try again.';
      });
      // Timer wapas chalu — student ka bacha hua waqt cheenna theek nahi.
      if (_secondsLeft > 0) _startTimer();
    }
  }

  Future<void> _openPdf() async {
    final url = Uri.parse('${AppConstants.apiUrl}/tier2/typing/pdf/'
        '${widget.passageId}?user_id=${widget.userId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String get _clock {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int get _wordCount =>
      _typed.text.trim().isEmpty ? 0 : _typed.text.trim().split(RegExp(r'\s+')).length;

  Future<bool> _confirmExit() async {
    if (_phase != _Phase.typing) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the test?'),
        content: const Text(
            'Your typing will be lost and this attempt will not be saved.'),
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
      canPop: _phase != _Phase.typing,
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
          automaticallyImplyLeading: _phase != _Phase.typing,
          title: Text(
              (_meta?['title'] ?? (widget.isPractice ? 'Practice' : 'Typing test'))
                  .toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: t.text, fontSize: 16)),
          actions: [
            if (_phase == _Phase.typing)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                      color: _secondsLeft <= 60
                          ? const Color(0xFFC0392B)
                          : kDGold,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_clock,
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w900,
                          fontSize: 14)),
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
      case _Phase.submitting:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Checking your typing…',
                  style: TextStyle(color: t.muted, fontSize: 13.5)),
            ],
          ),
        );
      case _Phase.ready:
        return _readyView(t);
      case _Phase.typing:
        return _typingView(t);
      case _Phase.result:
        return _resultView(t);
    }
  }

  // ── PHASE 1: rules + test number ──

  Widget _readyView(DT t) {
    if (_error != null && _meta == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.text2, fontSize: 14)),
        ),
      );
    }

    final m = _meta!;
    final numbers = ((m['all_test_numbers'] as List?) ?? [])
        .map((e) => (e as num).toInt())
        .toList();
    final practiceText = (m['passage_text'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(15),
            boxShadow: t.shadow,
          ),
          child: Row(
            children: [
              _spec(t, '${m['duration_min'] ?? 10}', 'minutes'),
              _spec(t, '${m['target_wpm'] ?? 30}', 'target WPM'),
              _spec(t, '${m['min_accuracy'] ?? 90}%', 'min accuracy'),
              _spec(t, '${m['word_count'] ?? '—'}', 'words'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (!widget.isPractice) ...[
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: kDGold.withOpacity(0.08),
              border: Border.all(color: kDGold.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Passage is not shown on screen',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kDGold,
                        fontSize: 14)),
                const SizedBox(height: 6),
                Text(
                    'In the real exam the passage is on paper. Download the PDF, '
                    'keep it in front of you, then start. The PDF carries your '
                    'mobile number as a watermark.',
                    style: TextStyle(
                        fontSize: 13, height: 1.55, color: t.text2)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kDGold,
                      side: BorderSide(color: kDGold.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    label: const Text('Download passage PDF',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        if (widget.isPractice && practiceText.isNotEmpty) ...[
          Text('Passage',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: t.text)),
          const SizedBox(height: 4),
          Text('Practice mode — in a real test this stays on paper.',
              style: TextStyle(fontSize: 11.5, color: t.muted)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: SelectableText(practiceText,
                style: TextStyle(
                    fontSize: 14, height: 1.75, color: t.text2)),
          ),
          const SizedBox(height: 18),
        ],

        Text('Which test number are you typing?',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: t.text)),
        const SizedBox(height: 5),
        Text(
            'Pick the number printed on your passage. Choosing the wrong one '
            'means no score — exactly like the real exam.',
            style: TextStyle(fontSize: 12, height: 1.5, color: t.muted)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: (numbers.isEmpty ? [m['test_number'] ?? 1] : numbers)
              .map<Widget>((n) {
            final no = (n as num).toInt();
            final on = _selectedTestNo == no;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTestNo = no);
              },
              child: Container(
                width: 54,
                height: 46,
                decoration: BoxDecoration(
                  color: on ? kDGold : t.card,
                  border: Border.all(color: on ? kDGold : t.line),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text('$no',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: on ? const Color(0xFF1A1A1A) : t.text)),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _begin,
            style: ElevatedButton.styleFrom(
              backgroundColor: kDGold,
              foregroundColor: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Start typing',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 10),
        Text('The timer starts as soon as you tap Start.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: t.muted)),
      ],
    );
  }

  Widget _spec(DT t, String value, String label) => Expanded(
        child: Column(
          children: [
            FittedBox(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: t.text)),
            ),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: t.muted)),
          ],
        ),
      );

  // ── PHASE 2: typing ──

  Widget _typingView(DT t) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          color: t.chip,
          child: Row(
            children: [
              Text('Test ${_selectedTestNo ?? '-'}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: t.text2)),
              const Spacer(),
              Text('$_wordCount words',
                  style: TextStyle(fontSize: 12.5, color: t.muted)),
            ],
          ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            color: const Color(0xFFC0392B).withOpacity(0.12),
            child: Text(_error!,
                style: const TextStyle(
                    color: Color(0xFFC0392B), fontSize: 12.5)),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _typed,
              focusNode: _focus,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              autocorrect: false,
              enableSuggestions: false,
              // Asli exam me paste nahi hota, aur paste se poori practice
              // bekaar ho jati hai — isliye selection toolbar band hai.
              enableInteractiveSelection: false,
              contextMenuBuilder: (_, __) => const SizedBox.shrink(),
              keyboardType: TextInputType.multiline,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 15, height: 1.6, color: t.text),
              decoration: InputDecoration(
                hintText: 'Start typing the passage here…',
                hintStyle: TextStyle(color: t.muted, fontSize: 14),
                filled: true,
                fillColor: t.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kDGold)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submit(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDGold,
                  foregroundColor: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PHASE 3: result ──

  Widget _resultView(DT t) {
    if (_wrongSelection) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 30),
          const Icon(Icons.error_outline_rounded,
              size: 62, color: Color(0xFFC0392B)),
          const SizedBox(height: 16),
          Text('Wrong test number',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: t.text)),
          const SizedBox(height: 10),
          Text(_wrongMsg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.6, color: t.text2)),
          const SizedBox(height: 14),
          Text(
              'No score for this attempt — this is exactly what happens in the '
              'real exam. It has been saved so you can see how often it happens.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.6, color: t.muted)),
          const SizedBox(height: 26),
          _againButton(),
        ],
      );
    }

    final r = _result ?? {};
    final qualified = r['qualified'] == true;
    final segments = (r['segments'] as List?) ?? [];

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
              Icon(
                  qualified
                      ? Icons.verified_rounded
                      : Icons.cancel_outlined,
                  size: 42,
                  color: qualified ? kDGreen : const Color(0xFFC0392B)),
              const SizedBox(height: 9),
              Text(qualified ? 'Qualified' : 'Not qualified',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: qualified ? kDGreen : const Color(0xFFC0392B))),
              if ((r['verdict'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(r['verdict'].toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: t.text2)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _rStat(t, '${r['net_wpm'] ?? 0}', 'Net WPM',
                r['speed_ok'] == true ? kDGreen : const Color(0xFFC0392B)),
            const SizedBox(width: 10),
            _rStat(t, '${r['accuracy'] ?? 0}%', 'Accuracy',
                r['accuracy_ok'] == true ? kDGreen : const Color(0xFFC0392B)),
            const SizedBox(width: 10),
            _rStat(t, '${r['gross_wpm'] ?? 0}', 'Gross WPM', t.text),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _row(t, 'Words typed', '${r['words_typed'] ?? 0}'),
              _row(t, 'Correct', '${r['words_correct'] ?? 0}', kDGreen),
              _row(t, 'Wrong', '${r['words_wrong'] ?? 0}',
                  const Color(0xFFC0392B)),
              _row(t, 'Not attempted', '${r['not_attempted_words'] ?? 0}'),
              Divider(color: t.line, height: 20),
              _row(t, 'Spelling errors', '${r['err_spelling'] ?? 0}'),
              _row(t, 'Punctuation errors', '${r['err_punctuation'] ?? 0}'),
              _row(t, 'Capitalisation errors', '${r['err_caps'] ?? 0}'),
              _row(t, 'Spacing / format errors', '${r['err_format'] ?? 0}'),
            ],
          ),
        ),
        if (segments.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Where you went wrong',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: t.text)),
          const SizedBox(height: 5),
          Text(
              'Green = correct, red = wrong word, grey = you skipped it, '
              'orange = extra word you added.',
              style: TextStyle(fontSize: 11.5, height: 1.5, color: t.muted)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Wrap(
              spacing: 5,
              runSpacing: 7,
              children: segments
                  .map((e) => _segChip(t, Map<String, dynamic>.from(e as Map)))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _againButton(),
      ],
    );
  }

  Widget _segChip(DT t, Map<String, dynamic> s) {
    final op = (s['op'] ?? '').toString();
    final text = (s['text'] ?? '').toString();
    final typed = (s['typed'] ?? '').toString();

    switch (op) {
      case 'ok':
        return Text(text,
            style: TextStyle(fontSize: 13.5, height: 1.6, color: t.text2));

      case 'wrong':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: const Color(0xFFC0392B).withOpacity(0.14),
              borderRadius: BorderRadius.circular(5)),
          child: RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: text,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kDGreen)),
              TextSpan(
                  text: '  $typed',
                  style: const TextStyle(
                      fontSize: 13.5,
                      decoration: TextDecoration.lineThrough,
                      color: Color(0xFFC0392B))),
            ]),
          ),
        );

      case 'missing':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: t.chip, borderRadius: BorderRadius.circular(5)),
          child: Text(text,
              style: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: t.muted)),
        );

      case 'extra':
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.16),
              borderRadius: BorderRadius.circular(5)),
          child: Text('+$typed',
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange)),
        );
    }
  }

  Widget _rStat(DT t, String value, String label, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(13)),
          child: Column(
            children: [
              FittedBox(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: c)),
              ),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11, color: t.muted)),
            ],
          ),
        ),
      );

  Widget _row(DT t, String label, String value, [Color? c]) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 13, color: t.text2))),
            Text(value,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c ?? t.text)),
          ],
        ),
      );

  Widget _againButton() => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
              child: const Text('Back',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _typed.clear();
                setState(() {
                  _result = null;
                  _wrongSelection = false;
                  _error = null;
                  _elapsed = 0;
                  _phase = _Phase.loading;
                });
                _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kDGold,
                foregroundColor: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
              child: const Text('Try again',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      );
}
