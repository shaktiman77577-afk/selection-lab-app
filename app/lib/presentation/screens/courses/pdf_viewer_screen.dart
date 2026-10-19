// PDF viewer — watermarked PDF backend se aati hai.
//
// Pehle yahan course_content ka seedha file URL khulta tha, isliye:
//   - Mobile number ka watermark nahi aata tha
//   - Koi bhi wo link share karke PDF le sakta tha
//   - Download ka koi rasta nahi tha
//
// Ab /api/secure-pdf/{id} se PDF aati hai, jisme har student ka apna number
// chhapa hota hai. Leak ho to pata chal jata hai kisne kiya.
//
// SECURITY (Oct 2026): backend ab ?user_id= par bharosa nahi karta (koi bhi
// kisi aur ka id daal kar PDF le sakta tha). PDF Google viewer me khulti hai,
// jo login token (header) nahi bhej sakta — isliye pehle
// /secure-pdf/{id}/link se 30 min wala ticket lete hain (token AuthClient
// apne aap jodta hai), phir /secure-pdf/{id}?t=<ticket> kholte hain.
// Ticket sirf isi PDF aur isi student ka hai.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;

  /// Naya tarika — content ka id do, watermarked PDF khud aayegi.
  final int? contentId;
  final int? userId;

  /// Purana tarika — seedha URL. Ab bhi chalta hai (free samples ke liye),
  /// par usme watermark nahi hoga.
  final String? url;

  const PdfViewerScreen({
    super.key,
    required this.title,
    this.contentId,
    this.userId,
    this.url,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  /// Ticket wala pata (secure) ya seedha URL (purana tarika).
  String _pdfUrl = '';

  bool get _secure => widget.contentId != null;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A0A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    _open();
  }

  /// Secure PDF ke liye pehle ticket lo, phir viewer kholo.
  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_secure) {
        final q = widget.userId != null ? '?user_id=${widget.userId}' : '';
        final res = await http
            .get(Uri.parse('${AppConstants.apiUrl}/secure-pdf/${widget.contentId}/link$q'))
            .timeout(const Duration(seconds: 30));
        Map<String, dynamic> body = {};
        try {
          body = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {}
        if (res.statusCode != 200 || body['ticket'] == null) {
          final detail = body['detail'];
          throw Exception(detail is String ? detail : 'Could not open the PDF (${res.statusCode})');
        }
        final ticket = Uri.encodeQueryComponent(body['ticket'] as String);
        _pdfUrl = '${AppConstants.apiUrl}/secure-pdf/${widget.contentId}?t=$ticket';
      } else {
        _pdfUrl = widget.url ?? '';
      }
      if (_pdfUrl.isEmpty) throw Exception('PDF not available');

      // Google Docs viewer PDF ko render karta hai bina download button ke.
      // Hum apna download button dete hain taaki file par watermark rahe.
      final viewerUrl =
          'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(_pdfUrl)}';
      await _controller.loadRequest(Uri.parse(viewerUrl));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _download() async {
    if (_pdfUrl.isEmpty) return;
    // Ticket wale URL me pehle se "?" hai
    final url = _secure ? '$_pdfUrl&download=1' : _pdfUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the download.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _pdfUrl.isEmpty ? null : _download,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error == null) WebViewWidget(controller: _controller),

          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 40),
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _open,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),

          if (_loading)
            Center(child: CircularProgressIndicator(color: AppColors.primary)),

          // Watermark ke baare me batana zaroori hai — students ko pata rahe
          // ki ye copy unke naam par hai, to share karne se pehle sochenge.
          if (_secure && !_loading && _error == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                color: Colors.black.withOpacity(0.72),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: Colors.white70, size: 15),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your mobile number is printed on this PDF. Please do not share it.',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
