// lib/presentation/screens/about/about_screen.dart
//
// "About Selection Lab" — Why us, faculty aur exams.
// Redesign (Sep 2026) me ye home se hataye gaye: app kholne wala pehle se
// student hai, use marketing nahi, apne tests aur offers chahiye. Content
// admin panel (app-config) se aata hai; na ho to purane default.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/ui.dart';
import '../../../data/providers/app_config_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _site = 'https://selectionlab.in';

  static const _whyFallback = [
    {
      'icon': '🖥️',
      'title': 'Real Exam Interface',
      'desc':
          "Mock tests on the same TCS/SSC-pattern screen you'll face on exam day — palette, timer, sections, everything."
    },
    {
      'icon': '🌐',
      'title': 'Hindi + English',
      'desc':
          'Every question, option and explanation available in both languages. Switch anytime during the test.'
    },
    {
      'icon': '👩‍🏫',
      'title': 'Expert Guidance',
      'desc':
          "Courses and strategy by Nikki Ma'am — trusted by thousands of aspirants on YouTube."
    },
    {
      'icon': '💰',
      'title': 'Honest Pricing',
      'desc':
          "Serious preparation shouldn't cost thousands. Full test series and courses at affordable prices."
    },
  ];

  static const _facultyFallback = [
    {'name': "Nikki Ma'am", 'subject': 'English & Interview', 'img': '/nikki_maam.png'},
    {'name': 'Ravi Sir', 'subject': 'GK/GS & Current Affairs', 'img': '/ravi_sir.jpg'},
    {'name': 'Ashutosh Sir', 'subject': 'Maths', 'img': '/ashutosh_sir.jpg'},
  ];

  static const _examsFallback = [
    'SSC CGL',
    'SSC CHSL',
    'IB Security Assistant',
    'Railways RRB',
    'UP Police SI',
    'Allahabad High Court',
    'CISF / CRPF',
    'UPSC CAPF',
  ];

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final cfg = context.watch<AppConfigProvider>();

    final why = cfg.whyUs.isEmpty
        ? _whyFallback
        : cfg.whyUs
            .map((w) => {
                  'icon': (w['emoji'] ?? '').toString(),
                  'title': (w['title'] ?? '').toString(),
                  'desc': (w['text'] ?? '').toString(),
                })
            .toList();
    final faculty = cfg.faculty.isEmpty
        ? _facultyFallback
        : cfg.faculty
            .map((f) => {
                  'name': (f['name'] ?? '').toString(),
                  'subject': (f['subject'] ?? '').toString(),
                  'img': (f['image_url'] ?? '').toString(),
                })
            .toList();
    final exams = cfg.exams.isEmpty ? _examsFallback : cfg.exams;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('About Selection Lab')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        children: [
          const SectionHeader('Why Selection Lab?'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final w in why)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w['icon'] ?? '',
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w['title'] ?? '',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: t.text)),
                                const SizedBox(height: 4),
                                Text(w['desc'] ?? '',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.45,
                                        color: t.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SectionHeader('Our Faculty'),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: faculty.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final f = faculty[i];
                final img = f['img'] ?? '';
                return SizedBox(
                  width: 136,
                  child: AppCard(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            img.startsWith('http') ? img : '$_site$img',
                            height: 88,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 88,
                              color: t.chip,
                              child: Icon(Icons.person, color: t.muted, size: 38),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(f['name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: t.text)),
                        const SizedBox(height: 2),
                        Text(f['subject'] ?? '',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: t.muted)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Exams We Cover'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in exams)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: t.card,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(e,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: t.text2)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
