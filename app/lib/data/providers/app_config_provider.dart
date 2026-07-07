// lib/data/providers/app_config_provider.dart
//
// Loads dynamic content (hero slides, faculty, exams, why-us, community) from
// the backend /app-config endpoint so most home-screen changes need no app update.
// Ships with the same defaults as the backend, so the UI is never empty even
// offline or before the first fetch.

import 'package:flutter/foundation.dart';
import '../../core/network/api_service.dart';

class AppConfigProvider extends ChangeNotifier {
  Map<String, dynamic> _config = _defaults;
  bool _loaded = false;

  Map<String, dynamic> get config => _config;
  bool get loaded => _loaded;

  List<Map<String, dynamic>> _list(String key) {
    final v = _config[key];
    if (v is List) {
      return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get heroSlides => _list('hero_slides');
  List<Map<String, dynamic>> get whyUs => _list('why_us');
  List<Map<String, dynamic>> get faculty => _list('faculty');
  List<String> get exams {
    final v = _config['exams'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  Map<String, dynamic> get community {
    final v = _config['community'];
    return v is Map ? Map<String, dynamic>.from(v) : {};
  }

  Map<String, dynamic> get announcement {
    final v = _config['announcement'];
    return v is Map ? Map<String, dynamic>.from(v) : {};
  }

  Future<void> load() async {
    try {
      final res = await ApiService.get('/app-config');
      final cfg = res['config'];
      if (cfg is Map) {
        _config = Map<String, dynamic>.from(cfg);
      }
    } catch (_) {
      // keep defaults on any failure — UI still works
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  static final Map<String, dynamic> _defaults = {
    'hero_slides': [
      {
        'emoji': '🏆',
        'title': 'Crack SSC, IB & Railway Exams',
        'subtitle':
            "Courses, real exam-interface mock tests and daily practice — in Hindi + English, guided by Nikki Ma'am.",
        'primary_label': '🎯 Try Free Mock Test',
        'primary_action': 'mock',
        'secondary_label': 'Explore Courses',
        'secondary_action': 'courses',
      },
      {
        'emoji': '🖥️',
        'title': 'Real Exam-Interface Mock Tests',
        'subtitle':
            'Same TCS/SSC-pattern screen — palette, timer, sections, negative marking. English + हिंदी. Instant result & solutions.',
        'primary_label': 'Start Free Mock →',
        'primary_action': 'mock',
        'secondary_label': '',
        'secondary_action': '',
      },
      {
        'emoji': '✍️',
        'title': 'Punjab & Haryana High Court',
        'subtitle':
            'Descriptive Writing Practice — Essay, Letter, Précis & Translation, auto-scored instantly with model answers.',
        'primary_label': 'Practice Writing →',
        'primary_action': 'descriptive',
        'secondary_label': '',
        'secondary_action': '',
      },
      {
        'emoji': '📚',
        'title': 'Courses by Expert Faculty',
        'subtitle':
            "Nikki Ma'am (English), Ravi Sir (GK/GS) & Ashutosh Sir (Maths). Free + affordable batches with PDFs and PYQs.",
        'primary_label': 'Explore Courses →',
        'primary_action': 'courses',
        'secondary_label': '',
        'secondary_action': '',
      },
    ],
    'why_us': [
      {'emoji': '🖥️', 'title': 'Real Exam Interface', 'text': "Practice on the exact screen you'll face on exam day."},
      {'emoji': '✍️', 'title': 'Instant Auto-Evaluation', 'text': 'Descriptive answers scored instantly with detailed feedback.'},
      {'emoji': '🌐', 'title': 'Hindi + English', 'text': 'Every question, option and explanation in both languages.'},
      {'emoji': '💰', 'title': 'Honest Pricing', 'text': "Serious prep shouldn't cost thousands. Free tests too."},
    ],
    'faculty': [
      {'name': "Nikki Ma'am", 'subject': 'English & Interview', 'image_url': ''},
      {'name': 'Ravi Sir', 'subject': 'GK/GS & Current Affairs', 'image_url': ''},
      {'name': 'Ashutosh Sir', 'subject': 'Mathematics', 'image_url': ''},
    ],
    'exams': [
      'SSC CGL', 'SSC CHSL', 'IB Security Assistant', 'IB ACIO',
      'Railways RRB', 'UP Police SI', 'Punjab & Haryana High Court',
      'Allahabad High Court',
    ],
    'community': {
      'youtube': 'https://youtube.com/@selection_lab',
      'telegram': 'https://t.me/Selection_Lab',
      'instagram': '',
      'whatsapp': '',
    },
    'announcement': {'enabled': false, 'text': '', 'link': ''},
  };
}
