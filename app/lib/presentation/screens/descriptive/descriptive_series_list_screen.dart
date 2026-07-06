// lib/presentation/screens/descriptive/descriptive_series_list_screen.dart
//
// UI matched 1:1 with the website (selectionlab.in/descriptive).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/descriptive_api.dart';
import 'descriptive_theme.dart';
import 'descriptive_series_detail_screen.dart';

class DescriptiveSeriesListScreen extends StatefulWidget {
  const DescriptiveSeriesListScreen({super.key});

  @override
  State<DescriptiveSeriesListScreen> createState() =>
      _DescriptiveSeriesListScreenState();
}

class _DescriptiveSeriesListScreenState
    extends State<DescriptiveSeriesListScreen> {
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
      final list = await DescriptiveApi.series(uid);
      if (!mounted) return;
      setState(() {
        _series = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load tests. Pull down to refresh.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        title: Text('Descriptive Tests',
            style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
        iconTheme: IconThemeData(color: t.text),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            DescriptiveHero(
              title: 'Descriptive Writing Practice',
              subtitle:
                  'Essay, Précis and Letter writing tests for banking & descriptive exams. '
                  'Write against the clock, then compare with a model answer and your auto-score.',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 26, bottom: 10),
              child: Text('Test Series',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
            ),
            if (_loading)
              Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Center(
                      child: Text('Loading tests…',
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
                  child: Text(
                      'New descriptive series launching soon — join our Telegram for updates!',
                      style: TextStyle(color: t.muted, fontSize: 14)))
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: _series.length,
                itemBuilder: (_, i) => _card(_series[i], t),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> s, DT t) {
    final title = (s['title'] ?? '').toString();
    final thumb = (s['thumbnail_url'] ?? '').toString();
    final price = _num(s['price']);
    final orig = _num(s['original_price']);
    final free = price <= 0;
    final purchased = s['is_purchased'] == true;
    final locked = !free && !purchased;

    final badgeBg = locked
        ? Colors.black.withOpacity(0.65)
        : free
            ? kDGreen
            : kDGold;
    final badgeFg = (locked || free) ? Colors.white : const Color(0xFF1A1A1A);
    final badgeText = locked ? '🔒 Locked' : (free ? 'FREE' : '✓ Unlocked');

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DescriptiveSeriesDetailScreen(seriesId: s['id'] as int),
          ),
        );
        _load();
      },
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(t.dark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumb.isNotEmpty
                      ? Image.network(thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbFallback(t))
                      : _thumbFallback(t),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(badgeText,
                        style: TextStyle(
                            color: badgeFg,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 36,
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            color: t.text)),
                  ),
                  const SizedBox(height: 6),
                  free
                      ? const Text('FREE',
                          style: TextStyle(
                              color: kDGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5))
                      : Row(
                          children: [
                            Text('₹${price.toInt()}',
                                style: const TextStyle(
                                    color: kDGold,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5)),
                            if (orig > price) ...[
                              const SizedBox(width: 5),
                              Text('₹${orig.toInt()}',
                                  style: TextStyle(
                                      color: t.muted,
                                      fontSize: 11.5,
                                      decoration: TextDecoration.lineThrough)),
                            ],
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback(DT t) => Container(
        color: t.chip,
        child: const Center(child: Text('✍️', style: TextStyle(fontSize: 30))),
      );

  num _num(dynamic v) =>
      v is num ? v : num.tryParse((v ?? '').toString()) ?? 0;
}
