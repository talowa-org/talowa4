// Comprehensive Media Widget - Complete media handling interface
// Part of Task 10: Implement media handling system

import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/media/media_service.dart';
import '../../services/media/media_picker_service.dart';
import '../../services/media/media_upload_manager.dart';
import 'media_preview_widget.dart';

/// Comprehensive media handling widget for post creation
class ComprehensiveMediaWidget extends StatefulWidget {
  final Function(List<MediaUploadResult>) onMediaUploaded;
  final String userId;
  final String postId;
  final int maxFiles;
  final bool allowImages;
  final bool allowDocuments;
  final CompressionSettings compressionSettings;
  final bool generateThumbnails;
  
  const ComprehensiveMediaWidget({
    super.key,
    required this.onMediaUploaded,
    required this.userId,
    required this.postId,
    this.maxFiles = 5,
    this.allowImages = true,
    this.allowDocuments = true,
    this.compressionSettings = CompressionSettings.fullSize,
    this.generateThumbnails = true,
  });
  
  @override
  State<ComprehensiveMediaWidget> createState() => _ComprehensiveMediaWidgetState();
}

class _ComprehensiveMediaWidgetState extends State<ComprehensiveMediaWidget> {
  final List<File> _selectedFiles = [];
  final MediaUploadManager _uploadManager = MediaUploadManager();
  bool _isUploading = false;
  
  @override
  void initState() {
    super.initState();
    _uploadManager.addListener(_onUploadStateChanged);
  }
  
  @override
  void dispose() {
    _uploadManager.removeListener(_onUploadStateChanged);
    _uploadManager.dispose();
    super.dispose();
  }
  
  void _onUploadStateChanged() {
    setState(() {
      _isUploading = _uploadManager.isUploading;
    });
    
    // Notify parent when upload completes
    if (_uploadManager.currentUpload?.isCompleted == true) {
      final results = _uploadManager.getSuccessfulResults();
      widget.onMediaUploaded(results);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Media selection interface
        if (!_isUploading) ...[
          _buildMediaSelectionSection(),
          
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSelectedFilesSection(),
          ],
          
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildUploadButton(),
          ],
        ],
        
        // Upload progress
        if (_isUploading) ...[
          const SizedBox(height: 16),
          _buildUploadProgressSection(),
        ],
        
        // Upload results
        if (_uploadManager.currentUpload?.isCompleted == true) ...[
          const SizedBox(height: 16),
          _buildUploadResultsSection(),
        ],
      ],
    );
  }
  
  Widget _buildMediaSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_file, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Attach Media',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedFiles.length}/${widget.maxFiles}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Selection buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.allowImages) ...[
                  _buildSelectionButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: _selectFromGallery,
                    enabled: _selectedFiles.length < widget.maxFiles,
                  ),
                  _buildSelectionButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: _selectFromCamera,
                    enabled: _selectedFiles.length < widget.maxFiles,
                  ),
                ],
                
                if (widget.allowDocuments)
                  _buildSelectionButton(
                    icon: Icons.description,
                    label: 'Documents',
                    onTap: _selectDocuments,
                    enabled: _selectedFiles.length < widget.maxFiles,
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Help text
            Text(
              'You can attach up to ${widget.maxFiles} files. '
              '${widget.allowImages ? 'Images' : ''}${widget.allowImages && widget.allowDocuments ? ' and ' : ''}'
              '${widget.allowDocuments ? 'documents' : ''} are supported.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSelectionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: enabled 
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled 
              ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
              : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled 
                ? Theme.of(context).primaryColor
                : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled 
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSelectedFilesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_open, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Selected Files (${_selectedFiles.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearAllFiles,
                  child: const Text('Clear All'),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // File previews
            MediaPreviewWidget(
              files: _selectedFiles,
              onRemoveFile: _removeFile,
              onEditFile: _editFile,
              maxHeight: 200,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _selectedFiles.isNotEmpty ? _startUpload : null,
        icon: const Icon(Icons.cloud_upload),
        label: Text('Upload ${_selectedFiles.length} File${_selectedFiles.length == 1 ? '' : 's'}'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
  
  Widget _buildUploadProgressSection() {
    return StreamBuilder<BatchUploadState>(
      stream: _uploadManager.uploadStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _uploadManager.currentUpload;
        
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress header
                Row(
                  children: [
                    const Icon(Icons.cloud_upload, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Uploading Files',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _cancelUpload,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Overall progress
                LinearProgressIndicator(
                  value: state.overallProgress,
                  backgroundColor: Colors.grey.shade200,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  '${(state.overallProgress * 100).toInt()}% complete '
                  '(${state.completedCount}/${state.files.length} files)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Individual file progress
                ...state.files.map((fileState) => _buildFileProgressItem(fileState)),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFileProgressItem(FileUploadState fileState) {
    IconData statusIcon;
    Color statusColor;
    
    switch (fileState.status) {
      case UploadStatus.pending:
        statusIcon = Icons.schedule;
        statusColor = Colors.grey;
        break;
      case UploadStatus.uploading:
        statusIcon = Icons.cloud_upload;
        statusColor = Colors.blue;
        break;
      case UploadStatus.completed:
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case UploadStatus.failed:
        statusIcon = Icons.error;
        statusColor = Colors.red;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileState.fileName,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileState.status == UploadStatus.uploading)
                  LinearProgressIndicator(
                    value: fileState.progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                if (fileState.errorMessage != null)
                  Text(
                    fileState.errorMessage!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (fileState.status == UploadStatus.uploading)
            Text(
              '${(fileState.progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildUploadResultsSection() {
    final state = _uploadManager.currentUpload!;
    final successfulResults = _uploadManager.getSuccessfulResults();
    final failedUploads = _uploadManager.getFailedUploads();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Results header
            Row(
              children: [
                Icon(
                  state.hasErrors ? Icons.warning : Icons.check_circle,
                  size: 20,
                  color: state.hasErrors ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  state.hasErrors ? 'Upload Completed with Issues' : 'Upload Successful',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearUploadResults,
                  child: const Text('Clear'),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Success summary
            if (successfulResults.isNotEmpty) ...[
              Text(
                '✅ ${successfulResults.length} file${successfulResults.length == 1 ? '' : 's'} uploaded successfully',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Failed summary
            if (failedUploads.isNotEmpty) ...[
              Text(
                '❌ ${failedUploads.length} file${failedUploads.length == 1 ? '' : 's'} failed to upload',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              
              // Retry button for failed uploads
              ElevatedButton.icon(
                onPressed: _retryFailedUploads,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Failed Uploads'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Event handlers
  
  Future<void> _selectFromGallery() async {
    final remainingSlots = widget.maxFiles - _selectedFiles.length;
    final result = remainingSlots > 1
        ? await MediaPickerService.pickMultipleImages(maxImages: remainingSlots)
        : await MediaPickerService.pickImageFromGallery();
    
    _handleSelectionResult(result);
  }
  
  Future<void> _selectFromCamera() async {
    final result = await MediaPickerService.pickImageFromCamera();
    _handleSelectionResult(result);
  }
  
  Future<void> _selectDocuments() async {
    final remainingSlots = widget.maxFiles - _selectedFiles.length;
    final result = await MediaPickerService.pickDocuments(
      allowMultiple: remainingSlots > 1,
      maxFiles: remainingSlots,
    );
    _handleSelectionResult(result);
  }
  
  void _handleSelectionResult(MediaSelectionResult result) {
    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    } else if (result.hasFiles) {
      setState(() {
        _selectedFiles.addAll(result.files);
      });
      
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
  
  void _removeFile(File file) {
    setState(() {
      _selectedFiles.remove(file);
    });
  }
  
  void _editFile(File file) {
    // TODO: Implement image editing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image editing feature coming soon!'),
      ),
    );
  }
  
  void _clearAllFiles() {
    setState(() {
      _selectedFiles.clear();
    });
  }
  
  Future<void> _startUpload() async {
    if (_selectedFiles.isEmpty) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      await _uploadManager.uploadFiles(
        files: _selectedFiles,
        userId: widget.userId,
        postId: widget.postId,
        compression: widget.compressionSettings,
        generateThumbnails: widget.generateThumbnails,
      );
      
      // Clear selected files after successful upload
      setState(() {
        _selectedFiles.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _cancelUpload() {
    _uploadManager.cancelUpload();
    setState(() {
      _isUploading = false;
    });
  }
  
  void _clearUploadResults() {
    _uploadManager.clearUpload();
  }
  
  Future<void> _retryFailedUploads() async {
    try {
      await _uploadManager.retryFailedUploads(
        userId: widget.userId,
        postId: widget.postId,
        compression: widget.compressionSettings,
        generateThumbnails: widget.generateThumbnails,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retry failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}