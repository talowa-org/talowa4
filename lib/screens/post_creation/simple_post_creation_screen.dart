// Enhanced Post Creation Screen for TALOWA
// Full-featured post creation with media upload and stories
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/post_model.dart';
import '../../services/social_feed/feed_service.dart';
import '../../services/auth_service.dart';
import '../../services/media/media_upload_service.dart';
import '../../services/media/mock_media_upload_service.dart';

class SimplePostCreationScreen extends StatefulWidget {
  const SimplePostCreationScreen({super.key});

  @override
  State<SimplePostCreationScreen> createState() => _SimplePostCreationScreenState();
}

class _SimplePostCreationScreenState extends State<SimplePostCreationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  
  PostCategory _selectedCategory = PostCategory.generalDiscussion;
  bool _isSubmitting = false;
  bool _isUploadingMedia = false;
  List<String> _hashtags = [];
  
  // Media handling
  List<String> _selectedImages = [];
  List<String> _selectedVideos = [];
  List<String> _selectedDocuments = [];
  final ImagePicker _imagePicker = ImagePicker();
  
  // Post type selection
  String _postType = 'regular'; // 'regular' or 'story'
  
  // Constants
  static const int maxImages = 5;
  static const int maxVideos = 2;
  static const int maxDocuments = 3;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_extractHashtags);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _extractHashtags() {
    final text = _contentController.text;
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(text);
    final hashtags = matches.map((match) => match.group(1)!).toSet().toList();
    
    if (hashtags.toString() != _hashtags.toString()) {
      setState(() {
        _hashtags = hashtags;
      });
    }
  }

  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty || _isSubmitting) return;

    // Check if user is authenticated
    if (AuthService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to create a post'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload media files first
      List<String> uploadedImageUrls = [];
      List<String> uploadedVideoUrls = [];
      List<String> uploadedDocumentUrls = [];

      if (_selectedImages.isNotEmpty || _selectedVideos.isNotEmpty || _selectedDocuments.isNotEmpty) {
        setState(() {
          _isUploadingMedia = true;
        });

        // Upload images (use mock service for web)
        if (_selectedImages.isNotEmpty) {
          if (kIsWeb) {
            uploadedImageUrls = await MockMediaUploadService.uploadImages(
              imagePaths: _selectedImages,
              userId: AuthService.currentUser!.uid,
              folder: 'feed_posts',
            );
          } else {
            uploadedImageUrls = await MediaUploadService.uploadImages(
              imagePaths: _selectedImages,
              userId: AuthService.currentUser!.uid,
              folder: 'feed_posts',
            );
          }
        }

        // Upload videos (use mock service for web)
        if (_selectedVideos.isNotEmpty) {
          if (kIsWeb) {
            uploadedVideoUrls = await MockMediaUploadService.uploadImages(
              imagePaths: _selectedVideos,
              userId: AuthService.currentUser!.uid,
              folder: 'feed_videos',
            );
          } else {
            uploadedVideoUrls = await MediaUploadService.uploadImages(
              imagePaths: _selectedVideos,
              userId: AuthService.currentUser!.uid,
              folder: 'feed_videos',
            );
          }
        }

        // Upload documents (use mock service for web)
        if (_selectedDocuments.isNotEmpty) {
          if (kIsWeb) {
            uploadedDocumentUrls = await MockMediaUploadService.uploadDocuments(
              documentPaths: _selectedDocuments,
              userId: AuthService.currentUser!.uid,
              folder: 'feed_documents',
            );
          } else {
            uploadedDocumentUrls = await MediaUploadService.uploadDocuments(
              documentPaths: _selectedDocuments,
              userId: AuthService.currentUser!.uid,
              folder: 'feed_documents',
            );
          }
        }

        setState(() {
          _isUploadingMedia = false;
        });
      }

      // Create the post with media URLs
      await FeedService().createPost(
        title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
        content: _contentController.text.trim(),
        hashtags: _hashtags,
        category: _selectedCategory,
        mediaUrls: [...uploadedImageUrls, ...uploadedVideoUrls, ...uploadedDocumentUrls],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return true to indicate successful post creation
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create post: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingMedia = false;
        });
      }
    }
  }

  // Media selection methods
  Future<void> _pickImages() async {
    try {
      if (kIsWeb) {
        // For web, use single image picker multiple times
        final List<XFile> images = [];
        final remainingSlots = maxImages - _selectedImages.length;
        
        for (int i = 0; i < remainingSlots; i++) {
          final XFile? image = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
          );
          if (image != null) {
            images.add(image);
          } else {
            break; // User cancelled
          }
        }
        
        if (images.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(images.map((image) => image.path));
          });
        }
      } else {
        final List<XFile> images = await _imagePicker.pickMultipleMedia(
          limit: maxImages - _selectedImages.length,
        );
        
        if (images.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(images.map((image) => image.path));
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImages.add(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      
      if (video != null) {
        setState(() {
          _selectedVideos.add(video.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
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
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick documents: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  void _removeDocument(int index) {
    setState(() {
      _selectedDocuments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_postType == 'story' ? 'Create Story' : 'Create Post'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Post type toggle
          IconButton(
            onPressed: () {
              setState(() {
                _postType = _postType == 'regular' ? 'story' : 'regular';
              });
            },
            icon: Icon(_postType == 'story' ? Icons.article : Icons.auto_stories),
            tooltip: _postType == 'story' ? 'Switch to Post' : 'Switch to Story',
          ),
          TextButton(
            onPressed: _isSubmitting || _isUploadingMedia ? null : _submitPost,
            child: _isSubmitting || _isUploadingMedia
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _postType == 'story' ? 'Share Story' : 'Post',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category selection
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PostCategory>(
                        value: _selectedCategory,
                        isExpanded: true,
                        onChanged: (PostCategory? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          }
                        },
                        items: PostCategory.values.map((PostCategory category) {
                          return DropdownMenuItem<PostCategory>(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  size: 20,
                                  color: _getCategoryColor(category),
                                ),
                                const SizedBox(width: 8),
                                Text(category.displayName),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Title field (optional)
                  const Text(
                    'Title (Optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Enter a title for your post...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.talowaGreen),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 100,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Content field
                  const Text(
                    'Content',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind? Use #hashtags to categorize your post...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.talowaGreen),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    maxLines: 8,
                    minLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 1000,
                  ),
                  
                  // Hashtags preview
                  if (_hashtags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Hashtags',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _hashtags.map((hashtag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.talowaGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.talowaGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '#$hashtag',
                          style: TextStyle(
                            color: AppTheme.talowaGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Media upload section
                  if (_postType == 'regular') ...[
                    const Text(
                      'Add Media',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Media buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedImages.length < maxImages ? _pickImages : null,
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: Text('Photos (${_selectedImages.length}/$maxImages)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.talowaGreen.withOpacity(0.1),
                              foregroundColor: AppTheme.talowaGreen,
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedImages.length < maxImages ? _pickCamera : null,
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Camera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.talowaGreen.withOpacity(0.1),
                              foregroundColor: AppTheme.talowaGreen,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedVideos.length < maxVideos ? _pickVideo : null,
                            icon: const Icon(Icons.videocam, size: 18),
                            label: Text('Video (${_selectedVideos.length}/$maxVideos)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              foregroundColor: Colors.blue,
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedDocuments.length < maxDocuments ? _pickDocuments : null,
                            icon: const Icon(Icons.attach_file, size: 18),
                            label: Text('Docs (${_selectedDocuments.length}/$maxDocuments)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.withOpacity(0.1),
                              foregroundColor: Colors.orange,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Media preview
                    if (_selectedImages.isNotEmpty || _selectedVideos.isNotEmpty || _selectedDocuments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMediaPreview(),
                    ],
                    
                    const SizedBox(height: 20),
                  ],
                  
                  // Story-specific media (single image/video)
                  if (_postType == 'story') ...[
                    const Text(
                      'Story Media (Required)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedImages.isEmpty ? _pickCamera : null,
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Take Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.talowaGreen.withOpacity(0.1),
                              foregroundColor: AppTheme.talowaGreen,
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedVideos.isEmpty ? _pickVideo : null,
                            icon: const Icon(Icons.videocam, size: 18),
                            label: const Text('Record Video'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              foregroundColor: Colors.blue,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    if (_selectedImages.isNotEmpty || _selectedVideos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildStoryPreview(),
                    ],
                    
                    const SizedBox(height: 20),
                  ],
                  
                  // Upload progress
                  if (_isUploadingMedia) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          const Text('Uploading media files...'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Tips card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.blue[600], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Tips for better posts',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Use #hashtags to help others find your post\n'
                          '• Choose the right category for better visibility\n'
                          '• Add photos/videos to make your post more engaging\n'
                          '• Share success stories to inspire others\n'
                          '• Stories disappear after 24 hours',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom action bar
          Container(
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
                Expanded(
                  child: Text(
                    '${_contentController.text.length}/1000 characters',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                
                // Post button
                ElevatedButton(
                  onPressed: _canSubmit() ? _submitPost : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.talowaGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isSubmitting || _isUploadingMedia
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _postType == 'story' ? 'Share Story' : 'Post',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(PostCategory category) {
    switch (category) {
      case PostCategory.announcement:
        return Icons.campaign;
      case PostCategory.successStory:
        return Icons.celebration;
      case PostCategory.legalUpdate:
        return Icons.gavel;
      case PostCategory.emergency:
        return Icons.warning;
      case PostCategory.communityNews:
        return Icons.people;
      case PostCategory.landRights:
        return Icons.landscape;
      case PostCategory.agriculture:
        return Icons.agriculture;
      case PostCategory.governmentSchemes:
        return Icons.account_balance;
      case PostCategory.education:
        return Icons.school;
      case PostCategory.health:
        return Icons.health_and_safety;
      default:
        return Icons.chat;
    }
  }

  Color _getCategoryColor(PostCategory category) {
    switch (category) {
      case PostCategory.announcement:
        return Colors.blue;
      case PostCategory.successStory:
        return Colors.green;
      case PostCategory.legalUpdate:
        return Colors.purple;
      case PostCategory.emergency:
        return Colors.red;
      case PostCategory.communityNews:
        return Colors.orange;
      case PostCategory.landRights:
        return Colors.brown;
      case PostCategory.agriculture:
        return Colors.green[700]!;
      case PostCategory.governmentSchemes:
        return Colors.indigo;
      case PostCategory.education:
        return Colors.teal;
      case PostCategory.health:
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  bool _canSubmit() {
    if (_isSubmitting || _isUploadingMedia) return false;
    
    if (_postType == 'story') {
      // Stories require media and optional text
      return _selectedImages.isNotEmpty || _selectedVideos.isNotEmpty;
    } else {
      // Regular posts require text content
      return _contentController.text.trim().isNotEmpty;
    }
  }

  Widget _buildImageWidget(String imagePath, {double? width, double? height, BoxFit? fit}) {
    if (kIsWeb) {
      // For web, use Image.network with the blob URL
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, color: Colors.grey[600], size: width != null ? width * 0.3 : 24),
                if (height != null && height > 50) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Image Preview',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          );
        },
      );
    } else {
      // For mobile, use Image.file
      return Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
      );
    }
  }

  Widget _buildMediaPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Media',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          
          // Images preview
          if (_selectedImages.isNotEmpty) ...[
            const Text('Images:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImageWidget(
                            _selectedImages[index],
                            width: 80,
                            height: 80,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 12,
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
            const SizedBox(height: 8),
          ],
          
          // Videos preview
          if (_selectedVideos.isNotEmpty) ...[
            const Text('Videos:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            ...List.generate(_selectedVideos.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Video ${index + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeVideo(index),
                      child: const Icon(Icons.close, color: Colors.red, size: 16),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          
          // Documents preview
          if (_selectedDocuments.isNotEmpty) ...[
            const Text('Documents:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            ...List.generate(_selectedDocuments.length, (index) {
              final fileName = _selectedDocuments[index].split('/').last;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeDocument(index),
                      child: const Icon(Icons.close, color: Colors.red, size: 16),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStoryPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Story Preview',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          
          if (_selectedImages.isNotEmpty) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImageWidget(
                    _selectedImages.first,
                    width: double.infinity,
                    height: 200,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeImage(0),
                    child: Container(
                      width: 30,
                      height: 30,
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
          ] else if (_selectedVideos.isNotEmpty) ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam, size: 48, color: Colors.blue),
                        SizedBox(height: 8),
                        Text('Video Story', style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeVideo(0),
                      child: Container(
                        width: 30,
                        height: 30,
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
            ),
          ],
          
          if (_contentController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _contentController.text.trim(),
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}