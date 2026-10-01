// lib/presentation/screens/courses/course_detail_screen.dart
//
// Redesign (Sep 2026) — clean look (DT tokens, navy), aur kuch sudhaar:
// - Access check ab /courses/my/{uid} se — bundle se mila course bhi "owned"
//   ginta hai (pehle bundle wale student ko "Buy Now" dikhta tha).
// - Bina kharide paid course ka content nahi khulta (free preview chhod kar).
//   Pehle app har video/PDF khol deta tha.
// - Bundle course me "Included in this bundle" — website jaisa.
// - Nakli "4.8 rating" hata di — backend deta hi nahi.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import '../checkout/checkout_screen.dart';
import '../descriptive/descriptive_series_detail_screen.dart';
import '../descriptive/descriptive_theme.dart';
import '../mock/mock_series_detail_screen.dart';
import 'pdf_viewer_screen.dart';
import 'video_player_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> course = Map<String, dynamic>.from(widget.course);
  List<Map<String, dynamic>> _content = [];
  List<Map<String, dynamic>> _bundle = [];
  bool _loadingContent = true;
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  bool _descExpanded = false;
  bool _isPurchased = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCourse();
      _checkAccess();
    });
    _loadContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int? get _uid {
    final raw = context.read<AuthProvider>().user?['id'];
    return raw is int ? raw : int.tryParse('${raw ?? ''}');
  }

  int? get _courseId => course['id'] is int
      ? course['id'] as int
      : int.tryParse('${course['id'] ?? ''}');

  num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
  num get _price => _num(course['price']);
  num get _orig => _num(course['original_price']);
  bool get _isFree => course.containsKey('price') && _price <= 0;
  bool get _owned => _isFree || _isPurchased;

  /// Bundle/search se aaye course me sirf id-title hota hai — poora mangwa lo
  Future<void> _ensureCourse() async {
    if (course.containsKey('price')) return;
    try {
      final r = await http
          .get(Uri.parse('${AppConstants.apiUrl}/courses/'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return;
      final d = jsonDecode(r.body);
      final list = d is List ? d : (d['courses'] ?? []);
      for (final c in list) {
        if ('${c['id']}' == '${course['id']}') {
          if (mounted) setState(() => course = Map<String, dynamic>.from(c));
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _checkAccess() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.apiUrl}/courses/my/$uid'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final owned = (data['courses'] as List? ?? [])
          .any((c) => '${c['id']}' == '${course['id']}');
      if (mounted && owned) setState(() => _isPurchased = true);
    } catch (_) {}
  }

  Future<void> _loadContent() async {
    try {
      // user_id zaroori: backend paid course ke video/PDF links ab sirf
      // kharidne wale ko deta hai (baaki ko "locked": true, url khaali)
      final uid = context.read<AuthProvider>().user?['id'];
      final q = uid != null ? '?user_id=$uid' : '';
      final res = await http
          .get(Uri.parse('${AppConstants.apiUrl}/courses/${course['id']}/content$q'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> maps(dynamic l) => (l is List ? l : [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (!mounted) return;
        setState(() {
          _content = maps(data['content']);
          _bundle = maps(data['bundle']);
          _loadingContent = false;
        });
      } else if (mounted) {
        setState(() => _loadingContent = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContent = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _buyCourse() async {
    if (_uid == null) {
      _snack('Please log out and log in again to purchase.');
      return;
    }
    final id = _courseId;
    if (id == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          productType: 'course',
          productId: id,
          title: (course['title'] ?? 'Course').toString(),
          price: _price,
          originalPrice: _orig > _price ? _orig : _price,
          onSuccess: () {},
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => _isPurchased = true);
      _loadContent(); // ab links khule milenge
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.check_circle_rounded, color: kDGreen),
            SizedBox(width: 8),
            Text('Unlocked!'),
          ]),
          content: Text(_bundle.isNotEmpty
              ? 'Everything in this bundle is now yours.'
              : 'Course unlocked. You can now access all content.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(1);
              },
              child: const Text('Start Learning'),
            ),
          ],
        ),
      );
    }
  }

  void _shareContent() {
    ShareHelper.share(
      type: 'course',
      id: course['id'],
      title: (course['title'] ?? 'Course').toString(),
      subtitle: _isFree ? 'Free course' : 'Only ₹${_price.toInt()}',
    );
  }

  void _openContent(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    // Paid course: bina kharide sirf free preview khulta hai
    if ((!_owned && item['is_free_preview'] != true) || item['locked'] == true) {
      _snack('Buy this course to unlock all lessons.');
      return;
    }
    final type = item['content_type'];
    if (type == 'video') {
      final videoUrl = item['url']?.toString();
      if (videoUrl != null && videoUrl.isNotEmpty) {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                  videoUrl: videoUrl, title: item['title'] ?? 'Video'),
            ));
      } else {
        _snack('Video link not available for this lecture.');
      }
    } else if (type == 'pdf' || type == 'file') {
      // Watermarked PDF backend se — usme student ka mobile number chhapa hota hai
      final raw = item['id'];
      final contentId = raw is int ? raw : int.tryParse('${raw ?? ''}');
      final fileUrl = (item['file_url'] ?? item['url'])?.toString();
      if (contentId != null) {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                  contentId: contentId,
                  userId: _uid,
                  title: item['title'] ?? 'Document'),
            ));
      } else if (fileUrl != null && fileUrl.isNotEmpty) {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                  url: fileUrl, title: item['title'] ?? 'Document'),
            ));
      } else {
        _snack('Document not available.');
      }
    }
  }

  void _openBundleItem(Map<String, dynamic> b) {
    final id = b['id'] is int ? b['id'] as int : int.tryParse('${b['id']}');
    if (id == null) return;
    final Widget screen;
    switch ('${b['type']}') {
      case 'mock':
        screen = MockSeriesDetailScreen(seriesId: id);
        break;
      case 'descriptive':
        screen = DescriptiveSeriesDetailScreen(seriesId: id);
        break;
      default:
        screen = CourseDetailScreen(
            course: {'id': id, 'title': b['title'], 'thumbnail_url': b['thumbnail_url']});
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  int get _videoCount =>
      _content.where((c) => c['content_type'] == 'video').length;
  int get _pdfCount => _content
      .where((c) => c['content_type'] == 'pdf' || c['content_type'] == 'file')
      .length;

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final img =
        '${course['thumbnail_url_mobile'] ?? course['thumbnail_url'] ?? ''}';
    final students = _num(course['students_count']);

    return Scaffold(
      backgroundColor: t.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            // Navy bar — poster ke upar bhi aur collapse hone par bhi padhne me aaye
            backgroundColor: kDNavy,
            foregroundColor: Colors.white,
            title: Text((course['title'] ?? '').toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: _shareContent),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color: kDNavy,
                child: img.isEmpty
                    ? const Center(
                        child: Icon(Icons.school_rounded,
                            color: Colors.white54, size: 64))
                    : Image.network(img,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.school_rounded,
                                color: Colors.white54, size: 64))),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: t.card,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (_isFree)
                      const Tag('FREE COURSE', color: kDGreen)
                    else if ('${course['course_type'] ?? ''}'.isNotEmpty)
                      Tag('${course['course_type']}'.toUpperCase(),
                          color: t.primary),
                    if (_isPurchased && !_isFree)
                      const Tag('ENROLLED', color: kDGreen),
                    if (_bundle.isNotEmpty) Tag('BUNDLE', color: t.primary),
                  ]),
                  const SizedBox(height: 10),
                  Text((course['title'] ?? '').toString(),
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: t.text)),
                  if (students > 0) ...[
                    const SizedBox(height: 6),
                    Text('${students.toInt()}+ students enrolled',
                        style: TextStyle(fontSize: 12.5, color: t.muted)),
                  ],
                  if (_content.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (_videoCount > 0)
                        _statChip(t, Icons.play_circle_outline_rounded,
                            '$_videoCount videos'),
                      if (_pdfCount > 0)
                        _statChip(t, Icons.picture_as_pdf_outlined,
                            '$_pdfCount PDFs'),
                      if (course['validity_days'] != null)
                        _statChip(t, Icons.schedule_rounded,
                            '${course['validity_days']} days access'),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: t.card,
                border: Border(
                    top: BorderSide(color: t.line),
                    bottom: BorderSide(color: t.line)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: t.primary,
                indicatorWeight: 2.5,
                labelColor: t.primary,
                unselectedLabelColor: t.muted,
                dividerColor: Colors.transparent,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                tabs: [
                  const Tab(text: 'Overview'),
                  Tab(text: _bundle.isNotEmpty ? 'Included' : 'Content'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_overviewTab(t), _contentTab(t)],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(t),
    );
  }

  Widget _bottomBar(DT t) {
    final off = (!_isFree && _orig > _price)
        ? ((1 - _price / _orig) * 100).round()
        : 0;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (!_owned) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${_price.toInt()}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: t.text)),
                    if (off > 0)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('₹${_orig.toInt()}',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: t.muted,
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 5),
                        Text('$off% OFF',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: kDGreen,
                                fontWeight: FontWeight.w800)),
                      ]),
                  ],
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: _owned
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kDGreen,
                            foregroundColor: Colors.white),
                        onPressed: () => _tabController.animateTo(1),
                        child: const Text('Start Learning'),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _buyCourse();
                        },
                        child: const Text('Buy Now'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── OVERVIEW ──
  Widget _overviewTab(DT t) {
    final features = '${course['features'] ?? ''}'
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final desc = '${course['description'] ?? ''}';
    final isLong = desc.length > 180;

    Widget heading(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(s,
              style: TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w800, color: t.text)),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (desc.isNotEmpty) ...[
          heading('About this course'),
          Text(_descExpanded || !isLong ? desc : '${desc.substring(0, 180)}…',
              style: TextStyle(fontSize: 14, height: 1.6, color: t.text2)),
          if (isLong)
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_descExpanded ? 'Read less' : 'Read more',
                    style: TextStyle(
                        color: t.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          const SizedBox(height: 22),
        ],
        AppCard(
          onTap: () => _tabController.animateTo(1),
          child: Row(
            children: [
              Icon(_bundle.isNotEmpty
                  ? Icons.inventory_2_rounded
                  : Icons.school_rounded,
                  color: t.primary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _bundle.isNotEmpty
                            ? '${_bundle.length} items in this bundle'
                            : '${_content.length} learning materials',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: t.text)),
                    const SizedBox(height: 2),
                    Text(
                        _bundle.isNotEmpty
                            ? 'Courses and test series, all unlocked together'
                            : '$_videoCount video lectures, $_pdfCount PDF files',
                        style: TextStyle(fontSize: 12, color: t.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.muted),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (features.isNotEmpty) ...[
          heading('What you will get'),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: kDGreen, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(f,
                          style: TextStyle(
                              fontSize: 14, height: 1.4, color: t.text2))),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (!_owned)
          AppCard(
            borderColor: kDGold.withOpacity(0.5),
            child: Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: kDGold, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Have a coupon? Apply it at checkout.',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.text)),
                ),
              ],
            ),
          ),
        if (!_isFree && course['validity_days'] != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: t.muted, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Access valid for ${course['validity_days']} days after purchase',
                    style: TextStyle(fontSize: 12.5, color: t.muted)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  // ── CONTENT / BUNDLE ──
  Widget _contentTab(DT t) {
    if (_loadingContent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bundle.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
              _owned
                  ? 'Everything below is unlocked for you.'
                  : 'Buy this bundle to unlock everything below.',
              style: TextStyle(fontSize: 13, color: t.muted)),
          const SizedBox(height: 12),
          for (final b in _bundle)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(10),
                onTap: () => _openBundleItem(b),
                child: Row(
                  children: [
                    Text('${b['icon'] ?? '📦'}',
                        style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${b['title'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: t.text)),
                          Text('${b['label'] ?? ''}',
                              style:
                                  TextStyle(fontSize: 12, color: t.muted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: t.muted),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    if (_content.isEmpty) {
      return EmptyState(
          icon: Icons.video_library_outlined,
          text: 'Content is being added. Check back soon.');
    }

    final sections = <String, List<Map<String, dynamic>>>{};
    for (final item in _content) {
      final sec = item['section']?.toString() ?? 'Course material';
      sections.putIfAbsent(sec, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in sections.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Text(e.key,
                style: TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800, color: t.text)),
          ),
          for (final item in e.value) _contentTile(t, item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _contentTile(DT t, Map<String, dynamic> item) {
    final type = item['content_type'] ?? 'video';
    final isVideo = type == 'video';
    final preview = item['is_free_preview'] == true;
    final locked = (!_owned && !preview) || item['locked'] == true;

    final IconData icon;
    final Color color;
    if (isVideo) {
      icon = Icons.play_circle_fill_rounded;
      color = const Color(0xFFD64545);
    } else if (type == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      color = const Color(0xFFD9822B);
    } else {
      icon = Icons.insert_drive_file_rounded;
      color = const Color(0xFF2C6FD1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        onTap: () => _openContent(item),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item['title'] ?? ''}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: locked ? t.muted : t.text)),
                  if (item['duration'] != null)
                    Text('${item['duration']}',
                        style: TextStyle(fontSize: 11.5, color: t.muted)),
                ],
              ),
            ),
            if (preview && !_owned)
              const Tag('FREE', color: kDGreen)
            else if (locked)
              Icon(Icons.lock_rounded, size: 18, color: t.muted)
            else
              Icon(
                  isVideo
                      ? Icons.play_arrow_rounded
                      : Icons.chevron_right_rounded,
                  color: t.muted),
          ],
        ),
      ),
    );
  }

  Widget _statChip(DT t, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.chip,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: t.text2, size: 15),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: t.text2)),
        ],
      ),
    );
  }
}
