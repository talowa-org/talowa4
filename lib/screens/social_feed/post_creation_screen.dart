// Post Creation Screen - Interface for coordinators to create new posts
// Part of Task 9: Build PostCreationScreen for coordinators

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/geographic_targeting.dart';
import '../../services/social_feed/feed_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/media/media_upload_manager.dart';
import '../../services/media/media_service.dart';
import '../../widgets/media/comprehensive_media_widget.dart';
import '../../widgets/social_feed/hashtag_text_widget.dart';
import '../../widgets/social_feed/geographic_scope_widget.dart';

/// Screen for creating new social feed posts (coordinators only)
class PostCreationScreen extends StatefulWidget {
  final PostModel? editingPost; // For editing existing posts
  final PostCategory? initialCategory;
  final GeographicTargeting? initialTargeting;
  
  const PostCreationScreen({
    Key? key,
    this.editingPost,
    this.initialCategory,
    this.initialTargeting,
  }) : super(key: key);
  
  @override
  State<PostCreationScreen> createState() => _PostCreationScreenState();
}

class _PostCreationScreenState extends State<PostCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _scrollController = ScrollController();
  
  // Post data
  PostCategory _selectedCategory = PostCategory.generalDiscussion;
  PostPriority _selectedPriority = PostPriority.normal;
  PostVisibility _selectedVisibility = PostVisibility.public;
  GeographicTargeting? _geographicTargeting;
  List<String> _hashtags = [];
  List<MediaUploadResult> _uploadedMedia = [];
  
  // UI state
  bool _isLoading = false;
  bool _isDraft = false;
  bool _showPreview = false;
  int _characterCount = 0;
  
  // Constants
  static const int maxTitleLength = 100;
  static const int maxContentLength = 2000;
  static const int maxHashtags = 10;
  static const int maxMediaFiles = 5;
  
  @override
  void initState() {
    super.initState();
    _initializeForm();
    _contentController.addListener(_updateCharacterCount);
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _initializeForm() {
    if (widget.editingPost != null) {
      // Initialize form for editing
      final post = widget.editingPost!;
      _titleController.text = post.title ?? '';
      _contentController.text = post.content;
      _selectedCategory = post.category;
      _selectedPriority = post.priority;
      _selectedVisibility = post.visibility;
      _geographicTargeting = post.geographicTargeting;
      _hashtags = List.from(post.hashtags);
      _characterCount = post.content.length;
    } else {
      // Initialize form for new post
      if (widget.initialCategory != null) {
        _selectedCategory = widget.initialCategory!;
      }
      if (widget.initialTargeting != null) {
        _geographicTargeting = widget.initialTargeting;
      }
    }
  }
  
  void _updateCharacterCount() {
    setState(() {
      _characterCount = _contentController.text.length;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _showPreview 
              ? _buildPreview()
              : _buildForm(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.editingPost != null ? 'Edit Post' : 'Create Post'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _handleBackPressed,
      ),
      actions: [
        // Draft button
        if (!_showPreview)
          TextButton(
            onPressed: _saveDraft,
            child: const Text('Draft'),
          ),
        
        // Preview toggle
        IconButton(
          icon: Icon(_showPreview ? Icons.edit : Icons.preview),
          onPressed: () {
            setState(() {
              _showPreview = !_showPreview;
            });
          },
          tooltip: _showPreview ? 'Edit' : 'Preview',
        ),
      ],
    );
  }
  
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role verification banner
            _buildRoleVerificationBanner(),
            
            const SizedBox(height: 16),
            
            // Post title (optional)
            _buildTitleField(),
            
            const SizedBox(height: 16),
            
            // Post content
            _buildContentField(),
            
            const SizedBox(height: 16),
            
            // Media attachment
            _buildMediaSection(),
            
            const SizedBox(height: 16),
            
            // Hashtags
            _buildHashtagSection(),
            
            const SizedBox(height: 16),
            
            // Category selection
            _buildCategorySection(),
            
            const SizedBox(height: 16),
            
            // Priority selection
            _buildPrioritySection(),
            
            const SizedBox(height: 16),
            
            // Geographic targeting
            _buildGeographicSection(),
            
            const SizedBox(height: 16),
            
            // Visibility settings
            _buildVisibilitySection(),
            
            const SizedBox(height: 80), // Space for bottom bar
          ],
        ),
      ),
    );
  }
  
  Widget _buildRoleVerificationBanner() {
    final currentUser = AuthService.currentUser;
    final userRole = currentUser?.role ?? 'member';
    
    if (!_isCoordinator(userRole)) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Only coordinators can create posts. Contact your local coordinator to share content.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Posting as ${_getRoleDisplayName(userRole)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Title (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Add a title to your post...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            counterText: '${_titleController.text.length}/$maxTitleLength',
          ),
          maxLength: maxTitleLength,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value != null && value.length > maxTitleLength) {
              return 'Title cannot exceed $maxTitleLength characters';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildContentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Content',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(' *', style: TextStyle(color: Colors.red)),
            const Spacer(),
            Text(
              '$_characterCount/$maxContentLength',
              style: TextStyle(
                fontSize: 12,
                color: _characterCount > maxContentLength ? Colors.red : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _contentController,
          decoration: InputDecoration(
            hintText: 'What would you like to share with the community?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 8,
          maxLength: maxContentLength,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Post content is required';
            }
            if (value.length > maxContentLength) {
              return 'Content cannot exceed $maxContentLength characters';
            }
            return null;
          },
        ),
        
        // Content formatting tips
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use #hashtags to categorize your content and @mentions to tag users',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Media Attachments',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        ComprehensiveMediaWidget(
          onMediaUploaded: (results) {
            setState(() {
              _uploadedMedia.addAll(results);
            });
          },
          userId: AuthService.currentUser?.uid ?? '',
          postId: widget.editingPost?.id ?? 'new_post_${DateTime.now().millisecondsSinceEpoch}',
          maxFiles: maxMediaFiles,
          allowImages: true,
          allowDocuments: true,
        ),
      ],
    );
  }
  
  Widget _buildHashtagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hashtags',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        HashtagInputWidget(
          onHashtagsChanged: (hashtags) {
            setState(() {
              _hashtags = hashtags;
            });
          },
          initialHashtags: _hashtags,
          suggestions: _getHashtagSuggestions(),
          maxHashtags: maxHashtags,
        ),
      ],
    );
  }
  
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: PostCategory.values.map((category) {
              return RadioListTile<PostCategory>(
                title: Text(category.displayName),
                subtitle: Text(_getCategoryDescription(category)),
                value: category,
                groupValue: _selectedCategory,
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPrioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        DropdownButtonFormField<PostPriority>(
          value: _selectedPriority,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          items: PostPriority.values.map((priority) {
            return DropdownMenuItem(
              value: priority,
              child: Row(
                children: [
                  Icon(
                    _getPriorityIcon(priority),
                    size: 16,
                    color: _getPriorityColor(priority),
                  ),
                  const SizedBox(width: 8),
                  Text(_getPriorityDisplayName(priority)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedPriority = value!;
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildGeographicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Geographic Targeting',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        GeographicTargetingSelector(
          initialTargeting: _geographicTargeting,
          onTargetingChanged: (targeting) {
            setState(() {
              _geographicTargeting = targeting;
            });
          },
          allowRadius: true,
        ),
      ],
    );
  }
  
  Widget _buildVisibilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visibility',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: PostVisibility.values.map((visibility) {
              return RadioListTile<PostVisibility>(
                title: Text(visibility.displayName),
                subtitle: Text(visibility.description),
                value: visibility,
                groupValue: _selectedVisibility,
                onChanged: (value) {
                  setState(() {
                    _selectedVisibility = value!;
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPreview() {
    final previewPost = _createPostFromForm();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Post Preview',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showPreview = false;
                    });
                  },
                  child: const Text('Edit'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Post preview
          if (previewPost != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AuthService.currentUser?.displayName ?? 'Your Name',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Just now',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Title
                    if (previewPost.title?.isNotEmpty == true) ...[
                      Text(
                        previewPost.title!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Content
                    HashtagTextWidget(
                      text: previewPost.content,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Media preview
                    if (_uploadedMedia.isNotEmpty) ...[
                      Text(
                        'Media: ${_uploadedMedia.length} file${_uploadedMedia.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Metadata
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // Category
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            previewPost.category.displayName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                        // Priority
                        if (previewPost.priority != PostPriority.normal)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(previewPost.priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getPriorityDisplayName(previewPost.priority),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getPriorityColor(previewPost.priority),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        
                        // Geographic scope
                        if (previewPost.geographicTargeting != null)
                          GeographicScopeWidget(
                            targeting: previewPost.geographicTargeting!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Character count
          if (!_showPreview)
            Text(
              '$_characterCount/$maxContentLength',
              style: TextStyle(
                fontSize: 12,
                color: _characterCount > maxContentLength ? Colors.red : Colors.grey.shade600,
              ),
            ),
          
          const Spacer(),
          
          // Cancel button
          TextButton(
            onPressed: _handleBackPressed,
            child: const Text('Cancel'),
          ),
          
          const SizedBox(width: 8),
          
          // Publish button
          ElevatedButton(
            onPressed: _canPublish() ? _publishPost : null,
            child: Text(widget.editingPost != null ? 'Update' : 'Publish'),
          ),
        ],
      ),
    );
  }
  
  // Helper methods
  
  bool _isCoordinator(String role) {
    return role.contains('coordinator') || role.contains('admin') || role.contains('founder');
  }
  
  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'founder':
        return 'Founder';
      case 'admin':
        return 'Administrator';
      case 'district_coordinator':
        return 'District Coordinator';
      case 'mandal_coordinator':
        return 'Mandal Coordinator';
      case 'village_coordinator':
        return 'Village Coordinator';
      default:
        return 'Coordinator';
    }
  }
  
  List<String> _getHashtagSuggestions() {
    return [
      'LandRights',
      'PattalandRights',
      'FarmersRights',
      'CommunitySupport',
      'LegalHelp',
      'Success',
      'Update',
      'Emergency',
      'Meeting',
      'Training',
    ];
  }
  
  String _getCategoryDescription(PostCategory category) {
    switch (category) {
      case PostCategory.successStory:
        return 'Share positive outcomes and achievements';
      case PostCategory.legalUpdate:
        return 'Important legal information and updates';
      case PostCategory.announcement:
        return 'General announcements and notices';
      case PostCategory.emergency:
        return 'Urgent matters requiring immediate attention';
      case PostCategory.generalDiscussion:
        return 'Open discussion topics';
      case PostCategory.landRights:
        return 'Land rights specific content';
      case PostCategory.communityNews:
        return 'Local community news and events';
      default:
        return '';
    }
  }
  
  IconData _getPriorityIcon(PostPriority priority) {
    switch (priority) {
      case PostPriority.low:
        return Icons.keyboard_arrow_down;
      case PostPriority.normal:
        return Icons.remove;
      case PostPriority.high:
        return Icons.keyboard_arrow_up;
      case PostPriority.urgent:
        return Icons.priority_high;
    }
  }
  
  Color _getPriorityColor(PostPriority priority) {
    switch (priority) {
      case PostPriority.low:
        return Colors.grey;
      case PostPriority.normal:
        return Colors.blue;
      case PostPriority.high:
        return Colors.orange;
      case PostPriority.urgent:
        return Colors.red;
    }
  }
  
  String _getPriorityDisplayName(PostPriority priority) {
    switch (priority) {
      case PostPriority.low:
        return 'Low Priority';
      case PostPriority.normal:
        return 'Normal';
      case PostPriority.high:
        return 'High Priority';
      case PostPriority.urgent:
        return 'Urgent';
    }
  }
  
  PostModel? _createPostFromForm() {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return null;
    
    return PostModel(
      id: widget.editingPost?.id ?? 'preview',
      authorId: currentUser.uid,
      authorName: currentUser.displayName ?? 'Unknown',
      authorRole: currentUser.role,
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      content: _contentController.text.trim(),
      category: _selectedCategory,
      priority: _selectedPriority,
      targeting: _geographicTargeting,
      hashtags: _hashtags,
      imageUrls: _uploadedMedia.where((m) => m.fileType == 'image').map((m) => m.downloadUrl).toList(),
      documentUrls: _uploadedMedia.where((m) => m.fileType == 'document').map((m) => m.downloadUrl).toList(),
      visibility: _selectedVisibility,
      createdAt: DateTime.now(),
    );
  }
  
  bool _canPublish() {
    return _contentController.text.trim().isNotEmpty &&
           _contentController.text.length <= maxContentLength &&
           !_isLoading;
  }
  
  // Event handlers
  
  void _handleBackPressed() {
    if (_hasUnsavedChanges()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text('You have unsaved changes. Are you sure you want to leave?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }
  
  bool _hasUnsavedChanges() {
    return _titleController.text.trim().isNotEmpty ||
           _contentController.text.trim().isNotEmpty ||
           _hashtags.isNotEmpty ||
           _uploadedMedia.isNotEmpty;
  }
  
  Future<void> _saveDraft() async {
    // TODO: Implement draft saving functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft saving feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  Future<void> _publishPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      _showError('Please log in to create posts');
      return;
    }
    
    if (!_isCoordinator(currentUser.role ?? '')) {
      _showError('Only coordinators can create posts');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Extract hashtags from content
      final contentHashtags = PostModel.extractHashtags(_contentController.text);
      final allHashtags = {..._hashtags, ...contentHashtags}.toList();
      
      if (widget.editingPost != null) {
        // Update existing post
        await FeedService.updatePost(
          postId: widget.editingPost!.id,
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          hashtags: allHashtags,
          targeting: _geographicTargeting,
          visibility: _selectedVisibility,
          imageUrls: _uploadedMedia.where((m) => m.fileType == 'image').map((m) => m.downloadUrl).toList(),
          documentUrls: _uploadedMedia.where((m) => m.fileType == 'document').map((m) => m.downloadUrl).toList(),
        );
        
        _showSuccess('Post updated successfully!');
      } else {
        // Create new post
        await FeedService.createPost(
          authorId: currentUser.uid,
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          hashtags: allHashtags,
          targeting: _geographicTargeting,
          visibility: _selectedVisibility,
          imageUrls: _uploadedMedia.where((m) => m.fileType == 'image').map((m) => m.downloadUrl).toList(),
          documentUrls: _uploadedMedia.where((m) => m.fileType == 'document').map((m) => m.downloadUrl).toList(),
        );
        
        _showSuccess('Post published successfully!');
      }
      
      // Navigate back to feed
      Navigator.pop(context, true);
      
    } catch (e) {
      _showError('Failed to publish post: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}