import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import 'video_player_screen.dart';
import 'pdf_viewer_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  List<Map<String, dynamic>> _content = [];
  bool _loadingContent = true;

  Map<String, dynamic> get course => widget.course;

  @override
  void initState() {
    super.initState();
    _loadContent();
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
    final title = course['title'] ?? 'Course';
    final price = course['price']?.toString() ?? '0';
    final url = course['redirect_url'] ?? 'https://selectionlab.online';
    final text = '🎓 $title\n💰 ₹$price\n👉 $url\n\nDownload Selection Lab App!';
    _launchUrl('https://wa.me/?text=${Uri.encodeComponent(text)}');
  }

  void _openContent(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    final type = item['content_type'];
    if (type == 'video' && item['youtube_id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            youtubeId: item['youtube_id'],
            title: item['title'] ?? 'Video',
          ),
        ),
      );
    } else if ((type == 'pdf' || type == 'file') && item['file_url'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: item['file_url'],
            title: item['title'] ?? 'Document',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final price = course['price']?.toString() ?? '0';
    final originalPrice = course['original_price']?.toString();
    final hasDiscount = originalPrice != null && originalPrice != price;
    final discount = hasDiscount
        ? ((1 - double.parse(price) / double.parse(originalPrice!)) * 100).round()
        : 0;

    final features = course['features'] != null
        ? (course['features'] as String)
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                GestureDetector(
                  onTap: _shareContent,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: course['thumbnail_url'] != null
                  ? Image.network(
                      course['thumbnail_url'],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _placeholderImage(),
                    )
                  : _placeholderImage(),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── COURSE INFO ──
                Container(
                  color: cardBg,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (course['course_type'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Text(
                            _formatCourseType(course['course_type']),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        course['title'] ?? '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            '₹$price',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 10),
                            Text(
                              '₹$originalPrice',
                              style: TextStyle(
                                fontSize: 18,
                                color: isDark ? Colors.white38 : Colors.black38,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$discount% OFF',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── COURSE CONTENT ──
                Container(
                  color: cardBg,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.play_lesson_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Course Content',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          if (!_loadingContent)
                            Text(
                              '${_content.length} items',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_loadingContent)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ))
                      else if (_content.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'No content available yet',
                              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                        )
                      else
                        ..._buildContentList(isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── DESCRIPTION ──
                if (course['description'] != null && course['description'].toString().isNotEmpty)
                  Container(
                    color: cardBg,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About this course',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          course['description'],
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (course['description'] != null) const SizedBox(height: 8),

                // ── FEATURES ──
                if (features.isNotEmpty)
                  Container(
                    color: cardBg,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What you will get',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...features.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        color: Colors.green, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      f,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹$price',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (hasDiscount)
                    Text(
                      'You save ₹${(double.parse(originalPrice!) - double.parse(price)).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  if (course['redirect_url'] != null) {
                    _launchUrl(course['redirect_url']);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Buy Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentList(bool isDark) {
    return _content.map((item) {
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
            color: isDark ? const Color(0xFF252527) : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (item['section'] != null || item['duration'] != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (item['section'] != null)
                            Text(
                              item['section'],
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          if (item['duration'] != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.access_time_rounded, size: 11, color: isDark ? Colors.white38 : Colors.black38),
                            const SizedBox(width: 2),
                            Text(
                              item['duration'],
                              style: TextStyle(
                                fontSize: 11,
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
              if (isPreview)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('FREE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black38),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _placeholderImage() {
    return Container(
      color: AppColors.primary.withOpacity(0.15),
      child: Center(
        child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 80),
      ),
    );
  }

  String _formatCourseType(String type) {
    switch (type) {
      case 'mock_test': return 'Mock Test';
      case 'study_material': return 'Study Material';
      case 'paid_batch': return 'Paid Batch';
      case 'Paid Batch': return 'Paid Batch';
      case 'video': return 'Video Course';
      case 'pyq': return 'PYQ';
      case 'ebook': return 'E-Book';
      default: return type;
    }
  }
}
