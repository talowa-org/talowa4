// Post Creation FAB - Floating Action Button for creating posts
// Part of Task 9: Build PostCreationScreen for coordinators

import 'package:flutter/material.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/geographic_targeting.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/navigation_helper.dart';

/// Floating Action Button for post creation (coordinators only)
class PostCreationFAB extends StatelessWidget {
  final PostCategory? initialCategory;
  final GeographicTargeting? initialTargeting;
  final Function(PostModel)? onPostCreated;
  final bool showQuickActions;
  
  const PostCreationFAB({
    super.key,
    this.initialCategory,
    this.initialTargeting,
    this.onPostCreated,
    this.showQuickActions = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final userRole = currentUser?.role ?? 'member';
    
    // Only show FAB for coordinators
    if (!_isCoordinator(userRole)) {
      return const SizedBox.shrink();
    }
    
    if (showQuickActions) {
      return _buildExpandableFAB(context);
    } else {
      return _buildSimpleFAB(context);
    }
  }
  
  Widget _buildSimpleFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _createPost(context),
      tooltip: 'Create Post',
      child: const Icon(Icons.add),
    );
  }
  
  Widget _buildExpandableFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showQuickActions(context),
      tooltip: 'Create Content',
      child: const Icon(Icons.add),
    );
  }
  
  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Create Content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Quick action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildQuickActionTile(
                    context,
                    icon: Icons.announcement,
                    title: 'Announcement',
                    subtitle: 'Share important news and updates',
                    color: Colors.orange,
                    category: PostCategory.announcement,
                  ),
                  
                  _buildQuickActionTile(
                    context,
                    icon: Icons.celebration,
                    title: 'Success Story',
                    subtitle: 'Share positive outcomes and achievements',
                    color: Colors.green,
                    category: PostCategory.successStory,
                  ),
                  
                  _buildQuickActionTile(
                    context,
                    icon: Icons.gavel,
                    title: 'Legal Update',
                    subtitle: 'Important legal information',
                    color: Colors.blue,
                    category: PostCategory.legalUpdate,
                  ),
                  
                  _buildQuickActionTile(
                    context,
                    icon: Icons.warning,
                    title: 'Emergency',
                    subtitle: 'Urgent matters requiring attention',
                    color: Colors.red,
                    category: PostCategory.emergency,
                  ),
                  
                  _buildQuickActionTile(
                    context,
                    icon: Icons.forum,
                    title: 'General Post',
                    subtitle: 'Open discussion and general content',
                    color: Colors.purple,
                    category: PostCategory.generalDiscussion,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required PostCategory category,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _createPost(context, category: category);
      },
    );
  }
  
  Future<void> _createPost(
    BuildContext context, {
    PostCategory? category,
  }) async {
    final result = await context.navigateToPostCreation(
      initialCategory: category ?? initialCategory,
      initialTargeting: initialTargeting,
    );
    
    if (result == true && onPostCreated != null) {
      // Post was created successfully
      // In a real implementation, you might want to pass the created post
      // For now, we'll just notify that a post was created
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  bool _isCoordinator(String role) {
    return role.contains('coordinator') || 
           role.contains('admin') || 
           role.contains('founder');
  }
}

/// Speed dial FAB for multiple post types
class PostCreationSpeedDial extends StatefulWidget {
  final PostCategory? initialCategory;
  final GeographicTargeting? initialTargeting;
  final Function(PostModel)? onPostCreated;
  
  const PostCreationSpeedDial({
    super.key,
    this.initialCategory,
    this.initialTargeting,
    this.onPostCreated,
  });
  
  @override
  State<PostCreationSpeedDial> createState() => _PostCreationSpeedDialState();
}

class _PostCreationSpeedDialState extends State<PostCreationSpeedDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isOpen = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final userRole = currentUser?.role ?? 'member';
    
    // Only show for coordinators
    if (!_isCoordinator(userRole)) {
      return const SizedBox.shrink();
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed dial options
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation.value,
              child: Opacity(
                opacity: _animation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isOpen) ...[
                      _buildSpeedDialOption(
                        context,
                        icon: Icons.warning,
                        label: 'Emergency',
                        color: Colors.red,
                        category: PostCategory.emergency,
                      ),
                      const SizedBox(height: 8),
                      _buildSpeedDialOption(
                        context,
                        icon: Icons.announcement,
                        label: 'Announcement',
                        color: Colors.orange,
                        category: PostCategory.announcement,
                      ),
                      const SizedBox(height: 8),
                      _buildSpeedDialOption(
                        context,
                        icon: Icons.celebration,
                        label: 'Success',
                        color: Colors.green,
                        category: PostCategory.successStory,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleSpeedDial,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0, // 45 degree rotation
            duration: const Duration(milliseconds: 300),
            child: Icon(_isOpen ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSpeedDialOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required PostCategory category,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Mini FAB
        FloatingActionButton.small(
          onPressed: () => _createPost(context, category: category),
          backgroundColor: color,
          heroTag: 'speed_dial_$label',
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }
  
  void _toggleSpeedDial() {
    setState(() {
      _isOpen = !_isOpen;
    });
    
    if (_isOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }
  
  Future<void> _createPost(
    BuildContext context, {
    required PostCategory category,
  }) async {
    // Close speed dial
    _toggleSpeedDial();
    
    final result = await context.navigateToPostCreation(
      initialCategory: category,
      initialTargeting: widget.initialTargeting,
    );
    
    if (result == true && widget.onPostCreated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  bool _isCoordinator(String role) {
    return role.contains('coordinator') || 
           role.contains('admin') || 
           role.contains('founder');
  }
}