// Message Threading and Chronological Ordering Service for TALOWA
// Implements Task 5: Implement chronological message ordering and proper message threading
// Reference: in-app-communication/requirements.md - Requirements 5.3, 5.4

import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';

class MessageThreadingService {
  static final MessageThreadingService _instance = MessageThreadingService._internal();
  factory MessageThreadingService() => _instance;
  MessageThreadingService._internal();

  // Threading configuration
  static const Duration threadingWindow = Duration(minutes: 5);
  static const int maxThreadDepth = 3;
  static const int minMessagesForThread = 2;

  /// Sort messages chronologically with proper threading
  List<MessageModel> sortMessagesChronologically({
    required List<MessageModel> messages,
    bool ascending = false,
    bool enableThreading = true,
  }) {
    try {
      if (messages.isEmpty) return messages;

      // First, sort by timestamp
      final sortedMessages = List<MessageModel>.from(messages);
      sortedMessages.sort((a, b) {
        final comparison = a.sentAt.compareTo(b.sentAt);
        return ascending ? comparison : -comparison;
      });

      // Apply threading if enabled
      if (enableThreading) {
        return _applyMessageThreading(sortedMessages);
      }

      return sortedMessages;
    } catch (e) {
      debugPrint('Error sorting messages chronologically: $e');
      return messages;
    }
  }

  /// Group messages into threads based on timing and sender patterns
  List<MessageThread> createMessageThreads({
    required List<MessageModel> messages,
    Duration? threadingWindow,
    int? maxThreadDepth,
  }) {
    try {
      if (messages.isEmpty) return [];

      final window = threadingWindow ?? MessageThreadingService.threadingWindow;
      final maxDepth = maxThreadDepth ?? MessageThreadingService.maxThreadDepth;
      
      // Sort messages chronologically first
      final sortedMessages = sortMessagesChronologically(
        messages: messages,
        ascending: true,
        enableThreading: false,
      );

      final threads = <MessageThread>[];
      MessageThread? currentThread;

      for (final message in sortedMessages) {
        if (currentThread == null || _shouldStartNewThread(currentThread, message, window)) {
          // Start new thread
          currentThread = MessageThread(
            id: 'thread_${message.id}',
            rootMessage: message,
            messages: [message],
            participants: {message.senderId},
            startTime: message.sentAt,
            endTime: message.sentAt,
          );
          threads.add(currentThread);
        } else {
          // Add to current thread
          currentThread = currentThread.copyWith(
            messages: [...currentThread.messages, message],
            participants: {...currentThread.participants, message.senderId},
            endTime: message.sentAt,
          );
          threads[threads.length - 1] = currentThread;
        }

        // Check if thread is getting too deep
        if (currentThread.messages.length > maxDepth) {
          currentThread = null; // Force new thread on next message
        }
      }

      // Filter out single-message threads if they don't meet criteria
      return threads.where((thread) => 
          thread.messages.length >= minMessagesForThread ||
          thread.hasMultipleParticipants ||
          thread.duration.inMinutes > 1
      ).toList();
    } catch (e) {
      debugPrint('Error creating message threads: $e');
      return [];
    }
  }

  /// Merge messages from different sources while maintaining chronological order
  List<MessageModel> mergeMessageSources({
    required List<List<MessageModel>> messageSources,
    bool removeDuplicates = true,
    bool enableThreading = true,
  }) {
    try {
      if (messageSources.isEmpty) return [];

      final allMessages = <MessageModel>[];
      final messageIds = <String>{};

      // Combine all message sources
      for (final source in messageSources) {
        for (final message in source) {
          if (!removeDuplicates || !messageIds.contains(message.id)) {
            allMessages.add(message);
            messageIds.add(message.id);
          }
        }
      }

      // Sort chronologically
      return sortMessagesChronologically(
        messages: allMessages,
        enableThreading: enableThreading,
      );
    } catch (e) {
      debugPrint('Error merging message sources: $e');
      return [];
    }
  }

  /// Insert new message into existing chronologically sorted list
  List<MessageModel> insertMessageChronologically({
    required List<MessageModel> existingMessages,
    required MessageModel newMessage,
    bool maintainThreading = true,
  }) {
    try {
      final updatedMessages = List<MessageModel>.from(existingMessages);
      
      // Find insertion point
      int insertIndex = 0;
      for (int i = 0; i < updatedMessages.length; i++) {
        if (newMessage.sentAt.isAfter(updatedMessages[i].sentAt)) {
          insertIndex = i;
          break;
        }
        insertIndex = i + 1;
      }

      updatedMessages.insert(insertIndex, newMessage);

      // Re-apply threading if needed
      if (maintainThreading) {
        return _applyMessageThreading(updatedMessages);
      }

      return updatedMessages;
    } catch (e) {
      debugPrint('Error inserting message chronologically: $e');
      return [...existingMessages, newMessage];
    }
  }

  /// Update message in chronologically sorted list
  List<MessageModel> updateMessageInList({
    required List<MessageModel> messages,
    required MessageModel updatedMessage,
    bool maintainThreading = true,
  }) {
    try {
      final updatedMessages = messages.map((message) {
        return message.id == updatedMessage.id ? updatedMessage : message;
      }).toList();

      // Re-sort if timestamp changed
      final originalMessage = messages.firstWhere(
        (msg) => msg.id == updatedMessage.id,
        orElse: () => updatedMessage,
      );

      if (originalMessage.sentAt != updatedMessage.sentAt) {
        return sortMessagesChronologically(
          messages: updatedMessages,
          enableThreading: maintainThreading,
        );
      }

      return updatedMessages;
    } catch (e) {
      debugPrint('Error updating message in list: $e');
      return messages;
    }
  }

  /// Remove message from chronologically sorted list
  List<MessageModel> removeMessageFromList({
    required List<MessageModel> messages,
    required String messageId,
    bool maintainThreading = true,
  }) {
    try {
      final updatedMessages = messages
          .where((message) => message.id != messageId)
          .toList();

      // Re-apply threading if needed
      if (maintainThreading) {
        return _applyMessageThreading(updatedMessages);
      }

      return updatedMessages;
    } catch (e) {
      debugPrint('Error removing message from list: $e');
      return messages;
    }
  }

  /// Get message context (messages before and after)
  MessageContext getMessageContext({
    required List<MessageModel> messages,
    required String messageId,
    int contextSize = 5,
  }) {
    try {
      final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex == -1) {
        return MessageContext(
          targetMessage: null,
          messagesBefore: [],
          messagesAfter: [],
        );
      }

      final targetMessage = messages[messageIndex];
      
      final startIndex = (messageIndex - contextSize).clamp(0, messages.length);
      final endIndex = (messageIndex + contextSize + 1).clamp(0, messages.length);
      
      final messagesBefore = messages.sublist(startIndex, messageIndex);
      final messagesAfter = messages.sublist(messageIndex + 1, endIndex);

      return MessageContext(
        targetMessage: targetMessage,
        messagesBefore: messagesBefore,
        messagesAfter: messagesAfter,
      );
    } catch (e) {
      debugPrint('Error getting message context: $e');
      return MessageContext(
        targetMessage: null,
        messagesBefore: [],
        messagesAfter: [],
      );
    }
  }

  /// Analyze message patterns for threading insights
  ThreadingAnalysis analyzeMessagePatterns({
    required List<MessageModel> messages,
    Duration? analysisWindow,
  }) {
    try {
      if (messages.isEmpty) {
        return ThreadingAnalysis(
          totalMessages: 0,
          uniqueSenders: 0,
          averageTimeBetweenMessages: Duration.zero,
          threadingOpportunities: 0,
          conversationPeaks: [],
        );
      }

      final window = analysisWindow ?? const Duration(hours: 24);
      final cutoffTime = DateTime.now().subtract(window);
      final recentMessages = messages
          .where((msg) => msg.sentAt.isAfter(cutoffTime))
          .toList();

      // Calculate statistics
      final uniqueSenders = recentMessages
          .map((msg) => msg.senderId)
          .toSet()
          .length;

      Duration totalTimeBetween = Duration.zero;
      int timeBetweenCount = 0;

      for (int i = 1; i < recentMessages.length; i++) {
        final timeBetween = recentMessages[i].sentAt
            .difference(recentMessages[i - 1].sentAt);
        totalTimeBetween += timeBetween;
        timeBetweenCount++;
      }

      final averageTimeBetween = timeBetweenCount > 0
          ? Duration(milliseconds: totalTimeBetween.inMilliseconds ~/ timeBetweenCount)
          : Duration.zero;

      // Find threading opportunities
      int threadingOpportunities = 0;
      for (int i = 1; i < recentMessages.length; i++) {
        final timeBetween = recentMessages[i].sentAt
            .difference(recentMessages[i - 1].sentAt);
        if (timeBetween <= threadingWindow) {
          threadingOpportunities++;
        }
      }

      // Find conversation peaks (high activity periods)
      final conversationPeaks = _findConversationPeaks(recentMessages);

      return ThreadingAnalysis(
        totalMessages: recentMessages.length,
        uniqueSenders: uniqueSenders,
        averageTimeBetweenMessages: averageTimeBetween,
        threadingOpportunities: threadingOpportunities,
        conversationPeaks: conversationPeaks,
      );
    } catch (e) {
      debugPrint('Error analyzing message patterns: $e');
      return ThreadingAnalysis(
        totalMessages: 0,
        uniqueSenders: 0,
        averageTimeBetweenMessages: Duration.zero,
        threadingOpportunities: 0,
        conversationPeaks: [],
      );
    }
  }

  // Private helper methods

  /// Apply message threading to sorted messages
  List<MessageModel> _applyMessageThreading(List<MessageModel> sortedMessages) {
    try {
      if (sortedMessages.length < 2) return sortedMessages;

      final threadedMessages = <MessageModel>[];
      final threads = createMessageThreads(messages: sortedMessages);

      for (final thread in threads) {
        threadedMessages.addAll(thread.messages);
      }

      // Add any messages not included in threads
      final threadedMessageIds = threadedMessages.map((msg) => msg.id).toSet();
      final unthreadedMessages = sortedMessages
          .where((msg) => !threadedMessageIds.contains(msg.id))
          .toList();

      threadedMessages.addAll(unthreadedMessages);

      // Final sort to ensure chronological order
      threadedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      return threadedMessages;
    } catch (e) {
      debugPrint('Error applying message threading: $e');
      return sortedMessages;
    }
  }

  /// Determine if a new thread should be started
  bool _shouldStartNewThread(
    MessageThread currentThread,
    MessageModel newMessage,
    Duration threadingWindow,
  ) {
    try {
      // Check time gap
      final timeSinceLastMessage = newMessage.sentAt
          .difference(currentThread.endTime);
      
      if (timeSinceLastMessage > threadingWindow) {
        return true;
      }

      // Check if it's a different conversation pattern
      final lastMessage = currentThread.messages.last;
      
      // Different sender after a gap might indicate new topic
      if (newMessage.senderId != lastMessage.senderId &&
          timeSinceLastMessage > const Duration(minutes: 2)) {
        return true;
      }

      // Check message type changes
      if (newMessage.messageType != lastMessage.messageType &&
          newMessage.messageType == MessageType.system) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error determining thread start: $e');
      return false;
    }
  }

  /// Find conversation peaks (periods of high activity)
  List<ConversationPeak> _findConversationPeaks(List<MessageModel> messages) {
    try {
      if (messages.length < 10) return [];

      final peaks = <ConversationPeak>[];
      const peakWindow = Duration(minutes: 15);
      const minMessagesForPeak = 5;

      // Group messages by time windows
      final timeWindows = <DateTime, List<MessageModel>>{};
      
      for (final message in messages) {
        final windowStart = DateTime(
          message.sentAt.year,
          message.sentAt.month,
          message.sentAt.day,
          message.sentAt.hour,
          (message.sentAt.minute ~/ 15) * 15,
        );
        
        timeWindows.putIfAbsent(windowStart, () => []).add(message);
      }

      // Find peaks
      for (final entry in timeWindows.entries) {
        if (entry.value.length >= minMessagesForPeak) {
          final participants = entry.value
              .map((msg) => msg.senderId)
              .toSet();
          
          peaks.add(ConversationPeak(
            startTime: entry.key,
            endTime: entry.key.add(peakWindow),
            messageCount: entry.value.length,
            participantCount: participants.length,
            participants: participants.toList(),
          ));
        }
      }

      // Sort peaks by message count (highest first)
      peaks.sort((a, b) => b.messageCount.compareTo(a.messageCount));

      return peaks.take(5).toList(); // Return top 5 peaks
    } catch (e) {
      debugPrint('Error finding conversation peaks: $e');
      return [];
    }
  }
}

// Data models for message threading

class MessageThread {
  final String id;
  final MessageModel rootMessage;
  final List<MessageModel> messages;
  final Set<String> participants;
  final DateTime startTime;
  final DateTime endTime;

  MessageThread({
    required this.id,
    required this.rootMessage,
    required this.messages,
    required this.participants,
    required this.startTime,
    required this.endTime,
  });

  MessageThread copyWith({
    String? id,
    MessageModel? rootMessage,
    List<MessageModel>? messages,
    Set<String>? participants,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return MessageThread(
      id: id ?? this.id,
      rootMessage: rootMessage ?? this.rootMessage,
      messages: messages ?? this.messages,
      participants: participants ?? this.participants,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Duration get duration => endTime.difference(startTime);
  int get messageCount => messages.length;
  bool get hasMultipleParticipants => participants.length > 1;
  bool get isLongThread => duration.inMinutes > 10;
  bool get isActiveThread => messageCount > 5;
}

class MessageContext {
  final MessageModel? targetMessage;
  final List<MessageModel> messagesBefore;
  final List<MessageModel> messagesAfter;

  MessageContext({
    required this.targetMessage,
    required this.messagesBefore,
    required this.messagesAfter,
  });

  int get totalContextMessages => messagesBefore.length + messagesAfter.length;
  bool get hasContext => totalContextMessages > 0;
  bool get hasMessagesBefore => messagesBefore.isNotEmpty;
  bool get hasMessagesAfter => messagesAfter.isNotEmpty;
}

class ThreadingAnalysis {
  final int totalMessages;
  final int uniqueSenders;
  final Duration averageTimeBetweenMessages;
  final int threadingOpportunities;
  final List<ConversationPeak> conversationPeaks;

  ThreadingAnalysis({
    required this.totalMessages,
    required this.uniqueSenders,
    required this.averageTimeBetweenMessages,
    required this.threadingOpportunities,
    required this.conversationPeaks,
  });

  double get threadingPotential => totalMessages > 0 
      ? threadingOpportunities / totalMessages 
      : 0.0;
  
  bool get isActiveConversation => totalMessages > 10 && uniqueSenders > 1;
  bool get hasGoodThreadingPotential => threadingPotential > 0.3;
}

class ConversationPeak {
  final DateTime startTime;
  final DateTime endTime;
  final int messageCount;
  final int participantCount;
  final List<String> participants;

  ConversationPeak({
    required this.startTime,
    required this.endTime,
    required this.messageCount,
    required this.participantCount,
    required this.participants,
  });

  Duration get duration => endTime.difference(startTime);
  double get messagesPerMinute => duration.inMinutes > 0 
      ? messageCount / duration.inMinutes 
      : 0.0;
  bool get isHighActivity => messagesPerMinute > 2.0;
}