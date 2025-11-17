// Video Picker Service for TALOWA
// Works on Android, iOS, and Web
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PickedVideo {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final int? duration; // Duration in seconds

  PickedVideo({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    this.duration,
  });
}

class VideoPickerService {
  final ImagePicker _picker = ImagePicker();

  /// Pick video from gallery or camera
  Future<PickedVideo?> pickVideo({
    ImageSource source = ImageSource.gallery,
    Duration? maxDuration,
  }) async {
    try {
      if (kIsWeb) {
        // WEB PICKER - uses file_picker for better web support
        final result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          withData: true,
        );

        if (result == null || result.files.isEmpty) return null;

        final file = result.files.first;

        // Check file size (max 100MB for web)
        if (file.size > 100 * 1024 * 1024) {
          debugPrint('❌ Video too large: ${file.size} bytes');
          throw Exception('Video must be less than 100MB');
        }

        return PickedVideo(
          bytes: file.bytes!,
          fileName: file.name,
          mimeType: _getMimeType(file.extension ?? 'mp4'),
        );
      } else {
        // ANDROID / iOS PICKER
        final XFile? file = await _picker.pickVideo(
          source: source,
          maxDuration: maxDuration,
        );
        
        if (file == null) return null;

        final bytes = await file.readAsBytes();

        // Check file size (max 100MB)
        if (bytes.length > 100 * 1024 * 1024) {
          debugPrint('❌ Video too large: ${bytes.length} bytes');
          throw Exception('Video must be less than 100MB');
        }

        return PickedVideo(
          bytes: bytes,
          fileName: file.name,
          mimeType: file.mimeType ?? 'video/mp4',
        );
      }
    } catch (e) {
      debugPrint('❌ Video pick error: $e');
      rethrow;
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }
}
