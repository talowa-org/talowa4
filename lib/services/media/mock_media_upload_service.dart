// Mock Media Upload Service for Web Testing
// Provides mock functionality for image and document uploads during development

import 'package:flutter/foundation.dart';

class MockMediaUploadService {
  /// Mock upload multiple images
  static Future<List<String>> uploadImages({
    required List<String> imagePaths,
    required String userId,
    String folder = 'posts',
    Function(int, int)? onProgress,
  }) async {
    try {
      debugPrint('MockMediaUploadService: Simulating upload of ${imagePaths.length} images');
      
      final uploadedUrls = <String>[];
      
      for (int i = 0; i < imagePaths.length; i++) {
        // Simulate upload progress
        onProgress?.call(i, imagePaths.length);
        
        // Simulate upload delay
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Generate mock URL (using data URL to avoid CORS)
        const mockUrl = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtc2l6ZT0iMTgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5JbWFnZSAke2kgKyAxfTwvdGV4dD48L3N2Zz4=';
        uploadedUrls.add(mockUrl);
        
        debugPrint('MockMediaUploadService: Mock image ${i + 1} uploaded: $mockUrl');
      }
      
      onProgress?.call(imagePaths.length, imagePaths.length);
      return uploadedUrls;
      
    } catch (e) {
      debugPrint('MockMediaUploadService: Error in mock upload: $e');
      rethrow;
    }
  }
  
  /// Mock upload multiple documents
  static Future<List<String>> uploadDocuments({
    required List<String> documentPaths,
    required String userId,
    String folder = 'documents',
    Function(int, int)? onProgress,
  }) async {
    try {
      debugPrint('MockMediaUploadService: Simulating upload of ${documentPaths.length} documents');
      
      final uploadedUrls = <String>[];
      
      for (int i = 0; i < documentPaths.length; i++) {
        // Simulate upload progress
        onProgress?.call(i, documentPaths.length);
        
        // Simulate upload delay
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Generate mock URL (using data URL to avoid CORS)
        const mockUrl = 'data:application/pdf;base64,JVBERi0xLjQKJdPr6eEKMSAwIG9iago8PAovVHlwZSAvQ2F0YWxvZwovUGFnZXMgMiAwIFIKPj4KZW5kb2JqCjIgMCBvYmoKPDwKL1R5cGUgL1BhZ2VzCi9LaWRzIFszIDAgUl0KL0NvdW50IDEKPD4KZW5kb2JqCjMgMCBvYmoKPDwKL1R5cGUgL1BhZ2UKL1BhcmVudCAyIDAgUgovTWVkaWFCb3ggWzAgMCA2MTIgNzkyXQovUmVzb3VyY2VzIDw8Ci9Gb250IDw8Ci9GMSA0IDAgUgo+Pgo+PgovQ29udGVudHMgNSAwIFIKPj4KZW5kb2JqCjQgMCBvYmoKPDwKL1R5cGUgL0ZvbnQKL1N1YnR5cGUgL1R5cGUxCi9CYXNlRm9udCAvSGVsdmV0aWNhCj4+CmVuZG9iago1IDAgb2JqCjw8Ci9MZW5ndGggNDQKPj4Kc3RyZWFtCkJUCi9GMSA4IFRmCjEwIDUwIFRkCihNb2NrIERvY3VtZW50KSBUagpFVApzdHJlYW0KZW5kb2JqCnhyZWYKMCA2CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAwOSAwMDAwMCBuIAowMDAwMDAwMDU4IDAwMDAwIG4gCjAwMDAwMDAxMTUgMDAwMDAgbiAKMDAwMDAwMDI0NSAwMDAwMCBuIAowMDAwMDAwMzIzIDAwMDAwIG4gCnRyYWlsZXIKPDwKL1NpemUgNgovUm9vdCAxIDAgUgo+PgpzdGFydHhyZWYKNDE3CiUlRU9G';
        uploadedUrls.add(mockUrl);
        
        debugPrint('MockMediaUploadService: Mock document ${i + 1} uploaded: $mockUrl');
      }
      
      onProgress?.call(documentPaths.length, documentPaths.length);
      return uploadedUrls;
      
    } catch (e) {
      debugPrint('MockMediaUploadService: Error in mock upload: $e');
      rethrow;
    }
  }
  
  /// Mock image compression
  static Future<String> compressImage(String imagePath) async {
    debugPrint('MockMediaUploadService: Mock compressing image: $imagePath');
    await Future.delayed(const Duration(milliseconds: 200));
    return imagePath; // Return original path for mock
  }
  
  /// Mock file validation
  static bool validateImageFile(String filePath) {
    final allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final extension = filePath.toLowerCase().split('.').last;
    return allowedExtensions.contains('.$extension');
  }
  
  /// Mock file validation for documents
  static bool validateDocumentFile(String filePath) {
    final allowedExtensions = ['.pdf', '.doc', '.docx', '.txt'];
    final extension = filePath.toLowerCase().split('.').last;
    return allowedExtensions.contains('.$extension');
  }
  
  /// Get mock file size
  static int getMockFileSize(String filePath) {
    // Return mock file size in bytes
    return 1024 * 500; // 500KB mock size
  }
}