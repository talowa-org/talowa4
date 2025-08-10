// Media Preview Widget - Display selected media files before upload
// Part of Task 10: Implement media handling system

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../../services/media/media_picker_service.dart';

/// Widget for previewing selected media files
class MediaPreviewWidget extends StatelessWidget {
  final List<File> files;
  final Function(File)? onRemoveFile;
  final Function(File)? onEditFile;
  final bool showEditButton;
  final bool showRemoveButton;
  final double maxHeight;
  
  const MediaPreviewWidget({
    super.key,
    required this.files,
    this.onRemoveFile,
    this.onEditFile,
    this.showEditButton = true,
    this.showRemoveButton = true,
    this.maxHeight = 200,
  });
  
  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildFilePreview(context, file),
          );
        },
      ),
    );
  }
  
  Widget _buildFilePreview(BuildContext context, File file) {
    final isImage = MediaPickerService.isImageFile(file.path);
    
    return Container(
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File preview
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: isImage 
                ? _buildImagePreview(file)
                : _buildDocumentPreview(file),
            ),
          ),
          
          // File info and actions
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File name
                Text(
                  path.basename(file.path),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                // File size
                FutureBuilder<int>(
                  future: file.length(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        MediaPickerService.getFileSizeString(snapshot.data!),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                
                const SizedBox(height: 8),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (showEditButton && isImage)
                      _buildActionButton(
                        icon: Icons.edit,
                        onTap: () => onEditFile?.call(file),
                        tooltip: 'Edit',
                      ),
                    
                    if (showRemoveButton)
                      _buildActionButton(
                        icon: Icons.delete,
                        onTap: () => onRemoveFile?.call(file),
                        tooltip: 'Remove',
                        color: Colors.red,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImagePreview(File imageFile) {
    if (kIsWeb) {
      // For web, use Image.network with the file path
      return Image.network(
        imageFile.path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 32,
              ),
            ),
          );
        },
      );
    } else {
      // For mobile, use Image.file
      return Image.file(
        imageFile,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 32,
              ),
            ),
          );
        },
      );
    }
  }
  
  Widget _buildDocumentPreview(File documentFile) {
    final extension = path.extension(documentFile.path).toLowerCase();
    IconData iconData;
    Color iconColor;
    
    switch (extension) {
      case '.pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case '.doc':
      case '.docx':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case '.txt':
        iconData = Icons.text_snippet;
        iconColor = Colors.grey;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }
    
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 48,
              color: iconColor,
            ),
            const SizedBox(height: 8),
            Text(
              extension.toUpperCase().replaceAll('.', ''),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: (color ?? Colors.blue).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color ?? Colors.blue,
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying upload progress
class MediaUploadProgressWidget extends StatelessWidget {
  final List<String> fileNames;
  final double progress;
  final String? currentFileName;
  final bool isCompleted;
  final String? errorMessage;
  
  const MediaUploadProgressWidget({
    super.key,
    required this.fileNames,
    required this.progress,
    this.currentFileName,
    this.isCompleted = false,
    this.errorMessage,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Row(
            children: [
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.green, size: 20)
              else if (errorMessage != null)
                const Icon(Icons.error, color: Colors.red, size: 20)
              else
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              
              const SizedBox(width: 8),
              
              Text(
                isCompleted 
                  ? 'Upload Complete'
                  : errorMessage != null
                    ? 'Upload Failed'
                    : 'Uploading Files...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress bar
          if (!isCompleted && errorMessage == null) ...[
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '${(progress * 100).toInt()}% complete',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          
          // Current file
          if (currentFileName != null && !isCompleted) ...[
            const SizedBox(height: 8),
            Text(
              'Uploading: $currentFileName',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          // Error message
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ],
          
          // File list
          if (fileNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Files (${fileNames.length}):',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            ...fileNames.map((fileName) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_file,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

/// Widget for selecting media files
class MediaSelectionWidget extends StatelessWidget {
  final Function(List<File>) onFilesSelected;
  final int maxFiles;
  final bool allowImages;
  final bool allowDocuments;
  final String? helpText;
  
  const MediaSelectionWidget({
    super.key,
    required this.onFilesSelected,
    this.maxFiles = 5,
    this.allowImages = true,
    this.allowDocuments = true,
    this.helpText,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Selection buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (allowImages) ...[
                _buildSelectionButton(
                  context,
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _selectFromGallery(context),
                ),
                _buildSelectionButton(
                  context,
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _selectFromCamera(context),
                ),
              ],
              
              if (allowDocuments)
                _buildSelectionButton(
                  context,
                  icon: Icons.attach_file,
                  label: 'Documents',
                  onTap: () => _selectDocuments(context),
                ),
              
              if (allowImages && allowDocuments)
                _buildSelectionButton(
                  context,
                  icon: Icons.folder,
                  label: 'All Files',
                  onTap: () => _selectAnyFiles(context),
                ),
            ],
          ),
          
          // Help text
          if (helpText != null) ...[
            const SizedBox(height: 12),
            Text(
              helpText!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSelectionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectFromGallery(BuildContext context) async {
    final result = allowImages && maxFiles > 1
        ? await MediaPickerService.pickMultipleImages(maxImages: maxFiles)
        : await MediaPickerService.pickImageFromGallery();
    
    _handleSelectionResult(context, result);
  }
  
  Future<void> _selectFromCamera(BuildContext context) async {
    final result = await MediaPickerService.pickImageFromCamera();
    _handleSelectionResult(context, result);
  }
  
  Future<void> _selectDocuments(BuildContext context) async {
    final result = await MediaPickerService.pickDocuments(
      allowMultiple: maxFiles > 1,
      maxFiles: maxFiles,
    );
    _handleSelectionResult(context, result);
  }
  
  Future<void> _selectAnyFiles(BuildContext context) async {
    final result = await MediaPickerService.pickAnyFiles(
      allowMultiple: maxFiles > 1,
      maxFiles: maxFiles,
    );
    _handleSelectionResult(context, result);
  }
  
  void _handleSelectionResult(BuildContext context, MediaSelectionResult result) {
    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    } else if (result.hasFiles) {
      onFilesSelected(result.files);
      
      // Show warning if there was a limit applied
      if (result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}