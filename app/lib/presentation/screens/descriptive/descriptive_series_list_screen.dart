// lib/presentation/screens/descriptive/descriptive_series_list_screen.dart
//
// Redesign (Sep 2026): clean list — filter (All / Enrolled / Free) aur
// ek jaise ProductCard.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/descriptive_api.dart';
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
  int _filter = 0; // 0 All, 1 Enrolled, 2 Free

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  Future<void> _load() async {
    setState(() {
      _loading = _series.isEmpty;
      _error = null;
    });
    try {
      final list = await DescriptiveApi.series(_uid);
      if (!mounted) return;
      setState(() {
        _series = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load tests. Check your internet.';
        _loading = false;
      });
    }
  }

  num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

  List<Map<String, dynamic>> get _shown {
    switch (_filter) {
      case 1:
        return _series.where((s) => s['is_purchased'] == true).toList();
      case 2:
        return _series.where((s) => _num(s['price']) <= 0).toList();
      default:
        return _series;
    }
  }

  Future<void> _open(Map<String, dynamic> s) async {
    final id = s['id'] is int ? s['id'] as int : int.tryParse('${s['id']}');
    if (id == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DescriptiveSeriesDetailScreen(seriesId: id)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final shown = _shown;
    final state = ListStateView(
      loading: _loading,
      error: _error,
      empty: shown.isEmpty,
      emptyText: _filter == 1
          ? 'You have not enrolled in any descriptive series yet.'
          : 'New descriptive series launching soon — join our Telegram for updates!',
      emptyIcon: Icons.edit_note_rounded,
      onRetry: _load,
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Descriptive Tests')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                  'Essay, précis and letter writing — write against the clock, '
                  'then compare with a model answer and your auto-score.',
                  style:
                      TextStyle(fontSize: 13, height: 1.5, color: t.muted)),
            ),
            FilterChips(
              options: const ['All', 'Enrolled', 'Free'],
              selected: _filter,
              onChanged: (i) => setState(() => _filter = i),
            ),
            const SizedBox(height: 12),
            if (state.show)
              state
            else
              for (final s in shown)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ProductCard(
                    img: '${s['thumbnail_url_mobile'] ?? s['thumbnail_url'] ?? ''}',
                    title: '${s['title'] ?? ''}',
                    meta: _num(s['test_count']) > 0
                        ? '${_num(s['test_count']).toInt()} tests'
                        : 'Writing tests',
                    price: _num(s['price']),
                    original: _num(s['original_price']),
                    owned: s['is_purchased'] == true,
                    fallbackIcon: Icons.edit_note_rounded,
                    onTap: () => _open(s),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
