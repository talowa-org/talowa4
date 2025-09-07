// Enhanced Feed Media Widget - Proper rendering with error handling and analytics
// Implements all requirements for feed media display

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/media/comprehensive_media_service.dart';
import '../../services/media/media_url_processor.dart';
import '../../core/theme/app_theme.dart';

class EnhancedFeedMediaWidget extends StatefulWidget {
  final String mediaUrl;
  final String? contentType;
  final String postId;
  final int mediaIndex;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showControls;
  final bool autoPlay;

  const EnhancedFeedMediaWidget({
    super.key,
    required this.mediaUrl,
    this.contentType,
    required this.postId,
    required this.mediaIndex,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showControls = true,
    this.autoPlay = false,
  });

  @override
  State<EnhancedFeedMediaWidget> createState() => _EnhancedFeedMediaWidgetState();
}

class _EnhancedFeedMediaWidgetState extends State<EnhancedFeedMediaWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _detectedContentType;
  String? _processedMediaUrl;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  final MediaUrlProcessor _urlProcessor = MediaUrlProcessor();

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMedia() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Validate URL format
      if (!_isValidUrl(widget.mediaUrl)) {
        throw const MediaException(
          type: MediaErrorType.invalidUrl,
          message: 'Invalid media URL format',
        );
      }

      // Check if this is a Firebase Storage URL
      final isFirebaseStorageUrl = widget.mediaUrl.contains('firebasestorage.googleapis.com') || 
                                  (widget.mediaUrl.contains('firebase') && widget.mediaUrl.contains('storage'));
      
      // Process URL with authentication if it's a Firebase Storage URL
      if (isFirebaseStorageUrl) {
        debugPrint('🔐 Processing Firebase Storage URL with authentication');
        _processedMediaUrl = await _urlProcessor.processMediaUrlWithAuth(widget.mediaUrl);
      } else {
        // Process regular URL for CORS compatibility
        _processedMediaUrl = await _urlProcessor.processMediaUrl(widget.mediaUrl);
      }
      
      // Log the processed URL (safely)
      if (_processedMediaUrl != null && _processedMediaUrl!.isNotEmpty) {
        final maxLength = _processedMediaUrl!.length > 100 ? 100 : _processedMediaUrl!.length;
        debugPrint('🔄 Processed media URL: ${_processedMediaUrl!.substring(0, maxLength)}...');
      }

      // Detect content type
      _detectedContentType = widget.contentType ?? _detectContentType(_processedMediaUrl ?? widget.mediaUrl);
      
      setState(() {
        _isLoading = false;
      });

      // Initialize video player if it's a video
      if (_isVideoContent(_detectedContentType)) {
        await _initializeVideoPlayer();
      }

    } catch (e) {
      await _handleMediaError(e);
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      final videoUrl = _processedMediaUrl ?? widget.mediaUrl;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      
      await _videoController!.initialize();
      
      setState(() {
        _isVideoInitialized = true;
      });

      if (widget.autoPlay) {
        await _videoController!.play();
      }

    } catch (e) {
      await _handleMediaError(MediaException(
        type: MediaErrorType.videoInitialization,
        message: 'Failed to initialize video: $e',
      ));
    }
  }

  Future<void> _handleMediaError(dynamic error) async {
    String errorType;
    String errorMessage;
    
    if (error is MediaException) {
      errorType = error.type.name;
      errorMessage = error.message;
    } else {
      errorType = 'unknown';
      errorMessage = error.toString();
    }
    
    // Check for CORS or token issues
    final isCorsError = errorMessage.toLowerCase().contains('cors') ||
                       errorMessage.toLowerCase().contains('access-control-allow-origin');
    final isTokenError = errorMessage.toLowerCase().contains('token') ||
                        errorMessage.toLowerCase().contains('unauthorized');
    
    if (isCorsError || isTokenError) {
      errorType = isCorsError ? 'cors_error' : 'token_error';
    }
    
    // Log structured error
    await ComprehensiveMediaService.instance.logMediaError(
      postId: widget.postId,
      mediaIndex: widget.mediaIndex,
      url: widget.mediaUrl,
      errorType: errorType,
      errorMessage: errorMessage,
      additionalData: {
        'contentType': _detectedContentType,
        'isCorsError': isCorsError,
        'isTokenError': isTokenError,
      },
    );
    
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = errorMessage;
    });
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  String _detectContentType(String url) {
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
    }
    
    return 'image/jpeg'; // Default assumption
  }

  bool _isVideoContent(String? contentType) {
    return contentType?.startsWith('video/') == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    if (_isVideoContent(_detectedContentType)) {
      return _buildVideoPlayer();
    } else {
      return _buildImageWidget();
    }
  }

  Widget _buildLoadingWidget() {
    return Container(
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
    final isCorsError = _errorMessage?.toLowerCase().contains('cors') == true;
    final isTokenError = _errorMessage?.toLowerCase().contains('token') == true;
    
    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            isCorsError || isTokenError 
                ? 'Media temporarily unavailable'
                : 'Failed to load media',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              // Retry loading
              _initializeMedia();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Tap to retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage ?? 'Unknown error',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red[600],
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: _processedMediaUrl ?? widget.mediaUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) => _buildLoadingWidget(),
        errorWidget: (context, url, error) {
          // Handle image loading error
          debugPrint('❌ Image loading error: $error for URL: $url');
          
          // Check if it's a CORS error
          final errorString = error.toString().toLowerCase();
          final isCorsError = errorString.contains('cors') || 
                             errorString.contains('cross-origin') || 
                             errorString.contains('access-control');
          
          // Check if it's an authentication error
          final isAuthError = errorString.contains('permission') || 
                             errorString.contains('unauthorized') || 
                             errorString.contains('forbidden') || 
                             errorString.contains('auth');
          
          _handleMediaError(MediaException(
            type: isCorsError ? MediaErrorType.corsError : 
                  isAuthError ? MediaErrorType.tokenError : MediaErrorType.imageLoading,
            message: 'Failed to load image: $error',
          ));
          return _buildErrorWidget();
        },
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 200),
        // Add cacheKey to avoid caching issues with Firebase Storage URLs
        cacheKey: '${_processedMediaUrl ?? widget.mediaUrl}_${DateTime.now().day}',
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_isVideoInitialized) {
      return _buildLoadingWidget();
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Exception Classes

class MediaException implements Exception {
  final MediaErrorType type;
  final String message;

  const MediaException({
    required this.type,
    required this.message,
  });

  @override
  String toString() => 'MediaException: ${type.name} - $message';
}

enum MediaErrorType {
  invalidUrl,
  imageLoading,
  videoInitialization,
  corsError,
  tokenError,
  networkError,
  unknown,
}


