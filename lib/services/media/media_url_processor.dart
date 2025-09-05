// Media URL Processor Service - Handles CORS and authentication for media URLs
// This service ensures media URLs work properly across web and mobile platforms

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MediaUrlProcessor {
  static final MediaUrlProcessor _instance = MediaUrlProcessor._internal();
  factory MediaUrlProcessor() => _instance;
  MediaUrlProcessor._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Process a media URL to ensure it's compatible with CORS and optimized for display
  Future<String?> processMediaUrl(String? url) async {
    if (url == null || url.isEmpty) {
      return null;
    }
    
    try {
      // If it's already a download URL, process it for CORS
      if (url.contains('firebasestorage.googleapis.com') || (url.contains('firebase') && url.contains('storage'))) {
        // Check if URL contains the wrong bucket name and fix it
        if (url.contains('talowa.appspot.com')) {
          debugPrint('âš ï¸ Detected incorrect bucket name (talowa.appspot.com), replacing with talowa.firebasestorage.app');
          url = url.replaceAll('talowa.appspot.com', 'talowa.firebasestorage.app');
        }
        return _processCorsUrl(url);
      }

      // If it's a storage path (gs:// or path), get download URL
      if (url.startsWith('gs://') || !url.startsWith('http')) {
        return await _getDownloadUrlFromPath(url);
      }

      // For other URLs, return as-is
      return url;
    } catch (e) {
      debugPrint('âŒ Error processing media URL: $e');
      return url; // Return original URL if processing fails
    }
  }
  
  /// Process a media URL with authentication token if needed
  /// This is useful for Firebase Storage URLs that require authentication
  Future<String?> processMediaUrlWithAuth(String? url) async {
    if (url == null || url.isEmpty) {
      return null;
    }
    
    try {
      // If it's a Firebase Storage URL, process it without overriding download token
      if (url.contains('firebasestorage.googleapis.com') || (url.contains('firebase') && url.contains('storage'))) {
        // Fix legacy bucket name if present
        if (url.contains('talowa.appspot.com')) {
          debugPrint('Detected incorrect bucket name (talowa.appspot.com), replacing with talowa.firebasestorage.app');
          url = url.replaceAll('talowa.appspot.com', 'talowa.firebasestorage.app');
        }
        
        // Preserve existing token and just enforce alt=media and optional cache-buster on web
        final uri = Uri.parse(url);
        final queryParams = Map<String, String>.from(uri.queryParameters);
        
        // Ensure alt=media
        queryParams['alt'] = 'media';
        
        // IMPORTANT: Do NOT replace existing 'token' parameter – it is the Storage download token
        // If no token exists, leave it as-is. Private objects without token will 403, which is expected.
        
        // Add a small cache-buster for web to mitigate CORS cache quirks
        if (kIsWeb) {
          queryParams['_cb'] = DateTime.now().millisecondsSinceEpoch.toString();
        }
        
        final newUri = uri.replace(queryParameters: queryParams);
        final processedUrl = newUri.toString();
        debugPrint('Processed URL with preserved token for bucket: ${uri.host}');
        return processedUrl;
      }

      // For other URLs, use regular processing
      return await processMediaUrl(url);
    } catch (e) {
      debugPrint('Error processing media URL with auth: $e');
      return url; // Return original URL if processing fails
    }
  }

  /// Process Firebase Storage URL for CORS compatibility
  String _processCorsUrl(String url) {
    try {
      debugPrint('ðŸ” Processing URL for CORS: $url');
      final uri = Uri.parse(url);
      
      // Ensure proper parameters for Firebase Storage URLs
      final queryParams = Map<String, String>.from(uri.queryParameters);
      
      // Always ensure alt=media is present
      queryParams['alt'] = 'media';
      
      // Add authentication token if not present and user is authenticated
      if (!queryParams.containsKey('token') && isUserAuthenticated()) {
        // Get the current user's ID token if available
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          // We can't directly add the token here as it requires an async call
          // Instead, we'll log that authentication is needed and handle it at a higher level
          debugPrint('ðŸ” User is authenticated, token should be added for secure access');
        } else {
          debugPrint('âš ï¸ No token in URL and user is not authenticated, access might be restricted');
        }
      }
      
      // Add CORS headers for web platform
      if (kIsWeb) {
        // Add cache-busting parameter for web to avoid CORS caching issues
        queryParams['_cb'] = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      final newUri = uri.replace(queryParameters: queryParams);

      final processedUrl = newUri.toString();
      debugPrint('âœ… Processed URL: $processedUrl');
      return processedUrl;
    } catch (e) {
      debugPrint('âŒ Error processing CORS URL: $e');
      return url;
    }
  }

  /// Get download URL from storage path
  Future<String> _getDownloadUrlFromPath(String path) async {
    try {
      // Clean up the path
      String cleanPath = path;
      if (cleanPath.startsWith('gs://')) {
        final uri = Uri.parse(cleanPath);
        // Check if the bucket name is correct
        if (uri.authority != 'talowa.firebasestorage.app') {
          debugPrint('âš ï¸ Using bucket: ${uri.authority}, expected: talowa.firebasestorage.app');
        }
        cleanPath = uri.path.substring(1); // Remove leading slash
      }

      debugPrint('ðŸ” Getting download URL from path: $cleanPath');

      // Get reference and download URL
      final ref = _storage.ref().child(cleanPath);
      final downloadUrl = await ref.getDownloadURL();
      
      debugPrint('âœ… Got download URL from Firebase Storage: ${downloadUrl.substring(0, min(100, downloadUrl.length))}...');

      // Process for CORS
      final processedUrl = _processCorsUrl(downloadUrl);
      return processedUrl;
    } catch (e) {
      debugPrint('âŒ Failed to get download URL for path $path: $e');
      return path; // Return original path if download URL retrieval fails
    }
  }

  /// Check if user is authenticated for media access
  bool isUserAuthenticated() {
    return _auth.currentUser != null;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Process multiple media URLs in batch
  Future<List<String>> processMediaUrls(List<String> urls) async {
    final List<String> processedUrls = [];
    
    for (final url in urls) {
      try {
        final processedUrl = await processMediaUrl(url);
        if (processedUrl != null) {
          processedUrls.add(processedUrl);
        } else {
          debugPrint('âš ï¸ Skipping null URL in batch processing');
        }
      } catch (e) {
        debugPrint('âŒ Failed to process URL $url: $e');
        processedUrls.add(url); // Add original URL if processing fails
      }
    }
    
    return processedUrls;
  }

  /// Validate media URL format
  bool isValidMediaUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Get media type from URL
  String getMediaTypeFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    
    if (path.contains('.mp4') || path.contains('.mov') || path.contains('.avi')) {
      return 'video';
    } else if (path.contains('.jpg') || path.contains('.jpeg') || path.contains('.png') || path.contains('.gif')) {
      return 'image';
    } else if (path.contains('.pdf') || path.contains('.doc') || path.contains('.docx')) {
      return 'document';
    }
    
    return 'unknown';
  }

  /// Create optimized URL for different quality levels
  String createOptimizedUrl(String baseUrl, {String quality = 'medium'}) {
    try {
      if (!baseUrl.contains('firebasestorage.googleapis.com')) {
        return baseUrl;
      }

      final uri = Uri.parse(baseUrl);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      
      // Add quality parameters for Firebase Storage
      switch (quality) {
        case 'low':
          queryParams['w'] = '480';
          queryParams['h'] = '360';
          break;
        case 'medium':
          queryParams['w'] = '720';
          queryParams['h'] = '540';
          break;
        case 'high':
          queryParams['w'] = '1080';
          queryParams['h'] = '810';
          break;
      }

      return uri.replace(queryParameters: queryParams).toString();
    } catch (e) {
      debugPrint('âŒ Error creating optimized URL: $e');
      return baseUrl;
    }
  }

  /// Clear any cached URLs (if needed)
  void clearCache() {
    debugPrint('ðŸ§¹ MediaUrlProcessor cache cleared');
  }
}

