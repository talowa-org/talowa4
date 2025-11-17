// Image Picker Service for TALOWA
// Works on Android, iOS, and Web
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PickedImage {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  PickedImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Pick single image from gallery or camera
  Future<PickedImage?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      if (kIsWeb) {
        // WEB PICKER - uses file_picker for better web support
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );

        if (result == null || result.files.isEmpty) return null;

        final file = result.files.first;

        return PickedImage(
          bytes: file.bytes!,
          fileName: file.name,
          mimeType: _getMimeType(file.extension ?? 'jpg'),
        );
      } else {
        // ANDROID / iOS PICKER
        final XFile? file = await _picker.pickImage(source: source);
        if (file == null) return null;

        final bytes = await file.readAsBytes();

        return PickedImage(
          bytes: bytes,
          fileName: file.name,
          mimeType: file.mimeType ?? 'image/jpeg',
        );
      }
    } catch (e) {
      debugPrint('❌ Image pick error: $e');
      return null;
    }
  }

  /// Pick multiple images
  Future<List<PickedImage>> pickMultipleImages({int maxImages = 10}) async {
    try {
      if (kIsWeb) {
        // WEB PICKER - multiple files
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
          allowMultiple: true,
        );

        if (result == null || result.files.isEmpty) return [];

        final images = <PickedImage>[];
        for (final file in result.files.take(maxImages)) {
          if (file.bytes != null) {
            images.add(PickedImage(
              bytes: file.bytes!,
              fileName: file.name,
              mimeType: _getMimeType(file.extension ?? 'jpg'),
            ));
          }
        }
        return images;
      } else {
        // ANDROID / iOS PICKER
        final List<XFile> files = await _picker.pickMultiImage();
        if (files.isEmpty) return [];

        final images = <PickedImage>[];
        for (final file in files.take(maxImages)) {
          final bytes = await file.readAsBytes();
          images.add(PickedImage(
            bytes: bytes,
            fileName: file.name,
            mimeType: file.mimeType ?? 'image/jpeg',
          ));
        }
        return images;
      }
    } catch (e) {
      debugPrint('❌ Multiple images pick error: $e');
      return [];
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
