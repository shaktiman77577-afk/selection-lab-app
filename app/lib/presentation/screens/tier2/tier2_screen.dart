// lib/presentation/screens/tier2/tier2_screen.dart
//
// Tier 2 Practice — series list aur ek series ke andar ke passages.
//
// Ye module app me tha hi nahi. Website par /tier2 se student typing series
// khareedta tha, par app se Tier 2 kabhi khareedi hi nahi ja sakti thi —
// checkout me 'tier2' case hi nahi tha. Ab dono screens yahan hain.
//
// Ek zaroori baat jo poore module ka design tay karti hai:
// backend test passages ka text KABHI nahi bhejta. Asli exam me passage kagaz
// par milta hai, screen par nahi — agar text API me chala jaye to student
// network tab se dekh lega aur practice ka matlab khatam. Isliye test se
// pehle PDF download karna padta hai, aur wahi flow yahan bhi rakha hai.
// Sirf practice passages me text aata hai (jinke paas printer nahi hai).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/tier2_api.dart';
import '../checkout/checkout_screen.dart';
import '../descriptive/descriptive_theme.dart';
import 'excel_hub_screen.dart';
import 'typing_test_screen.dart';

// ── SERIES LIST ─────────────────────────────────────────────────────────────

class Tier2Screen extends StatefulWidget {
  const Tier2Screen({super.key});

  @override
  State<Tier2Screen> createState() => _Tier2ScreenState();
}

class _Tier2ScreenState extends State<Tier2Screen> {
  List<Map<String, dynamic>> _series = [];
  Map<String, dynamic>? _progress;
  bool _loading = true;
  String? _error;

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = _uid;
    try {
      final list = await Tier2Api.series(uid);
      Map<String, dynamic>? prog;
      if (uid != null) {
        try {
          prog = await Tier2Api.typingProgress(uid);
        } catch (_) {
          // Progress optional — na aaye to list phir bhi dikhni chahiye.
        }
      }
      if (!mounted) return;
      setState(() {
        _series = list;
        _progress = prog;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load Tier 2 series. Pull down to refresh.';
      });
    }
  }

  String _money(dynamic v) {
    final n = v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
    return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
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
        title: Text('Tier 2 Practice',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: t.text, fontSize: 17)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            const DescriptiveHero(
              title: 'Typing & Excel Practice',
              subtitle:
                  'Skill test practice for High Court Clerk, SSC CGL Tier 2 and similar exams. '
                  'Real exam rules — passage on paper, timed typing, backend checking.',
            ),
            if (_progress != null && (_progress!['total_attempts'] ?? 0) > 0)
              _progressCard(t),
            const SizedBox(height: 22),
            Text('Series',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text)),
            const SizedBox(height: 12),
            if (_loading)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                    child: Text('Loading…', style: TextStyle(color: t.muted))),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.muted))),
              )
            else if (_series.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                    child: Text('No series yet.',
                        style: TextStyle(color: t.muted))),
              )
            else
              ..._series.map((s) => _seriesCard(t, s)),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(DT t) {
    final p = _progress!;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(15),
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your typing so far',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: t.muted)),
          const SizedBox(height: 11),
          Row(
            children: [
              _pStat(t, 'Best WPM', '${p['best_wpm'] ?? 0}', kDGold),
              _pStat(t, 'Avg WPM', '${p['avg_wpm'] ?? 0}', t.text),
              _pStat(t, 'Accuracy', '${p['avg_accuracy'] ?? 0}%', kDGreen),
              _pStat(t, 'Attempts', '${p['total_attempts'] ?? 0}', t.text2),
            ],
          ),
          if ((p['wrong_selections'] ?? 0) > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${p['wrong_selections']} attempt(s) had the wrong test number selected — '
              'in the real exam that alone costs the paper.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.4, color: const Color(0xFFC0392B)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pStat(DT t, String label, String value, Color c) => Expanded(
        child: Column(
          children: [
            FittedBox(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900, color: c)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: t.muted)),
          ],
        ),
      );

  Widget _seriesCard(DT t, Map<String, dynamic> s) {
    final purchased = s['is_purchased'] == true;
    final price = s['price'];
    final priceNum = price is num ? price : num.tryParse('${price ?? ''}') ?? 0;
    final free = priceNum <= 0;
    final mrp = s['original_price'];
    final mrpNum = mrp is num ? mrp : num.tryParse('${mrp ?? ''}');

    final practice = s['practice_count'] ?? 0;
    final tests = s['typing_test_count'] ?? 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Tier2SeriesScreen(
                seriesId: s['id'] as int, title: (s['title'] ?? '').toString()),
          ),
        ).then((_) => _load());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(15),
          boxShadow: t.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text((s['title'] ?? '').toString(),
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: t.text)),
                ),
                if (purchased)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: kDGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('OWNED',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: kDGreen)),
                  ),
              ],
            ),
            if ((s['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(s['description'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12.5, height: 1.5, color: t.text2)),
            ],
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (practice > 0) _tag(t, '$practice practice'),
                if (tests > 0) _tag(t, '$tests typing tests'),
                _tag(t, 'Excel / CPT'),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                if (!purchased) ...[
                  Text(free ? 'FREE' : 'Rs.${_money(priceNum)}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: free ? kDGreen : kDGold)),
                  if (!free && mrpNum != null && mrpNum > priceNum) ...[
                    const SizedBox(width: 7),
                    Text('Rs.${_money(mrpNum)}',
                        style: TextStyle(
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                            color: t.muted)),
                  ],
                ],
                const Spacer(),
                Text(purchased ? 'Open' : 'View',
                    style: const TextStyle(
                        color: kDGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5)),
                const Icon(Icons.arrow_forward_rounded,
                    color: kDGold, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(DT t, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: t.chip, borderRadius: BorderRadius.circular(7)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: t.text2)),
      );
}

// ── SERIES DETAIL ───────────────────────────────────────────────────────────

class Tier2SeriesScreen extends StatefulWidget {
  final int seriesId;
  final String? title;
  const Tier2SeriesScreen({super.key, required this.seriesId, this.title});

  @override
  State<Tier2SeriesScreen> createState() => _Tier2SeriesScreenState();
}

class _Tier2SeriesScreenState extends State<Tier2SeriesScreen> {
  Map<String, dynamic>? _series;
  List<Map<String, dynamic>> _practice = [];
  List<Map<String, dynamic>> _tests = [];
  bool _purchased = false;
  bool _loading = true;
  String? _error;
  bool _showTests = true;

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await Tier2Api.seriesDetail(widget.seriesId, _uid);
      if (!mounted) return;
      setState(() {
        _series = (d['series'] as Map?)?.cast<String, dynamic>();
        _purchased = d['is_purchased'] == true;
        _practice = ((d['practice'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _tests = ((d['tests'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this series.';
      });
    }
  }

  void _buy() {
    final s = _series;
    if (s == null) return;
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }
    final price = s['price'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          productType: 'tier2',
          productId: widget.seriesId,
          title: (s['title'] ?? 'Tier 2 Practice').toString(),
          price: price is num ? price : num.tryParse('${price ?? ''}') ?? 0,
          originalPrice: s['original_price'] is num
              ? s['original_price'] as num
              : null,
          onSuccess: () {
            if (mounted) _load();
          },
        ),
      ),
    );
  }

  /// Test passage ki PDF. Har page par student ke number ka watermark lagta
  /// hai, isliye backend user_id ko optional nahi rakhta — bina uske 422.
  Future<void> _openPdf(int passageId) async {
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to download the passage.')),
      );
      return;
    }
    final url = Uri.parse(
        '${AppConstants.apiUrl}/tier2/typing/pdf/$passageId?user_id=$uid');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _start(Map<String, dynamic> p) {
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TypingTestScreen(
          passageId: p['id'] as int,
          userId: uid,
          isPractice: (p['kind'] ?? '') == 'practice',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final title = (_series?['title'] ?? widget.title ?? 'Series').toString();
    final list = _showTests ? _tests : _practice;

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
                fontWeight: FontWeight.w800, color: t.text, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!, style: TextStyle(color: t.muted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    children: [
                      if (!_purchased && !_isFree) _buyCard(t),
                      _excelCard(t),
                      const SizedBox(height: 18),
                      _toggle(t),
                      const SizedBox(height: 14),
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: Center(
                              child: Text(
                                  _showTests
                                      ? 'No tests in this series yet.'
                                      : 'No practice passages yet.',
                                  style: TextStyle(color: t.muted))),
                        )
                      else
                        ...list.map((p) => _passageCard(t, p)),
                    ],
                  ),
                ),
    );
  }

  bool get _isFree {
    final p = _series?['price'];
    final n = p is num ? p : num.tryParse('${p ?? ''}') ?? 0;
    return n <= 0;
  }

  Widget _buyCard(DT t) {
    final s = _series!;
    final price = s['price'];
    final priceNum = price is num ? price : num.tryParse('${price ?? ''}') ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [kDNavy, kDNavy2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unlock this series',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 5),
          Text(
              'All typing tests, passage PDFs and full result analysis.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 12.5,
                  height: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Rs.${priceNum == priceNum.roundToDouble() ? priceNum.toInt() : priceNum}',
                  style: const TextStyle(
                      color: kDGold,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const Spacer(),
              ElevatedButton(
                onPressed: _buy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDGold,
                  foregroundColor: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Buy now',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _excelCard(DT t) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExcelHubScreen(
                seriesId: widget.seriesId, purchased: _purchased),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: kDGold.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: kDGreen.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.grid_on_rounded,
                    color: kDGreen, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Excel / CPT',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: t.text)),
                    const SizedBox(height: 3),
                    Text('Formula chart, guided practice and mock tests',
                        style: TextStyle(fontSize: 12, color: t.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(DT t) {
    Widget btn(String label, bool tests) {
      final on = _showTests == tests;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _showTests = tests),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? kDGold : t.card,
              border: Border.all(color: on ? kDGold : t.line),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: on ? const Color(0xFF1A1A1A) : t.text2)),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn('Typing tests (${_tests.length})', true),
        const SizedBox(width: 10),
        btn('Practice (${_practice.length})', false),
      ],
    );
  }

  Widget _passageCard(DT t, Map<String, dynamic> p) {
    final unlocked = p['unlocked'] == true;
    final isPractice = (p['kind'] ?? '') == 'practice';
    final testNo = p['test_number'];

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
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
              Expanded(
                child: Text(
                    (p['title'] ?? '${isPractice ? 'Practice' : 'Test'} $testNo')
                        .toString(),
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: t.text)),
              ),
              if (!unlocked)
                Icon(Icons.lock_rounded, size: 17, color: t.muted)
              else if (p['is_free'] == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          const SizedBox(height: 7),
          Text(
              '${p['duration_min'] ?? 10} min  ·  target ${p['target_wpm'] ?? 30} WPM'
              '${testNo != null ? '  ·  Test $testNo' : ''}',
              style: TextStyle(fontSize: 11.5, color: t.muted)),
          const SizedBox(height: 12),
          if (!unlocked)
            Text('Unlock this series to attempt.',
                style: TextStyle(fontSize: 12, color: t.muted))
          else
            Row(
              children: [
                if (!isPractice) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPdf(p['id'] as int),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.text2,
                        side: BorderSide(color: t.line),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      label: const Text('Passage PDF',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _start(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDGold,
                      foregroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isPractice ? 'Practice' : 'Start test',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
