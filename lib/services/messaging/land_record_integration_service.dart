// Land Record Integration Service for TALOWA Messaging System
// Automatically links shared documents to relevant land records
// Requirements: 4.4, 4.5 - Integrate with land records system and GPS extraction

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../models/messaging/file_model.dart';
import '../../models/land_record_model.dart';
import '../land_records_service.dart';
import '../location_service.dart';

class LandRecordIntegrationService {
  static final LandRecordIntegrationService _instance = LandRecordIntegrationService._internal();
  factory LandRecordIntegrationService() => _instance;
  LandRecordIntegrationService._internal();

  final LandRecordsService _landRecordsService = LandRecordsService();
  final LocationService _locationService = LocationService();

  /// Auto-link file to relevant land records based on GPS and content analysis
  Future<String?> autoLinkToLandRecord({
    required File file,
    required String userId,
    GpsLocation? gpsLocation,
    List<String> tags = const [],
    String? messageContent,
  }) async {
    try {
      // Strategy 1: GPS-based linking
      if (gpsLocation != null) {
        final gpsLinkedRecord = await _linkByGpsLocation(
          gpsLocation, 
          userId
        );
        if (gpsLinkedRecord != null) {
          debugPrint('File linked to land record via GPS: $gpsLinkedRecord');
          return gpsLinkedRecord;
        }
      }

      // Strategy 2: Content-based linking
      final contentLinkedRecord = await _linkByContent(
        file, 
        userId, 
        tags, 
        messageContent
      );
      if (contentLinkedRecord != null) {
        debugPrint('File linked to land record via content: $contentLinkedRecord');
        return contentLinkedRecord;
      }

      // Strategy 3: User's recent activity
      final activityLinkedRecord = await _linkByRecentActivity(userId);
      if (activityLinkedRecord != null) {
        debugPrint('File linked to land record via recent activity: $activityLinkedRecord');
        return activityLinkedRecord;
      }

      return null;
    } catch (e) {
      debugPrint('Error auto-linking to land record: $e');
      return null;
    }
  }

  /// Link file based on GPS coordinates
  Future<String?> _linkByGpsLocation(GpsLocation gpsLocation, String userId) async {
    try {
      // Find land records within proximity
      // Note: This method would need to be implemented in LandRecordsService
      final nearbyRecords = <LandRecordModel>[]; // Placeholder for now

      if (nearbyRecords.isEmpty) {
        return null;
      }

      // Filter by user's records first
      final userRecords = nearbyRecords.where((record) => 
        record.ownerId == userId
      ).toList();

      if (userRecords.isNotEmpty) {
        // Return the closest user record
        return _findClosestRecord(userRecords, gpsLocation);
      }

      // If no user records found, check if user has access to any nearby records
      // (e.g., as a coordinator or legal representative)
      final accessibleRecords = await _filterAccessibleRecords(nearbyRecords, userId);
      if (accessibleRecords.isNotEmpty) {
        return _findClosestRecord(accessibleRecords, gpsLocation);
      }

      return null;
    } catch (e) {
      debugPrint('Error linking by GPS location: $e');
      return null;
    }
  }

  /// Link file based on content analysis
  Future<String?> _linkByContent(
    File file, 
    String userId, 
    List<String> tags, 
    String? messageContent
  ) async {
    try {
      // Extract keywords from file name and tags
      final fileName = file.path.split('/').last.toLowerCase();
      final keywords = <String>[];
      
      // Add file name words
      keywords.addAll(fileName.split(RegExp(r'[^a-zA-Z0-9]')));
      
      // Add tags
      keywords.addAll(tags.map((tag) => tag.toLowerCase()));
      
      // Add message content words
      if (messageContent != null) {
        keywords.addAll(messageContent.toLowerCase().split(RegExp(r'\s+')));
      }

      // Remove empty strings and common words
      final filteredKeywords = keywords
          .where((word) => word.isNotEmpty && word.length > 2)
          .where((word) => !_isCommonWord(word))
          .toSet()
          .toList();

      if (filteredKeywords.isEmpty) {
        return null;
      }

      // Search land records by keywords
      final matchingRecords = await _searchLandRecordsByKeywords(
        filteredKeywords, 
        userId
      );

      if (matchingRecords.isNotEmpty) {
        // Return the record with highest keyword match score
        return _findBestContentMatch(matchingRecords, filteredKeywords);
      }

      return null;
    } catch (e) {
      debugPrint('Error linking by content: $e');
      return null;
    }
  }

  /// Link file based on user's recent activity
  Future<String?> _linkByRecentActivity(String userId) async {
    try {
      // Get user's recently accessed land records
      // Note: This method would need to be implemented in LandRecordsService
      final recentRecords = <LandRecordModel>[]; // Placeholder for now

      if (recentRecords.isNotEmpty) {
        // Return the most recently accessed record
        return recentRecords.first.id;
      }

      return null;
    } catch (e) {
      debugPrint('Error linking by recent activity: $e');
      return null;
    }
  }

  /// Find the closest land record to GPS location
  String _findClosestRecord(List<LandRecordModel> records, GpsLocation gpsLocation) {
    if (records.isEmpty) return '';
    
    LandRecordModel? closestRecord;
    double minDistance = double.infinity;

    for (final record in records) {
      if (record.location.coordinates != null) {
        final distance = _calculateDistance(
          gpsLocation.latitude,
          gpsLocation.longitude,
          record.location.coordinates!.latitude,
          record.location.coordinates!.longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          closestRecord = record;
        }
      }
    }

    return closestRecord?.id ?? records.first.id;
  }

  /// Calculate distance between two GPS coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Filter records that user has access to
  Future<List<LandRecordModel>> _filterAccessibleRecords(
    List<LandRecordModel> records, 
    String userId
  ) async {
    // In a real implementation, this would check user permissions
    // For now, return empty list for non-owned records
    return records.where((record) => record.ownerId == userId).toList();
  }

  /// Search land records by keywords
  Future<List<LandRecordModel>> _searchLandRecordsByKeywords(
    List<String> keywords, 
    String userId
  ) async {
    try {
      // Get user's land records
      // Note: This method would need to be implemented in LandRecordsService
      final userRecords = <LandRecordModel>[]; // Placeholder for now
      
      final matchingRecords = <LandRecordModel>[];
      
      for (final record in userRecords) {
        if (_recordMatchesKeywords(record, keywords)) {
          matchingRecords.add(record);
        }
      }
      
      return matchingRecords;
    } catch (e) {
      debugPrint('Error searching land records by keywords: $e');
      return [];
    }
  }

  /// Check if land record matches keywords
  bool _recordMatchesKeywords(LandRecordModel record, List<String> keywords) {
    final recordText = [
      record.surveyNumber,
      record.location.village,
      record.location.mandal,
      record.location.district,
      record.landType,
      record.legalStatus,
    ].join(' ').toLowerCase();

    for (final keyword in keywords) {
      if (recordText.contains(keyword.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  /// Find best content match based on keyword scoring
  String _findBestContentMatch(List<LandRecordModel> records, List<String> keywords) {
    if (records.isEmpty) return '';
    
    LandRecordModel? bestMatch;
    int maxScore = 0;

    for (final record in records) {
      final score = _calculateContentMatchScore(record, keywords);
      if (score > maxScore) {
        maxScore = score;
        bestMatch = record;
      }
    }

    return bestMatch?.id ?? records.first.id;
  }

  /// Calculate content match score
  int _calculateContentMatchScore(LandRecordModel record, List<String> keywords) {
    final recordText = [
      record.surveyNumber,
      record.location.village,
      record.location.mandal,
      record.location.district,
      record.landType,
      record.legalStatus,
    ].join(' ').toLowerCase();

    int score = 0;
    for (final keyword in keywords) {
      if (recordText.contains(keyword.toLowerCase())) {
        score++;
      }
    }

    return score;
  }

  /// Check if word is a common word that should be ignored
  bool _isCommonWord(String word) {
    const commonWords = {
      'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
      'by', 'from', 'up', 'about', 'into', 'through', 'during', 'before',
      'after', 'above', 'below', 'between', 'among', 'is', 'are', 'was',
      'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does',
      'did', 'will', 'would', 'could', 'should', 'may', 'might', 'must',
      'can', 'this', 'that', 'these', 'those', 'a', 'an', 'file', 'image',
      'document', 'photo', 'picture', 'pdf', 'jpg', 'png', 'doc', 'docx'
    };
    
    return commonWords.contains(word.toLowerCase());
  }

  /// Get suggested land records for manual linking
  Future<List<LandRecordModel>> getSuggestedLandRecords({
    required String userId,
    GpsLocation? gpsLocation,
    List<String> tags = const [],
    int limit = 5,
  }) async {
    try {
      final suggestions = <LandRecordModel>[];
      
      // Add GPS-based suggestions
      if (gpsLocation != null) {
        // Note: This method would need to be implemented in LandRecordsService
        final nearbyRecords = <LandRecordModel>[]; // Placeholder for now
        suggestions.addAll(nearbyRecords.where((r) => r.ownerId == userId));
      }
      
      // Add content-based suggestions
      if (tags.isNotEmpty) {
        final contentRecords = await _searchLandRecordsByKeywords(tags, userId);
        suggestions.addAll(contentRecords);
      }
      
      // Add recent records
      // Note: This method would need to be implemented in LandRecordsService
      final recentRecords = <LandRecordModel>[]; // Placeholder for now
      suggestions.addAll(recentRecords);
      
      // Remove duplicates and limit results
      final uniqueSuggestions = suggestions.toSet().toList();
      return uniqueSuggestions.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting suggested land records: $e');
      return [];
    }
  }

  /// Create automatic tags based on land record
  List<String> generateTagsFromLandRecord(LandRecordModel landRecord) {
    final tags = <String>[];
    
    tags.add('survey_${landRecord.surveyNumber}');
    tags.add('village_${landRecord.location.village}');
    tags.add('mandal_${landRecord.location.mandal}');
    tags.add('district_${landRecord.location.district}');
    tags.add('land_type_${landRecord.landType}');
    tags.add('status_${landRecord.legalStatus}');
    
    if (landRecord.issues.hasEncroachment) {
      tags.add('encroachment');
    }
    
    if (landRecord.issues.hasDispute) {
      tags.add('dispute');
    }
    
    if (landRecord.issues.hasLegalCase) {
      tags.add('legal_case');
    }
    
    return tags;
  }
}