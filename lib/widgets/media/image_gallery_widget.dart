// Image Gallery Widget - Display and view multiple images with enhanced media support
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'enhanced_media_widget.dart';

class ImageGalleryWidget extends StatelessWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final bool isFullScreen;
  final Function(int)? onImageTap;
  final double? height;
  final EdgeInsets? padding;
  final String? heroTag;

  const ImageGalleryWidget({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.isFullScreen = false,
    this.onImageTap,
    this.height,
    this.padding,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    if (isFullScreen) {
      return _buildFullScreenGallery(context);
    } else {
      return _buildInlineGallery(context);
    }
  }

  Widget _buildInlineGallery(BuildContext context) {
    final displayHeight = height ?? _calculateHeight();

    return Container(
      height: displayHeight,
      padding: padding,
      child: _buildGalleryLayout(context),
    );
  }

  Widget _buildGalleryLayout(BuildContext context) {
    if (imageUrls.length == 1) {
      return _buildSingleImage(context, 0);
    } else if (imageUrls.length == 2) {
      return _buildTwoImages(context);
    } else if (imageUrls.length == 3) {
      return _buildThreeImages(context);
    } else {
      return _buildMultipleImages(context);
    }
  }

  Widget _buildSingleImage(BuildContext context, int index) {
    return GestureDetector(
      onTap: () => _handleImageTap(context, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Hero(
          tag: heroTag != null ? '${heroTag}_$index' : 'image_$index',
          child: EnhancedMediaWidget(
            legacyUrl: imageUrls[index],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildTwoImages(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildImageItem(context, 0),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _buildImageItem(context, 1),
        ),
      ],
    );
  }

  Widget _buildThreeImages(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildImageItem(context, 0),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _buildImageItem(context, 1),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _buildImageItem(context, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleImages(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildImageItem(context, 0),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _buildImageItem(context, 1),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Stack(
                  children: [
                    _buildImageItem(context, 2),
                    if (imageUrls.length > 3)
                      _buildMoreImagesOverlay(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageItem(BuildContext context, int index) {
    return GestureDetector(
      onTap: () => _handleImageTap(context, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Hero(
          tag: heroTag != null ? '${heroTag}_$index' : 'image_$index',
          child: EnhancedMediaWidget(
            legacyUrl: imageUrls[index],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildMoreImagesOverlay(BuildContext context) {
    final remainingCount = imageUrls.length - 3;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _handleImageTap(context, 2),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '+$remainingCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenGallery(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${initialIndex + 1} of ${imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () => _shareImage(context),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              child: EnhancedMediaWidget(
                legacyUrl: imageUrls[index],
                fit: BoxFit.contain,
                placeholder: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                errorWidget: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.white, size: 48),
                      SizedBox(height: 16),
                      Text('Failed to load image', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _calculateHeight() {
    if (imageUrls.length == 1) {
      return 200;
    } else if (imageUrls.length <= 3) {
      return 150;
    } else {
      return 180;
    }
  }

  void _handleImageTap(BuildContext context, int index) {
    if (onImageTap != null) {
      onImageTap!(index);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageGalleryWidget(
            imageUrls: imageUrls,
            initialIndex: index,
            isFullScreen: true,
          ),
        ),
      );
    }
  }

  void _shareImage(BuildContext context) {
    // TODO: Implement image sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image sharing will be implemented'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

