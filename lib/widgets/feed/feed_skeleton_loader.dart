// Feed Skeleton Loader Widget for TALOWA
// Loading placeholder that mimics the Instagram feed structure
import 'package:flutter/material.dart';

class FeedSkeletonLoader extends StatefulWidget {
  final int itemCount;

  const FeedSkeletonLoader({
    super.key,
    this.itemCount = 3,
  });

  @override
  State<FeedSkeletonLoader> createState() => _FeedSkeletonLoaderState();
}

class _FeedSkeletonLoaderState extends State<FeedSkeletonLoader>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.itemCount,
      itemBuilder: (context, index) => _buildSkeletonItem(),
    );
  }

  Widget _buildSkeletonItem() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonHeader(),
              _buildSkeletonMedia(),
              _buildSkeletonActions(),
              _buildSkeletonText(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSkeletonCircle(32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(120, 14),
                const SizedBox(height: 4),
                _buildSkeletonBox(80, 12),
              ],
            ),
          ),
          _buildSkeletonBox(20, 20),
        ],
      ),
    );
  }

  Widget _buildSkeletonMedia() {
    return _buildSkeletonBox(double.infinity, 400);
  }

  Widget _buildSkeletonActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSkeletonBox(24, 24),
          const SizedBox(width: 16),
          _buildSkeletonBox(24, 24),
          const SizedBox(width: 16),
          _buildSkeletonBox(24, 24),
          const Spacer(),
          _buildSkeletonBox(24, 24),
        ],
      ),
    );
  }

  Widget _buildSkeletonText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonBox(100, 14),
          const SizedBox(height: 8),
          _buildSkeletonBox(double.infinity, 14),
          const SizedBox(height: 4),
          _buildSkeletonBox(200, 14),
          const SizedBox(height: 8),
          _buildSkeletonBox(150, 12),
          const SizedBox(height: 4),
          _buildSkeletonBox(80, 12),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300]!.withValues(alpha: _animation.value),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildSkeletonCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300]!.withValues(alpha: _animation.value),
        shape: BoxShape.circle,
      ),
    );
  }
}