import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/voice_call.dart';
import '../auth_service.dart';

/// Service for managing call history and missed call notifications
class CallHistoryService {
  static final CallHistoryService _instance = CallHistoryService._internal();
  factory CallHistoryService() => _instance;
  CallHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Collections
  static const String _callHistoryCollection = 'call_history';
  static const String _missedCallsCollection = 'missed_calls';

  /// Save a call to history
  Future<void> saveCallToHistory(CallSession callSession) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return;

      final otherParticipant = callSession.getOtherParticipant(currentUserId);
      if (otherParticipant == null) return;

      final historyEntry = CallHistoryEntry(
        id: callSession.id,
        participantId: otherParticipant.userId,
        participantName: otherParticipant.name,
        participantRole: otherParticipant.role,
        callType: 'voice', // For now, only voice calls
        status: _getCallStatus(callSession.status),
        startTime: callSession.startTime,
        endTime: callSession.endTime,
        duration: callSession.duration,
        isIncoming: _isIncomingCall(callSession, currentUserId),
        isEncrypted: callSession.isEncrypted,
      );

      // Save to user's call history
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_callHistoryCollection)
          .doc(callSession.id)
          .set(historyEntry.toJson());

      debugPrint('Call saved to history: ${callSession.id}');
    } catch (e) {
      debugPrint('Failed to save call to history: $e');
    }
  }

  /// Get call history for current user
  Future<List<CallHistoryEntry>> getCallHistory({
    int limit = 50,
    String? lastCallId,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return [];

      Query query = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_callHistoryCollection)
          .orderBy('startTime', descending: true)
          .limit(limit);

      // Pagination support
      if (lastCallId != null) {
        final lastDoc = await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection(_callHistoryCollection)
            .doc(lastCallId)
            .get();
        
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => CallHistoryEntry.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to get call history: $e');
      return [];
    }
  }

  /// Get call history stream for real-time updates
  Stream<List<CallHistoryEntry>> getCallHistoryStream({int limit = 50}) {
    return Stream.fromFuture(_authService.getCurrentUserId()).asyncExpand((currentUserId) {
      if (currentUserId == null) {
        return Stream.value(<CallHistoryEntry>[]);
      }

      return _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_callHistoryCollection)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => CallHistoryEntry.fromJson(doc.data()))
              .toList());
    });
  }

  /// Save missed call notification
  Future<void> saveMissedCall(IncomingCall incomingCall) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return;

      final missedCall = MissedCallNotification(
        id: incomingCall.id,
        callerId: incomingCall.callerId,
        callerName: incomingCall.callerName,
        callerRole: incomingCall.callerRole,
        timestamp: incomingCall.timestamp,
        isRead: false,
      );

      // Save to user's missed calls
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_missedCallsCollection)
          .doc(incomingCall.id)
          .set(missedCall.toJson());

      // Also save to call history as missed
      final historyEntry = CallHistoryEntry(
        id: incomingCall.id,
        participantId: incomingCall.callerId,
        participantName: incomingCall.callerName,
        participantRole: incomingCall.callerRole,
        callType: incomingCall.callType,
        status: 'missed',
        startTime: incomingCall.timestamp,
        endTime: null,
        duration: 0,
        isIncoming: true,
        isEncrypted: true,
      );

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_callHistoryCollection)
          .doc(incomingCall.id)
          .set(historyEntry.toJson());

      debugPrint('Missed call saved: ${incomingCall.id}');
    } catch (e) {
      debugPrint('Failed to save missed call: $e');
    }
  }

  /// Get missed call notifications
  Future<List<MissedCallNotification>> getMissedCalls({
    bool unreadOnly = false,
    int limit = 20,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return [];

      Query query = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_missedCallsCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => MissedCallNotification.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to get missed calls: $e');
      return [];
    }
  }

  /// Get missed calls stream
  Stream<List<MissedCallNotification>> getMissedCallsStream({
    bool unreadOnly = false,
    int limit = 20,
  }) {
    return Stream.fromFuture(_authService.getCurrentUserId()).asyncExpand((currentUserId) {
      if (currentUserId == null) {
        return Stream.value(<MissedCallNotification>[]);
      }

      Query query = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_missedCallsCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      return query.snapshots().map((snapshot) => snapshot.docs
          .map((doc) => MissedCallNotification.fromJson(doc.data() as Map<String, dynamic>))
          .toList());
    });
  }

  /// Mark missed call as read
  Future<void> markMissedCallAsRead(String callId) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_missedCallsCollection)
          .doc(callId)
          .update({'isRead': true});

      debugPrint('Missed call marked as read: $callId');
    } catch (e) {
      debugPrint('Failed to mark missed call as read: $e');
    }
  }

  /// Mark all missed calls as read
  Future<void> markAllMissedCallsAsRead() async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return;

      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_missedCallsCollection)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      debugPrint('All missed calls marked as read');
    } catch (e) {
      debugPrint('Failed to mark all missed calls as read: $e');
    }
  }

  /// Get unread missed calls count
  Future<int> getUnreadMissedCallsCount() async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return 0;

      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_missedCallsCollection)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Failed to get unread missed calls count: $e');
      return 0;
    }
  }

  /// Delete call from history
  Future<void> deleteCallFromHistory(String callId) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_callHistoryCollection)
          .doc(callId)
          .delete();

      debugPrint('Call deleted from history: $callId');
    } catch (e) {
      debugPrint('Failed to delete call from history: $e');
    }
  }

  /// Clear all call history
  Future<void> clearCallHistory() async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return;

      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_callHistoryCollection)
          .get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Call history cleared');
    } catch (e) {
      debugPrint('Failed to clear call history: $e');
    }
  }

  /// Get call statistics
  Future<Map<String, dynamic>> getCallStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return {};

      Query query = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(_callHistoryCollection);

      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: endDate.millisecondsSinceEpoch);
      }

      final snapshot = await query.get();
      final calls = snapshot.docs
          .map((doc) => CallHistoryEntry.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      int totalCalls = calls.length;
      int completedCalls = calls.where((c) => c.status == 'completed').length;
      int missedCalls = calls.where((c) => c.status == 'missed').length;
      int rejectedCalls = calls.where((c) => c.status == 'rejected').length;
      int failedCalls = calls.where((c) => c.status == 'failed').length;
      int incomingCalls = calls.where((c) => c.isIncoming).length;
      int outgoingCalls = calls.where((c) => !c.isIncoming).length;
      int totalDuration = calls.fold(0, (sum, call) => sum + call.duration);

      return {
        'totalCalls': totalCalls,
        'completedCalls': completedCalls,
        'missedCalls': missedCalls,
        'rejectedCalls': rejectedCalls,
        'failedCalls': failedCalls,
        'incomingCalls': incomingCalls,
        'outgoingCalls': outgoingCalls,
        'totalDuration': totalDuration,
        'averageDuration': totalCalls > 0 ? (totalDuration / totalCalls).round() : 0,
        'successRate': totalCalls > 0 ? ((completedCalls / totalCalls) * 100).round() : 0,
      };
    } catch (e) {
      debugPrint('Failed to get call statistics: $e');
      return {};
    }
  }

  // Private helper methods

  String _getCallStatus(String sessionStatus) {
    switch (sessionStatus) {
      case 'connected':
        return 'completed';
      case 'ended':
        return 'completed';
      case 'failed':
        return 'failed';
      case 'rejected':
        return 'rejected';
      default:
        return 'missed';
    }
  }

  bool _isIncomingCall(CallSession callSession, String currentUserId) {
    // Assume first participant is the caller
    return callSession.participants.isNotEmpty && 
           callSession.participants.first.userId != currentUserId;
  }
}