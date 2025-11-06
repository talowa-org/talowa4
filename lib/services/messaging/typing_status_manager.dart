// Typing Status Manager for TALOWA Messaging
// Manages typing indicators across conversations

import 'dart:async';
import 'package:flutter/foundation.dart';

class TypingStatusManager {
  static final Map<String, List<String>> _typingUsers = {};
  static final Map<String, StreamController<List<String>>> _controllers = {};
  static final Map<String, Timer> _typingTimers = {};

  /// Add a typing listener for a conversation
  static void addListener(String conversationId, Function(List<String>) callback) {
    if (!_controllers.containsKey(conversationId)) {
      _controllers[conversationId] = StreamController<List<String>>.broadcast();
      _typingUsers[conversationId] = [];
    }
    
    _controllers[conversationId]!.stream.listen(callback);
  }

  /// Remove typing listener for a conversation
  static void removeListener(String conversationId) {
    _controllers[conversationId]?.close();
    _controllers.remove(conversationId);
    _typingUsers.remove(conversationId);
    _typingTimers[conversationId]?.cancel();
    _typingTimers.remove(conversationId);
  }

  /// Start typing for a user in a conversation
  static void startTyping(String conversationId, String userId, String userName) {
    if (!_typingUsers.containsKey(conversationId)) {
      _typingUsers[conversationId] = [];
    }

    final typingList = _typingUsers[conversationId]!;
    if (!typingList.contains(userName)) {
      typingList.add(userName);
      _notifyListeners(conversationId);
    }

    // Auto-stop typing after 3 seconds
    final timerKey = '${conversationId}_$userId';
    _typingTimers[timerKey]?.cancel();
    _typingTimers[timerKey] = Timer(const Duration(seconds: 3), () {
      stopTyping(conversationId, userId, userName);
    });
  }

  /// Stop typing for a user in a conversation
  static void stopTyping(String conversationId, String userId, String userName) {
    if (_typingUsers.containsKey(conversationId)) {
      _typingUsers[conversationId]!.remove(userName);
      _notifyListeners(conversationId);
    }

    final timerKey = '${conversationId}_$userId';
    _typingTimers[timerKey]?.cancel();
    _typingTimers.remove(timerKey);
  }

  /// Notify listeners of typing status changes
  static void _notifyListeners(String conversationId) {
    if (_controllers.containsKey(conversationId)) {
      final typingList = _typingUsers[conversationId] ?? [];
      _controllers[conversationId]!.add(List.from(typingList));
    }
  }

  /// Get current typing users for a conversation
  static List<String> getTypingUsers(String conversationId) {
    return List.from(_typingUsers[conversationId] ?? []);
  }

  /// Clear all typing status
  static void clearAll() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    
    _controllers.clear();
    _typingUsers.clear();
    _typingTimers.clear();
  }
}