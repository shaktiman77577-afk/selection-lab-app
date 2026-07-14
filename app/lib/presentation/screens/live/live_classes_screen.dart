import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../checkout/checkout_screen.dart';

class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key});

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _batches = [];
  bool _loading = true;

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _uid;
    final q = uid != null ? '?user_id=$uid' : '';
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${AppConstants.apiUrl}/live/classes$q'))
            .timeout(const Duration(seconds: 12)),
        http.get(Uri.parse('${AppConstants.apiUrl}/live/batches$q'))
            .timeout(const Duration(seconds: 12)),
      ]);

      if (!mounted) return;
      final cls = results[0].statusCode == 200
          ? List<Map<String, dynamic>>.from(
              jsonDecode(results[0].body)['classes'] ?? [])
          : <Map<String, dynamic>>[];
      final bat = results[1].statusCode == 200
          ? List<Map<String, dynamic>>.from(
              jsonDecode(results[1].body)['batches'] ?? [])
          : <Map<String, dynamic>>[];

      setState(() {
        _classes = cls;
        _batches = bat;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _join(String url) async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Could not open the meeting link.');
    }
  }

  Future<void> _buy(Map<String, dynamic> item, String kind) async {
    if (_uid == null) {
      _snack('Please log in to continue.');
      return;
    }
    final price = _num(item['price']);
    final orig = _num(item['original_price']);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          productType: kind == 'batch' ? 'live_batch' : 'live_class',
          productId: item['id'] as int,
          title: item['title']?.toString() ?? 'Live Class',
          price: price,
          originalPrice: orig > price ? orig : price,
          onSuccess: () {},
        ),
      ),
    );
    if (result == true && mounted) {
      _snack('Enrolled! You can join when the class starts.');
      _load();
    }
  }

  num _num(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString()) ?? 0;

  // ── Time helpers ───────────────────────────────────────────────────────────
  DateTime? _startOf(Map<String, dynamic> c) {
    try {
      return DateTime.parse(c['scheduled_at'].toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _whenLabel(DateTime t) {
    final now = DateTime.now();
    final diff = t.difference(now);
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    if (diff.isNegative && diff.inMinutes > -120) return 'Live now · started $time';
    if (diff.inMinutes.abs() < 60 && !diff.isNegative) {
      return 'Starts in ${diff.inMinutes} min';
    }
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    if (sameDay) return 'Today · $time';

    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow =
        t.year == tomorrow.year && t.month == tomorrow.month && t.day == tomorrow.day;
    if (isTomorrow) return 'Tomorrow · $time';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${t.day} ${months[t.month - 1]} · $time';
  }

  bool _isLiveNow(Map<String, dynamic> c) => c['can_join'] == true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text('Live Classes',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_classes.isEmpty && _batches.isEmpty)
              ? _empty(isDark)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_classes.isNotEmpty) ...[
                        _label(isDark, 'UPCOMING CLASSES'),
                        ..._classes.map((c) => _classCard(c, isDark)),
                        const SizedBox(height: 20),
                      ],
                      if (_batches.isNotEmpty) ...[
                        _label(isDark, 'LIVE BATCHES'),
                        ..._batches.map((b) => _batchCard(b, isDark)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _label(bool isDark, String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(t,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: isDark ? Colors.white38 : Colors.black38)),
      );

  Widget _classCard(Map<String, dynamic> c, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final start = _startOf(c);
    final isFree = c['is_free'] == true;
    final unlocked = c['is_unlocked'] == true;
    final liveNow = _isLiveNow(c);
    final price = _num(c['price']);
    final faculty = (c['faculty'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: liveNow
            ? Border.all(color: Colors.red.withOpacity(0.6), width: 1.4)
            : null,
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (liveNow) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.circle, color: Colors.white, size: 7),
                      SizedBox(width: 5),
                      Text('LIVE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isFree)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('FREE',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          if (liveNow || isFree) const SizedBox(height: 8),
          Text(c['title']?.toString() ?? '',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
          if (faculty.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(faculty,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 14, color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  start != null ? _whenLabel(start) : '',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: liveNow
                          ? Colors.red
                          : (isDark ? Colors.white70 : Colors.black54)),
                ),
              ),
              Text('${c['duration_min'] ?? 60} min',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: _classButton(c, unlocked, liveNow, price),
          ),
        ],
      ),
    );
  }

  Widget _classButton(
      Map<String, dynamic> c, bool unlocked, bool liveNow, num price) {
    // Live now + has access → Join
    if (liveNow && c['meet_url'] != null) {
      return ElevatedButton.icon(
        onPressed: () => _join(c['meet_url'].toString()),
        icon: const Icon(Icons.videocam_rounded, size: 18),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        label: const Text('Join Live Class',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      );
    }

    // Has access, not started yet
    if (unlocked) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_circle_rounded, size: 17),
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: Colors.green,
          side: BorderSide(color: Colors.green.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        label: const Text('Enrolled · Link opens 10 min before',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
      );
    }

    // Locked → buy
    return ElevatedButton(
      onPressed: () => _buy(c, 'class'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text('Enroll · ₹${price.toInt()}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }

  Widget _batchCard(Map<String, dynamic> b, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final purchased = b['is_purchased'] == true;
    final isFree = b['is_free'] == true;
    final price = _num(b['price']);
    final orig = _num(b['original_price']);
    final count = b['class_count'] ?? 0;
    final faculty = (b['faculty'] ?? '').toString();
    final thumb = (b['thumbnail_url'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thumb.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(thumb,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b['title']?.toString() ?? '',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                if (faculty.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(faculty,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.video_call_rounded,
                        size: 15,
                        color: isDark ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 5),
                    Text('$count live class${count == 1 ? '' : 'es'}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white70 : Colors.black54)),
                  ],
                ),
                const SizedBox(height: 12),
                if (purchased || isFree)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Text('Enrolled',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5)),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Text('₹${price.toInt()}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                      if (orig > price) ...[
                        const SizedBox(width: 7),
                        Text('₹${orig.toInt()}',
                            style: TextStyle(
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38)),
                      ],
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => _buy(b, 'batch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: const Color(0xFF1A1A1A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: const Text('Enroll',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.video_call_rounded,
                  size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No live classes yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text('Live doubt sessions and classes will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}
