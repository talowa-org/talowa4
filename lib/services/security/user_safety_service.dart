// User Safety Service for TALOWA
// Provides user report/block features and lightweight harassment analysis

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../safety/safe_browsing_service.dart'; // For RiskLevel enum

enum UserReportReason {
  harassment,
  spam,
  inappropriateContent,
  impersonation,
  threats,
  hateSpeech,
  other,
}

class HarassmentAnalysis {
  final RiskLevel riskLevel;
  final List<String> detectedPatterns;
  final List<String> recommendations;
  final int reportCount;

  HarassmentAnalysis({
    required this.riskLevel,
    required this.detectedPatterns,
    required this.recommendations,
    this.reportCount = 0,
  });
}

class BlockedUser {
  final String userId;
  final String name;
  final String? avatarUrl;
  final DateTime blockedAt;
  final String? reason;

  BlockedUser({
    required this.userId,
    required this.name,
    required this.blockedAt,
    this.avatarUrl,
    this.reason,
  });
}

class UserSafetyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> reportUser({
    required String reporterId,
    required String reportedUserId,
    required UserReportReason reason,
    String? description,
  }) async {
    try {
      final ref = await _firestore.collection('user_reports').add({
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reason': reason.toString(),
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('Error reporting user: $e');
      rethrow;
    }
  }

  Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
    String? reason,
  }) async {
    try {
      // Use deterministic doc id to avoid duplicates
      final docId = '${blockerId}_$blockedUserId';
      await _firestore.collection('blocked_users').doc(docId).set({
        'blockerId': blockerId,
        'blockedUserId': blockedUserId,
        'reason': reason,
        // Optional display fields if available later
        'name': null,
        'avatarUrl': null,
        'blockedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error blocking user: $e');
      rethrow;
    }
  }

  Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      final docId = '${blockerId}_$blockedUserId';
      await _firestore.collection('blocked_users').doc(docId).delete();
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      rethrow;
    }
  }

  Future<List<BlockedUser>> getBlockedUsers(String blockerId) async {
    try {
      final snap = await _firestore
          .collection('blocked_users')
          .where('blockerId', isEqualTo: blockerId)
          .orderBy('blockedAt', descending: true)
          .get();

      return snap.docs.map((d) {
        final data = d.data();
        DateTime blockedAt;
        final ts = data['blockedAt'];
        if (ts is Timestamp) {
          blockedAt = ts.toDate();
        } else {
          blockedAt = DateTime.now();
        }
        return BlockedUser(
          userId: data['blockedUserId'] ?? '',
          name: data['name'] ?? 'Unknown User',
          avatarUrl: data['avatarUrl'],
          blockedAt: blockedAt,
          reason: data['reason'],
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
      rethrow;
    }
  }

  Future<HarassmentAnalysis> analyzeHarassmentPattern({
    required String userId,
    required String targetUserId,
    required List<String> recentMessages,
  }) async {
    try {
      // Simple heuristic analysis based on keywords and frequency
      final patterns = <String>[];
      final recs = <String>[];

      const harassmentKeywords = [
        'idiot', 'stupid', 'hate', 'kill', 'threat', 'abuse', 'die', 'attack',
        'fake', 'scam', 'fraud', 'harass', 'spam', 'suck', 'dumb'
      ];

      int hits = 0;
      for (final m in recentMessages) {
        final lower = m.toLowerCase();
        for (final k in harassmentKeywords) {
          if (lower.contains(k)) {
            hits += 1;
            patterns.add('keyword:$k');
          }
        }
      }

      RiskLevel level;
      if (hits >= 8 || recentMessages.length > 150) {
        level = RiskLevel.critical;
        recs.addAll([
          'Block the user to stop further contact',
          'Report the user for immediate review',
        ]);
      } else if (hits >= 4 || recentMessages.length > 100) {
        level = RiskLevel.high;
        recs.addAll([
          'Consider blocking the user',
          'Report the user if behavior continues',
        ]);
      } else if (hits >= 2 || recentMessages.length > 50) {
        level = RiskLevel.medium;
        recs.add('Mute or warn the user');
      } else {
        level = RiskLevel.low;
        recs.add('Monitor the conversation');
      }

      return HarassmentAnalysis(
        riskLevel: level,
        detectedPatterns: patterns.toSet().toList(),
        recommendations: recs,
        reportCount: 0,
      );
    } catch (e) {
      debugPrint('Error analyzing harassment pattern: $e');
      return HarassmentAnalysis(
        riskLevel: RiskLevel.low,
        detectedPatterns: const [],
        recommendations: const ['Monitor the conversation'],
      );
    }
  }
}