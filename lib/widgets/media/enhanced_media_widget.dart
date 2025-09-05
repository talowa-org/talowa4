// Enhanced Media Widget - Proper image and video loading with CORS fix
// Handles Firebase Storage URLs correctly and provides fallbacks

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/media/enhanced_media_service.dart';
import '../../core/theme/app_theme.dart';

class EnhancedMediaWidget extends StatefulWidget {
  final String? storagePath;
  final String? legacyUrl; // For backward compatibility
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showControls;
  final bool autoPlay;
  final Widget? placeholder;
  final Widget? errorWidget;

  const EnhancedMediaWidget({
    super.key,
    this.storagePath,
    this.legacyUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showControls = true,
    this.autoPlay = false,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<EnhancedMediaWidget> createState() => _EnhancedMediaWidgetState();
}

class _EnhancedMediaWidgetState extends State<EnhancedMediaWidget> {
  String? _downloadUrl;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _contentType;
  
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      String? url;
      
      if (widget.storagePath != null) {
        // Use proper Firebase Storage path
        url = await EnhancedMediaService.instance.getDownloadUrl(widget.storagePath!);
        debugPrint('✅ Got download URL from storage path: ${widget.storagePath!}');
        
        // Get metadata to determine content type
        final metadata = await EnhancedMediaService.instance.getMediaMetadata(widget.storagePath!);
        _contentType = metadata?.contentType;
        
      } else if (widget.legacyUrl != null) {
        // Handle legacy URLs - try to convert to storage path first
        final storagePath = EnhancedMediaService.instance.urlToStoragePath(widget.legacyUrl!);
        
        if (storagePath != null) {
          url = await EnhancedMediaService.instance.getDownloadUrl(storagePath);
          final metadata = await EnhancedMediaService.instance.getMediaMetadata(storagePath);
          _contentType = metadata?.contentType;
          debugPrint('✅ Converted legacy URL to storage path: $storagePath');
        } else {
          // Process legacy URL for CORS compatibility
          url = EnhancedMediaService.instance._processCorsUrl(widget.legacyUrl!);
          _contentType = _guessContentTypeFromUrl(url);
          debugPrint('⚠️ Using processed legacy URL: ${url.substring(0, min(url.length, 100))}...');
        }
      }

      if (url == null) {
        throw Exception('No media URL available');
      }

      setState(() {
        _downloadUrl = url;
        _isLoading = false;
      });

      // Initialize video player if it's a video
      if (_isVideoContent(_contentType)) {
        await _initializeVideoPlayer(url);
      }

    } catch (e) {
      debugPrint('❌ Failed to load media: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _initializeVideoPlayer(String url) async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      
      await _videoController!.initialize();
      
      setState(() {
        _isVideoInitialized = true;
      });

      if (widget.autoPlay) {
        await _videoController!.play();
      }

    } catch (e) {
      debugPrint('❌ Failed to initialize video player: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load video: $e';
      });
    }
  }

  bool _isVideoContent(String? contentType) {
    if (contentType == null) return false;
    return contentType.startsWith('video/');
  }

  bool _isImageContent(String? contentType) {
    if (contentType == null) return false;
    return contentType.startsWith('image/');
  }

  String _guessContentTypeFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    
    if (path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi')) {
      return 'video/mp4';
    } else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (path.endsWith('.png')) {
      return 'image/png';
    } else if (path.endsWith('.webp')) {
      return 'image/webp';
    } else if (path.endsWith('.svg')) {
      return 'image/svg+xml';
    }
    
    return 'application/octet-stream';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildPlaceholder();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    if (_downloadUrl == null) {
      return _buildErrorWidget();
    }

    if (_isVideoContent(_contentType)) {
      return _buildVideoPlayer();
    } else {
      return _buildImageWidget();
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ?? Container(
      width: widget.width,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ?? Container(
      width: widget.width,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load media',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.red,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadMedia,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: _downloadUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          debugPrint('❌ CachedNetworkImage error: $error');
          return _buildErrorWidget();
        },
        // Remove custom headers - let Firebase handle CORS
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_isVideoInitialized) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          children: [
            VideoPlayer(_videoController!),
            if (widget.showControls) _buildVideoControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                      setState(() {});
                    },
                    icon: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _videoController!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppTheme.primaryColor,
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Toggle fullscreen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FullscreenVideoPlayer(
                            controller: _videoController!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                    ),
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

// Fullscreen Video Player
class FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;

  const FullscreenVideoPlayer({
    super.key,
    required this.controller,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (widget.controller.value.isPlaying) {
                          widget.controller.pause();
                        } else {
                          widget.controller.play();
                        }
                        setState(() {});
                      },
                      icon: Icon(
                        widget.controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        widget.controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppTheme.primaryColor,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white12,
                        ),
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


