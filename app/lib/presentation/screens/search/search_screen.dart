// lib/presentation/screens/search/search_screen.dart
//
// Website jaisa search — backend ka /api/search (platform=app, taaki
// website-only cheezein na dikhein). Ek hi call me saari categories.
//
// Redesign (Sep 2026): clean look. Aur: Tier 2, blog jaise jo results app me
// native nahi hain, wo ab app ke andar hi (WebView, auto-login) khulte hain —
// pehle browser me jaate the jahan student logged-in nahi hota tha.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/shop.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import '../courses/course_detail_screen.dart';
import '../descriptive/descriptive_series_detail_screen.dart';
import '../descriptive/descriptive_theme.dart';
import '../mock/mock_series_detail_screen.dart';
import '../web/site_web_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _trending = [];
  String _query = '';
  String _kind = 'all';
  bool _loading = false;
  String? _error;

  Timer? _debounce;
  // build me set hota hai — itemBuilder ke andar watch nahi karna padta
  bool _shop = false;
  // Purana jawab naye ke baad aa jaye to galat result na dikhe
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  int? get _userId {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  Future<void> _loadTrending() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.apiUrl}/search/trending'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 || !mounted) return;
      final list = jsonDecode(res.body)['trending'];
      if (list is List) {
        setState(() {
          _trending = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) => '${e['label'] ?? ''}'.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {}
  }

  void _onChanged(String text) {
    setState(() => _query = text);
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
        _kind = 'all';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;
    final myReq = ++_reqId;
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = _userId;
    final url = Uri.parse('${AppConstants.apiUrl}/search/'
        '?q=${Uri.encodeQueryComponent(q)}&platform=app&limit=20'
        '${uid != null ? '&user_id=$uid' : ''}');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted || myReq != _reqId) return;
      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Search is not working right now. Please try again.';
        });
        return;
      }
      final list = jsonDecode(res.body)['results'];
      setState(() {
        _results = list is List
            ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _kind = 'all';
        _loading = false;
      });
    } catch (_) {
      if (!mounted || myReq != _reqId) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Check your connection.';
      });
    }
  }

  /// Website ka link: '/...' ho to app ke andar (auto-login), warna browser
  Future<void> _openLink(String link) async {
    if (link.startsWith('/')) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => SiteWebScreen(path: link)));
      return;
    }
    try {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openResult(Map<String, dynamic> r) {
    HapticFeedback.lightImpact();
    final raw = r['id'];
    final id = raw is int ? raw : int.tryParse('${raw ?? ''}');
    void push(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    switch ('${r['kind'] ?? ''}') {
      case 'course':
        // CourseDetail khud poora course mangwa leta hai
        if (id != null) {
          push(CourseDetailScreen(course: {
            'id': id,
            'title': r['title'],
            'thumbnail_url': r['thumbnail_url'],
          }));
        }
        return;
      case 'mock':
        if (id != null) push(MockSeriesDetailScreen(seriesId: id));
        return;
      case 'descriptive':
        if (id != null) push(DescriptiveSeriesDetailScreen(seriesId: id));
        return;
      default:
        final link = '${r['link'] ?? ''}';
        if (link.isNotEmpty) _openLink(link);
    }
  }

  List<String> get _kindTabs {
    final seen = <String>[];
    for (final r in _results) {
      final k = '${r['kind_label'] ?? ''}';
      if (k.isNotEmpty && !seen.contains(k)) seen.add(k);
    }
    return seen;
  }

  List<Map<String, dynamic>> get _shown => _kind == 'all'
      ? _results
      : _results.where((r) => '${r['kind_label']}' == _kind).toList();

  num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    _shop = context.shopOn;
    final tabs = ['all', ..._kindTabs];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (s) {
                _debounce?.cancel();
                _search(s);
              },
              style: TextStyle(color: t.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Courses, mock tests, descriptive…',
                contentPadding: EdgeInsets.zero,
                fillColor: t.bg,
                prefixIcon: Icon(Icons.search_rounded, color: t.muted, size: 22),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded, color: t.muted, size: 20),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_query.isEmpty && _trending.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SectionHeader('Trending'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tr in _trending)
                      ActionChip(
                        avatar: Icon(Icons.trending_up_rounded,
                            size: 16, color: t.primary),
                        label: Text('${tr['label']}'),
                        onPressed: () {
                          final link = '${tr['link'] ?? ''}';
                          if (link.isNotEmpty) {
                            _openLink(link);
                            return;
                          }
                          final q = '${tr['query'] ?? tr['label']}';
                          _controller.text = q;
                          _debounce?.cancel();
                          setState(() => _query = q);
                          _search(q);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_query.isNotEmpty && tabs.length > 2) ...[
            const SizedBox(height: 12),
            FilterChips(
              options: [for (final k in tabs) k == 'all' ? 'All' : k],
              selected: tabs.indexOf(_kind).clamp(0, tabs.length - 1),
              onChanged: (i) => setState(() => _kind = tabs[i]),
            ),
          ],
          Expanded(child: _body(t)),
        ],
      ),
    );
  }

  Widget _body(DT t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(icon: Icons.cloud_off_rounded, text: _error!);
    }
    if (_query.trim().isEmpty) {
      return _trending.isEmpty
          ? const EmptyState(
              icon: Icons.search_rounded,
              text: 'Search courses, mock tests, descriptive tests and more')
          : const SizedBox.shrink();
    }
    final shown = _shown;
    if (shown.isEmpty) {
      return const EmptyState(
          icon: Icons.search_off_rounded,
          text: 'No results found.\nTry a different keyword or exam name.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: shown.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _resultCard(t, shown[i]),
    );
  }

  Widget _resultCard(DT t, Map<String, dynamic> r) {
    final price = _n(r['price']);
    final mrp = _n(r['original_price']);
    final free = price != null && price <= 0;
    final thumb = '${r['thumbnail_url'] ?? ''}';
    final subtitle = '${r['subtitle'] ?? ''}';
    String money(num v) =>
        v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => _openResult(r),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 84,
              height: 64,
              child: thumb.isEmpty
                  ? Container(
                      color: t.chip,
                      child: Icon(Icons.menu_book_rounded, color: t.muted))
                  : Container(
                      color: t.chip,
                      child: Image.network(thumb,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.menu_book_rounded, color: t.muted)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ('${r['kind_label'] ?? ''}'.isNotEmpty)
                  Tag('${r['kind_label']}'.toUpperCase(), color: t.primary),
                const SizedBox(height: 4),
                Text('${r['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: t.text)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: t.muted)),
                if (price != null && (free || _shop)) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(free ? 'FREE' : '₹${money(price)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: free ? kDGreen : t.text)),
                    if (!free && mrp != null && mrp > price) ...[
                      const SizedBox(width: 6),
                      Text('₹${money(mrp)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: t.muted,
                              decoration: TextDecoration.lineThrough)),
                    ],
                  ]),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.muted),
        ],
      ),
    );
  }
}
