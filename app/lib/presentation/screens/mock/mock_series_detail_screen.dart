// lib/presentation/screens/mock/mock_series_detail_screen.dart
//
// Mock series detail — tests list + buy (Razorpay via /payments/series-order).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/razorpay_service.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/mock_api.dart';
import '../descriptive/descriptive_theme.dart';
import 'mock_instructions_screen.dart';
import '../../../core/utils/share_helper.dart';
import '../checkout/checkout_screen.dart';

class MockSeriesDetailScreen extends StatefulWidget {
  final int seriesId;
  const MockSeriesDetailScreen({super.key, required this.seriesId});

  @override
  State<MockSeriesDetailScreen> createState() =>
      _MockSeriesDetailScreenState();
}

class _MockSeriesDetailScreenState extends State<MockSeriesDetailScreen> {
  Map<String, dynamic>? _series;
  List<Map<String, dynamic>> _tests = [];
  bool _purchased = false;
  bool _loading = true;
  bool _buying = false;
  String? _error;
  final RazorpayService _razorpay = RazorpayService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _razorpay.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = context.read<AuthProvider>().user?['id'] as int?;
    try {
      final res = await MockApi.seriesDetail(widget.seriesId, uid);
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
        _purchased = _series!['is_purchased'] == true;
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

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
          productType: 'mock',
          productId: widget.seriesId,
          title: _series?['title']?.toString() ?? 'Mock Test Series',
          price: _price,
          originalPrice: _orig > _price ? _orig : _price,
          onSuccess: () {},
        ),
      ),
    );
    if (result == true && mounted) {
      _snack('Series unlocked! All tests are now available.');
      _load();
    }
  }

  void _openTest(Map<String, dynamic> t) {
    if (context.read<AuthProvider>().user?['id'] == null) {
      _snack('Please log in to continue.');
      return;
    }
    if (t['is_unlocked'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MockInstructionsScreen(test: t),
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
        title: Text(_series?['title']?.toString() ?? 'Test Series',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
        actions: [
          if (_series != null)
            IconButton(
              icon: Icon(Icons.share_rounded, color: t.text),
              onPressed: () => ShareHelper.share(
                type: 'mock',
                id: _series!['id'],
                title: _series!['title']?.toString() ?? 'Mock Test Series',
                subtitle: (_series!['description'] ?? '').toString(),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(child: Text('Loading…', style: TextStyle(color: t.muted)))
          : _series == null
              ? Center(
                  child: Text(_error ?? 'Series not found.',
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
                    Padding(
                      padding: const EdgeInsets.only(top: 26, bottom: 10),
                      child: Text('Tests',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: t.text)),
                    ),
                    if (_tests.isEmpty)
                      Text('Tests will be added soon.',
                          style: TextStyle(color: t.muted, fontSize: 14))
                    else
                      ..._tests.asMap().entries.map(
                          (e) => _testRow(e.key + 1, e.value, t)),
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
      return _pill('✓ Full access');
    }
    if (_price > 0) {
      return Row(
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
          const SizedBox(width: 12),
          GoldButton(
            label: _buying ? 'Please wait…' : 'Buy Series',
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

  Widget _testRow(int index, Map<String, dynamic> t, DT th) {
    final unlocked = t['is_unlocked'] == true;
    final isFree = t['is_free'] == true;
    final q = t['total_questions'] ?? 0;
    final dur = t['duration_minutes'] ?? 0;
    final marks = t['total_marks'] ?? 0;
    final neg = _num(t['negative_marking']);

    return Opacity(
      opacity: unlocked ? 1 : 0.65,
      child: GestureDetector(
        onTap: () => _openTest(t),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: th.card,
            border: Border.all(color: unlocked ? th.border : th.line),
            borderRadius: BorderRadius.circular(14),
            boxShadow: th.shadow,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlocked
                      ? kDGold.withOpacity(0.15)
                      : th.chip,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(unlocked ? '$index' : '🔒',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: unlocked ? kDGold : th.muted)),
              ),
              const SizedBox(width: 12),
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
                      '$q Qs · $dur min · $marks marks${neg > 0 ? ' · −$neg' : ''}',
                      style: TextStyle(fontSize: 12, color: th.muted),
                    ),
                  ],
                ),
              ),
              if (isFree && !_purchased)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      border: Border.all(color: kDGreen.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('FREE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kDGreen)),
                ),
              if (unlocked)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('→',
                      style: TextStyle(
                          color: kDGold, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
