// Story Creation Screen
// Create and post Instagram-style stories

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/social_feed/stories_service.dart';
import '../../services/auth_service.dart';
import '../../models/social_feed/story_model.dart';
import 'dart:html' as html;

class StoryCreationScreen extends StatefulWidget {
  const StoryCreationScreen({super.key});

  @override
  State<StoryCreationScreen> createState() => _StoryCreationScreenState();
}

class _StoryCreationScreenState extends State<StoryCreationScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final StoriesService _storiesService = StoriesService();
  
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        // Web-specific image picker using html package
        final uploadInput = html.FileUploadInputElement();
        uploadInput.accept = 'image/*';
        uploadInput.click();

        await uploadInput.onChange.first;
        
        final files = uploadInput.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          final reader = html.FileReader();
          
          reader.onLoadEnd.listen((e) {
            if (reader.result != null) {
              final bytes = reader.result as Uint8List;
              if (mounted) {
                setState(() {
                  _imageBytes = bytes;
                  _imageName = file.name;
                });
              }
            }
          });
          
          reader.readAsArrayBuffer(file);
        }
      } else {
        // Mobile image picker
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1080,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imageName = image.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showError('Failed to pick image. Please try again.');
    }
  }

  Future<void> _postStory() async {
    if (_imageBytes == null) {
      _showError('Please select an image');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('📤 Starting story upload...');
      debugPrint('Image size: ${_imageBytes!.length} bytes');

      // Upload image to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${_imageName ?? "story.jpg"}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('stories')
          .child(currentUser.uid)
          .child(fileName);

      debugPrint('📁 Uploading to: stories/${currentUser.uid}/$fileName');

      final uploadTask = await storageRef.putData(
        _imageBytes!,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': currentUser.uid,
            'uploadedAt': timestamp.toString(),
          },
        ),
      );

      debugPrint('✅ Upload complete, getting download URL...');
      final imageUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('🔗 Download URL: $imageUrl');

      // Create story
      debugPrint('📝 Creating story document...');
      final storyId = await _storiesService.createStory(
        mediaUrl: imageUrl,
        mediaType: StoryMediaType.image,
        caption: _captionController.text.trim().isEmpty 
            ? null 
            : _captionController.text.trim(),
      );
      debugPrint('✅ Story created with ID: $storyId');

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story posted successfully! 🎉'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error posting story: $e');
      debugPrint('Stack trace: $stackTrace');
      _showError('Failed to post story: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
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
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Story',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_imageBytes != null)
            TextButton(
              onPressed: _isUploading ? null : _postStory,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Share',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _imageBytes == null
          ? _buildImagePicker()
          : _buildStoryPreview(),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 100,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 24),
          Text(
            'Select a photo for your story',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose from Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryPreview() {
    return Stack(
      children: [
        // Image preview
        Positioned.fill(
          child: Image.memory(
            _imageBytes!,
            fit: BoxFit.contain,
          ),
        ),

        // Caption input at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Change image',
                ),
              ],
            ),
          ),
        ),

        // Loading overlay
        if (_isUploading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Posting your story...',
                      style: TextStyle(
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
}
