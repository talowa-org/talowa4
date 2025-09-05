// Media Compression Service for TALOWA Messaging System
// Handles compression and optimization for images, audio, and video files
// Requirements: 4.2 - Create media compression and optimization

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class MediaCompressionService {
  static final MediaCompressionService _instance = MediaCompressionService._internal();
  factory MediaCompressionService() => _instance;
  MediaCompressionService._internal();

  // Compression settings
  static const int defaultImageQuality = 85;
  static const int thumbnailSize = 300;
  static const int previewSize = 800;
  static const int maxImageDimension = 2048;
  static const int maxThumbnailDimension = 300;

  /// Compress image with various quality settings
  Future<CompressedImageResult> compressImage({
    required File imageFile,
    CompressionLevel level = CompressionLevel.balanced,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Invalid image format');
      }

      // Determine compression settings based on level
      final settings = _getCompressionSettings(level);
      final targetWidth = maxWidth ?? settings.maxWidth;
      final targetHeight = maxHeight ?? settings.maxHeight;
      final targetQuality = quality ?? settings.quality;

      // Calculate new dimensions maintaining aspect ratio
      final newDimensions = _calculateNewDimensions(
        image.width,
        image.height,
        targetWidth,
        targetHeight,
      );

      // Resize image if needed
      img.Image processedImage = image;
      if (newDimensions.width != image.width || newDimensions.height != image.height) {
        processedImage = img.copyResize(
          image,
          width: newDimensions.width,
          height: newDimensions.height,
          interpolation: img.Interpolation.cubic,
        );
      }

      // Apply additional optimizations based on compression level
      if (level == CompressionLevel.maximum) {
        // Apply noise reduction and sharpening for maximum compression
        processedImage = img.gaussianBlur(processedImage, radius: 0.5);
        processedImage = img.convolution(processedImage, [
          0, -1, 0,
          -1, 5, -1,
          0, -1, 0
        ]);
      }

      // Encode with specified quality
      final compressedBytes = img.encodeJpg(processedImage, quality: targetQuality);
      
      // Calculate compression ratio
      final originalSize = bytes.length;
      final compressedSize = compressedBytes.length;
      final compressionRatio = (1 - (compressedSize / originalSize)) * 100;

      return CompressedImageResult(
        compressedData: Uint8List.fromList(compressedBytes),
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: compressionRatio,
        width: processedImage.width,
        height: processedImage.height,
        quality: targetQuality,
      );
    } catch (e) {
      debugPrint('Error compressing image: $e');
      rethrow;
    }
  }

  /// Generate thumbnail from image
  Future<Uint8List> generateThumbnail({
    required File imageFile,
    int size = thumbnailSize,
    int quality = 70,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Invalid image format');
      }

      // Create square thumbnail with center crop
      final thumbnail = _createSquareThumbnail(image, size);
      
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: quality));
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      rethrow;
    }
  }

  /// Compress audio file (simplified implementation)
  Future<CompressedAudioResult> compressAudio({
    required File audioFile,
    AudioCompressionLevel level = AudioCompressionLevel.balanced,
  }) async {
    try {
      // Simplified audio compression - in production, use proper audio processing library
      final originalBytes = await audioFile.readAsBytes();
      final originalSize = originalBytes.length;
      
      // For now, return original data with metadata
      // In production, implement actual audio compression using libraries like:
      // - flutter_ffmpeg for audio processing
      // - audio compression algorithms
      
      final settings = _getAudioCompressionSettings(level);
      
      return CompressedAudioResult(
        compressedData: originalBytes,
        originalSize: originalSize,
        compressedSize: originalSize, // Would be smaller after real compression
        compressionRatio: 0, // Would be calculated after real compression
        bitrate: settings.bitrate,
        sampleRate: settings.sampleRate,
      );
    } catch (e) {
      debugPrint('Error compressing audio: $e');
      rethrow;
    }
  }

  /// Optimize image for different use cases
  Future<Map<String, Uint8List>> generateImageVariants(File imageFile) async {
    try {
      final variants = <String, Uint8List>{};
      
      // Generate thumbnail
      variants['thumbnail'] = await generateThumbnail(
        imageFile: imageFile,
        size: thumbnailSize,
        quality: 70,
      );
      
      // Generate preview
      final previewResult = await compressImage(
        imageFile: imageFile,
        level: CompressionLevel.balanced,
        maxWidth: previewSize,
        maxHeight: previewSize,
        quality: 80,
      );
      variants['preview'] = previewResult.compressedData;
      
      // Generate full size (optimized)
      final fullResult = await compressImage(
        imageFile: imageFile,
        level: CompressionLevel.minimal,
        maxWidth: maxImageDimension,
        maxHeight: maxImageDimension,
        quality: defaultImageQuality,
      );
      variants['full'] = fullResult.compressedData;
      
      return variants;
    } catch (e) {
      debugPrint('Error generating image variants: $e');
      rethrow;
    }
  }

  /// Extract video thumbnail (simplified)
  Future<Uint8List?> extractVideoThumbnail(File videoFile) async {
    try {
      // Simplified video thumbnail extraction
      // In production, use flutter_ffmpeg or similar library
      
      debugPrint('Video thumbnail extraction not implemented - would use FFmpeg');
      return null;
    } catch (e) {
      debugPrint('Error extracting video thumbnail: $e');
      return null;
    }
  }

  /// Compress video file (simplified)
  Future<CompressedVideoResult> compressVideo({
    required File videoFile,
    VideoCompressionLevel level = VideoCompressionLevel.balanced,
  }) async {
    try {
      // Simplified video compression - in production, use proper video processing
      final originalBytes = await videoFile.readAsBytes();
      final originalSize = originalBytes.length;
      
      final settings = _getVideoCompressionSettings(level);
      
      return CompressedVideoResult(
        compressedData: originalBytes,
        originalSize: originalSize,
        compressedSize: originalSize, // Would be smaller after real compression
        compressionRatio: 0, // Would be calculated after real compression
        resolution: settings.resolution,
        bitrate: settings.bitrate,
        fps: settings.fps,
      );
    } catch (e) {
      debugPrint('Error compressing video: $e');
      rethrow;
    }
  }

  // Private helper methods

  ImageCompressionSettings _getCompressionSettings(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.minimal:
        return const ImageCompressionSettings(
          maxWidth: 2048,
          maxHeight: 2048,
          quality: 90,
        );
      case CompressionLevel.balanced:
        return const ImageCompressionSettings(
          maxWidth: 1920,
          maxHeight: 1080,
          quality: 85,
        );
      case CompressionLevel.maximum:
        return const ImageCompressionSettings(
          maxWidth: 1280,
          maxHeight: 720,
          quality: 70,
        );
    }
  }

  AudioCompressionSettings _getAudioCompressionSettings(AudioCompressionLevel level) {
    switch (level) {
      case AudioCompressionLevel.minimal:
        return const AudioCompressionSettings(
          bitrate: 320,
          sampleRate: 44100,
        );
      case AudioCompressionLevel.balanced:
        return const AudioCompressionSettings(
          bitrate: 192,
          sampleRate: 44100,
        );
      case AudioCompressionLevel.maximum:
        return const AudioCompressionSettings(
          bitrate: 128,
          sampleRate: 22050,
        );
    }
  }

  VideoCompressionSettings _getVideoCompressionSettings(VideoCompressionLevel level) {
    switch (level) {
      case VideoCompressionLevel.minimal:
        return const VideoCompressionSettings(
          resolution: '1920x1080',
          bitrate: 5000,
          fps: 30,
        );
      case VideoCompressionLevel.balanced:
        return const VideoCompressionSettings(
          resolution: '1280x720',
          bitrate: 2500,
          fps: 30,
        );
      case VideoCompressionLevel.maximum:
        return const VideoCompressionSettings(
          resolution: '854x480',
          bitrate: 1000,
          fps: 24,
        );
    }
  }

  ImageDimensions _calculateNewDimensions(
    int originalWidth,
    int originalHeight,
    int maxWidth,
    int maxHeight,
  ) {
    if (originalWidth <= maxWidth && originalHeight <= maxHeight) {
      return ImageDimensions(originalWidth, originalHeight);
    }

    final aspectRatio = originalWidth / originalHeight;
    
    int newWidth = maxWidth;
    int newHeight = (newWidth / aspectRatio).round();
    
    if (newHeight > maxHeight) {
      newHeight = maxHeight;
      newWidth = (newHeight * aspectRatio).round();
    }
    
    return ImageDimensions(newWidth, newHeight);
  }

  img.Image _createSquareThumbnail(img.Image image, int size) {
    // Calculate crop dimensions for square thumbnail
    final minDimension = image.width < image.height ? image.width : image.height;
    final cropX = (image.width - minDimension) ~/ 2;
    final cropY = (image.height - minDimension) ~/ 2;
    
    // Crop to square
    final cropped = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: minDimension,
      height: minDimension,
    );
    
    // Resize to target size
    return img.copyResize(cropped, width: size, height: size);
  }
}

// Compression levels
enum CompressionLevel { minimal, balanced, maximum }
enum AudioCompressionLevel { minimal, balanced, maximum }
enum VideoCompressionLevel { minimal, balanced, maximum }

// Settings classes
class ImageCompressionSettings {
  final int maxWidth;
  final int maxHeight;
  final int quality;

  const ImageCompressionSettings({
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
  });
}

class AudioCompressionSettings {
  final int bitrate; // kbps
  final int sampleRate; // Hz

  const AudioCompressionSettings({
    required this.bitrate,
    required this.sampleRate,
  });
}

class VideoCompressionSettings {
  final String resolution;
  final int bitrate; // kbps
  final int fps;

  const VideoCompressionSettings({
    required this.resolution,
    required this.bitrate,
    required this.fps,
  });
}

// Result classes
class CompressedImageResult {
  final Uint8List compressedData;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  final int width;
  final int height;
  final int quality;

  CompressedImageResult({
    required this.compressedData,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
    required this.width,
    required this.height,
    required this.quality,
  });

  String get compressionInfo => 
    'Compressed ${(compressionRatio).toStringAsFixed(1)}% '
    '(${_formatFileSize(originalSize)} â†’ ${_formatFileSize(compressedSize)})';

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class CompressedAudioResult {
  final Uint8List compressedData;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  final int bitrate;
  final int sampleRate;

  CompressedAudioResult({
    required this.compressedData,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
    required this.bitrate,
    required this.sampleRate,
  });
}

class CompressedVideoResult {
  final Uint8List compressedData;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  final String resolution;
  final int bitrate;
  final int fps;

  CompressedVideoResult({
    required this.compressedData,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
    required this.resolution,
    required this.bitrate,
    required this.fps,
  });
}

class ImageDimensions {
  final int width;
  final int height;

  ImageDimensions(this.width, this.height);
}
