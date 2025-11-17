// Instagram-style Post Creation Screen for TALOWA
// Modern post creation with media upload, captions, and tagging
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../../widgets/common/loading_widget.dart';
import '../../services/media/media_upload_service.dart';
import '../../services/auth/auth_service.dart';

class InstagramPostCreationScreen extends StatefulWidget {
  const InstagramPostCreationScreen({super.key});

  @override
  State<InstagramPostCreationScreen> createState() => _InstagramPostCreationScreenState();
}

class _InstagramPostCreationScreenState extends State<InstagramPostCreationScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  final List<XFile> _selectedMedia = [];
  bool _isLoading = false;
  bool _allowComments = true;
  bool _allowSharing = true;
  PostVisibility _visibility = PostVisibility.public;
  
  static const int _maxCaptionLength = 2200;
  static const int _maxMediaCount = 10;

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
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
        'New Post',
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _canPost() ? _createPost : null,
          child: Text(
            'Share',
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
    if (_isLoading) {
      return const LoadingWidget(message: 'Creating post...');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMediaSection(),
          const SizedBox(height: 16),
          _buildCaptionSection(),
          const SizedBox(height: 24),
          _buildOptionsSection(),
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
              TextButton.icon(
                onPressed: _showMediaPicker,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Media'),
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
    return GestureDetector(
      onTap: _showMediaPicker,
      child: Container(
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
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Add photos or videos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to select media from your device',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
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

  Widget _buildMediaItem(XFile media, int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              media.path,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                );
              },
            ),
          ),
        ),
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
          focusNode: _captionFocusNode,
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
          'Use #hashtags and @mentions to reach more people',
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
        
        // Visibility
        _buildOptionTile(
          icon: Icons.public,
          title: 'Visibility',
          subtitle: _visibility.name,
          onTap: _showVisibilityPicker,
        ),
        
        // Comments
        _buildSwitchTile(
          icon: Icons.comment_outlined,
          title: 'Allow Comments',
          subtitle: 'People can comment on your post',
          value: _allowComments,
          onChanged: (value) => setState(() => _allowComments = value),
        ),
        
        // Sharing
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

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
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
        activeThumbColor: AppTheme.talowaGreen,
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVisibilityPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Who can see your post?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...PostVisibility.values.map((visibility) => ListTile(
              title: Text(visibility.name),
              trailing: _visibility == visibility 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() => _visibility = visibility);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia(ImageSource source) async {
    try {
      final XFile? media = await _imagePicker.pickImage(source: source);
      if (media != null) {
        setState(() {
          _selectedMedia.add(media);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick media: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  bool _canPost() {
    return _captionController.text.trim().isNotEmpty || _selectedMedia.isNotEmpty;
  }

  Future<void> _createPost() async {
    if (!_canPost()) return;

    setState(() => _isLoading = true);

    try {
      // Import required services
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // 1. Upload media files to Firebase Storage
      final imageUrls = <String>[];
      
      for (final media in _selectedMedia) {
        final url = await MediaUploadService.uploadFeedImage(media, currentUser.uid);
        if (url != null) {
          imageUrls.add(url);
        }
      }
      
      // 2. Extract hashtags from caption
      final hashtags = _extractHashtags(_captionController.text);
      
      // 3. Get user profile data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final userData = userDoc.data() ?? {};
      
      // 4. Create post document
      final postId = FirebaseFirestore.instance.collection('posts').doc().id;
      
      final postData = {
        'id': postId,
        'authorId': currentUser.uid,
        'authorName': userData['fullName'] ?? 'Unknown User',
        'authorRole': userData['role'] ?? 'member',
        'authorAvatarUrl': userData['profileImageUrl'],
        'content': _captionController.text.trim(),
        'imageUrls': imageUrls,
        'videoUrls': [], // Video support can be added later
        'mediaUrls': imageUrls, // Legacy support
        'hashtags': hashtags,
        'category': 'general_discussion',
        'location': userData['address']?['villageCity'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'viewsCount': 0,
        'visibility': _visibility.value,
        'allowComments': _allowComments,
        'allowShares': _allowSharing,
        'isDeleted': false,
        'isPinned': false,
        'isEmergency': false,
      };
      
      // 5. Save post to Firestore
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .set(postData);
      
      debugPrint('✅ Post created successfully: $postId');
      
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
    } catch (e) {
      debugPrint('❌ Post creation failed: $e');
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create post: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// Extract hashtags from text
  List<String> _extractHashtags(String text) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(text);
    return matches.map((match) => match.group(1)!).toList();
  }
}