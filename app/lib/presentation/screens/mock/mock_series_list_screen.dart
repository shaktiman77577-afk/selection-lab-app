// lib/presentation/screens/mock/mock_series_list_screen.dart
//
// Mock test series list — website-style, app theme aware.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/mock_api.dart';
import '../descriptive/descriptive_theme.dart';
import 'mock_series_detail_screen.dart';

class MockSeriesListScreen extends StatefulWidget {
  const MockSeriesListScreen({super.key});

  @override
  State<MockSeriesListScreen> createState() => _MockSeriesListScreenState();
}

class _MockSeriesListScreenState extends State<MockSeriesListScreen> {
  List<Map<String, dynamic>> _series = [];
  bool _loading = true;
  String? _error;

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
    final uid = context.read<AuthProvider>().user?['id'] as int?;
    try {
      final list = await MockApi.series(uid);
      if (!mounted) return;
      setState(() {
        _series = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load test series. Pull down to refresh.';
        _loading = false;
      });
    }
  }

  num _num(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text('Mock Tests',
            style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            DescriptiveHero(
              title: 'Real Exam-Interface Mocks',
              subtitle:
                  'Full-length mock tests on the same TCS/SSC-pattern screen — '
                  'palette, timer, sections, negative marking. In Hindi + English.',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 26, bottom: 10),
              child: Text('Test Series',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
            ),
            if (_loading)
              Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                      child: Text('Loading test series…',
                          style: TextStyle(color: t.muted))))
            else if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                      child: Column(children: [
                    Text(_error!,
                        style: const TextStyle(color: Color(0xFFC0392B))),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ])))
            else if (_series.isEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text('Test series coming soon. Stay tuned!',
                      style: TextStyle(color: t.muted, fontSize: 14)))
            else
              ..._series.map((s) => _card(s, t)),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> s, DT t) {
    final price = _num(s['price']);
    final purchased = s['is_purchased'] == true;
    final free = price <= 0;
    final testsCount = s['tests_count'] ?? 0;
    final freeCount = _num(s['free_count']);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MockSeriesDetailScreen(seriesId: s['id'] as int)),
        );
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['title']?.toString() ?? '',
                          style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: t.text)),
                      if ((s['description']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(s['description'].toString(),
                            style: TextStyle(
                                fontSize: 13, color: t.muted, height: 1.5)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                purchased
                    ? _badge('OWNED ✓', kDGreen)
                    : free
                        ? _badge('FREE', kDGreen)
                        : _badge('₹${price.toInt()}', kDGold),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text('📝 $testsCount tests',
                  style: TextStyle(fontSize: 12.5, color: t.text2)),
              if (freeCount > 0 && !purchased && price > 0) ...[
                const SizedBox(width: 14),
                Text('🎁 ${freeCount.toInt()} free',
                    style: const TextStyle(fontSize: 12.5, color: kDGreen)),
              ],
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kDGold.withOpacity(0.12),
                border: Border.all(color: kDGold.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                purchased
                    ? 'View Tests →'
                    : freeCount > 0
                        ? 'Try Free Tests →'
                        : 'View Series →',
                style: const TextStyle(
                    color: Color(0xFFB47F00),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      );
}
