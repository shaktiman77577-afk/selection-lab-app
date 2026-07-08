// lib/core/utils/share_helper.dart
//
// One place that builds the correct public web link for any content and opens
// the native share sheet. Any screen can call this — new content automatically
// gets the right link because it's built from the item's id.

import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static const String site = 'https://selectionlab.in';

  /// Build the canonical public link for a piece of content.
  static String linkFor(String type, dynamic id) {
    final sid = id?.toString() ?? '';
    switch (type) {
      case 'course':
        return '$site/course/$sid';
      case 'descriptive':
        return '$site/descriptive/$sid';
      case 'mock':
        return '$site/mock-tests/$sid';
      default:
        return site;
    }
  }

  /// Open the native share sheet with a nice message + the direct link.
  static Future<void> share({
    required String type,
    required dynamic id,
    required String title,
    String? subtitle,
  }) async {
    final url = linkFor(type, id);
    final buffer = StringBuffer();
    buffer.writeln(title);
    if (subtitle != null && subtitle.trim().isNotEmpty) {
      buffer.writeln(subtitle.trim());
    }
    buffer.writeln();
    buffer.writeln(url);
    buffer.write('\n📚 Selection Lab');
    await Share.share(buffer.toString(), subject: title);
  }
}
