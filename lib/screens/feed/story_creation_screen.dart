// Story Creation Screen for TALOWA
// Instagram-like story creation with media selection and editing
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/social_feed/stories_service.dart';
import '../../services/media/media_upload_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/story_model.dart';

class StoryCreationScreen extends StatefulWidget {
  const StoryCreationScreen({super.key});

  @override
  State<StoryCreationScreen> createState() => _StoryCreationScreenState();
}

class _StoryCreationScreenState extends State<StoryCreationScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedMedia;
  XFile? _selectedXFile;
  StoryMediaType _mediaType = StoryMediaType.image;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  // Text overlay properties
  String _textOverlay = '';
  Color _textColor = Colors.white;
  double _textSize = 24.0;
  Offset _textPosition = const Offset(0.5, 0.5);
  
  // Text story properties
  bool _isTextStory = false;
  String _textStoryContent = '';
  Color _textStoryBackgroundColor = const Color(0xFF6200EA);
  
  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
  
  Future<void> _selectMedia() async {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create Story',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMediaOption(
                    icon: Icons.text_fields,
                    label: 'Text',
                    onTap: () {
                      Navigator.pop(context);
                      _createTextStory();
                    },
                  ),
                  _buildMediaOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.camera);
                    },
                  ),
                  _buildMediaOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.gallery);
                    },
                  ),
                  _buildMediaOption(
                    icon: Icons.videocam,
                    label: 'Video',
                    onTap: () {
                      Navigator.pop(context);
                      _pickVideo();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to open media selector: $e');
    }
  }
  
  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.talowaGreen.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: AppTheme.talowaGreen,
            ),
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
  
  Future<void> _pickMedia(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedXFile = image;
          if (!kIsWeb) {
            _selectedMedia = File(image.path);
          }
          _mediaType = StoryMediaType.image;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }
  
  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      
      if (video != null) {
        setState(() {
          _selectedXFile = video;
          if (!kIsWeb) {
            _selectedMedia = File(video.path);
          }
          _mediaType = StoryMediaType.video;
        });
      }
    } catch (e) {
      _showError('Failed to pick video: $e');
    }
  }
  
  void _showTextEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Text',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: 'Type your text...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _textOverlay = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Text Size: '),
                  Expanded(
                    child: Slider(
                      value: _textSize,
                      min: 16.0,
                      max: 48.0,
                      divisions: 8,
                      onChanged: (value) {
                        setState(() {
                          _textSize = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Colors.white,
                  Colors.black,
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                ].map((color) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _textColor = color;
                    });
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _textColor == color ? Colors.grey : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _createTextStory() {
    setState(() {
      _isTextStory = true;
      _mediaType = StoryMediaType.text;
      _selectedXFile = null;
      _selectedMedia = null;
    });
  }
  
  Future<void> _createStory() async {
    // Validate based on story type
    if (_isTextStory) {
      if (_textStoryContent.trim().isEmpty) {
        _showError('Please enter some text for your story');
        return;
      }
    } else {
      if (_selectedXFile == null) {
        _showError('Please select media first');
        return;
      }
    }
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    
    try {
      String? mediaUrl;
      
      // Upload media only if not a text story
      if (!_isTextStory && _selectedXFile != null) {
        mediaUrl = await MediaUploadService.uploadStoryMedia(
          _selectedXFile!,
          AuthService.currentUser!.uid,
        );
        
        if (mediaUrl == null) {
          throw Exception('Failed to upload media');
        }
      }
      
      // Create story
      final storyId = await StoriesService().createStory(
        mediaUrl: mediaUrl,
        mediaType: _mediaType,
        caption: _captionController.text.trim().isNotEmpty 
            ? _captionController.text.trim() 
            : null,
        textContent: _isTextStory ? _textStoryContent : null,
        backgroundColor: _isTextStory ? _textStoryBackgroundColor : null,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, storyId);
      }
    } catch (e) {
      _showError('Failed to create story: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }
  
  void _showBackgroundColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Background Color',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                const Color(0xFF6200EA), // Purple
                const Color(0xFFD32F2F), // Red
                const Color(0xFF1976D2), // Blue
                const Color(0xFF388E3C), // Green
                const Color(0xFFF57C00), // Orange
                const Color(0xFFC2185B), // Pink
                const Color(0xFF0097A7), // Cyan
                const Color(0xFF7B1FA2), // Deep Purple
                const Color(0xFF303F9F), // Indigo
                const Color(0xFF5D4037), // Brown
                Colors.black,
                const Color(0xFF455A64), // Blue Grey
              ].map((color) => GestureDetector(
                onTap: () {
                  setState(() {
                    _textStoryBackgroundColor = color;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _textStoryBackgroundColor == color 
                          ? Colors.white 
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _textStoryBackgroundColor == color
                      ? const Icon(Icons.check, color: Colors.white, size: 30)
                      : null,
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        title: const Text(
          'Create Story',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_selectedXFile != null || _isTextStory)
            TextButton(
              onPressed: _isUploading ? null : _createStory,
              child: Text(
                'Share',
                style: TextStyle(
                  color: _isUploading ? Colors.grey : AppTheme.talowaGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _selectedXFile == null && !_isTextStory
          ? _buildMediaSelector()
          : _buildStoryEditor(),
    );
  }
  
  Widget _buildMediaSelector() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_photo_alternate,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Select media to create your story',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _selectMedia,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text(
              'Select Media',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStoryEditor() {
    return Stack(
      children: [
        // Media Preview
        Positioned.fill(
          child: _buildMediaPreview(),
        ),
        
        // Text Overlay
        if (_textOverlay.isNotEmpty)
          Positioned(
            left: _textPosition.dx * MediaQuery.of(context).size.width - 50,
            top: _textPosition.dy * MediaQuery.of(context).size.height - 20,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _textPosition = Offset(
                    (_textPosition.dx * MediaQuery.of(context).size.width + details.delta.dx) / MediaQuery.of(context).size.width,
                    (_textPosition.dy * MediaQuery.of(context).size.height + details.delta.dy) / MediaQuery.of(context).size.height,
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _textOverlay,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: _textSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        
        // Story Controls
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: _buildStoryControls(),
        ),
        
        // Caption Input
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: _buildCaptionInput(),
        ),
        
        // Upload Progress
        if (_isUploading)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _uploadProgress,
                      color: AppTheme.talowaGreen,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Uploading... ${(_uploadProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildMediaPreview() {
    // Text story preview
    if (_isTextStory) {
      return Container(
        color: _textStoryBackgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: TextField(
              autofocus: true,
              maxLines: null,
              maxLength: 500,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'Type your story...',
                hintStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: 32,
                ),
                border: InputBorder.none,
                counterStyle: TextStyle(color: Colors.white70),
              ),
              onChanged: (value) {
                setState(() {
                  _textStoryContent = value;
                });
              },
            ),
          ),
        ),
      );
    }
    
    // Video preview
    if (_mediaType == StoryMediaType.video) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 80,
              ),
              SizedBox(height: 16),
              Text(
                'Video selected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Image preview
    if (kIsWeb && _selectedXFile != null) {
      return FutureBuilder<Uint8List>(
        future: _selectedXFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
            );
          }
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        },
      );
    } else if (_selectedMedia != null) {
      return Image.file(
        _selectedMedia!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 80,
              ),
            ),
          );
        },
      );
    }
    
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.white,
          size: 80,
        ),
      ),
    );
  }
  
  Widget _buildStoryControls() {
    if (_isTextStory) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.palette,
            label: 'Color',
            onTap: _showBackgroundColorPicker,
          ),
          _buildControlButton(
            icon: Icons.photo_library,
            label: 'Change',
            onTap: _selectMedia,
          ),
        ],
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.text_fields,
          label: 'Text',
          onTap: _showTextEditor,
        ),
        _buildControlButton(
          icon: Icons.photo_library,
          label: 'Change',
          onTap: _selectMedia,
        ),
      ],
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCaptionInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: _captionController,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Add a caption...',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: 1,
        maxLength: 200,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
          return null; // Hide counter
        },
      ),
    );
  }
}

