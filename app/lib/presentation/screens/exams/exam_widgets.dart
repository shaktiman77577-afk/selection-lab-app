// lib/presentation/screens/exams/exam_widgets.dart
//
// Exam Pages (Nov 2026) — app ke chhote hisse: exam logo, exam tile aur home
// ka "Browse by exam" section. Data backend /api/exam-pages se
// (selection-lab-api routers/exam_pages.py). Website jaisa hi.
//
// Logo SVG bhi ho sakta hai (website ke public/exam-logos/*.svg) — isliye
// flutter_svg. ImgBB wala PNG/JPG ho to normal Image.network.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/widgets/ui.dart';
import '../descriptive/descriptive_theme.dart';
import 'exam_list_screen.dart';
import 'exam_page_screen.dart';

const String kSiteUrl = 'https://www.selectionlab.in';

int examInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

List<Map<String, dynamic>> examMaps(dynamic l) => l is List
    ? l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

/// "/exam-logos/x.svg" jaisa relative link ho to website ka domain jodo
String examLogoUrl(Map e) {
  final raw = '${e['logo_url'] ?? ''}'.trim();
  if (raw.isEmpty) return '';
  if (raw.startsWith('//')) return 'https:$raw';
  if (raw.startsWith('/')) return '$kSiteUrl$raw';
  return raw;
}

/// Logo na ho to naam ke pehle akshar (P&H, SCI...)
String examInitials(Map e) {
  final s = '${e['short_name'] ?? ''}'.trim().isNotEmpty
      ? '${e['short_name']}'.trim()
      : '${e['name'] ?? ''}'.trim();
  final first = s.split(RegExp(r'\s+')).first;
  final w = first.isEmpty ? s : first;
  return (w.length > 4 ? w.substring(0, 4) : w).toUpperCase();
}

/// "12 test series & courses"
String examTotalLabel(int n) =>
    '$n ${n == 1 ? 'test series / course' : 'test series & courses'}';

/// Gol exam logo — SVG / PNG / initials
class ExamLogo extends StatelessWidget {
  final Map exam;
  final double size;
  final Color? ring;
  final double ringWidth;
  const ExamLogo(
      {super.key,
      required this.exam,
      this.size = 56,
      this.ring,
      this.ringWidth = 1});

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final url = examLogoUrl(exam);
    final isSvg = url.toLowerCase().split('?').first.endsWith('.svg');

    Widget initials() => Container(
          color: kDGold.withOpacity(0.18),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FittedBox(
              child: Text(examInitials(exam),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF8A5A00))),
            ),
          ),
        );

    Widget img;
    if (url.isEmpty) {
      img = initials();
    } else if (isSvg) {
      img = SvgPicture.network(url,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Container(color: Colors.white));
    } else {
      img = Image.network(url,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials());
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: ring ?? t.line, width: ringWidth),
      ),
      child: ClipOval(child: img),
    );
  }
}

/// Exam ka tile — logo, naam, kitne products
class ExamTile extends StatelessWidget {
  final Map<String, dynamic> exam;
  final double? width;
  const ExamTile({super.key, required this.exam, this.width});

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final total = examInt(exam['total']);
    return SizedBox(
      width: width,
      child: AppCard(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        onTap: () => openExamPage(context, exam),
        // Height bahar se tay (patti / grid) — naam bachi jagah me
        child: Column(
          children: [
            ExamLogo(exam: exam, size: 58),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Text('${exam['name'] ?? ''}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: t.text)),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kDGold.withOpacity(0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(examTotalLabel(total),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: t.dark
                          ? const Color(0xFFFFC94D)
                          : const Color(0xFF8A5A00))),
            ),
          ],
        ),
      ),
    );
  }
}

void openExamPage(BuildContext context, Map exam) {
  final slug = '${exam['slug'] ?? ''}';
  if (slug.isEmpty) return;
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ExamPageScreen(
              slug: slug, preview: Map<String, dynamic>.from(exam))));
}

/// Home ka "Browse by exam" — category chips + exam tiles ki patti.
/// data = /api/exam-pages/?platform=app ka jawab. Koi exam na ho to kuch nahi.
class ExamBrowseSection extends StatefulWidget {
  final Map<String, dynamic>? data;
  const ExamBrowseSection({super.key, required this.data});

  @override
  State<ExamBrowseSection> createState() => _ExamBrowseSectionState();
}

class _ExamBrowseSectionState extends State<ExamBrowseSection> {
  int _cat = 0; // 0 = Popular / All

  @override
  Widget build(BuildContext context) {
    final exams = examMaps(widget.data?['exams']);
    if (exams.isEmpty) return const SizedBox.shrink();

    final cats = <String>[];
    for (final c in (widget.data?['categories'] is List
        ? widget.data!['categories'] as List
        : const [])) {
      final s = '$c';
      if (s.isNotEmpty && exams.any((e) => '${e['category']}' == s)) {
        cats.add(s);
      }
    }
    for (final e in exams) {
      final s = '${e['category'] ?? ''}';
      if (s.isNotEmpty && !cats.contains(s)) cats.add(s);
    }
    final hasPopular = exams.any((e) => e['is_popular'] == true);
    final first = hasPopular ? 'Popular' : 'All';
    final options = [first, ...cats];
    final sel = _cat.clamp(0, options.length - 1);

    final shown = sel == 0
        ? (hasPopular
            ? [
                ...exams.where((e) => e['is_popular'] == true),
                ...exams.where((e) => e['is_popular'] != true),
              ]
            : exams)
        : exams.where((e) => '${e['category']}' == options[sel]).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        SectionHeader('Browse by exam',
            onViewAll: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ExamListScreen(initial: widget.data)))),
        if (options.length > 2) ...[
          FilterChips(
            options: options,
            selected: sel,
            onChanged: (i) => setState(() => _cat = i),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => ExamTile(exam: shown[i], width: 140),
          ),
        ),
      ],
    );
  }
}
