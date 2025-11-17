// Enhanced Post Creation Screen with Image + Video Support
// Instagram-style post creation with full media capabilities
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../services/media/image_picker_service.dart';
import '../../services/media/video_picker_service.dart';
import '../../services/media/firebase_uploader_service.dart';
import '../../services/auth/auth_service.dart';

enum MediaType { image, video }

class MediaItem {
  final Uint8List bytes;
  final String fileName;
  final MediaType type;

  MediaItem({
    required this.bytes,
    required this.fileName,
    required this.type,
  });
}

class EnhancedPostCreationScreen extends StatefulWidget {
  const EnhancedPostCreationScreen({super.key});

  @override
  State<EnhancedPostCreationScreen> createState() => _EnhancedPostCreationScreenState();
}

class _EnhancedPostCreationScreenState extends State<EnhancedPostCreationScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePickerService _imagePickerService = ImagePickerService();
  final VideoPickerService _videoPickerService = VideoPickerService();
  final FirebaseUploaderService _uploaderService = FirebaseUploaderService();

  final List<MediaItem> _selectedMedia = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _allowComments = true;
  bool _allowSharing = true;

  static const int _maxMediaCount = 10;
  static const int _maxCaptionLength = 2200;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: _handleBack,
        icon: const Icon(Icons.close, color: Colors.black),
      ),
      title: const Text(
        'Create Post',
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          TextButton(
            onPressed: _canPost() ? _createPost : null,
            child: Text(
              'Post',
              style: TextStyle(
                color: _canPost() ? AppTheme.talowaGreen : Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isUploading) _buildUploadProgress(),
          _buildMediaSection(),
          const SizedBox(height: 16),
          _buildCaptionSection(),
          const SizedBox(height: 24),
          _buildOptionsSection(),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.talowaGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_upload, color: AppTheme.talowaGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Uploading... ${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.talowaGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Media',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_selectedMedia.length < _maxMediaCount)
              Row(
                children: [
                  IconButton(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library),
                    tooltip: 'Add Photos',
                  ),
                  IconButton(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.videocam),
                    tooltip: 'Add Video',
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_selectedMedia.isEmpty)
          _buildEmptyMediaState()
        else
          _buildMediaGrid(),
      ],
    );
  }

  Widget _buildEmptyMediaState() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMediaTypeButton(
                icon: Icons.photo_library,
                label: 'Photos',
                onTap: _pickImages,
              ),
              const SizedBox(width: 24),
              _buildMediaTypeButton(
                icon: Icons.videocam,
                label: 'Video',
                onTap: _pickVideo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Add photos or videos to your post',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTypeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.talowaGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppTheme.talowaGreen),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _selectedMedia.length,
      itemBuilder: (context, index) {
        final media = _selectedMedia[index];
        return _buildMediaItem(media, index);
      },
    );
  }

  Widget _buildMediaItem(MediaItem media, int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: media.type == MediaType.image
                ? Image.memory(
                    media.bytes,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
          ),
        ),
        // Media type badge
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  media.type == MediaType.image ? Icons.photo : Icons.videocam,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  media.type == MediaType.image ? 'Photo' : 'Video',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeMedia(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
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
    );
  }

  Widget _buildCaptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caption',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _captionController,
          maxLines: null,
          maxLength: _maxCaptionLength,
          decoration: InputDecoration(
            hintText: 'Write a caption...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.talowaGreen),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          'Use #hashtags to reach more people',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Post Options',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        _buildSwitchTile(
          icon: Icons.comment_outlined,
          title: 'Allow Comments',
          subtitle: 'People can comment on your post',
          value: _allowComments,
          onChanged: (value) => setState(() => _allowComments = value),
        ),

        _buildSwitchTile(
          icon: Icons.share_outlined,
          title: 'Allow Sharing',
          subtitle: 'People can share your post',
          value: _allowSharing,
          onChanged: (value) => setState(() => _allowSharing = value),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppTheme.talowaGreen,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  // Event handlers
  void _handleBack() {
    if (_captionController.text.isNotEmpty || _selectedMedia.isNotEmpty) {
      _showDiscardDialog();
    } else {
      Navigator.pop(context);
    }
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard post?'),
        content: const Text('If you go back now, you\'ll lose your post.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePickerService.pickMultipleImages(
        maxImages: _maxMediaCount - _selectedMedia.length,
      );

      if (images.isNotEmpty) {
        setState(() {
          for (final image in images) {
            _selectedMedia.add(MediaItem(
              bytes: image.bytes,
              fileName: image.fileName,
              type: MediaType.image,
            ));
          }
        });
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _videoPickerService.pickVideo(
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        setState(() {
          _selectedMedia.add(MediaItem(
            bytes: video.bytes,
            fileName: video.fileName,
            type: MediaType.video,
          ));
        });
      }
    } catch (e) {
      _showError('Failed to pick video: $e');
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  bool _canPost() {
    return !_isUploading && 
           (_captionController.text.trim().isNotEmpty || _selectedMedia.isNotEmpty);
  }

  Future<void> _createPost() async {
    if (!_canPost()) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Upload media files and create mediaItems array
      final mediaItems = <Map<String, dynamic>>[];
      
      int uploadedCount = 0;
      final totalMedia = _selectedMedia.length;

      for (int i = 0; i < _selectedMedia.length; i++) {
        final media = _selectedMedia[i];
        String? url;
        
        if (media.type == MediaType.image) {
          url = await _uploaderService.uploadImage(
            bytes: media.bytes,
            fileName: media.fileName,
            userId: currentUser.uid,
          );
        } else {
          url = await _uploaderService.uploadVideo(
            bytes: media.bytes,
            fileName: media.fileName,
            userId: currentUser.uid,
            onProgress: (progress) {
              setState(() {
                _uploadProgress = (uploadedCount + progress) / totalMedia;
              });
            },
          );
        }
        
        if (url != null) {
          mediaItems.add({
            'id': 'media_$i',
            'type': media.type == MediaType.image ? 'image' : 'video',
            'url': url,
            'aspectRatio': 1.0,
          });
        }
        
        uploadedCount++;
        setState(() {
          _uploadProgress = uploadedCount / totalMedia;
        });
      }

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};

      // Extract hashtags
      final hashtags = _extractHashtags(_captionController.text);

      // Create post
      final postId = FirebaseFirestore.instance.collection('posts').doc().id;

      final postData = {
        'id': postId,
        'authorId': currentUser.uid,
        'authorName': userData['fullName'] ?? 'Unknown User',
        'authorProfileImageUrl': userData['profileImageUrl'],
        'caption': _captionController.text.trim(),
        'mediaItems': mediaItems,
        'hashtags': hashtags,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'viewsCount': 0,
        'allowComments': _allowComments,
        'allowSharing': _allowSharing,
        'visibility': 'public',
        'isDeleted': false,
      };

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .set(postData);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to create post: $e');
      setState(() => _isUploading = false);
    }
  }

  List<String> _extractHashtags(String text) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(text);
    return matches.map((match) => match.group(1)!).toList();
  }

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
}
