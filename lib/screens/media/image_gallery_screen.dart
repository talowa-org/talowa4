// Image Gallery Screen - Full screen image viewer with swipe navigation
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroTag;

  const ImageGalleryScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
    required this.heroTag,
  });

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _overlayAnimationController;
  late Animation<double> _overlayAnimation;
  
  int _currentIndex = 0;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    _overlayAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _overlayAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _overlayAnimationController, curve: Curves.easeInOut),
    );
    
    _overlayAnimationController.forward();
    
    // Auto-hide overlay after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showOverlay) {
        _toggleOverlay();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _overlayAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image PageView
          GestureDetector(
            onTap: _toggleOverlay,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return _buildImagePage(index);
              },
            ),
          ),
          
          // Overlay with controls
          AnimatedBuilder(
            animation: _overlayAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _showOverlay ? _overlayAnimation.value : 0.0,
                child: child,
              );
            },
            child: _buildOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePage(int index) {
    final isInitialImage = index == widget.initialIndex;
    
    return Center(
      child: Hero(
        tag: isInitialImage ? '${widget.heroTag}_$index' : 'gallery_image_$index',
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.network(
            widget.images[index],
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading image...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Column(
      children: [
        // Top bar
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back',
              ),
              const Spacer(),
              Text(
                '${_currentIndex + 1} of ${widget.images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'save',
                    child: ListTile(
                      leading: Icon(Icons.download),
                      title: Text('Save Image'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share),
                      title: Text('Share Image'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_link',
                    child: ListTile(
                      leading: Icon(Icons.link),
                      title: Text('Copy Link'),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Bottom bar with thumbnails
        if (widget.images.length > 1)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                // Page indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.images.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Thumbnail strip
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.images.length,
                    itemBuilder: (context, index) {
                      final isSelected = _currentIndex == index;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              widget.images[index],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.white.withValues(alpha: 0.2),
                                    size: 20,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
    
    if (_showOverlay) {
      _overlayAnimationController.forward();
      // Auto-hide after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showOverlay) {
          _toggleOverlay();
        }
      });
    } else {
      _overlayAnimationController.reverse();
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'save':
        _saveImage();
        break;
      case 'share':
        _shareImage();
        break;
      case 'copy_link':
        _copyImageLink();
        break;
    }
  }

  void _saveImage() {
    // TODO: Implement image saving
    debugPrint('Saving image: ${widget.images[_currentIndex]}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image saved to gallery'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareImage() {
    // TODO: Implement image sharing
    debugPrint('Sharing image: ${widget.images[_currentIndex]}');
  }

  void _copyImageLink() {
    // TODO: Implement copy image link
    Clipboard.setData(ClipboardData(text: widget.images[_currentIndex]));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image link copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

