// Emoji Reaction Service - Advanced emoji reactions and interactions
// Comprehensive emoji reaction system for TALOWA platform

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmojiReactionService {
  static EmojiReactionService? _instance;
  static EmojiReactionService get instance => _instance ??= EmojiReactionService._internal();
  
  EmojiReactionService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Emoji categories and reactions
  static const Map<String, List<String>> emojiCategories = {
    'support': ['ðŸ‘', 'â¤ï¸', 'ðŸ™', 'ðŸ’ª', 'âœŠ', 'ðŸ¤'],
    'emotions': ['ðŸ˜Š', 'ðŸ˜¢', 'ðŸ˜¡', 'ðŸ˜®', 'ðŸ˜', 'ðŸ¤”'],
    'activism': ['âš–ï¸', 'ðŸ›ï¸', 'ðŸ“¢', 'ðŸ”¥', 'ðŸ’¯', 'ðŸŽ¯'],
    'celebration': ['ðŸŽ‰', 'ðŸŽŠ', 'ðŸ‘', 'ðŸ¥³', 'ðŸŒŸ', 'ðŸ†'],
    'solidarity': ['âœŠ', 'ðŸ¤', 'ðŸ’ª', 'ðŸ™Œ', 'ðŸ‘¥', 'ðŸŒ'],
  };
  
  // Reaction animations
  final Map<String, List<EmojiAnimation>> _activeAnimations = {};
  
  /// Initialize emoji reaction service
  void initialize() {
    debugPrint('ðŸ˜Š Initializing Emoji Reaction Service...');
    
    // Setup emoji data
    _setupEmojiData();
    
    debugPrint('âœ… Emoji Reaction Service initialized');
  }
  
  /// Add emoji reaction to content
  Future<void> addReaction({
    required String contentId,
    required String contentType,
    required String emoji,
    String? userId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final reactionId = '${currentUser.uid}_$emoji';
      final reactionData = {
        'userId': currentUser.uid,
        'emoji': emoji,
        'timestamp': FieldValue.serverTimestamp(),
        'contentId': contentId,
        'contentType': contentType,
      };
      
      // Add reaction to Firestore
      await _firestore
          .collection('content_reactions')
          .doc(contentId)
          .collection('reactions')
          .doc(reactionId)
          .set(reactionData, SetOptions(merge: true));
      
      // Update reaction count
      await _updateReactionCount(contentId, emoji, 1);
      
      // Trigger haptic feedback
      HapticFeedback.lightImpact();
      
      debugPrint('ðŸ˜Š Added reaction: $emoji to $contentId');
      
    } catch (e) {
      debugPrint('âŒ Failed to add reaction: $e');
      rethrow;
    }
  }
  
  /// Remove emoji reaction from content
  Future<void> removeReaction({
    required String contentId,
    required String emoji,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final reactionId = '${currentUser.uid}_$emoji';
      
      // Remove reaction from Firestore
      await _firestore
          .collection('content_reactions')
          .doc(contentId)
          .collection('reactions')
          .doc(reactionId)
          .delete();
      
      // Update reaction count
      await _updateReactionCount(contentId, emoji, -1);
      
      debugPrint('ðŸ—‘ï¸ Removed reaction: $emoji from $contentId');
      
    } catch (e) {
      debugPrint('âŒ Failed to remove reaction: $e');
      rethrow;
    }
  }
  
  /// Get reactions for content
  Stream<Map<String, ReactionData>> getReactionsStream(String contentId) {
    return _firestore
        .collection('content_reactions')
        .doc(contentId)
        .collection('reactions')
        .snapshots()
        .map((snapshot) {
      final reactions = <String, ReactionData>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final emoji = data['emoji'] as String;
        
        if (reactions.containsKey(emoji)) {
          reactions[emoji] = reactions[emoji]!.copyWith(
            count: reactions[emoji]!.count + 1,
            users: [...reactions[emoji]!.users, data['userId'] as String],
          );
        } else {
          reactions[emoji] = ReactionData(
            emoji: emoji,
            count: 1,
            users: [data['userId'] as String],
          );
        }
      }
      
      return reactions;
    });
  }
  
  /// Create emoji reaction picker widget
  Widget createEmojiReactionPicker({
    required String contentId,
    required String contentType,
    Function(String)? onEmojiSelected,
    List<String>? customEmojis,
    bool showCategories = true,
  }) {
    return EmojiReactionPicker(
      contentId: contentId,
      contentType: contentType,
      onEmojiSelected: onEmojiSelected,
      customEmojis: customEmojis,
      showCategories: showCategories,
    );
  }
  
  /// Create floating emoji animation
  Widget createFloatingEmojiAnimation({
    required String emoji,
    required String animationId,
    Duration duration = const Duration(seconds: 3),
    double startY = 0.0,
    double endY = -100.0,
  }) {
    return FloatingEmojiAnimation(
      emoji: emoji,
      animationId: animationId,
      duration: duration,
      startY: startY,
      endY: endY,
    );
  }
  
  /// Trigger emoji burst animation
  void triggerEmojiBurst({
    required BuildContext context,
    required String emoji,
    required Offset position,
    int count = 5,
  }) {
    final overlay = Overlay.of(context);
    final random = Random();
    
    for (int i = 0; i < count; i++) {
      final animationId = '${emoji}_burst_${DateTime.now().millisecondsSinceEpoch}_$i';
      
      final offsetX = (random.nextDouble() - 0.5) * 100;
      final offsetY = (random.nextDouble() - 0.5) * 50;
      
      final entry = OverlayEntry(
        builder: (context) => Positioned(
          left: position.dx + offsetX,
          top: position.dy + offsetY,
          child: createFloatingEmojiAnimation(
            emoji: emoji,
            animationId: animationId,
            duration: Duration(milliseconds: 1500 + random.nextInt(1000)),
          ),
        ),
      );
      
      overlay.insert(entry);
      
      // Remove after animation
      Timer(const Duration(seconds: 3), () {
        entry.remove();
      });
    }
    
    HapticFeedback.mediumImpact();
  }
  
  /// Get emoji suggestions based on content
  List<String> getEmojiSuggestions(String content) {
    final suggestions = <String>[];
    final lowerContent = content.toLowerCase();
    
    // Analyze content for emotion keywords
    final emotionKeywords = {
      'happy': ['ðŸ˜Š', 'ðŸ˜„', 'ðŸŽ‰'],
      'sad': ['ðŸ˜¢', 'ðŸ˜ž', 'ðŸ’”'],
      'angry': ['ðŸ˜¡', 'ðŸ¤¬', 'ðŸ’¢'],
      'love': ['â¤ï¸', 'ðŸ˜', 'ðŸ’•'],
      'support': ['ðŸ‘', 'ðŸ™', 'ðŸ’ª'],
      'justice': ['âš–ï¸', 'âœŠ', 'ðŸ›ï¸'],
      'victory': ['ðŸŽ‰', 'ðŸ†', 'ðŸ‘'],
      'fight': ['ðŸ’ª', 'âœŠ', 'ðŸ”¥'],
    };
    
    for (final entry in emotionKeywords.entries) {
      if (lowerContent.contains(entry.key)) {
        suggestions.addAll(entry.value);
      }
    }
    
    // Add default suggestions if none found
    if (suggestions.isEmpty) {
      suggestions.addAll(['ðŸ‘', 'â¤ï¸', 'ðŸ˜Š', 'ðŸ™', 'ðŸ’ª']);
    }
    
    return suggestions.take(6).toList();
  }
  
  /// Update reaction count in Firestore
  Future<void> _updateReactionCount(String contentId, String emoji, int delta) async {
    try {
      final reactionCountRef = _firestore
          .collection('content_reactions')
          .doc(contentId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(reactionCountRef);
        
        final data = doc.data() ?? {};
        final counts = Map<String, int>.from(data['counts'] ?? {});
        
        counts[emoji] = (counts[emoji] ?? 0) + delta;
        
        // Remove if count reaches 0
        if (counts[emoji]! <= 0) {
          counts.remove(emoji);
        }
        
        transaction.set(reactionCountRef, {
          'counts': counts,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      
    } catch (e) {
      debugPrint('âŒ Failed to update reaction count: $e');
    }
  }
  
  /// Setup emoji data
  void _setupEmojiData() {
    // This would include loading custom emoji data, user preferences, etc.
    debugPrint('ðŸ“Š Emoji data setup complete');
  }
}

// Emoji Reaction Picker Widget
class EmojiReactionPicker extends StatefulWidget {
  final String contentId;
  final String contentType;
  final Function(String)? onEmojiSelected;
  final List<String>? customEmojis;
  final bool showCategories;

  const EmojiReactionPicker({
    super.key,
    required this.contentId,
    required this.contentType,
    this.onEmojiSelected,
    this.customEmojis,
    this.showCategories = true,
  });

  @override
  State<EmojiReactionPicker> createState() => _EmojiReactionPickerState();
}

class _EmojiReactionPickerState extends State<EmojiReactionPicker> {
  String _selectedCategory = 'support';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showCategories) _buildCategoryTabs(),
          const SizedBox(height: 16),
          _buildEmojiGrid(),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: EmojiReactionService.emojiCategories.keys.map((category) {
          final isSelected = category == _selectedCategory;
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = category);
              HapticFeedback.selectionClick();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                category.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmojiGrid() {
    final emojis = widget.customEmojis ?? 
        EmojiReactionService.emojiCategories[_selectedCategory] ?? [];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        
        return GestureDetector(
          onTap: () async {
            await EmojiReactionService.instance.addReaction(
              contentId: widget.contentId,
              contentType: widget.contentType,
              emoji: emoji,
            );
            
            widget.onEmojiSelected?.call(emoji);
            
            // Trigger burst animation
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final position = renderBox.localToGlobal(Offset.zero);
              EmojiReactionService.instance.triggerEmojiBurst(
                context: context,
                emoji: emoji,
                position: position,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Floating Emoji Animation Widget
class FloatingEmojiAnimation extends StatefulWidget {
  final String emoji;
  final String animationId;
  final Duration duration;
  final double startY;
  final double endY;

  const FloatingEmojiAnimation({
    super.key,
    required this.emoji,
    required this.animationId,
    required this.duration,
    this.startY = 0.0,
    this.endY = -100.0,
  });

  @override
  State<FloatingEmojiAnimation> createState() => _FloatingEmojiAnimationState();
}

class _FloatingEmojiAnimationState extends State<FloatingEmojiAnimation>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _positionAnimation = Tween<double>(
      begin: widget.startY,
      end: widget.endY,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.7, 1.0),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.3),
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _positionAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Data Classes

class ReactionData {
  final String emoji;
  final int count;
  final List<String> users;

  const ReactionData({
    required this.emoji,
    required this.count,
    required this.users,
  });

  ReactionData copyWith({
    String? emoji,
    int? count,
    List<String>? users,
  }) {
    return ReactionData(
      emoji: emoji ?? this.emoji,
      count: count ?? this.count,
      users: users ?? this.users,
    );
  }
}

class EmojiAnimation {
  final String emoji;
  final Offset position;
  final DateTime startTime;
  final Duration duration;

  const EmojiAnimation({
    required this.emoji,
    required this.position,
    required this.startTime,
    required this.duration,
  });
}

