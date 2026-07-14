import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/theme/app_theme.dart';

/// Plays a video from a direct HLS (.m3u8) or MP4 URL — e.g. a Bunny Stream
/// pull-zone URL like:
///   https://vz-XXXXXXXX.b-cdn.net/<videoGuid>/playlist.m3u8
///
/// Pass that URL as [videoUrl]. Full controls (seek, play/pause, speed,
/// fullscreen in both orientations, volume) are provided by Chewie.
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  const VideoPlayerScreen(
      {super.key, required this.videoUrl, required this.title});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _videoController = controller;
      await controller.initialize();

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        aspectRatio: controller.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
        placeholder: Container(color: Colors.black),
        errorBuilder: (context, msg) => Center(
          child: Text('Could not play video',
              style: TextStyle(color: Colors.white.withOpacity(0.7))),
        ),
      );

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _initError = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _chewieController != null &&
        _videoController != null &&
        _videoController!.value.isInitialized;

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
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: ready ? _videoController!.value.aspectRatio : 16 / 9,
            child: Container(
              color: Colors.black,
              child: _initError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.white.withOpacity(0.6), size: 34),
                          const SizedBox(height: 10),
                          Text('Could not load this video',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13)),
                        ],
                      ),
                    )
                  : ready
                      ? Chewie(controller: _chewieController!)
                      : const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white54)),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Protected content • Selection Lab',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
