import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Exception thrown when recognition and retention operations fail
class RecognitionRetentionException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const RecognitionRetentionException(this.message, [this.code = 'RECOGNITION_RETENTION_FAILED', this.context]);
  
  @override
  String toString() => 'RecognitionRetentionException: $message';
}

/// Achievement data model
class Achievement {
  final String id;
  final String name;
  final String description;
  final String badgeUrl;
  final String category;
  final int points;
  final Map<String, dynamic> criteria;
  final DateTime unlockedAt;
  final bool isShared;
  final Map<String, dynamic> rewards;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.badgeUrl,
    required this.category,
    required this.points,
    required this.criteria,
    required this.unlockedAt,
    required this.isShared,
    required this.rewards,
  });

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      badgeUrl: map['badgeUrl'] ?? '',
      category: map['category'] ?? '',
      points: map['points'] ?? 0,
      criteria: (map['criteria'] as Map<String, dynamic>?) ?? {},
      unlockedAt: (map['unlockedAt'] as Timestamp).toDate(),
      isShared: map['isShared'] ?? false,
      rewards: (map['rewards'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'badgeUrl': badgeUrl,
      'category': category,
      'points': points,
      'criteria': criteria,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
      'isShared': isShared,
      'rewards': rewards,
    };
  }
}

/// Certificate data model
class PromotionCertificate {
  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String oldRole;
  final String newRole;
  final DateTime promotionDate;
  final String certificateUrl;
  final String digitalSignature;
  final Map<String, dynamic> achievements;
  final bool isDownloaded;
  final DateTime? downloadedAt;

  const PromotionCertificate({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.oldRole,
    required this.newRole,
    required this.promotionDate,
    required this.certificateUrl,
    required this.digitalSignature,
    required this.achievements,
    required this.isDownloaded,
    this.downloadedAt,
  });

  factory PromotionCertificate.fromMap(Map<String, dynamic> map) {
    return PromotionCertificate(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhotoUrl: map['userPhotoUrl'] ?? '',
      oldRole: map['oldRole'] ?? '',
      newRole: map['newRole'] ?? '',
      promotionDate: (map['promotionDate'] as Timestamp).toDate(),
      certificateUrl: map['certificateUrl'] ?? '',
      digitalSignature: map['digitalSignature'] ?? '',
      achievements: Map<String, dynamic>.from(map['achievements'] ?? {}),
      isDownloaded: map['isDownloaded'] ?? false,
      downloadedAt: map['downloadedAt'] != null 
          ? (map['downloadedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'oldRole': oldRole,
      'newRole': newRole,
      'promotionDate': Timestamp.fromDate(promotionDate),
      'certificateUrl': certificateUrl,
      'digitalSignature': digitalSignature,
      'achievements': achievements,
      'isDownloaded': isDownloaded,
      'downloadedAt': downloadedAt != null ? Timestamp.fromDate(downloadedAt!) : null,
    };
  }
}

/// Service for recognition and retention functionality
class RecognitionRetentionService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Generate promotion certificate
  static Future<PromotionCertificate> generatePromotionCertificate({
    required String userId,
    required String userName,
    required String userPhotoUrl,
    required String oldRole,
    required String newRole,
    required Map<String, dynamic> achievements,
  }) async {
    try {
      final certificateId = _generateCertificateId();
      final promotionDate = DateTime.now();
      
      // Generate digital signature
      final digitalSignature = _generateDigitalSignature(
        userId: userId,
        userName: userName,
        oldRole: oldRole,
        newRole: newRole,
        promotionDate: promotionDate,
      );
      
      // Generate certificate URL (in real implementation, this would create an actual certificate image)
      final certificateUrl = await _generateCertificateImage(
        certificateId: certificateId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        oldRole: oldRole,
        newRole: newRole,
        promotionDate: promotionDate,
        digitalSignature: digitalSignature,
      );
      
      final certificate = PromotionCertificate(
        id: certificateId,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        oldRole: oldRole,
        newRole: newRole,
        promotionDate: promotionDate,
        certificateUrl: certificateUrl,
        digitalSignature: digitalSignature,
        achievements: achievements,
        isDownloaded: false,
      );
      
      // Save certificate to database
      await _firestore
          .collection('certificates')
          .doc(certificateId)
          .set(certificate.toMap());
      
      return certificate;
    } catch (e) {
      throw RecognitionRetentionException(
        'Failed to generate promotion certificate: $e',
        'CERTIFICATE_GENERATION_FAILED',
        {'userId': userId, 'oldRole': oldRole, 'newRole': newRole}
      );
    }
  }
  
  /// Create celebration animation data
  static Map<String, dynamic> createCelebrationAnimation({
    required String type, // 'promotion', 'achievement', 'milestone'
    required String title,
    required String subtitle,
    required Color primaryColor,
    required Color secondaryColor,
    required List<String> confettiColors,
    required String soundEffect,
    required Duration duration,
  }) {
    return {
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'primaryColor': primaryColor.value,
      'secondaryColor': secondaryColor.value,
      'confettiColors': confettiColors,
      'soundEffect': soundEffect,
      'duration': duration.inMilliseconds,
      'animations': {
        'confetti': {
          'enabled': true,
          'particleCount': 100,
          'spread': 70,
          'startVelocity': 45,
          'decay': 0.9,
          'gravity': 1,
          'drift': 0,
          'ticks': 200,
        },
        'fireworks': {
          'enabled': type == 'promotion',
          'count': 3,
          'delay': 500,
        },
        'badge': {
          'enabled': true,
          'scale': 1.5,
          'rotation': 360,
          'bounce': true,
        },
        'text': {
          'typewriter': true,
          'fadeIn': true,
          'slideUp': true,
        },
      },
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
  
  /// Create role-specific badge
  static Future<Map<String, dynamic>> createRoleSpecificBadge({
    required String userId,
    required String role,
    required Map<String, dynamic> achievements,
    required Map<String, dynamic> statistics,
  }) async {
    try {
      final badgeId = _generateBadgeId();
      
      final badge = {
        'id': badgeId,
        'userId': userId,
        'role': role,
        'roleName': _formatRoleName(role),
        'achievements': achievements,
        'statistics': statistics,
        'badgeUrl': await _generateBadgeImage(role, achievements, statistics),
        'unlockedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'displayOrder': _getRoleDisplayOrder(role),
        'colors': _serializeRoleColors(_getRoleColors(role)),
        'features': _getRoleFeatures(role),
      };
      
      await _firestore
          .collection('user_badges')
          .doc(badgeId)
          .set(badge);
      
      return badge;
    } catch (e) {
      throw RecognitionRetentionException(
        'Failed to create role-specific badge: $e',
        'BADGE_CREATION_FAILED',
        {'userId': userId, 'role': role}
      );
    }
  }
  
  /// Track achievement timeline
  static Future<void> trackAchievementTimeline({
    required String userId,
    required Achievement achievement,
  }) async {
    try {
      final timelineEntry = {
        'userId': userId,
        'achievementId': achievement.id,
        'achievementName': achievement.name,
        'achievementCategory': achievement.category,
        'points': achievement.points,
        'unlockedAt': Timestamp.fromDate(achievement.unlockedAt),
        'isShared': achievement.isShared,
        'rewards': achievement.rewards,
        'milestone': _calculateMilestone(achievement),
      };
      
      await _firestore
          .collection('achievement_timeline')
          .add(timelineEntry);
      
      // Update user's total achievement points
      await _updateUserAchievementPoints(userId, achievement.points);
    } catch (e) {
      throw RecognitionRetentionException(
        'Failed to track achievement timeline: $e',
        'TIMELINE_TRACKING_FAILED',
        {'userId': userId, 'achievementId': achievement.id}
      );
    }
  }
  
  /// Generate social media sharing content
  static Map<String, dynamic> generateSocialSharingContent({
    required String type, // 'promotion', 'achievement', 'milestone'
    required String userName,
    required String title,
    required String description,
    required String imageUrl,
    required List<String> hashtags,
  }) {
    final baseHashtags = ['#Talowa', '#ReferralSuccess', '#TeamGrowth'];
    final allHashtags = [...baseHashtags, ...hashtags];
    
    return {
      'type': type,
      'platforms': {
        'facebook': {
          'text': '🎉 $description\n\nJoin the movement! ${allHashtags.join(' ')}',
          'imageUrl': imageUrl,
          'link': 'https://talowa.app/join',
        },
        'twitter': {
          'text': '🚀 $title\n\n$description\n\n${allHashtags.join(' ')}\n\nJoin: https://talowa.app/join',
          'imageUrl': imageUrl,
        },
        'instagram': {
          'text': '$description\n\n${allHashtags.join(' ')}',
          'imageUrl': imageUrl,
        },
        'linkedin': {
          'text': 'Excited to share: $description\n\n${allHashtags.join(' ')}\n\nLearn more: https://talowa.app/join',
          'imageUrl': imageUrl,
        },
        'whatsapp': {
          'text': '🎉 $description\n\nCheck out Talowa: https://talowa.app/join',
        },
      },
      'brandedGraphics': {
        'certificateUrl': imageUrl,
        'badgeUrl': imageUrl,
        'storyTemplate': _generateStoryTemplate(type, title, description),
        'postTemplate': _generatePostTemplate(type, title, description),
      },
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }
  
  /// Unlock role-specific features
  static Future<Map<String, dynamic>> unlockRoleFeatures({
    required String userId,
    required String newRole,
    required String oldRole,
  }) async {
    try {
      final roleFeatures = _getRoleFeatures(newRole);
      final newFeatures = _getNewFeatures(oldRole, newRole);
      
      // Update user's feature access
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
            'roleFeatures': roleFeatures,
            'newFeaturesUnlocked': newFeatures,
            'lastFeatureUnlock': FieldValue.serverTimestamp(),
          });
      
      // Create guided tour data
      final guidedTour = _createGuidedTour(newRole, newFeatures);
      
      return {
        'unlockedFeatures': newFeatures,
        'allFeatures': roleFeatures,
        'guidedTour': guidedTour,
        'celebrationData': createCelebrationAnimation(
          type: 'promotion',
          title: 'New Features Unlocked!',
          subtitle: 'Explore your new ${_formatRoleName(newRole)} capabilities',
          primaryColor: _getRoleColors(newRole)['primary'] as Color,
          secondaryColor: _getRoleColors(newRole)['secondary'] as Color,
          confettiColors: ['#FFD700', '#FF6B6B', '#4ECDC4', '#45B7D1'],
          soundEffect: 'achievement_unlock.mp3',
          duration: Duration(seconds: 3),
        ),
      };
    } catch (e) {
      throw RecognitionRetentionException(
        'Failed to unlock role features: $e',
        'FEATURE_UNLOCK_FAILED',
        {'userId': userId, 'newRole': newRole}
      );
    }
  }
  
  /// Send team notifications for leader promotions
  static Future<void> sendTeamPromotionNotifications({
    required String promotedUserId,
    required String promotedUserName,
    required String newRole,
    required List<String> teamMemberIds,
  }) async {
    try {
      final batch = _firestore.batch();
      
      for (final memberId in teamMemberIds) {
        final notificationRef = _firestore.collection('notifications').doc();
        
        batch.set(notificationRef, {
          'userId': memberId,
          'type': 'team_leader_promotion',
          'title': 'Team Leader Promoted! 🎊',
          'message': '$promotedUserName has been promoted to ${_formatRoleName(newRole)}!',
          'data': {
            'promotedUserId': promotedUserId,
            'promotedUserName': promotedUserName,
            'newRole': newRole,
            'action': 'view_team',
          },
          'priority': 'high',
          'channels': ['inApp', 'push'],
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'isDelivered': false,
        });
      }
      
      await batch.commit();
    } catch (e) {
      throw RecognitionRetentionException(
        'Failed to send team promotion notifications: $e',
        'TEAM_NOTIFICATION_FAILED',
        {'promotedUserId': promotedUserId, 'teamMemberIds': teamMemberIds}
      );
    }
  }
  
  /// Update profile card with new role information
  static Future<Map<String, dynamic>> updateProfileCard({
    required String userId,
    required String newRole,
    required List<Achievement> achievements,
    required Map<String, dynamic> statistics,
  }) async {
    try {
      final profileCard = {
        'userId': userId,
        'role': newRole,
        'roleName': _formatRoleName(newRole),
        'roleColors': _serializeRoleColors(_getRoleColors(newRole)),
        'roleBadge': await _generateBadgeImage(newRole, {}, statistics),
        'achievements': achievements.map((a) => a.toMap()).toList(),
        'statistics': statistics,
        'titles': _getRoleTitles(newRole),
        'displayBadges': _getDisplayBadges(achievements),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('profile_cards')
          .doc(userId)
          .set(profileCard, SetOptions(merge: true));
      
      return profileCard;
    } catch (e) {
      throw RecognitionRetentionException(
        'Failed to update profile card: $e',
        'PROFILE_UPDATE_FAILED',
        {'userId': userId, 'newRole': newRole}
      );
    }
  }
  
  /// Get user's achievement gallery
  static Future<Map<String, dynamic>> getAchievementGallery(String userId) async {
    try {
      final achievements = await _firestore
          .collection('achievement_timeline')
          .where('userId', isEqualTo: userId)
          .orderBy('unlockedAt', descending: true)
          .get();
      
      final certificates = await _firestore
          .collection('certificates')
          .where('userId', isEqualTo: userId)
          .orderBy('promotionDate', descending: true)
          .get();
      
      final badges = await _firestore
          .collection('user_badges')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('displayOrder')
          .get();
      
      return {
        'achievements': achievements.docs.map((doc) => doc.data()).toList(),
        'certificates': certificates.docs.map((doc) => doc.data()).toList(),
        'badges': badges.docs.map((doc) => doc.data()).toList(),
        'totalPoints': _calculateTotalPoints(achievements.docs),
        'categories': _categorizeAchievements(achievements.docs),
        'milestones': _calculateMilestones(achievements.docs),
      };
    } catch (e) {
      throw RecognitionRetentionException(
        'Failed to get achievement gallery: $e',
        'GALLERY_RETRIEVAL_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Download certificate
  static Future<String> downloadCertificate(String certificateId) async {
    try {
      final certificateDoc = await _firestore
          .collection('certificates')
          .doc(certificateId)
          .get();
      
      if (!certificateDoc.exists) {
        throw RecognitionRetentionException(
          'Certificate not found',
          'CERTIFICATE_NOT_FOUND',
          {'certificateId': certificateId}
        );
      }
      
      final certificateData = certificateDoc.data()!;
      final certificate = PromotionCertificate.fromMap({
        'id': certificateDoc.id,
        ...certificateData,
      });
      
      // Mark as downloaded
      await _firestore
          .collection('certificates')
          .doc(certificateId)
          .update({
            'isDownloaded': true,
            'downloadedAt': FieldValue.serverTimestamp(),
          });
      
      // In a real implementation, this would download the actual file
      // For now, return the certificate URL
      return certificate.certificateUrl;
    } catch (e) {
      throw RecognitionRetentionException(
        'Failed to download certificate: $e',
        'CERTIFICATE_DOWNLOAD_FAILED',
        {'certificateId': certificateId}
      );
    }
  }
  
  /// Private helper methods
  
  static String _generateCertificateId() {
    return 'cert_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  static String _generateBadgeId() {
    return 'badge_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  static String _generateDigitalSignature({
    required String userId,
    required String userName,
    required String oldRole,
    required String newRole,
    required DateTime promotionDate,
  }) {
    // In a real implementation, this would generate a cryptographic signature
    final data = '$userId:$userName:$oldRole:$newRole:${promotionDate.millisecondsSinceEpoch}';
    return 'TALOWA_CERT_${data.hashCode.abs()}';
  }
  
  static Future<String> _generateCertificateImage({
    required String certificateId,
    required String userName,
    required String userPhotoUrl,
    required String oldRole,
    required String newRole,
    required DateTime promotionDate,
    required String digitalSignature,
  }) async {
    // In a real implementation, this would generate an actual certificate image
    // For now, return a placeholder URL
    return 'https://certificates.talowa.app/$certificateId.png';
  }
  
  static Future<String> _generateBadgeImage(
    String role,
    Map<String, dynamic> achievements,
    Map<String, dynamic> statistics,
  ) async {
    // In a real implementation, this would generate an actual badge image
    // For now, return a placeholder URL
    return 'https://badges.talowa.app/${role}_badge.png';
  }
  
  static String _formatRoleName(String role) {
    return role.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
  
  static int _getRoleDisplayOrder(String role) {
    const roleOrder = {
      'member': 1,
      'organizer': 2,
      'coordinator': 3,
      'regional_coordinator': 4,
      'national_coordinator': 5,
    };
    return roleOrder[role] ?? 0;
  }
  
  static Map<String, Color> _getRoleColors(String role) {
    final roleColors = <String, Map<String, Color>>{
      'member': {'primary': Colors.blue.shade500, 'secondary': Colors.lightBlue.shade300},
      'organizer': {'primary': Colors.green.shade500, 'secondary': Colors.lightGreen.shade300},
      'coordinator': {'primary': Colors.orange.shade500, 'secondary': Colors.deepOrange.shade300},
      'regional_coordinator': {'primary': Colors.purple.shade500, 'secondary': Colors.deepPurple.shade300},
      'national_coordinator': {'primary': Colors.red.shade500, 'secondary': Colors.pink.shade300},
    };
    return roleColors[role] ?? {'primary': Colors.grey.shade500, 'secondary': Colors.grey.shade300};
  }

  static Map<String, int> _serializeRoleColors(Map<String, Color> colors) {
    return colors.map((key, color) => MapEntry(key, color.toARGB32()));
  }
  
  static Map<String, dynamic> _getRoleFeatures(String role) {
    const roleFeatures = {
      'member': {
        'canRefer': true,
        'canViewTeam': false,
        'canManageTeam': false,
        'canAccessAnalytics': false,
        'canCreateEvents': false,
      },
      'organizer': {
        'canRefer': true,
        'canViewTeam': true,
        'canManageTeam': true,
        'canAccessAnalytics': true,
        'canCreateEvents': false,
      },
      'coordinator': {
        'canRefer': true,
        'canViewTeam': true,
        'canManageTeam': true,
        'canAccessAnalytics': true,
        'canCreateEvents': true,
      },
    };
    return roleFeatures[role] ?? roleFeatures['member']!;
  }
  
  static List<String> _getNewFeatures(String oldRole, String newRole) {
    final oldFeatures = _getRoleFeatures(oldRole);
    final newFeatures = _getRoleFeatures(newRole);
    
    final newlyUnlocked = <String>[];
    for (final entry in newFeatures.entries) {
      if (entry.value == true && oldFeatures[entry.key] != true) {
        newlyUnlocked.add(entry.key);
      }
    }
    
    return newlyUnlocked;
  }
  
  static Map<String, dynamic> _createGuidedTour(String role, List<String> newFeatures) {
    return {
      'role': role,
      'newFeatures': newFeatures,
      'steps': newFeatures.map((feature) => {
        'feature': feature,
        'title': _getFeatureTitle(feature),
        'description': _getFeatureDescription(feature),
        'action': _getFeatureAction(feature),
      }).toList(),
      'duration': Duration(minutes: 5).inMilliseconds,
    };
  }
  
  static String _getFeatureTitle(String feature) {
    const titles = {
      'canViewTeam': 'View Your Team',
      'canManageTeam': 'Manage Team Members',
      'canAccessAnalytics': 'Access Analytics',
      'canCreateEvents': 'Create Events',
    };
    return titles[feature] ?? feature;
  }
  
  static String _getFeatureDescription(String feature) {
    const descriptions = {
      'canViewTeam': 'See all your team members and their progress',
      'canManageTeam': 'Help and guide your team members',
      'canAccessAnalytics': 'View detailed analytics and reports',
      'canCreateEvents': 'Organize events for your community',
    };
    return descriptions[feature] ?? 'New feature unlocked';
  }
  
  static String _getFeatureAction(String feature) {
    const actions = {
      'canViewTeam': 'view_team',
      'canManageTeam': 'manage_team',
      'canAccessAnalytics': 'view_analytics',
      'canCreateEvents': 'create_event',
    };
    return actions[feature] ?? 'explore';
  }
  
  static List<String> _getRoleTitles(String role) {
    const roleTitles = {
      'member': ['Member', 'Community Member'],
      'organizer': ['Organizer', 'Team Leader', 'Community Organizer'],
      'coordinator': ['Coordinator', 'Regional Leader', 'Community Coordinator'],
    };
    return roleTitles[role] ?? ['Member'];
  }
  
  static List<Map<String, dynamic>> _getDisplayBadges(List<Achievement> achievements) {
    return achievements
        .where((a) => a.category == 'badge')
        .map((a) => {
          'id': a.id,
          'name': a.name,
          'badgeUrl': a.badgeUrl,
          'unlockedAt': a.unlockedAt.toIso8601String(),
        })
        .toList();
  }
  
  static String _calculateMilestone(Achievement achievement) {
    if (achievement.points >= 1000) return 'legendary';
    if (achievement.points >= 500) return 'epic';
    if (achievement.points >= 100) return 'rare';
    return 'common';
  }
  
  static Future<void> _updateUserAchievementPoints(String userId, int points) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .set({
          'achievementPoints': FieldValue.increment(points),
          'lastAchievementUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
  
  static int _calculateTotalPoints(List<QueryDocumentSnapshot> achievements) {
    return achievements.fold(0, (total, doc) {
      final data = doc.data() as Map<String, dynamic>;
      return total + (data['points'] as int? ?? 0);
    });
  }
  
  static Map<String, List<Map<String, dynamic>>> _categorizeAchievements(
    List<QueryDocumentSnapshot> achievements,
  ) {
    final categories = <String, List<Map<String, dynamic>>>{};
    
    for (final doc in achievements) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['achievementCategory'] as String? ?? 'general';
      
      categories[category] ??= [];
      categories[category]!.add(data);
    }
    
    return categories;
  }
  
  static List<Map<String, dynamic>> _calculateMilestones(
    List<QueryDocumentSnapshot> achievements,
  ) {
    final milestones = <Map<String, dynamic>>[];
    final totalPoints = _calculateTotalPoints(achievements);
    
    const milestoneThresholds = [100, 500, 1000, 2500, 5000, 10000];
    
    for (final threshold in milestoneThresholds) {
      milestones.add({
        'threshold': threshold,
        'achieved': totalPoints >= threshold,
        'progress': totalPoints / threshold,
        'title': _getMilestoneTitle(threshold),
        'description': _getMilestoneDescription(threshold),
      });
    }
    
    return milestones;
  }
  
  static String _getMilestoneTitle(int threshold) {
    const titles = {
      100: 'Getting Started',
      500: 'Rising Star',
      1000: 'Community Builder',
      2500: 'Team Leader',
      5000: 'Regional Champion',
      10000: 'Legendary Achiever',
    };
    return titles[threshold] ?? 'Milestone';
  }
  
  static String _getMilestoneDescription(int threshold) {
    return 'Reach $threshold achievement points';
  }
  
  static String _generateStoryTemplate(String type, String title, String description) {
    return 'story_template_${type}_${DateTime.now().millisecondsSinceEpoch}.png';
  }
  
  static String _generatePostTemplate(String type, String title, String description) {
    return 'post_template_${type}_${DateTime.now().millisecondsSinceEpoch}.png';
  }
}
