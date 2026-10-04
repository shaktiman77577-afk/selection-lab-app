// lib/presentation/screens/blog/blog_screen.dart
//
// Blog — list aur post, dono app ke andar.
//
// Pehle home ka "Blog" chip Chrome kholta tha. Student app se bahar chala jata
// tha aur wapas aana uske haath me tha — content ka poora faayda nahi milta
// tha. Ab list aur post dono yahin khulte hain.
//
// Endpoints:
//   GET /blog/          -> { posts: [{slug, title, excerpt, cover_url, created_at}] }
//   GET /blog/{slug}    -> { post: {..., content} }
//
// Content ka format wahi hai jo website render karti hai:
//   "## "        -> heading
//   "- " lines   -> bullets
//   [text](url)  -> link
//   sirf ek link wala paragraph -> CTA button
//   baaki        -> paragraph
// Isliye renderer bhi wahi rakha hai, warna app par formatting toot jati.
//
// Redesign (Sep 2026): links/bullets navy (gold safed par padhne me nahi aata
// tha), aur website ke apne links ab app ke andar khulte hain.

import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../descriptive/descriptive_theme.dart';
import '../web/site_web_screen.dart';

const _site = 'https://selectionlab.in';

// ── LIST ────────────────────────────────────────────────────────────────────────────

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.apiUrl}/blog/'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final list = d['posts'];
        if (list is List && mounted) {
          setState(() {
            _posts =
                list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loading = false;
          });
          return;
        }
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load posts right now.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not reach the server. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Blog')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: _empty(t, _error!),
                        ),
                      ],
                    )
                  : _posts.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: _empty(t, 'No posts yet.'),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _posts.length,
                          itemBuilder: (context, i) => _card(t, _posts[i]),
                        ),
            ),
    );
  }

  Widget _empty(DT t, String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article_outlined, size: 54, color: t.muted),
              const SizedBox(height: 14),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.text2, fontSize: 14)),
            ],
          ),
        ),
      );

  Widget _card(DT t, Map<String, dynamic> p) {
    final cover = (p['cover_url'] ?? '').toString();
    final date = _fmtDate(p['created_at']);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlogPostScreen(
            slug: (p['slug'] ?? '').toString(),
            title: (p['title'] ?? '').toString(),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(16),
          boxShadow: t.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(cover,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date.isNotEmpty) ...[
                    Text(date,
                        style: TextStyle(fontSize: 11.5, color: t.muted)),
                    const SizedBox(height: 5),
                  ],
                  Text((p['title'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          color: t.text)),
                  if ((p['excerpt'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(p['excerpt'].toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, height: 1.5, color: t.text2)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('Read more',
                          style: TextStyle(
                              color: t.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded,
                          color: t.primary, size: 15),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDate(dynamic iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  if (d == null) return '';
  final l = d.toLocal();
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${l.day} ${m[l.month - 1]} ${l.year}';
}

// ── POST ────────────────────────────────────────────────────────────────────────────

class BlogPostScreen extends StatefulWidget {
  final String slug;
  final String? title;
  const BlogPostScreen({super.key, required this.slug, this.title});

  @override
  State<BlogPostScreen> createState() => _BlogPostScreenState();
}

class _BlogPostScreenState extends State<BlogPostScreen> {
  Map<String, dynamic>? _post;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.apiUrl}/blog/${widget.slug}'))
          .timeout(const Duration(seconds: 20));
      final d = jsonDecode(res.body);
      if (!mounted) return;
      if (res.statusCode == 200 && d['post'] != null) {
        setState(() {
          _post = Map<String, dynamic>.from(d['post'] as Map);
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = (d is Map ? d['detail'] : null)?.toString() ??
              'Post not found.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Check your connection.';
      });
    }
  }

  /// Website ka apna link ('/...' ya selectionlab.in) app ke andar khulta hai
  /// (WebView, auto-login) — pehle browser me jaata tha jahan student
  /// logged-in nahi hota. Baaki links browser me.
  Future<void> _openLink(String href) async {
    var path = href;
    for (final host in ['https://www.selectionlab.in', 'https://selectionlab.in']) {
      if (path.startsWith(host)) path = path.substring(host.length);
    }
    if (path.startsWith('/')) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => SiteWebScreen(path: path)));
      return;
    }
    try {
      await launchUrl(Uri.parse(href.startsWith('http') ? href : '$_site$href'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ── Renderer ──
  // Website ka format hi follow karte hain, warna ek hi post do jagah do tarah
  // dikhega.

  static final _linkRe = RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)');
  static final _onlyLinkRe = RegExp(r'^\[([^\]]+)\]\(([^)\s]+)\)$');

  /// [text](url) ko tappable span me badalta hai; baaki text waisa hi.
  List<InlineSpan> _inline(String text, DT t) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _linkRe.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final label = m.group(1) ?? '';
      final href = m.group(2) ?? '';
      spans.add(
        TextSpan(
          text: label,
          style: TextStyle(
              color: t.primary,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline),
          recognizer: _tap(() => _openLink(href)),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  // TapGestureRecognizer ko dispose karna padta hai, isliye ek list me rakhte
  // hain aur screen band hone par saaf kar dete hain.
  final List<_Recognizer> _recognizers = [];

  _Recognizer _tap(VoidCallback fn) {
    final r = _Recognizer(fn);
    _recognizers.add(r);
    return r;
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<Widget> _content(String raw, DT t) {
    final blocks = raw.split(RegExp(r'\n\s*\n'));
    final out = <Widget>[];

    for (final b in blocks) {
      final s = b.trim();
      if (s.isEmpty) continue;

      // Heading
      if (s.startsWith('## ')) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  color: t.text),
              children: _inline(s.substring(3), t),
            ),
          ),
        ));
        continue;
      }

      // CTA — poora paragraph sirf ek link ho
      final only = _onlyLinkRe.firstMatch(s);
      if (only != null) {
        out.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: ElevatedButton(
              onPressed: () => _openLink(only.group(2) ?? ''),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              ),
              child: Text(only.group(1) ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14.5)),
            ),
          ),
        ));
        continue;
      }

      // Bullets — tabhi jab block ki har line "- " se shuru ho
      final lines = s.split('\n');
      if (lines.every((l) => l.trim().startsWith('- '))) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 9),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: t.primary, shape: BoxShape.circle),
                      ),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 14.5, height: 1.6, color: t.text2),
                          children: _inline(l.trim().substring(2), t),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ));
        continue;
      }

      // Paragraph
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14.5, height: 1.65, color: t.text2),
            children: _inline(s, t),
          ),
        ),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    final title = (_post?['title'] ?? widget.title ?? 'Blog').toString();
    final cover = (_post?['cover_url'] ?? '').toString();
    final body = (_post?['content'] ?? '').toString();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 54, color: t.muted),
                        const SizedBox(height: 14),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: t.text2, fontSize: 14)),
                        const SizedBox(height: 16),
                        TextButton(
                            onPressed: _load,
                            child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                  children: [
                    if (cover.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(cover,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink()),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(title,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                            color: t.text)),
                    if (_fmtDate(_post?['created_at']).isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(_fmtDate(_post?['created_at']),
                          style: TextStyle(fontSize: 12.5, color: t.muted)),
                    ],
                    const SizedBox(height: 18),
                    ..._content(body, t),
                  ],
                ),
    );
  }
}

/// Chhota wrapper — TapGestureRecognizer ke liye, taaki dispose ek jagah ho.
class _Recognizer extends TapGestureRecognizer {
  _Recognizer(VoidCallback fn) {
    onTap = fn;
  }
}
