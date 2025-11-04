// CDN Configuration for TALOWA
// Centralized configuration for Content Delivery Network settings

class CDNConfig {
  // Firebase Storage Configuration
  static const String storageBucket = 'talowa.firebasestorage.app';
  static const String storageBaseUrl = 'https://firebasestorage.googleapis.com/v0/b/talowa.firebasestorage.app/o';
  
  // Regional CDN Endpoints for optimal performance
  static const Map<String, String> regionalEndpoints = {
    'asia-south1': 'https://asia-south1-firebasestorage.googleapis.com/v0/b/talowa.firebasestorage.app/o',
    'us-central1': 'https://us-central1-firebasestorage.googleapis.com/v0/b/talowa.firebasestorage.app/o',
    'europe-west1': 'https://europe-west1-firebasestorage.googleapis.com/v0/b/talowa.firebasestorage.app/o',
    'asia-southeast1': 'https://asia-southeast1-firebasestorage.googleapis.com/v0/b/talowa.firebasestorage.app/o',
  };
  
  // Cache Configuration
  static const Duration urlCacheExpiration = Duration(hours: 6);
  static const Duration mediaCacheExpiration = Duration(days: 7);
  static const Duration thumbnailCacheExpiration = Duration(days: 30);
  static const int maxCacheSize = 500; // MB
  static const int maxCacheEntries = 10000;
  
  // Asset Optimization Settings
  static const Map<String, int> imageQualitySettings = {
    'thumbnail': 60,
    'preview': 75,
    'full': 85,
    'original': 95,
  };
  
  static const Map<String, Map<String, int>> imageSizePresets = {
    'thumbnail': {'width': 150, 'height': 150},
    'small': {'width': 300, 'height': 300},
    'medium': {'width': 600, 'height': 600},
    'large': {'width': 1200, 'height': 1200},
    'xlarge': {'width': 1920, 'height': 1920},
  };
  
  // Video Configuration
  static const Map<String, String> videoQualitySettings = {
    'low': '480p',
    'medium': '720p',
    'high': '1080p',
    'auto': 'adaptive',
  };
  
  static const int maxVideoSizeMB = 100;
  static const int maxImageSizeMB = 10;
  static const int maxDocumentSizeMB = 25;
  
  // Supported File Formats
  static const List<String> supportedImageFormats = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'tiff'
  ];
  
  static const List<String> supportedVideoFormats = [
    'mp4', 'webm', 'ogg', 'avi', 'mov', 'wmv', 'flv', 'm4v'
  ];
  
  static const List<String> supportedDocumentFormats = [
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'pages'
  ];
  
  // Performance Thresholds
  static const Duration maxUploadTime = Duration(minutes: 5);
  static const Duration maxDownloadTime = Duration(seconds: 30);
  static const double minBandwidthMbps = 1.0;
  static const int maxConcurrentUploads = 3;
  static const int maxConcurrentDownloads = 10;
  
  // Security Settings
  static const List<String> allowedOrigins = [
    'https://talowa.web.app',
    'https://talowa.firebaseapp.com',
    'http://localhost:3000',
    'http://localhost:8080',
    'http://localhost:5000',
  ];
  
  static const Map<String, String> securityHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
  };
  
  // Monitoring and Analytics
  static const Duration metricsCollectionInterval = Duration(minutes: 5);
  static const int maxMetricsHistoryDays = 30;
  static const List<String> trackedMetrics = [
    'upload_time',
    'download_time',
    'cache_hit_rate',
    'bandwidth_usage',
    'error_rate',
    'concurrent_users',
  ];
  
  // Feature Flags
  static const bool enableImageOptimization = true;
  static const bool enableVideoTranscoding = true;
  static const bool enableProgressiveLoading = true;
  static const bool enableLazyLoading = true;
  static const bool enableCacheInvalidation = true;
  static const bool enableRealTimeMetrics = true;
  static const bool enableGeoDistribution = true;
  
  // Geographic Distribution
  static const Map<String, List<String>> regionMapping = {
    'asia-south1': ['IN', 'BD', 'LK', 'NP', 'BT', 'MV'],
    'asia-southeast1': ['SG', 'MY', 'TH', 'ID', 'PH', 'VN', 'KH', 'LA', 'MM', 'BN'],
    'us-central1': ['US', 'CA', 'MX'],
    'europe-west1': ['GB', 'IE', 'FR', 'DE', 'NL', 'BE', 'LU'],
  };
  
  // Error Handling
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration readTimeout = Duration(seconds: 60);
  
  // Utility Methods
  static String getOptimalEndpoint(String? countryCode) {
    if (countryCode == null) return storageBaseUrl;
    
    for (final entry in regionMapping.entries) {
      if (entry.value.contains(countryCode.toUpperCase())) {
        return regionalEndpoints[entry.key] ?? storageBaseUrl;
      }
    }
    
    return storageBaseUrl;
  }
  
  static Map<String, int> getImageSize(String preset) {
    return imageSizePresets[preset] ?? imageSizePresets['medium']!;
  }
  
  static int getImageQuality(String preset) {
    return imageQualitySettings[preset] ?? imageQualitySettings['full']!;
  }
  
  static bool isImageFormat(String extension) {
    return supportedImageFormats.contains(extension.toLowerCase());
  }
  
  static bool isVideoFormat(String extension) {
    return supportedVideoFormats.contains(extension.toLowerCase());
  }
  
  static bool isDocumentFormat(String extension) {
    return supportedDocumentFormats.contains(extension.toLowerCase());
  }
  
  static Duration getCacheExpiration(String assetType) {
    switch (assetType.toLowerCase()) {
      case 'thumbnail':
        return thumbnailCacheExpiration;
      case 'image':
      case 'video':
      case 'document':
        return mediaCacheExpiration;
      default:
        return urlCacheExpiration;
    }
  }
}

// CDN Environment Configuration
class CDNEnvironment {
  static const String development = 'development';
  static const String staging = 'staging';
  static const String production = 'production';
  
  static String get current {
    // In a real app, this would be determined by build configuration
    return production;
  }
  
  static Map<String, dynamic> getConfig(String environment) {
    switch (environment) {
      case development:
        return {
          'enableDebugLogging': true,
          'enableMetrics': false,
          'cacheSize': 100, // MB
          'maxConcurrentUploads': 1,
        };
      case staging:
        return {
          'enableDebugLogging': true,
          'enableMetrics': true,
          'cacheSize': 250, // MB
          'maxConcurrentUploads': 2,
        };
      case production:
      default:
        return {
          'enableDebugLogging': false,
          'enableMetrics': true,
          'cacheSize': 500, // MB
          'maxConcurrentUploads': 3,
        };
    }
  }
}