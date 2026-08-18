import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import 'video_player_screen.dart';
import 'pdf_viewer_screen.dart';
import '../../../core/utils/share_helper.dart';
import '../checkout/checkout_screen.dart';


class CourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _content = [];
  bool _loadingContent = true;
  late TabController _tabController;
  bool _descExpanded = false;
  bool _purchasing = false;
  bool _isPurchased = false;

  Map<String, dynamic> get course => widget.course;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccess());
    _loadContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final auth = context.read<AuthProvider>();
    final rawId = auth.user?['id'];
    final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final isFree = (course['course_type'] == 'Free Batch');
    if (isFree || userId == null) return;
    try {
      final cid = course['id'];
      final res = await http.get(
        Uri.parse('${AppConstants.apiUrl}/users/$userId/courses'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final owned = (data['courses'] as List? ?? [])
            .any((c) => c['id'].toString() == cid.toString());
        if (mounted && owned) {
          setState(() => _isPurchased = true);
        }
      }
    } catch (_) {}
  }

  Future<void> _buyCourse() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?['id'];
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please logout and login again to purchase')),
      );
      return;
    }
    final price = (course['price'] as num?) ?? 0;
    final originalPrice = (course['original_price'] as num?) ?? price;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          productType: 'course',
          productId: course['id'] is int
              ? course['id']
              : int.tryParse(course['id'].toString()) ?? 0,
          title: (course['title'] ?? 'Course').toString(),
          price: price,
          originalPrice: originalPrice,
          onSuccess: () {},
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => _isPurchased = true);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
          title: const Row(children: [Icon(Icons.check_circle_rounded, color: Colors.green), SizedBox(width: 8), Text('Success!')]),
          content: const Text('Course unlocked. You can now access all content.'),
          actions: [
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _tabController.animateTo(1); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Start Learning'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadContent() async {
    try {
      final id = course['id'];
      final res = await http
          .get(Uri.parse('https://api.selectionlab.online/api/courses/$id/content'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _content = List<Map<String, dynamic>>.from(data['content']);
          _loadingContent = false;
        });
      } else {
        setState(() => _loadingContent = false);
      }
    } catch (_) {
      setState(() => _loadingContent = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareContent() {
    final price = course['price']?.toString() ?? '0';
    final priceLine =
        (price == '0' || price.isEmpty) ? 'Free course' : 'Only ₹$price';
    ShareHelper.share(
      type: 'course',
      id: course['id'],
      title: (course['title'] ?? 'Course').toString(),
      subtitle: priceLine,
    );
  }

  void _openContent(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    final type = item['content_type'];
    if (type == 'video') {
      final videoUrl = item['url']?.toString();
      if (videoUrl != null && videoUrl.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(videoUrl: videoUrl, title: item['title'] ?? 'Video'),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video link not available for this lecture.')),
        );
      }
    } else if (type == 'pdf' || type == 'file') {
      // Watermarked PDF backend se maangte hain — usme student ka apna mobile
      // number chhapa hota hai. Content id na mile to purane tarike se
      // seedha URL khol dete hain (kuch bhi na khulne se behtar hai).
      final rawContentId = item['id'];
      final contentId = rawContentId is int
          ? rawContentId
          : int.tryParse('${rawContentId ?? ''}');

      final rawUid = context.read<AuthProvider>().user?['id'];
      final uid = rawUid is int ? rawUid : int.tryParse('${rawUid ?? ''}');

      final fileUrl = (item['file_url'] ?? item['url'])?.toString();

      if (contentId != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            contentId: contentId,
            userId: uid,
            title: item['title'] ?? 'Document',
          ),
        ));
      } else if (fileUrl != null && fileUrl.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PdfViewerScreen(url: fileUrl, title: item['title'] ?? 'Document'),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document not available.')),
        );
      }
    }
  }

  int get _videoCount => _content.where((c) => c['content_type'] == 'video').length;
  int get _pdfCount => _content.where((c) => c['content_type'] == 'pdf' || c['content_type'] == 'file').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final price = course['price']?.toString() ?? '0';
    final originalPrice = course['original_price']?.toString();
    final isFree = price == '0' || price == '0.0';
    final hasDiscount = !isFree && originalPrice != null && originalPrice != price && double.tryParse(originalPrice) != null;
    final discount = hasDiscount
        ? ((1 - double.parse(price) / double.parse(originalPrice!)) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black,
                    child: course['thumbnail_url'] != null
                        ? Image.network(course['thumbnail_url'], fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _placeholderImage())
                        : _placeholderImage(),
                  ),
                  // Dark gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.5)],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: _shareContent,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),

          // Title + stats card
          SliverToBoxAdapter(
            child: Container(
              color: cardBg,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFree ? Colors.green.withOpacity(0.15) : AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isFree ? 'FREE COURSE' : (course['course_type'] ?? 'Course').toString().toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isFree ? Colors.green : AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    course['title'] ?? '',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  // Rating + students
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 17),
                      const SizedBox(width: 3),
                      Text(
                          (course['rating'] ?? 4.8).toString(),
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                          '(${course['students_count'] ?? 0}+ enrolled)',
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Quick stats row
                  Row(
                    children: [
                      _statChip(Icons.play_circle_outline_rounded, '$_videoCount Videos', Colors.red, isDark),
                      const SizedBox(width: 10),
                      _statChip(Icons.picture_as_pdf_outlined, '$_pdfCount PDFs', Colors.orange, isDark),
                      if (course['validity_days'] != null) ...[
                        const SizedBox(width: 10),
                        _statChip(Icons.schedule_rounded, '${course['validity_days']}d', Colors.blue, isDark),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // ── ANIMATED TABS ──
            Container(
              color: cardBg,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Content'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _overviewTab(isDark, isFree, price, originalPrice, hasDiscount, discount),
                  _contentTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      // ── BOTTOM BAR ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: cardBg,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            if (!isFree)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rs.$price', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  if (hasDiscount)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Rs.$originalPrice', style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 4),
                        Text('$discount% OFF', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                      ],
                    ),
                ],
              ),
            if (!isFree) const SizedBox(width: 14),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: _purchasing ? null : () {
                  HapticFeedback.mediumImpact();
                  if (isFree || _isPurchased) {
                    _tabController.animateTo(1);
                  } else {
                    _buyCourse();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isFree || _isPurchased) ? Colors.green : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                child: _purchasing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text((isFree || _isPurchased) ? 'Start Learning' : 'Buy Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── OVERVIEW TAB ──
  Widget _overviewTab(bool isDark, bool isFree, String price, String? originalPrice, bool hasDiscount, int discount) {
    final features = course['features'] != null
        ? (course['features'] as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final desc = course['description']?.toString() ?? '';
    final isLongDesc = desc.length > 150;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // About
        if (desc.isNotEmpty) ...[
          Text('About This Course', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 10),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _descExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Text(
              isLongDesc ? '${desc.substring(0, 150)}...' : desc,
              style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : Colors.black54),
            ),
            secondChild: Text(desc, style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : Colors.black54)),
          ),
          if (isLongDesc)
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_descExpanded ? 'Read Less' : 'Read More', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          const SizedBox(height: 24),
        ],

        // Learning material summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.school_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_content.length} Learning Materials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text('$_videoCount Video lectures, $_pdfCount PDF files', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _tabController.animateTo(1),
                child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Features
        if (features.isNotEmpty) ...[
          Text('What You Will Get', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 14),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.check_rounded, color: Colors.green, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(f, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87))),
              ],
            ),
          )),
          const SizedBox(height: 24),
        ],

        // Coupon/Offers (paid only)
        if (!isFree) ...[
          Text('Available Offers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252527) : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3), style: BorderStyle.solid),
            ),
            child: Row(
              children: [
                Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Use coupon at checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                      Text('Apply coupon codes for extra discount', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Expiry (paid only)
        if (!isFree && course['validity_days'] != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252527) : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Course access valid for ${course['validity_days']} days after purchase',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),
      ],
    );
  }

  // ── CONTENT TAB ──
  Widget _contentTab(bool isDark) {
    if (_loadingContent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_content.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 56, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text('No content available yet', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      );
    }

    // Group by section
    final Map<String, List<Map<String, dynamic>>> sections = {};
    for (var item in _content) {
      final sec = item['section']?.toString() ?? 'Course Material';
      sections.putIfAbsent(sec, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Text(entry.key, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ),
            ...entry.value.map((item) => _contentTile(item, isDark)),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _contentTile(Map<String, dynamic> item, bool isDark) {
    final type = item['content_type'] ?? 'video';
    final isVideo = type == 'video';
    final isPreview = item['is_free_preview'] == true;

    IconData icon;
    Color iconColor;
    if (isVideo) {
      icon = Icons.play_circle_fill_rounded;
      iconColor = Colors.red;
    } else if (type == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      iconColor = Colors.orange;
    } else {
      icon = Icons.insert_drive_file_rounded;
      iconColor = Colors.blue;
    }

    return GestureDetector(
      onTap: () => _openContent(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  if (item['duration'] != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 11, color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 3),
                        Text(item['duration'], style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isPreview)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Text('FREE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            else
              Icon(isVideo ? Icons.play_arrow_rounded : Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: AppColors.primary.withOpacity(0.15),
      child: Center(child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 70)),
    );
  }
}
