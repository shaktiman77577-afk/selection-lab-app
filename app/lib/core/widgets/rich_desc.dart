// lib/core/widgets/rich_desc.dart
//
// Course description ka chhota markdown renderer (Oct 2026) — website ke
// RichText.tsx jaisa. Admin description me **bold**, ### heading, - list
// likhta hai; pehle app use seedha text dikhata tha ("**" aur "###" ke saath).
// Saada text (bina markdown) pehle jaisa hi dikhta hai — har line apni jagah.
//
// Samajhta hai: # / ## / ### heading, - * • list, 1. list, --- line,
// **bold**, __bold__, *italic*.

import 'package:flutter/material.dart';

class RichDesc extends StatelessWidget {
  final String text;
  final Color color; // aam text
  final Color strong; // heading / bold
  final Color accent; // bullet
  final double fontSize;

  const RichDesc({
    super.key,
    required this.text,
    required this.color,
    required this.strong,
    required this.accent,
    this.fontSize = 14,
  });

  static final _h = RegExp(r'^#{1,6}\s+(.*)$');
  static final _ul = RegExp(r'^[-*•]\s+(.*)$');
  static final _ol = RegExp(r'^(\d{1,3})[.)]\s+(.*)$');
  static final _hr = RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$');
  static final _inline =
      RegExp(r'(\*\*[^*\n]+?\*\*|__[^_\n]+?__|\*[^*\s][^*\n]*?\*)');

  List<InlineSpan> _spans(String s) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      final t = m.group(0)!;
      if ((t.startsWith('**') || t.startsWith('__')) && t.length > 4) {
        out.add(TextSpan(
            text: t.substring(2, t.length - 2),
            style: TextStyle(fontWeight: FontWeight.w700, color: strong)));
      } else if (t.length > 2) {
        out.add(TextSpan(
            text: t.substring(1, t.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic)));
      } else {
        out.add(TextSpan(text: t));
      }
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: fontSize, height: 1.6, color: color);
    final blocks = <Widget>[];
    final para = <String>[];

    void flushPara() {
      if (para.isEmpty) return;
      final spans = <InlineSpan>[];
      for (var i = 0; i < para.length; i++) {
        if (i > 0) spans.add(const TextSpan(text: '\n'));
        spans.addAll(_spans(para[i]));
      }
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text.rich(TextSpan(children: spans), style: base),
      ));
      para.clear();
    }

    Widget item(Widget marker, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 20, child: marker),
              Expanded(
                  child: Text.rich(TextSpan(children: _spans(body)),
                      style: base)),
            ],
          ),
        );

    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    var inList = false;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        flushPara();
        if (inList) {
          blocks.add(const SizedBox(height: 5));
          inList = false;
        }
        continue;
      }
      if (_hr.hasMatch(line)) {
        flushPara();
        blocks.add(Divider(color: color.withOpacity(0.2), height: 24));
        continue;
      }
      final h = _h.firstMatch(line);
      if (h != null) {
        flushPara();
        blocks.add(Padding(
          padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 8, bottom: 8),
          child: Text.rich(
            TextSpan(children: _spans(h.group(1)!.replaceAll(RegExp(r'\s+#+$'), ''))),
            style: TextStyle(
                fontSize: fontSize + 1.5,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: strong),
          ),
        ));
        continue;
      }
      final ul = _ul.firstMatch(line);
      if (ul != null) {
        flushPara();
        inList = true;
        blocks.add(item(
          Padding(
            padding: EdgeInsets.only(top: fontSize * 0.62, left: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
          ul.group(1)!,
        ));
        continue;
      }
      final ol = _ol.firstMatch(line);
      if (ol != null) {
        flushPara();
        inList = true;
        blocks.add(item(
          Text('${ol.group(1)}.',
              style: base.copyWith(fontWeight: FontWeight.w800, color: strong)),
          ol.group(2)!,
        ));
        continue;
      }
      if (inList) {
        blocks.add(const SizedBox(height: 5));
        inList = false;
      }
      para.add(line);
    }
    flushPara();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}
