// Document Preview Widget - Display document attachments in posts
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

/// Widget for displaying document attachments in posts
class DocumentPreviewWidget extends StatelessWidget {
  final List<String> documentUrls;
  final String postId;
  final bool showDownloadButton;
  final int maxDocuments;
  
  const DocumentPreviewWidget({
    super.key,
    required this.documentUrls,
    required this.postId,
    this.showDownloadButton = true,
    this.maxDocuments = 3,
  });
  
  @override
  Widget build(BuildContext context) {
    if (documentUrls.isEmpty) return const SizedBox.shrink();
    
    final displayDocuments = documentUrls.take(maxDocuments).toList();
    final hasMore = documentUrls.length > maxDocuments;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Documents header
          Row(
            children: [
              const Icon(Icons.attach_file, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Documents (${documentUrls.length})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Document list
          ...displayDocuments.asMap().entries.map((entry) {
            final index = entry.key;
            final documentUrl = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < displayDocuments.length - 1 ? 8 : 0),
              child: _buildDocumentItem(context, documentUrl),
            );
          }),
          
          // Show more button
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => _showAllDocuments(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.more_horiz, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '+${documentUrls.length - maxDocuments} more documents',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDocumentItem(BuildContext context, String documentUrl) {
    final fileName = _getFileNameFromUrl(documentUrl);
    final fileExtension = _getFileExtension(fileName);
    final fileSize = _getFileSizeFromUrl(documentUrl); // This would need to be implemented
    
    return InkWell(
      onTap: () => _openDocument(context, documentUrl),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Document icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getFileTypeColor(fileExtension).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  _getFileTypeIcon(fileExtension),
                  size: 20,
                  color: _getFileTypeColor(fileExtension),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Document info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 2),
                  
                  Row(
                    children: [
                      Text(
                        fileExtension.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: _getFileTypeColor(fileExtension),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      if (fileSize != null) ...[
                        Text(
                          ' • $fileSize',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View button
                IconButton(
                  onPressed: () => _openDocument(context, documentUrl),
                  icon: const Icon(Icons.visibility, size: 18),
                  tooltip: 'View Document',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                
                // Download button
                if (showDownloadButton)
                  IconButton(
                    onPressed: () => _downloadDocument(context, documentUrl),
                    icon: const Icon(Icons.download, size: 18),
                    tooltip: 'Download Document',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                
                // Share button
                IconButton(
                  onPressed: () => _shareDocument(context, documentUrl),
                  icon: const Icon(Icons.share, size: 18),
                  tooltip: 'Share Document',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final fileName = path.basename(uri.path);
      return fileName.isNotEmpty ? fileName : 'Document';
    } catch (e) {
      return 'Document';
    }
  }
  
  String _getFileExtension(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return extension.isNotEmpty ? extension.substring(1) : 'file';
  }
  
  String? _getFileSizeFromUrl(String url) {
    // This would need to be implemented to fetch file size
    // For now, return null
    return null;
  }
  
  IconData _getFileTypeIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'rtf':
        return Icons.text_fields;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  Color _getFileTypeColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'txt':
      case 'rtf':
        return Colors.grey;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  Future<void> _openDocument(BuildContext context, String documentUrl) async {
    try {
      final uri = Uri.parse(documentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError(context, 'Cannot open document');
      }
    } catch (e) {
      _showError(context, 'Failed to open document: $e');
    }
  }
  
  Future<void> _downloadDocument(BuildContext context, String documentUrl) async {
    try {
      // In a real app, this would trigger a download
      // For now, just open the document
      await _openDocument(context, documentUrl);
    } catch (e) {
      _showError(context, 'Failed to download document: $e');
    }
  }
  
  Future<void> _shareDocument(BuildContext context, String documentUrl) async {
    try {
      // In a real app, this would use the share plugin
      // For now, just copy to clipboard or show share dialog
      _showInfo(context, 'Share functionality coming soon!');
    } catch (e) {
      _showError(context, 'Failed to share document: $e');
    }
  }
  
  void _showAllDocuments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'All Documents (${documentUrls.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Documents list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: documentUrls.length,
                  itemBuilder: (context, index) {
                    final documentUrl = documentUrls[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: index < documentUrls.length - 1 ? 12 : 0),
                      child: _buildDocumentItem(context, documentUrl),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

/// Widget for document upload preview
class DocumentUploadPreview extends StatelessWidget {
  final List<String> documentPaths;
  final Function(String)? onRemoveDocument;
  final bool showRemoveButton;
  
  const DocumentUploadPreview({
    super.key,
    required this.documentPaths,
    this.onRemoveDocument,
    this.showRemoveButton = true,
  });
  
  @override
  Widget build(BuildContext context) {
    if (documentPaths.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents to upload (${documentPaths.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        const SizedBox(height: 8),
        
        ...documentPaths.map((documentPath) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildDocumentUploadItem(context, documentPath),
        )),
      ],
    );
  }
  
  Widget _buildDocumentUploadItem(BuildContext context, String documentPath) {
    final fileName = path.basename(documentPath);
    final fileExtension = path.extension(fileName).toLowerCase().substring(1);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Document icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getFileTypeColor(fileExtension).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(
                _getFileTypeIcon(fileExtension),
                size: 16,
                color: _getFileTypeColor(fileExtension),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Document info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 2),
                
                Text(
                  fileExtension.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getFileTypeColor(fileExtension),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Remove button
          if (showRemoveButton)
            IconButton(
              onPressed: () => onRemoveDocument?.call(documentPath),
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Remove Document',
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }
  
  IconData _getFileTypeIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'rtf':
        return Icons.text_fields;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  Color _getFileTypeColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'txt':
      case 'rtf':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}