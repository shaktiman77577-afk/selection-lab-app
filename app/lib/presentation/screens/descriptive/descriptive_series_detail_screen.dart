// lib/presentation/screens/descriptive/descriptive_series_detail_screen.dart
//
// UI matched 1:1 with the website (selectionlab.in/descriptive/[id]).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/descriptive_api.dart';
import 'descriptive_theme.dart';
import 'descriptive_player_screen.dart';
import '../../../core/utils/share_helper.dart';
import '../checkout/checkout_screen.dart';

class DescriptiveSeriesDetailScreen extends StatefulWidget {
  final int seriesId;
  const DescriptiveSeriesDetailScreen({super.key, required this.seriesId});

  @override
  State<DescriptiveSeriesDetailScreen> createState() =>
      _DescriptiveSeriesDetailScreenState();
}

class _DescriptiveSeriesDetailScreenState
    extends State<DescriptiveSeriesDetailScreen> {
  Map<String, dynamic>? _series;
  List<Map<String, dynamic>> _tests = [];
  bool _purchased = false;
  bool _loading = true;
  bool _buying = false;
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
      final res = await DescriptiveApi.seriesDetail(widget.seriesId, uid);
      if (!mounted) return;
      if (res['series'] == null) {
        setState(() {
          _error = 'Series not found.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _series = Map<String, dynamic>.from(res['series'] as Map);
        _tests = (res['tests'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _purchased = res['is_purchased'] == true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load series.';
        _loading = false;
      });
    }
  }

  num _num(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString()) ?? 0;
  num get _price => _num(_series?['price']);
  num get _orig => _num(_series?['original_price']);

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  Future<void> _buy() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?['id'] as int?;
    if (uid == null) {
      _snack('Please log in to continue.');
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          productType: 'descriptive',
          productId: widget.seriesId,
          title: _series?['title']?.toString() ?? 'Descriptive Series',
          price: _price,
          originalPrice: _orig > _price ? _orig : _price,
          onSuccess: () {},
        ),
      ),
    );
    if (result == true && mounted) {
      _snack('Series unlocked! You can now attempt all tests.');
      _load();
    }
  }

  void _openTest(Map<String, dynamic> t) {
    if (context.read<AuthProvider>().user?['id'] == null) {
      _snack('Please log in to continue.');
      return;
    }
    if (t['unlocked'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DescriptivePlayerScreen(
            testId: t['id'] as int,
            seriesId: widget.seriesId,
          ),
        ),
      );
    } else {
      _buy();
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
        iconTheme: IconThemeData(color: t.text),
        title: Text(_series?['title']?.toString() ?? 'Descriptive Series',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
        actions: [
          if (_series != null)
            IconButton(
              icon: Icon(Icons.share_rounded, color: t.text),
              onPressed: () => ShareHelper.share(
                type: 'descriptive',
                id: _series!['id'],
                title: _series!['title']?.toString() ?? 'Descriptive Series',
                subtitle: (_series!['description'] ?? '').toString(),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(child: Text('Loading…', style: TextStyle(color: t.muted)))
          : _error != null && _series == null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFC0392B))))
              : _series == null
                  ? Center(
                      child: Text('Series not found.',
                          style: TextStyle(color: t.muted)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      children: [
                        DescriptiveHero(
                          title: _series!['title']?.toString() ?? '',
                          subtitle:
                              (_series!['description'] ?? '').toString().isEmpty
                                  ? null
                                  : _series!['description'].toString(),
                          footer: _heroFooter(t),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style:
                                  const TextStyle(color: Color(0xFFC0392B), fontSize: 13)),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(top: 26, bottom: 10),
                          child: Text('Tests',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: t.text)),
                        ),
                        if (_tests.isEmpty)
                          Text('No tests in this series yet.',
                              style: TextStyle(color: t.muted, fontSize: 14))
                        else
                          ..._tests.map((x) => _testRow(x, t)),
                        if (!_purchased && _price > 0) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: GoldButton(
                              label: _buying
                                  ? 'Please wait…'
                                  : 'Unlock all tests · ₹${_price.toInt()}',
                              onTap: _buying ? null : _buy,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 13),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
    );
  }

  Widget _heroFooter(DT t) {
    if (_purchased) {
      return _pill('✓ Purchased');
    }
    if (_price > 0) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('₹${_price.toInt()}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              if (_orig > _price) ...[
                const SizedBox(width: 8),
                Text('₹${_orig.toInt()}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough)),
              ],
            ],
          ),
          const SizedBox(width: 12),
          GoldButton(
            label: _buying ? 'Please wait…' : 'Unlock full series',
            onTap: _buying ? null : _buy,
          ),
        ],
      );
    }
    return _pill('Free series');
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: kDPurchasedBg, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: const TextStyle(
                color: kDPurchasedFg,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      );

  Widget _testRow(Map<String, dynamic> t, DT th) {
    final unlocked = t['unlocked'] == true;
    final qc = t['question_count'] ?? 0;
    final dur = t['duration_min'] ?? 30;
    final isFree = t['is_free'] == true;

    return Opacity(
      opacity: unlocked ? 1 : 0.85,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: th.card,
          border: Border.all(color: th.line),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(th.dark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['title']?.toString() ?? 'Test',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: th.text)),
                  const SizedBox(height: 3),
                  Text(
                    '$qc question${qc == 1 ? '' : 's'} · $dur min${isFree ? ' · Free' : ''}',
                    style: TextStyle(fontSize: 12, color: th.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            unlocked
                ? GoldButton(
                    label: 'Start →',
                    onTap: () => _openTest(t),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    fontSize: 13,
                  )
                : GestureDetector(
                    onTap: () => _openTest(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                          border: Border.all(color: th.line),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('🔒 Locked',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: th.muted)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
