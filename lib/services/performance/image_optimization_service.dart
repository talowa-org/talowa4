// Image Optimization Service - Advanced image loading and optimization
// Comprehensive image handling with caching, compression, and lazy loading

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'caching_service.dart';

class ImageOptimizationService {
  static ImageOptimizationService? _instance;
  static ImageOptimizationService get instance => _instance ??= ImageOptimizationService._internal();
  
  ImageOptimizationService._internal();
  
  // Image processing configuration
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
  static const int thumbnailSize = 300;
  static const int jpegQuality = 85;
  
  // Memory management
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, Completer<ui.Image>> _loadingImages = {};
  
  /// Load and optimize image with advanced caching
  Future<ui.Image?> loadOptimizedImage(
    String imageUrl, {
    int? maxWidth,
    int? maxHeight,
    bool generateThumbnail = false,
    ImageOptimizationLevel optimization = ImageOptimizationLevel.balanced,
  }) async {
    try {
      final cacheKey = _generateImageCacheKey(
        imageUrl, 
        maxWidth ?? maxImageWidth, 
        maxHeight ?? maxImageHeight,
        generateThumbnail,
      );
      
      // Check memory cache first
      if (_imageCache.containsKey(cacheKey)) {
        debugPrint('ðŸŽ¯ Image cache hit (memory): $imageUrl');
        return _imageCache[cacheKey];
      }
      
      // Check if already loading
      if (_loadingImages.containsKey(cacheKey)) {
        debugPrint('â³ Image already loading: $imageUrl');
        return await _loadingImages[cacheKey]!.future;
      }
      
      // Start loading
      final completer = Completer<ui.Image>();
      _loadingImages[cacheKey] = completer;
      
      try {
        // Check disk cache
        final cachedImageData = await CachingService.instance.getCachedImage(cacheKey);
        ui.Image? image;
        
        if (cachedImageData != null) {
          debugPrint('ðŸŽ¯ Image cache hit (disk): $imageUrl');
          image = await _decodeImage(cachedImageData);
        } else {
          debugPrint('ðŸ“¥ Loading image from network: $imageUrl');
          image = await _loadAndOptimizeFromNetwork(
            imageUrl,
            maxWidth: maxWidth ?? maxImageWidth,
            maxHeight: maxHeight ?? maxImageHeight,
            generateThumbnail: generateThumbnail,
            optimization: optimization,
          );
        }
        
        if (image != null) {
          _imageCache[cacheKey] = image;
          completer.complete(image);
        } else {
          completer.complete(null);
        }
        
        return image;
        
      } catch (e) {
        completer.completeError(e);
        rethrow;
      } finally {
        _loadingImages.remove(cacheKey);
      }
      
    } catch (e) {
      debugPrint('âŒ Failed to load optimized image: $e');
      return null;
    }
  }
  
  /// Create optimized image widget
  Widget createOptimizedImageWidget(
    String imageUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    bool enableMemoryCache = true,
    bool enableDiskCache = true,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      placeholder: (context, url) => placeholder ?? _buildDefaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildDefaultErrorWidget(),
      cacheManager: enableDiskCache ? null : null, // Use default cache manager
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
      useOldImageOnUrlChange: true,
      cacheKey: _generateImageCacheKey(imageUrl, width?.toInt(), height?.toInt(), false),
    );
  }
  
  /// Preload images for better performance
  Future<void> preloadImages(List<String> imageUrls) async {
    try {
      debugPrint('ðŸš€ Preloading ${imageUrls.length} images...');
      
      final futures = imageUrls.map((url) => loadOptimizedImage(url));
      await Future.wait(futures, eagerError: false);
      
      debugPrint('âœ… Image preloading completed');
      
    } catch (e) {
      debugPrint('âŒ Failed to preload images: $e');
    }
  }
  
  /// Generate thumbnail from image
  Future<Uint8List?> generateThumbnail(
    String imageUrl, {
    int size = thumbnailSize,
    int quality = jpegQuality,
  }) async {
    try {
      debugPrint('ðŸ–¼ï¸ Generating thumbnail for: $imageUrl');
      
      // Check cache first
      final cacheKey = '${imageUrl}_thumb_$size';
      final cachedThumbnail = await CachingService.instance.getCachedImage(cacheKey);
      
      if (cachedThumbnail != null) {
        debugPrint('ðŸŽ¯ Thumbnail cache hit: $imageUrl');
        return cachedThumbnail;
      }
      
      // Load original image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
      
      // Decode and resize
      final originalImage = img.decodeImage(response.bodyBytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }
      
      final thumbnail = img.copyResize(
        originalImage,
        width: size,
        height: size,
        interpolation: img.Interpolation.cubic,
      );
      
      final thumbnailBytes = Uint8List.fromList(
        img.encodeJpg(thumbnail, quality: quality),
      );
      
      // Cache the thumbnail
      await CachingService.instance.cacheImage(cacheKey, thumbnailBytes);
      
      debugPrint('âœ… Thumbnail generated: ${thumbnailBytes.length} bytes');
      return thumbnailBytes;
      
    } catch (e) {
      debugPrint('âŒ Failed to generate thumbnail: $e');
      return null;
    }
  }
  
  /// Compress image for upload
  Future<Uint8List?> compressImageForUpload(
    Uint8List imageData, {
    int maxWidth = maxImageWidth,
    int maxHeight = maxImageHeight,
    int quality = jpegQuality,
  }) async {
    try {
      debugPrint('ðŸ—œï¸ Compressing image for upload...');
      
      final originalImage = img.decodeImage(imageData);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }
      
      // Calculate new dimensions
      final originalWidth = originalImage.width;
      final originalHeight = originalImage.height;
      
      int newWidth = originalWidth;
      int newHeight = originalHeight;
      
      if (originalWidth > maxWidth || originalHeight > maxHeight) {
        final widthRatio = maxWidth / originalWidth;
        final heightRatio = maxHeight / originalHeight;
        final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;
        
        newWidth = (originalWidth * ratio).round();
        newHeight = (originalHeight * ratio).round();
      }
      
      // Resize if needed
      img.Image processedImage = originalImage;
      if (newWidth != originalWidth || newHeight != originalHeight) {
        processedImage = img.copyResize(
          originalImage,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.cubic,
        );
      }
      
      // Compress
      final compressedBytes = Uint8List.fromList(
        img.encodeJpg(processedImage, quality: quality),
      );
      
      final compressionRatio = imageData.length / compressedBytes.length;
      debugPrint('âœ… Image compressed: ${compressionRatio.toStringAsFixed(2)}x reduction');
      
      return compressedBytes;
      
    } catch (e) {
      debugPrint('âŒ Failed to compress image: $e');
      return null;
    }
  }
  
  /// Load and optimize image from network
  Future<ui.Image?> _loadAndOptimizeFromNetwork(
    String imageUrl, {
    required int maxWidth,
    required int maxHeight,
    required bool generateThumbnail,
    required ImageOptimizationLevel optimization,
  }) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
      
      Uint8List imageData = response.bodyBytes;
      
      // Apply optimization based on level
      switch (optimization) {
        case ImageOptimizationLevel.none:
          break;
        case ImageOptimizationLevel.basic:
          imageData = await _basicOptimization(imageData, maxWidth, maxHeight) ?? imageData;
          break;
        case ImageOptimizationLevel.balanced:
          imageData = await _balancedOptimization(imageData, maxWidth, maxHeight) ?? imageData;
          break;
        case ImageOptimizationLevel.aggressive:
          imageData = await _aggressiveOptimization(imageData, maxWidth, maxHeight) ?? imageData;
          break;
      }
      
      // Cache the optimized image
      final cacheKey = _generateImageCacheKey(imageUrl, maxWidth, maxHeight, generateThumbnail);
      await CachingService.instance.cacheImage(cacheKey, imageData);
      
      // Decode to ui.Image
      return await _decodeImage(imageData);
      
    } catch (e) {
      debugPrint('âŒ Failed to load and optimize from network: $e');
      return null;
    }
  }
  
  /// Basic image optimization
  Future<Uint8List?> _basicOptimization(Uint8List imageData, int maxWidth, int maxHeight) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;
      
      // Only resize if image is larger than max dimensions
      if (image.width > maxWidth || image.height > maxHeight) {
        final resized = img.copyResize(
          image,
          width: maxWidth,
          height: maxHeight,
          maintainAspect: true,
        );
        
        return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
      }
      
      return imageData;
      
    } catch (e) {
      debugPrint('âŒ Basic optimization failed: $e');
      return null;
    }
  }
  
  /// Balanced image optimization
  Future<Uint8List?> _balancedOptimization(Uint8List imageData, int maxWidth, int maxHeight) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;
      
      // Resize and compress
      final resized = img.copyResize(
        image,
        width: maxWidth,
        height: maxHeight,
        maintainAspect: true,
        interpolation: img.Interpolation.cubic,
      );
      
      return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
      
    } catch (e) {
      debugPrint('âŒ Balanced optimization failed: $e');
      return null;
    }
  }
  
  /// Aggressive image optimization
  Future<Uint8List?> _aggressiveOptimization(Uint8List imageData, int maxWidth, int maxHeight) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;
      
      // Aggressive resize and compression
      final resized = img.copyResize(
        image,
        width: (maxWidth * 0.8).round(),
        height: (maxHeight * 0.8).round(),
        maintainAspect: true,
        interpolation: img.Interpolation.linear,
      );
      
      return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
      
    } catch (e) {
      debugPrint('âŒ Aggressive optimization failed: $e');
      return null;
    }
  }
  
  /// Decode image data to ui.Image
  Future<ui.Image> _decodeImage(Uint8List imageData) async {
    final completer = Completer<ui.Image>();
    
    ui.decodeImageFromList(imageData, (ui.Image image) {
      completer.complete(image);
    });
    
    return completer.future;
  }
  
  /// Generate cache key for image
  String _generateImageCacheKey(String url, int? width, int? height, bool thumbnail) {
    return '${url}_${width ?? 0}_${height ?? 0}_${thumbnail ? 'thumb' : 'full'}';
  }
  
  /// Build default placeholder widget
  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }
  
  /// Build default error widget
  Widget _buildDefaultErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
  
  /// Clear image cache
  void clearImageCache() {
    _imageCache.clear();
    debugPrint('ðŸ§¹ Image cache cleared');
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return {
      'memoryCachedImages': _imageCache.length,
      'loadingImages': _loadingImages.length,
    };
  }
}

// Enums

enum ImageOptimizationLevel {
  none,
  basic,
  balanced,
  aggressive,
}

