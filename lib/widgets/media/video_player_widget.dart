// Video Player Widget for TALOWA Social Feed
// Handles video playback with controls and optimization

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/app_theme.dart';
import 'web_video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool showControls;
  final bool looping;
  final double aspectRatio;
  final VoidCallback? onTap;
  final VoidCallback? onFullscreen;
  
  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.looping = false,
    this.aspectRatio = 16 / 9,
    this.onTap,
    this.onFullscreen,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isBuffering = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeVideo() async {
    try {
      debugPrint('Initializing video: ${widget.videoUrl}');
      debugPrint('Platform: ${Theme.of(context).platform}');

      // Parse and validate URL
      final uri = Uri.parse(widget.videoUrl);
      debugPrint('Parsed URI: $uri');

      // For web, we might need to handle Firebase Storage URLs differently
      String videoUrl = widget.videoUrl;

      // Add CORS-friendly parameters for Firebase Storage URLs on web
      if (videoUrl.contains('firebasestorage.googleapis.com')) {
        final uri = Uri.parse(videoUrl);
        final newUri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'alt': 'media',
          // Preserve existing token if present
          if (uri.queryParameters.containsKey('token'))
            'token': uri.queryParameters['token']!,
        });
        videoUrl = newUri.toString();
        debugPrint('Modified URL for web: $videoUrl');
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      // Add timeout for initialization
      await _controller!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Video initialization timeout after 30 seconds');
        },
      );

      _controller!.addListener(_videoListener);

      setState(() {
        _isInitialized = true;
        if (widget.autoPlay) {
          _controller!.play();
          _isPlaying = true;
        }
      });

      // Set looping
      _controller!.setLooping(widget.looping);

      debugPrint('Video initialized successfully');

    } catch (e) {
      debugPrint('Video initialization error: $e');
      setState(() {
        _errorMessage = 'Failed to load video: ${e.toString()}';
      });
    }
  }
  
  void _videoListener() {
    if (!mounted) return;
    
    final isPlaying = _controller!.value.isPlaying;
    final isBuffering = _controller!.value.isBuffering;
    
    if (_isPlaying != isPlaying || _isBuffering != isBuffering) {
      setState(() {
        _isPlaying = isPlaying;
        _isBuffering = isBuffering;
      });
    }
  }
  
  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    
    HapticFeedback.lightImpact();
    
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }
  
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    // Auto-hide controls after 3 seconds
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  @override
  Widget build(BuildContext context) {
    // Use web-specific video player for better compatibility on web
    if (kIsWeb) {
      return WebVideoPlayer(
        videoUrl: widget.videoUrl,
        thumbnailUrl: widget.thumbnailUrl,
        autoPlay: widget.autoPlay,
        showControls: widget.showControls,
        looping: widget.looping,
        aspectRatio: widget.aspectRatio,
        onTap: widget.onTap,
      );
    }

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.width / widget.aspectRatio,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: _buildVideoContent(),
      ),
    );
  }
  
  Widget _buildVideoContent() {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }
    
    if (!_isInitialized) {
      return _buildLoadingWidget();
    }
    
    return GestureDetector(
      onTap: widget.onTap ?? _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video player
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          
          // Loading indicator
          if (_isBuffering)
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          
          // Controls overlay
          if (widget.showControls && _showControls)
            _buildControlsOverlay(),
        ],
      ),
    );
  }
  
  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Show thumbnail if available
          if (widget.thumbnailUrl != null)
            Expanded(
              child: Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Loading video...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
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
  
  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
            Colors.black.withOpacity(0.3),
          ],
        ),
      ),
      child: Column(
        children: [
          // Top controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40), // Spacer
                if (widget.onFullscreen != null)
                  IconButton(
                    onPressed: widget.onFullscreen,
                    icon: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Center play/pause button
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _togglePlayPause,
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          
          const Spacer(),
          
          // Bottom controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Progress bar
                VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppTheme.talowaGreen,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white10,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Time display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_controller!.value.position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(_controller!.value.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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

