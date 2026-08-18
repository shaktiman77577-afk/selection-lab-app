// PDF viewer — watermarked PDF backend se aati hai.
//
// Pehle yahan course_content ka seedha file URL khulta tha, isliye:
//   - Mobile number ka watermark nahi aata tha
//   - Koi bhi wo link share karke PDF le sakta tha
//   - Download ka koi rasta nahi tha
//
// Ab /api/secure-pdf/{id}?user_id={id} se PDF aati hai, jisme har student ka
// apna number chhapa hota hai. Leak ho to pata chal jata hai kisne kiya.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;

  /// Naya tarika — content ka id aur user id do, watermarked PDF khud aayegi.
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

  /// Watermarked PDF ka pata — agar contentId mila ho to wahi use hota hai.
  String get _pdfUrl {
    if (widget.contentId != null) {
      final u = widget.userId != null ? '?user_id=${widget.userId}' : '';
      return '${AppConstants.apiUrl}/secure-pdf/${widget.contentId}$u';
    }
    return widget.url ?? '';
  }

  bool get _secure => widget.contentId != null;

  @override
  void initState() {
    super.initState();

    // Google Docs viewer PDF ko render karta hai bina download button ke.
    // Hum apna download button dete hain taaki file par watermark rahe.
    final viewerUrl =
        'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(_pdfUrl)}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A0A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(viewerUrl));
  }

  Future<void> _download() async {
    final url = _secure ? '$_pdfUrl&download=1' : _pdfUrl;
    if (url.isEmpty) return;
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
            onPressed: _download,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          if (_loading)
            Center(child: CircularProgressIndicator(color: AppColors.primary)),

          // Watermark ke baare me batana zaroori hai — students ko pata rahe
          // ki ye copy unke naam par hai, to share karne se pehle sochenge.
          if (_secure && !_loading)
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
