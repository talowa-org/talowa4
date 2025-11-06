// Story Creation Screen for TALOWA Instagram-like Stories
// Comprehensive story creation with media selection and editing
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/story_model.dart';
import '../../services/social_feed/story_service.dart';
import '../../widgets/common/error_boundary_widget.dart';

class StoryCreationScreen extends StatefulWidget {
  const StoryCreationScreen({super.key});

  @override
  State<StoryCreationScreen> createState() => _StoryCreationScreenState();
}

class _StoryCreationScreenState extends State<StoryCreationScreen> {
  final StoryService _storyService = StoryService();
  final ImagePicker _imagePicker = ImagePicker();
  final PageController _pageController = PageController();
  final List<TextEditingController> _textControllers = [];

  List<File> _selectedMedia = [];
  List<String> _backgroundColors = [];
  int _currentPage = 0;
  bool _isCreating = false;
  StoryPrivacy _privacy = StoryPrivacy.public;

  // Color options for text stories
  final List<Color> _colorOptions = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _showMediaPicker();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMediaPickerSheet(),
    );
  }

  Widget _buildMediaPickerSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Create Story',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPickerOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _pickFromGallery(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPickerOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _pickFromCamera(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _buildPickerOption(
              icon: Icons.text_fields,
              label: 'Text Story',
              onTap: () => _createTextStory(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppTheme.talowaGreen),
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
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    Navigator.pop(context);
    
    try {
      final List<XFile> images = await _imagePicker.pickMultipleMedia(
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedMedia = images.map((xfile) => File(xfile.path)).toList();
          _initializeControllers();
        });
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Error picking from gallery: $e');
      _showErrorSnackBar('Failed to pick media from gallery');
    }
  }

  Future<void> _pickFromCamera() async {
    Navigator.pop(context);
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedMedia = [File(image.path)];
          _initializeControllers();
        });
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Error picking from camera: $e');
      _showErrorSnackBar('Failed to take photo');
    }
  }

  void _createTextStory() {
    Navigator.pop(context);
    
    setState(() {
      _selectedMedia = []; // No media for text story
      _backgroundColors = ['#000000']; // Default black background
      _initializeControllers();
    });
  }

  void _initializeControllers() {
    _textControllers.clear();
    final count = _selectedMedia.isNotEmpty ? _selectedMedia.length : 1;
    
    for (int i = 0; i < count; i++) {
      _textControllers.add(TextEditingController());
      if (_selectedMedia.isEmpty) {
        _backgroundColors.add('#000000'); // Default for text stories
      } else {
        _backgroundColors.add(''); // No background for media stories
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedMedia.isEmpty && _backgroundColors.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return ErrorBoundaryWidget(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildStoryPreview(),
            _buildTopBar(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryPreview() {
    final itemCount = _selectedMedia.isNotEmpty ? _selectedMedia.length : 1;
    
    return PageView.builder(
      controller: _pageController,
      itemCount: itemCount,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      itemBuilder: (context, index) {
        if (_selectedMedia.isNotEmpty) {
          return _buildMediaStoryItem(index);
        } else {
          return _buildTextStoryItem(index);
        }
      },
    );
  }

  Widget _buildMediaStoryItem(int index) {
    final file = _selectedMedia[index];
    final isVideo = file.path.toLowerCase().contains('.mp4') ||
                   file.path.toLowerCase().contains('.mov');

    return Stack(
      fit: StackFit.expand,
      children: [
        if (isVideo)
          Container(
            color: Colors.black,
            child: const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 64,
              ),
            ),
          )
        else
          Image.file(
            file,
            fit: BoxFit.cover,
          ),
        
        // Text overlay
        if (_textControllers[index].text.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _textControllers[index].text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextStoryItem(int index) {
    final backgroundColor = Color(
      int.parse(_backgroundColors[index].replaceFirst('#', '0xFF')),
    );

    return Container(
      color: backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: TextField(
            controller: _textControllers[index],
            style: TextStyle(
              color: backgroundColor.computeLuminance() > 0.5 
                  ? Colors.black 
                  : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Type your story...',
              hintStyle: TextStyle(
                color: Colors.grey,
                fontSize: 24,
              ),
            ),
            onChanged: (text) {
              setState(() {}); // Rebuild to show text
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const Spacer(),
            if (_selectedMedia.length > 1 || _backgroundColors.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentPage + 1}/${_selectedMedia.isNotEmpty ? _selectedMedia.length : _backgroundColors.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Text input for media stories
              if (_selectedMedia.isNotEmpty) ...[
                TextField(
                  controller: _textControllers[_currentPage],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add text to your story...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Color picker for text stories
              if (_selectedMedia.isEmpty) ...[
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _colorOptions.length,
                    itemBuilder: (context, index) {
                      final color = _colorOptions[index];
                      final colorHex = '#${color.toARGB32().toRadixString(16).substring(2)}';
                      final isSelected = _backgroundColors[_currentPage] == colorHex;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _backgroundColors[_currentPage] = colorHex;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Bottom action bar
              Row(
                children: [
                  // Privacy selector
                  GestureDetector(
                    onTap: _showPrivacySelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _privacy == StoryPrivacy.public
                                ? Icons.public
                                : _privacy == StoryPrivacy.closeFriends
                                    ? Icons.star
                                    : Icons.lock,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _privacy == StoryPrivacy.public
                                ? 'Public'
                                : _privacy == StoryPrivacy.closeFriends
                                    ? 'Close Friends'
                                    : 'Private',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  
                  // Share button
                  GestureDetector(
                    onTap: _isCreating ? null : _createStory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isCreating ? Colors.grey : AppTheme.talowaGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Share',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacySelector() {
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
              'Story Privacy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...StoryPrivacy.values.map((privacy) {
              return ListTile(
                leading: Icon(
                  privacy == StoryPrivacy.public
                      ? Icons.public
                      : privacy == StoryPrivacy.closeFriends
                          ? Icons.star
                          : Icons.lock,
                  color: _privacy == privacy ? AppTheme.talowaGreen : Colors.grey,
                ),
                title: Text(
                  privacy == StoryPrivacy.public
                      ? 'Public'
                      : privacy == StoryPrivacy.closeFriends
                          ? 'Close Friends'
                          : 'Private',
                ),
                subtitle: Text(
                  privacy == StoryPrivacy.public
                      ? 'Everyone can see your story'
                      : privacy == StoryPrivacy.closeFriends
                          ? 'Only close friends can see'
                          : 'Only you can see',
                ),
                trailing: _privacy == privacy
                    ? const Icon(Icons.check, color: AppTheme.talowaGreen)
                    : null,
                onTap: () {
                  setState(() {
                    _privacy = privacy;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _createStory() async {
    setState(() => _isCreating = true);

    try {
      // Validate content
      bool hasContent = false;
      
      if (_selectedMedia.isNotEmpty) {
        hasContent = true;
      } else {
        // Check if any text story has content
        for (final controller in _textControllers) {
          if (controller.text.trim().isNotEmpty) {
            hasContent = true;
            break;
          }
        }
      }

      if (!hasContent) {
        throw Exception('Please add some content to your story');
      }

      // Prepare texts list
      final texts = _textControllers.map((controller) => controller.text.trim()).toList();

      // Create story
      await _storyService.createStory(
        mediaFiles: _selectedMedia.isNotEmpty ? _selectedMedia : [],
        texts: texts.any((text) => text.isNotEmpty) ? texts : null,
        backgroundColors: _selectedMedia.isEmpty ? _backgroundColors : null,
        privacy: _privacy,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.pop(context, true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story created successfully!'),
            backgroundColor: AppTheme.talowaGreen,
          ),
        );
      }

    } catch (e) {
      debugPrint('❌ Failed to create story: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to create story: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}