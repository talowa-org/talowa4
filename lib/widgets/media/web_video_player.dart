// Web-specific video player using HTML5 video element
// Provides better compatibility for Firebase Storage videos on web

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// Only import web-specific libraries when on web
import 'dart:html' as html show VideoElement, Event;
import 'dart:ui_web' as ui_web show platformViewRegistry;

class WebVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool showControls;
  final bool looping;
  final double aspectRatio;
  final VoidCallback? onTap;
  
  const WebVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.looping = false,
    this.aspectRatio = 16 / 9,
    this.onTap,
  });

  @override
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  late html.VideoElement _videoElement;
  late String _viewId;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewId = 'video-${DateTime.now().millisecondsSinceEpoch}';
    _initializeVideo();
  }

  void _initializeVideo() {
    try {
      debugPrint('ðŸŽ¬ Initializing web video: ${widget.videoUrl}');
      
      // Create HTML video element
      _videoElement = html.VideoElement()
        ..src = _processVideoUrl(widget.videoUrl)
        ..controls = widget.showControls
        ..autoplay = widget.autoPlay
        ..loop = widget.looping
        ..preload = 'metadata'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = 'black'
        ..crossOrigin = 'anonymous'; // Enable CORS

      // Add event listeners
      _videoElement.onLoadedData.listen((html.Event event) {
        debugPrint('âœ… Video loaded successfully');
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _errorMessage = null;
          });
        }
      });

      _videoElement.onError.listen((html.Event event) {
        debugPrint('âŒ Video error: ${_videoElement.error?.message}');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load video: ${_videoElement.error?.message ?? 'Unknown error'}';
          });
        }
      });

      _videoElement.onPlay.listen((html.Event event) {
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      });

      _videoElement.onPause.listen((html.Event event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      });

      // Register the video element with Flutter
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _videoElement,
      );

      setState(() {
        _isInitialized = true;
      });

    } catch (e) {
      debugPrint('âŒ Web video initialization error: $e');
      setState(() {
        _errorMessage = 'Failed to initialize video: $e';
      });
    }
  }

  String _processVideoUrl(String url) {
    debugPrint('ðŸ” Original URL: $url');

    // Add CORS-friendly parameters for Firebase Storage URLs
    if (url.contains('firebasestorage.googleapis.com')) {
      final uri = Uri.parse(url);
      final newUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'alt': 'media',
        // Preserve existing token if present
        if (uri.queryParameters.containsKey('token'))
          'token': uri.queryParameters['token']!,
      });
      final processedUrl = newUri.toString();
      debugPrint('ðŸ”„ Processed Firebase URL: $processedUrl');
      return processedUrl;
    }

    // For other URLs, return as-is
    debugPrint('ðŸ”„ Using original URL: $url');
    return url;
  }

  @override
  void dispose() {
    try {
      _videoElement.pause();
      _videoElement.remove();
    } catch (e) {
      debugPrint('Error disposing video element: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.width / widget.aspectRatio,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return GestureDetector(
      onTap: widget.onTap ?? _togglePlayPause,
      child: Stack(
        children: [
          // HTML video element
          HtmlElementView(viewType: _viewId),
          
          // Play/pause overlay (only if controls are hidden)
          if (!widget.showControls)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'URL: ${widget.videoUrl}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _isInitialized = false;
              });
              _initializeVideo();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() {
    try {
      if (_isPlaying) {
        _videoElement.pause();
      } else {
        _videoElement.play();
      }
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
    }
  }
}


