// lib/presentation/screens/search/search_screen.dart
//
// Website jaisa hi search — ab backend ka /api/search chalta hai.
//
// Pehle ye screen sirf /courses fetch karke local filter lagati thi, isliye
// mock test, descriptive, Tier 2 aur blog kuch bhi nahi milta tha. Ab ek hi
// call me saari categories aati hain, wahi ranking jo website par hai.
//
// platform=app zaroori hai: backend ka default "web" hai, aur wo visible_on
// dekh kar rows chhaanta hai. Bina iske app users ko website-only cheezein
// dikhne lagti hain.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../courses/course_detail_screen.dart';
import '../descriptive/descriptive_series_detail_screen.dart';
import '../mock/mock_series_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const String _site = 'https://selectionlab.in';

  final TextEditingController _controller = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _trending = [];
  String _query = '';
  String _kind = 'all';
  bool _loading = false;
  bool _opening = false;
  String? _error;

  Timer? _debounce;
  // Har keystroke ka jawab aata hai, par zaroori nahi ki usi order me. Purana
  // jawab naye ke baad aa jaye to result galat dikhega — isliye ginti rakhi hai.
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
    if (raw is int) return raw;
    return int.tryParse('${raw ?? ''}');
  }

  Future<void> _loadTrending() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.apiUrl}/search/trending'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 || !mounted) return;
      final data = jsonDecode(res.body);
      final list = data['trending'];
      if (list is List) {
        setState(() {
          _trending = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((e) => (e['label'] ?? '').toString().isNotEmpty)
              .toList();
        });
      }
    } catch (_) {
      // Trending chips zaroori nahi hain — na aayein to screen waise hi chalti hai.
    }
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
    // Har akshar par call nahi — student type karna band kare tab bhejte hain.
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
    final url = Uri.parse(
      '${AppConstants.apiUrl}/search/'
      '?q=${Uri.encodeQueryComponent(q)}'
      '&platform=app&limit=20'
      '${uid != null ? '&user_id=$uid' : ''}',
    );

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

      final data = jsonDecode(res.body);
      final list = data['results'];
      setState(() {
        _results = list is List
            ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
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

  Future<void> _openLink(String path) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$_site$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Search sirf id/title/price bhejti hai, par CourseDetailScreen ko poora row
  /// chahiye (description, features, validity). Isliye tap par asli course
  /// laate hain — aadha row bhej dein to detail page khaali dikhega.
  Future<void> _openCourse(int id) async {
    setState(() => _opening = true);
    Map<String, dynamic>? full;
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.apiUrl}/courses/'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['courses'];
        if (list is List) {
          for (final c in list) {
            final m = Map<String, dynamic>.from(c as Map);
            if ('${m['id']}' == '$id') {
              full = m;
              break;
            }
          }
        }
      }
    } catch (_) {
      // neeche fallback hai
    }
    if (!mounted) return;
    setState(() => _opening = false);

    if (full == null) {
      await _openLink('/course/$id');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: full!)),
    );
  }

  Future<void> _openResult(Map<String, dynamic> r) async {
    HapticFeedback.lightImpact();
    final kind = (r['kind'] ?? '').toString();
    final rawId = r['id'];
    final id = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');

    switch (kind) {
      case 'course':
        if (id != null) {
          await _openCourse(id);
        }
        return;

      case 'mock':
        if (id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MockSeriesDetailScreen(seriesId: id),
            ),
          );
        }
        return;

      case 'descriptive':
        if (id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DescriptiveSeriesDetailScreen(seriesId: id),
            ),
          );
        }
        return;

      // Tier 2 aur blog abhi app me nahi hain — website par bhej dete hain.
      default:
        final link = (r['link'] ?? '').toString();
        if (link.isNotEmpty) await _openLink(link);
    }
  }

  List<String> get _kindTabs {
    final seen = <String>[];
    for (final r in _results) {
      final k = (r['kind_label'] ?? '').toString();
      if (k.isNotEmpty && !seen.contains(k)) seen.add(k);
    }
    return seen;
  }

  List<Map<String, dynamic>> get _shown => _kind == 'all'
      ? _results
      : _results.where((r) => '${r['kind_label']}' == _kind).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (t) {
              _debounce?.cancel();
              _search(t);
            },
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Courses, mock tests, descriptive...',
              hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: isDark ? Colors.white38 : Colors.black38, size: 22),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white38 : Colors.black38,
                          size: 20),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_query.isEmpty && _trending.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _trending.length,
                    itemBuilder: (context, i) {
                      final t = _trending[i];
                      final label = (t['label'] ?? '').toString();
                      final q = (t['query'] ?? label).toString();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(label),
                          labelStyle: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          side: BorderSide(
                              color: AppColors.primary.withOpacity(0.3)),
                          onPressed: () {
                            final link = (t['link'] ?? '').toString();
                            if (link.isNotEmpty) {
                              _openLink(link);
                              return;
                            }
                            _controller.text = q;
                            _debounce?.cancel();
                            setState(() => _query = q);
                            _search(q);
                          },
                        ),
                      );
                    },
                  ),
                ),

              // Category filter — tabhi jab ek se zyada tarah ke result hon
              if (_query.isNotEmpty && _kindTabs.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: ['all', ..._kindTabs].map((k) {
                      final on = _kind == k;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(k == 'all' ? 'All' : k),
                          selected: on,
                          onSelected: (_) => setState(() => _kind = k),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: on
                                ? Colors.black
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                          selectedColor: AppColors.primary,
                          backgroundColor: cardBg,
                          side: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              Expanded(child: _body(isDark, cardBg)),
            ],
          ),
          if (_opening)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _body(bool isDark, Color cardBg) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _emptyState(
          isDark, Icons.cloud_off_rounded, 'Search unavailable', _error!);
    }
    if (_query.trim().isEmpty) {
      return _emptyState(isDark, Icons.search_rounded, 'What are you looking for?',
          'Courses, mock tests, descriptive tests and more');
    }
    if (_shown.isEmpty) {
      return _emptyState(isDark, Icons.search_off_rounded, 'No results found',
          'Try a different keyword or exam name');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shown.length,
      itemBuilder: (context, i) => _resultCard(_shown[i], isDark, cardBg),
    );
  }

  Widget _resultCard(Map<String, dynamic> r, bool isDark, Color cardBg) {
    final priceRaw = r['price'];
    final price = priceRaw == null
        ? null
        : (priceRaw is num ? priceRaw : num.tryParse('$priceRaw'));
    final isFree = price != null && price <= 0;
    final mrpRaw = r['original_price'];
    final mrp = mrpRaw == null
        ? null
        : (mrpRaw is num ? mrpRaw : num.tryParse('$mrpRaw'));

    final thumb = (r['thumbnail_url'] ?? '').toString();
    final subtitle = (r['subtitle'] ?? '').toString();

    return GestureDetector(
      onTap: () => _openResult(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: thumb.isNotEmpty
                  ? Image.network(thumb,
                      width: 90,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder())
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      (r['kind_label'] ?? '').toString(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    (r['title'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ],
                  if (price != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          isFree ? 'FREE' : 'Rs.${_money(price)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color:
                                  isFree ? Colors.green : AppColors.primary),
                        ),
                        if (!isFree && mrp != null && mrp > price) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Rs.${_money(mrp)}',
                            style: TextStyle(
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }

  String _money(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  Widget _thumbPlaceholder() {
    return Container(
      width: 90,
      height: 70,
      color: AppColors.primary.withOpacity(0.15),
      child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 28),
    );
  }

  Widget _emptyState(bool isDark, IconData icon, String title, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      ),
    );
  }
}
