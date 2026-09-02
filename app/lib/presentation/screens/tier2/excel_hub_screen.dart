// lib/presentation/screens/tier2/excel_hub_screen.dart
//
// Excel / CPT practice — chart, guided practice aur mock tests.
//
// Isme teen cheezein hain:
//   ExcelGrid       — chhoti Excel jaisi table (test screen bhi yahi use karta hai)
//   ExcelHubScreen  — 3 tabs: Chart / Practice / Tests
//   ExcelPracticeScreen — ek question, jitni baar chahe try karo
//
// Grid asli Excel ka clone nahi hai — 26 column, ribbon, sheet tabs kuch nahi.
// Sirf utna jitne me formula test ho jaye. Formula alag box me type hota hai,
// cell ke andar nahi — mobile par cell ke andar type karna takleef deta hai,
// aur asli Excel me bhi formula bar upar hi hoti hai.
//
// Locked cards ka syntax/example backend bhejta hi nahi — isliye yahan blur
// lagane ki zaroorat hi nahi padti, data hota hi nahi.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/tier2_api.dart';
import '../descriptive/descriptive_theme.dart';
import 'excel_test_screen.dart';

// ── SHARED: Excel grid ──────────────────────────────────────────────────────

/// "Name|Sales;Raju|1200" -> [["Name","Sales"],["Raju","1200"]]
List<List<String>> parseGrid(String? gridData) => (gridData ?? '')
    .split(';')
    .where((l) => l.trim().isNotEmpty)
    .map((l) => l.split('|'))
    .toList();

String colLetter(int i) {
  var s = '';
  var n = i + 1;
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

enum AnswerState { none, right, wrong }

class ExcelGrid extends StatelessWidget {
  final String? gridData;
  final String? targetCell;
  final String? answer;
  final AnswerState state;

  const ExcelGrid({
    super.key,
    required this.gridData,
    required this.targetCell,
    this.answer,
    this.state = AnswerState.none,
  });

  static const _line = Color(0xFFD0D7E2);
  static const _head = Color(0xFFEEF1F6);
  static const _blue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    final rows = parseGrid(gridData);
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final target = (targetCell ?? '').toUpperCase();

    Color borderFor(bool isTarget) {
      if (!isTarget) return _line;
      switch (state) {
        case AnswerState.right:
          return const Color(0xFF1C7A3E);
        case AnswerState.wrong:
          return const Color(0xFFC0392B);
        case AnswerState.none:
          return _blue;
      }
    }

    // Grid hamesha safed rehta hai — dark mode me bhi. Excel safed hi hota
    // hai, aur student ko wahi dekhna hai jo exam me dikhega.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _hcell('', 34),
                ...List.generate(cols, (c) => _hcell(colLetter(c), 86)),
              ],
            ),
            ...List.generate(rows.length, (r) {
              return Row(
                children: [
                  _hcell('${r + 1}', 34),
                  ...List.generate(cols, (c) {
                    final ref = '${colLetter(c)}${r + 1}';
                    final isTarget = ref == target;
                    final raw = c < rows[r].length ? rows[r][c] : '';
                    final isNum =
                        RegExp(r'^-?\d+(\.\d+)?$').hasMatch(raw.trim());
                    final show = isTarget && (answer ?? '').isNotEmpty
                        ? answer!
                        : raw;

                    return Container(
                      width: 86,
                      height: 32,
                      alignment:
                          isNum ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isTarget
                            ? borderFor(true).withOpacity(0.07)
                            : Colors.white,
                        border: Border.all(
                            color: borderFor(isTarget),
                            width: isTarget ? 2 : 0.5),
                      ),
                      child: Text(show,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF1A1A1A),
                              fontWeight: isTarget
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _hcell(String text, double w) => Container(
        width: w,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: _head, border: Border.all(color: _line, width: 0.5)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5F6A7D))),
      );
}

/// Formula bar — "fx  =" ke saath ek monospace input.
class FormulaBar extends StatelessWidget {
  final TextEditingController controller;
  final String? targetCell;
  final bool disabled;
  final VoidCallback onSubmit;
  final ValueChanged<String>? onChanged;

  const FormulaBar({
    super.key,
    required this.controller,
    required this.targetCell,
    required this.onSubmit,
    this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          decoration: BoxDecoration(
            color: t.chip,
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(10)),
            border: Border.all(color: t.line),
          ),
          child: Text((targetCell ?? 'fx').toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: t.muted)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !disabled,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: t.text,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '=SUM(B2:B5)',
              hintStyle: TextStyle(
                  color: t.muted, fontSize: 13, fontFamily: 'monospace'),
              filled: true,
              fillColor: t.card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: t.line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: t.line)),
              focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: kDGold)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
            ),
          ),
        ),
        GestureDetector(
          onTap: disabled ? null : onSubmit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: disabled ? t.chip : kDGold,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(10)),
            ),
            child: Icon(Icons.check_rounded,
                size: 20,
                color: disabled ? t.muted : const Color(0xFF1A1A1A)),
          ),
        ),
      ],
    );
  }
}

// ── HUB ─────────────────────────────────────────────────────────────────────

class ExcelHubScreen extends StatefulWidget {
  final int seriesId;
  final bool purchased;
  const ExcelHubScreen(
      {super.key, required this.seriesId, this.purchased = false});

  @override
  State<ExcelHubScreen> createState() => _ExcelHubScreenState();
}

class _ExcelHubScreenState extends State<ExcelHubScreen> {
  int _tab = 0;
  bool _hindi = false;

  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _practice = [];
  List<Map<String, dynamic>> _tests = [];
  bool _purchased = false;
  bool _loading = true;

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  @override
  void initState() {
    super.initState();
    _purchased = widget.purchased;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _uid;
    try {
      final results = await Future.wait([
        Tier2Api.excelChart(widget.seriesId, uid),
        Tier2Api.excelPractice(widget.seriesId, uid),
        Tier2Api.excelTests(widget.seriesId, uid),
      ]);
      if (!mounted) return;
      setState(() {
        _cards = ((results[0]['cards'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _practice = ((results[1]['questions'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _tests = ((results[2]['tests'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _purchased = results[0]['is_purchased'] == true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _chartPdf() async {
    final uid = _uid;
    if (uid == null) return;
    final url = Uri.parse('${AppConstants.apiUrl}/tier2/excel/chart/pdf/'
        '${widget.seriesId}?user_id=$uid');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _txt(Map<String, dynamic> m, String en, String hi) {
    if (_hindi && (m[hi]?.toString().isNotEmpty ?? false)) {
      return m[hi].toString();
    }
    return (m[en] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text('Excel / CPT',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: t.text, fontSize: 17)),
        actions: [
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                _tabBtn(t, 0, 'Chart (${_cards.length})'),
                const SizedBox(width: 8),
                _tabBtn(t, 1, 'Practice (${_practice.length})'),
                const SizedBox(width: 8),
                _tabBtn(t, 2, 'Tests (${_tests.length})'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _tab == 0
                        ? _chartTab(t)
                        : _tab == 1
                            ? _practiceTab(t)
                            : _testsTab(t),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(DT t, int i, String label) {
    final on = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? kDGold : t.card,
            border: Border.all(color: on ? kDGold : t.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: FittedBox(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: on ? const Color(0xFF1A1A1A) : t.text2)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab 1: formula chart ──

  Widget _chartTab(DT t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        if (_purchased)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _chartPdf,
                icon: const Icon(Icons.download_rounded, size: 17),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kDGold,
                  side: BorderSide(color: kDGold.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                label: const Text('Download full chart PDF',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ..._cards.map((c) => _chartCard(t, c)),
      ],
    );
  }

  Widget _chartCard(DT t, Map<String, dynamic> c) {
    final unlocked = c['unlocked'] == true;
    final syntax = (c['syntax'] ?? '').toString();
    final example = (c['example'] ?? '').toString();
    final result = (c['example_result'] ?? '').toString();
    final warning = _txt(c, 'warning_en', 'warning_hi');
    final pqId = c['practice_question_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(13),
        boxShadow: t.shadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: t.muted,
          collapsedIconColor: t.muted,
          title: Row(
            children: [
              Expanded(
                child: Text((c['name'] ?? '').toString(),
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: t.text)),
              ),
              if (!unlocked)
                Icon(Icons.lock_rounded, size: 15, color: t.muted),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(_txt(c, 'what_en', 'what_hi'),
                style: TextStyle(fontSize: 12, height: 1.4, color: t.muted)),
          ),
          children: [
            if (!unlocked)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Syntax, example and common mistakes unlock with this series.',
                    style: TextStyle(fontSize: 12.5, color: t.muted)),
              )
            else ...[
              if (syntax.isNotEmpty) _codeBox(t, 'Syntax', syntax),
              if (example.isNotEmpty)
                _codeBox(t, 'Example', example,
                    trailing: result.isNotEmpty ? '→ $result' : null),
              if (warning.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFC0392B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(9)),
                  child: Text(warning,
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Color(0xFFC0392B))),
                ),
              ],
              if (pqId != null) ...[
                const SizedBox(height: 11),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openPractice(pqId as int),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDGold,
                      foregroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                    child: const Text('Practice this',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _codeBox(DT t, String label, String code, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: t.muted)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: t.chip, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(code,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                        height: 1.5,
                        color: t.text)),
                if (trailing != null) ...[
                  const SizedBox(height: 4),
                  Text(trailing,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: kDGreen)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: practice ──

  void _openPractice(int questionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExcelPracticeScreen(questionId: questionId, hindi: _hindi),
      ),
    ).then((_) => _load());
  }

  Widget _practiceTab(DT t) {
    if (_practice.isEmpty) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(
              child: Text('No practice questions yet.',
                  style: TextStyle(color: t.muted))),
        ),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: _practice.length,
      itemBuilder: (context, i) {
        final q = _practice[i];
        final unlocked = q['unlocked'] == true;
        final done = q['done'] == true;

        return GestureDetector(
          onTap: unlocked ? () => _openPractice(q['id'] as int) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: done
                          ? kDGreen.withOpacity(0.15)
                          : t.chip,
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(
                      done
                          ? Icons.check_rounded
                          : (unlocked
                              ? Icons.edit_note_rounded
                              : Icons.lock_rounded),
                      size: 17,
                      color: done ? kDGreen : t.muted),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((q['concept'] ?? '').toString(),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: t.text)),
                      const SizedBox(height: 3),
                      Text(_txt(q, 'instruction_en', 'instruction_hi'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, height: 1.4, color: t.muted)),
                    ],
                  ),
                ),
                if (unlocked)
                  Icon(Icons.chevron_right_rounded, color: t.muted),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab 3: tests ──

  Widget _testsTab(DT t) {
    if (_tests.isEmpty) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(
              child: Text('No tests yet.', style: TextStyle(color: t.muted))),
        ),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: _tests.length,
      itemBuilder: (context, i) {
        final tst = _tests[i];
        final unlocked = tst['unlocked'] == true;
        final best = tst['best'] as Map?;

        return Container(
          margin: const EdgeInsets.only(bottom: 11),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(13),
            boxShadow: t.shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        (tst['title'] ?? 'Mock ${tst['mock_number'] ?? ''}')
                            .toString(),
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: t.text)),
                  ),
                  if (!unlocked)
                    Icon(Icons.lock_rounded, size: 16, color: t.muted)
                  else if (tst['is_free'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: kDGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('FREE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: kDGreen)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                  '${tst['duration_min'] ?? 10} min  ·  pass ${tst['pass_marks'] ?? 4} marks'
                  '${best != null ? '  ·  best ${best['score']}/${best['total']}' : ''}',
                  style: TextStyle(fontSize: 11.5, color: t.muted)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: unlocked
                      ? () {
                          final uid = _uid;
                          if (uid == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please log in first.')),
                            );
                            return;
                          }
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExcelTestScreen(
                                  testId: tst['id'] as int,
                                  userId: uid,
                                  hindi: _hindi),
                            ),
                          ).then((_) => _load());
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: unlocked ? kDGold : t.chip,
                    foregroundColor: unlocked
                        ? const Color(0xFF1A1A1A)
                        : t.muted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                      unlocked
                          ? (best != null ? 'Attempt again' : 'Start test')
                          : 'Locked',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── PRACTICE PLAYER ─────────────────────────────────────────────────────────

class ExcelPracticeScreen extends StatefulWidget {
  final int questionId;
  final bool hindi;
  const ExcelPracticeScreen(
      {super.key, required this.questionId, this.hindi = false});

  @override
  State<ExcelPracticeScreen> createState() => _ExcelPracticeScreenState();
}

class _ExcelPracticeScreenState extends State<ExcelPracticeScreen> {
  Map<String, dynamic>? _q;
  bool _loading = true;
  bool _busy = false;
  bool _showHints = false;
  String? _error;
  Map<String, dynamic>? _res;

  final _formula = TextEditingController();

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _formula.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Tier2Api.excelPracticeQuestion(widget.questionId, _uid);
      if (!mounted) return;
      setState(() {
        _q = (d['question'] as Map?)?.cast<String, dynamic>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this question.';
      });
    }
  }

  Future<void> _check() async {
    if (_formula.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await Tier2Api.excelCheck(
        userId: _uid,
        questionId: widget.questionId,
        formula: _formula.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _res = Map<String, dynamic>.from(r);
        _busy = false;
      });
      if (r['correct'] == true) HapticFeedback.mediumImpact();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not check your formula. Try again.';
      });
    }
  }

  String _t(String en, String hi) {
    final q = _q ?? {};
    if (widget.hindi && (q[hi]?.toString().isNotEmpty ?? false)) {
      return q[hi].toString();
    }
    return (q[en] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final q = _q;
    final correct = _res?['correct'] == true;

    final hints = (widget.hindi
            ? (q?['hints_hi'] as List?)
            : (q?['hints_en'] as List?)) ??
        (q?['hints_en'] as List?) ??
        [];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text((q?['concept'] ?? 'Practice').toString(),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: t.text,
                fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : q == null
              ? Center(
                  child: Text(_error ?? 'Question not found',
                      style: TextStyle(color: t.muted)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  children: [
                    Text(_t('instruction_en', 'instruction_hi'),
                        style: TextStyle(
                            fontSize: 15, height: 1.6, color: t.text)),
                    const SizedBox(height: 16),
                    ExcelGrid(
                      gridData: q['grid_data']?.toString(),
                      targetCell: q['target_cell']?.toString(),
                      answer: correct ? (_res?['value'] ?? '').toString() : '',
                      state: _res == null
                          ? AnswerState.none
                          : (correct ? AnswerState.right : AnswerState.wrong),
                    ),
                    const SizedBox(height: 14),
                    FormulaBar(
                      controller: _formula,
                      targetCell: q['target_cell']?.toString(),
                      disabled: _busy || correct,
                      onChanged: (_) {
                        if (_res != null) setState(() => _res = null);
                      },
                      onSubmit: _check,
                    ),
                    if (_res != null) ...[
                      const SizedBox(height: 13),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: (correct ? kDGreen : const Color(0xFFC0392B))
                              .withOpacity(0.10),
                          border: Border.all(
                              color: correct
                                  ? kDGreen
                                  : const Color(0xFFC0392B)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(correct ? 'Correct' : 'Not quite',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: correct
                                        ? kDGreen
                                        : const Color(0xFFC0392B))),
                            const SizedBox(height: 5),
                            Text(
                                (widget.hindi &&
                                        (_res?['feedback_hi'] ?? '')
                                            .toString()
                                            .isNotEmpty
                                    ? _res!['feedback_hi']
                                    : _res?['feedback'] ?? '')
                                    .toString(),
                                style: TextStyle(
                                    fontSize: 13, height: 1.5, color: t.text2)),
                          ],
                        ),
                      ),
                    ],
                    if (hints.isNotEmpty && !correct) ...[
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showHints = !_showHints),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                size: 17, color: kDGold),
                            const SizedBox(width: 6),
                            Text(_showHints ? 'Hide hints' : 'Show hints',
                                style: const TextStyle(
                                    color: kDGold,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      if (_showHints) ...[
                        const SizedBox(height: 9),
                        ...hints.map((h) => Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 6, right: 8),
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                          color: kDGold,
                                          shape: BoxShape.circle),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(h.toString(),
                                        style: TextStyle(
                                            fontSize: 13,
                                            height: 1.5,
                                            color: t.text2)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                    if (correct) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDGreen,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11)),
                          ),
                          child: const Text('Done',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15)),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
