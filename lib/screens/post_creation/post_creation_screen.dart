// Post Creation Screen - Create and publish posts for coordinators
// Part of Task 9: Build PostCreationScreen for coordinators

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../services/social_feed/feed_service.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/social_feed/hashtag_text_widget.dart';
import '../../widgets/social_feed/geographic_scope_widget.dart';
import '../../widgets/media/image_gallery_widget.dart';
import '../../widgets/social_feed/document_preview_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../../services/media/media_upload_service.dart';
import '../../services/social_feed/draft_service.dart';
import '../../widgets/feed/post_widget.dart';

class PostCreationScreen extends StatefulWidget {
  final PostModel? editPost; // For editing existing posts
  
  const PostCreationScreen({
    super.key,
    this.editPost,
  });

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
  PostVisibility _selectedVisibility = PostVisibility.public;
  PostPriority _selectedPriority = PostPriority.normal;
  GeographicTargeting? _geographicTargeting;
  List<String> _hashtags = [];
  List<String> _selectedImages = [];
  List<String> _selectedDocuments = [];
  bool _isPinned = false;
  bool _allowComments = true;
  bool _allowShares = true;
  
  // UI state
  bool _isLoading = false;
  bool _showPreview = false;
  int _currentStep = 0;
  
  // Constants
  static const int maxImages = 5;
  static const int maxDocuments = 3;
  static const int maxContentLength = 2000;
  static const int maxTitleLength = 100;
  
  @override
  void initState() {
    super.initState();
    
    // If editing, populate fields
    if (widget.editPost != null) {
      _populateFieldsForEdit();
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _populateFieldsForEdit() {
    final post = widget.editPost!;
    _titleController.text = post.title ?? '';
    _contentController.text = post.content;
    _selectedCategory = post.category;
    _selectedVisibility = post.visibility;
    _selectedPriority = post.priority;
    _geographicTargeting = post.geographicTargeting;
    _hashtags = List.from(post.hashtags);
    _selectedImages = List.from(post.imageUrls);
    _selectedDocuments = List.from(post.documentUrls);
    _isPinned = post.isPinned;
    _allowComments = post.allowComments;
    _allowShares = post.allowShares;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading 
          ? const LoadingWidget(message: 'Publishing post...')
          : _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.editPost != null ? 'Edit Post' : 'Create Post'),
      backgroundColor: AppTheme.talowaGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Preview toggle
        IconButton(
          onPressed: () {
            setState(() {
              _showPreview = !_showPreview;
            });
          },
          icon: Icon(_showPreview ? Icons.edit : Icons.preview),
          tooltip: _showPreview ? 'Edit' : 'Preview',
        ),
        
        // Save draft
        IconButton(
          onPressed: _saveDraft,
          icon: const Icon(Icons.save),
          tooltip: 'Save Draft',
        ),
      ],
    );
  }
  
  Widget _buildBody() {
    if (_showPreview) {
      return _buildPreview();
    }
    
    return Form(
      key: _formKey,
      child: Stepper(
        currentStep: _currentStep,
        onStepTapped: (step) {
          setState(() {
            _currentStep = step;
          });
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              if (details.stepIndex < 2)
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.talowaGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Next'),
                ),
              
              const SizedBox(width: 8),
              
              if (details.stepIndex > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
            ],
          );
        },
        steps: [
          // Step 1: Content
          Step(
            title: const Text('Content'),
            content: _buildContentStep(),
            isActive: _currentStep == 0,
          ),
          
          // Step 2: Media & Attachments
          Step(
            title: const Text('Media'),
            content: _buildMediaStep(),
            isActive: _currentStep == 1,
          ),
          
          // Step 3: Settings & Targeting
          Step(
            title: const Text('Settings'),
            content: _buildSettingsStep(),
            isActive: _currentStep == 2,
          ),
        ],
      ),
    );
  }
  
  Widget _buildContentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title field
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Post Title (Optional)',
            hintText: 'Enter a catchy title for your post',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.title),
          ),
          maxLength: maxTitleLength,
          validator: (value) {
            if (value != null && value.length > maxTitleLength) {
              return 'Title must be less than $maxTitleLength characters';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Content field
        TextFormField(
          controller: _contentController,
          decoration: const InputDecoration(
            labelText: 'Post Content',
            hintText: 'What would you like to share with the community?',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 8,
          maxLength: maxContentLength,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Post content is required';
            }
            if (value.length > maxContentLength) {
              return 'Content must be less than $maxContentLength characters';
            }
            return null;
          },
          onChanged: (value) {
            // Extract hashtags from content
            _extractHashtags(value);
          },
        ),
        
        const SizedBox(height: 16),
        
        // Hashtags section
        if (_hashtags.isNotEmpty) ...[
          const Text(
            'Hashtags found in your post:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          HashtagChipsWidget(
            hashtags: _hashtags,
            onHashtagTapped: _removeHashtag,
          ),
          const SizedBox(height: 16),
        ],
        
        // Manual hashtag input
        HashtagInputWidget(
          initialHashtags: _hashtags,
          onHashtagsChanged: (hashtags) {
            setState(() {
              _hashtags = hashtags;
            });
          },
          suggestions: const [
            'भूमि_अधिकार',
            'सफलता_की_कहानी',
            'कानूनी_अपडेट',
            'सामुदायिक_समाचार',
            'आपातकाल',
            'सर्वेक्षण',
            'पट्टा',
            'न्याय',
          ],
        ),
      ],
    );
  }
  
  Widget _buildMediaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.image, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Images',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_selectedImages.length}/$maxImages',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Image picker buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _selectedImages.length < maxImages 
                          ? () => _pickImages(ImageSource.gallery)
                          : null,
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Gallery'),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    ElevatedButton.icon(
                      onPressed: _selectedImages.length < maxImages 
                          ? () => _pickImages(ImageSource.camera)
                          : null,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Camera'),
                    ),
                  ],
                ),
                
                // Selected images preview
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        final imagePath = _selectedImages[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? Image.network(
                                        imagePath,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 100,
                                            height: 100,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image),
                                          );
                                        },
                                      )
                                    : Image.file(
                                        File(imagePath),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              
                              // Remove button
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Documents section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_selectedDocuments.length}/$maxDocuments',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Document picker button
                ElevatedButton.icon(
                  onPressed: _selectedDocuments.length < maxDocuments 
                      ? _pickDocuments
                      : null,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Add Documents'),
                ),
                
                // Selected documents preview
                if (_selectedDocuments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DocumentUploadPreview(
                    documentPaths: _selectedDocuments,
                    onRemoveDocument: _removeDocument,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category selection
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.category, color: Colors.purple),
                    SizedBox(width: 8),
                    Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                DropdownButtonFormField<PostCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Select Category',
                  ),
                  items: PostCategory.values.map((category) {
                    final categoryInfo = _getCategoryInfo(category);
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(
                            categoryInfo['icon'],
                            size: 20,
                            color: categoryInfo['color'],
                          ),
                          const SizedBox(width: 8),
                          Text(categoryInfo['label']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Geographic targeting
        GeographicTargetingSelector(
          initialTargeting: _geographicTargeting,
          onTargetingChanged: (targeting) {
            setState(() {
              _geographicTargeting = targeting;
            });
          },
          allowRadius: true,
        ),
        
        const SizedBox(height: 16),
        
        // Post settings
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Post Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Visibility
                DropdownButtonFormField<PostVisibility>(
                  value: _selectedVisibility,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Visibility',
                  ),
                  items: PostVisibility.values.map((visibility) {
                    return DropdownMenuItem(
                      value: visibility,
                      child: Text(_getVisibilityLabel(visibility)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedVisibility = value;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Priority
                DropdownButtonFormField<PostPriority>(
                  value: _selectedPriority,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Priority',
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
                          Text(_getPriorityLabel(priority)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPriority = value;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Switches
                SwitchListTile(
                  title: const Text('Pin this post'),
                  subtitle: const Text('Keep this post at the top of the feed'),
                  value: _isPinned,
                  onChanged: (value) {
                    setState(() {
                      _isPinned = value;
                    });
                  },
                ),
                
                SwitchListTile(
                  title: const Text('Allow comments'),
                  subtitle: const Text('Users can comment on this post'),
                  value: _allowComments,
                  onChanged: (value) {
                    setState(() {
                      _allowComments = value;
                    });
                  },
                ),
                
                SwitchListTile(
                  title: const Text('Allow shares'),
                  subtitle: const Text('Users can share this post'),
                  value: _allowShares,
                  onChanged: (value) {
                    setState(() {
                      _allowShares = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPreview() {
    // Create a mock post for preview
    final previewPost = PostModel(
      id: 'preview',
      authorId: AuthService.currentUser?.uid ?? 'current_user',
      authorName: AuthService.currentUser?.displayName ?? 'Current User',
      authorRole: 'coordinator', // Mock role
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      content: _contentController.text.trim(),
      imageUrls: _selectedImages,
      documentUrls: _selectedDocuments,
      hashtags: _hashtags,
      category: _selectedCategory,
      visibility: _selectedVisibility,
      priority: _selectedPriority,
      targeting: _geographicTargeting,
      createdAt: DateTime.now(),
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      isLikedByCurrentUser: false,
      recentComments: [],
      isPinned: _isPinned,
      allowComments: _allowComments,
      allowShares: _allowShares,
      isReported: false,
      isHidden: false,
    );
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Post Preview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Preview of the post
          PostWidget(
            post: previewPost,
            onLike: () {},
            onComment: () {},
            onShare: () {},
            onUserTap: () {},
            onPostTap: () {},
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
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Character count
          Expanded(
            child: Text(
              '${_contentController.text.length}/$maxContentLength characters',
              style: TextStyle(
                fontSize: 12,
                color: _contentController.text.length > maxContentLength * 0.9
                    ? Colors.red
                    : Colors.grey.shade600,
              ),
            ),
          ),
          
          // Action buttons
          TextButton(
            onPressed: _saveDraft,
            child: const Text('Save Draft'),
          ),
          
          const SizedBox(width: 8),
          
          ElevatedButton(
            onPressed: _canPublish() ? _publishPost : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(widget.editPost != null ? 'Update Post' : 'Publish Post'),
          ),
        ],
      ),
    );
  }  
  
// Event handlers and helper methods
  
  void _extractHashtags(String text) {
    final RegExp hashtagRegex = RegExp(r'#\w+');
    final matches = hashtagRegex.allMatches(text);
    final extractedHashtags = matches
        .map((match) => match.group(0)!.substring(1)) // Remove # symbol
        .toSet()
        .toList();
    
    setState(() {
      // Merge with existing hashtags
      _hashtags = {..._hashtags, ...extractedHashtags}.toList();
    });
  }
  
  void _removeHashtag(String hashtag) {
    setState(() {
      _hashtags.remove(hashtag);
    });
  }
  
  Future<void> _pickImages(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await ImagePicker().pickMultipleMedia(
          limit: maxImages - _selectedImages.length,
        );
        
        setState(() {
          _selectedImages.addAll(images.map((image) => image.path));
        });
      } else {
        final XFile? image = await ImagePicker().pickImage(source: source);
        if (image != null) {
          setState(() {
            _selectedImages.add(image.path);
          });
        }
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }
  
  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'rtf'],
        allowMultiple: true,
      );
      
      if (result != null) {
        final availableSlots = maxDocuments - _selectedDocuments.length;
        final filesToAdd = result.files.take(availableSlots);
        
        setState(() {
          _selectedDocuments.addAll(
            filesToAdd.map((file) => file.path!),
          );
        });
        
        if (result.files.length > availableSlots) {
          _showInfo('Only $availableSlots documents could be added due to limit');
        }
      }
    } catch (e) {
      _showError('Failed to pick documents: $e');
    }
  }
  
  void _removeDocument(String documentPath) {
    setState(() {
      _selectedDocuments.remove(documentPath);
    });
  }
  
  bool _canPublish() {
    return _contentController.text.trim().isNotEmpty &&
           _contentController.text.length <= maxContentLength &&
           !_isLoading;
  }
  
  Future<void> _saveDraft() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showError('Please log in to save drafts');
        return;
      }
      
      if (_contentController.text.trim().isEmpty) {
        _showError('Cannot save empty draft');
        return;
      }
      
      await DraftService.saveDraft(
        authorId: currentUser.uid,
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        content: _contentController.text.trim(),
        imageUrls: _selectedImages,
        documentUrls: _selectedDocuments,
        hashtags: _hashtags,
        category: _selectedCategory,
        priority: _selectedPriority,
        targeting: _geographicTargeting,
        visibility: _selectedVisibility,
        isPinned: _isPinned,
        allowComments: _allowComments,
        allowShares: _allowShares,
      );
      
      _showSuccess('Draft saved successfully!');
    } catch (e) {
      _showError('Failed to save draft: $e');
    }
  }
  
  Future<void> _publishPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (!_canPublish()) {
      _showError('Please check your post content');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Upload images first
      List<String> uploadedImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        try {
          uploadedImageUrls = await MediaUploadService.uploadImages(
            imagePaths: _selectedImages,
            userId: currentUser.uid,
            folder: 'posts',
          );
        } catch (e) {
          throw Exception('Failed to upload images: $e');
        }
      }
      
      // Upload documents
      List<String> uploadedDocumentUrls = [];
      if (_selectedDocuments.isNotEmpty) {
        try {
          uploadedDocumentUrls = await MediaUploadService.uploadDocuments(
            documentPaths: _selectedDocuments,
            userId: currentUser.uid,
            folder: 'posts',
          );
        } catch (e) {
          throw Exception('Failed to upload documents: $e');
        }
      }
      
      if (widget.editPost != null) {
        // Update existing post
        await FeedService.updatePost(
          postId: widget.editPost!.id,
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrls: uploadedImageUrls,
          documentUrls: uploadedDocumentUrls,
          hashtags: _hashtags,
          category: _selectedCategory,
          visibility: _selectedVisibility,
          priority: _selectedPriority,
          targeting: _geographicTargeting,
          isPinned: _isPinned,
          allowComments: _allowComments,
          allowShares: _allowShares,
        );
        
        _showSuccess('Post updated successfully!');
      } else {
        // Create new post
        await FeedService.createPost(
          authorId: currentUser.uid,
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrls: uploadedImageUrls,
          documentUrls: uploadedDocumentUrls,
          hashtags: _hashtags,
          category: _selectedCategory,
          visibility: _selectedVisibility,
          priority: _selectedPriority,
          targeting: _geographicTargeting,
          isPinned: _isPinned,
          allowComments: _allowComments,
          allowShares: _allowShares,
        );
        
        _showSuccess('Post published successfully!');
      }
      
      // Return to previous screen
      Navigator.pop(context, true);
      
    } catch (e) {
      _showError('Failed to publish post: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Helper methods for UI data
  
  Map<String, dynamic> _getCategoryInfo(PostCategory category) {
    switch (category) {
      case PostCategory.successStory:
        return {
          'label': 'Success Story',
          'icon': Icons.celebration,
          'color': Colors.green,
        };
      case PostCategory.legalUpdate:
        return {
          'label': 'Legal Update',
          'icon': Icons.gavel,
          'color': Colors.blue,
        };
      case PostCategory.announcement:
        return {
          'label': 'Announcement',
          'icon': Icons.campaign,
          'color': Colors.orange,
        };
      case PostCategory.emergency:
        return {
          'label': 'Emergency',
          'icon': Icons.warning,
          'color': Colors.red,
        };
      case PostCategory.generalDiscussion:
        return {
          'label': 'General Discussion',
          'icon': Icons.forum,
          'color': Colors.purple,
        };
      case PostCategory.landRights:
        return {
          'label': 'Land Rights',
          'icon': Icons.landscape,
          'color': Colors.brown,
        };
      case PostCategory.communityNews:
        return {
          'label': 'Community News',
          'icon': Icons.newspaper,
          'color': Colors.teal,
        };
      case PostCategory.education:
        return {
          'label': 'Education',
          'icon': Icons.school,
          'color': Colors.indigo,
        };
      case PostCategory.healthAndSafety:
        return {
          'label': 'Health & Safety',
          'icon': Icons.health_and_safety,
          'color': Colors.pink,
        };
      case PostCategory.agriculture:
        return {
          'label': 'Agriculture',
          'icon': Icons.agriculture,
          'color': Colors.lightGreen,
        };
    }
  }
  
  String _getVisibilityLabel(PostVisibility visibility) {
    switch (visibility) {
      case PostVisibility.public:
        return 'Public - Everyone can see';
      case PostVisibility.coordinatorsOnly:
        return 'Coordinators Only';
      case PostVisibility.localCommunity:
        return 'Local Community';
      case PostVisibility.directNetwork:
        return 'Direct Network';
    }
  }
  
  String _getPriorityLabel(PostPriority priority) {
    switch (priority) {
      case PostPriority.low:
        return 'Low Priority';
      case PostPriority.normal:
        return 'Normal Priority';
      case PostPriority.high:
        return 'High Priority';
      case PostPriority.urgent:
        return 'Urgent';
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
  
  // Utility methods
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  void _showInfo(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }
}