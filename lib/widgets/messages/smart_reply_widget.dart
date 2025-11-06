// Smart Reply Widget for AI-Powered Messaging
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/messaging/advanced_messaging_service.dart';

class SmartReplyWidget extends StatefulWidget {
  final String messageContent;
  final String? conversationContext;
  final Function(String) onReplySelected;
  final VoidCallback? onDismiss;

  const SmartReplyWidget({
    super.key,
    required this.messageContent,
    this.conversationContext,
    required this.onReplySelected,
    this.onDismiss,
  });

  @override
  State<SmartReplyWidget> createState() => _SmartReplyWidgetState();
}

class _SmartReplyWidgetState extends State<SmartReplyWidget>
    with SingleTickerProviderStateMixin {
  final AdvancedMessagingService _advancedMessaging = AdvancedMessagingService();
  List<String> _smartReplies = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _loadSmartReplies();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSmartReplies() async {
    try {
      final replies = await _advancedMessaging.generateSmartReplies(
        widget.messageContent,
        conversationContext: widget.conversationContext,
      );
      
      setState(() {
        _smartReplies = replies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading smart replies: $e');
    }
  }

  void _selectReply(String reply) {
    widget.onReplySelected(reply);
    _animationController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Opacity(
            opacity: _slideAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.talowaGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: AppTheme.talowaGreen,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Smart Replies',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.talowaGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          _animationController.reverse().then((_) {
                            widget.onDismiss?.call();
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Smart replies
                  if (_isLoading)
                    _buildLoadingState()
                  else if (_smartReplies.isEmpty)
                    _buildEmptyState()
                  else
                    _buildRepliesList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Generating smart replies...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(
            'No smart replies available',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepliesList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _smartReplies.asMap().entries.map((entry) {
          final index = entry.key;
          final reply = entry.value;
          
          return Container(
            margin: EdgeInsets.only(right: index < _smartReplies.length - 1 ? 8 : 0),
            child: _buildReplyChip(reply),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReplyChip(String reply) {
    return GestureDetector(
      onTap: () => _selectReply(reply),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.talowaGreen.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reply,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.send,
              size: 16,
              color: AppTheme.talowaGreen,
            ),
          ],
        ),
      ),
    );
  }
}

// Translation Widget for Multi-language Support
class MessageTranslationWidget extends StatefulWidget {
  final String originalText;
  final String originalLanguage;
  final Function(String translatedText, String targetLanguage) onTranslationComplete;

  const MessageTranslationWidget({
    super.key,
    required this.originalText,
    required this.originalLanguage,
    required this.onTranslationComplete,
  });

  @override
  State<MessageTranslationWidget> createState() => _MessageTranslationWidgetState();
}

class _MessageTranslationWidgetState extends State<MessageTranslationWidget> {
  final AdvancedMessagingService _advancedMessaging = AdvancedMessagingService();
  String? _selectedLanguage;
  String? _translatedText;
  bool _isTranslating = false;

  final Map<String, String> _supportedLanguages = {
    'en': 'English',
    'hi': 'Hindi',
    'te': 'Telugu',
    'ta': 'Tamil',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'bn': 'Bengali',
    'gu': 'Gujarati',
    'mr': 'Marathi',
    'pa': 'Punjabi',
    'or': 'Odia',
    'as': 'Assamese',
  };

  Future<void> _translateMessage(String targetLanguage) async {
    if (_isTranslating) return;

    setState(() {
      _isTranslating = true;
      _selectedLanguage = targetLanguage;
    });

    try {
      final translatedText = await _advancedMessaging.translateMessage(
        widget.originalText,
        targetLanguage,
      );

      setState(() {
        _translatedText = translatedText;
      });

      widget.onTranslationComplete(translatedText, targetLanguage);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Translation failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.translate, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Translate Message',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Original text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Original (${_supportedLanguages[widget.originalLanguage] ?? widget.originalLanguage}):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.originalText,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Language selection
          Text(
            'Translate to:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),

          // Language chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _supportedLanguages.entries
                .where((entry) => entry.key != widget.originalLanguage)
                .map((entry) {
              final isSelected = _selectedLanguage == entry.key;
              return GestureDetector(
                onTap: () => _translateMessage(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[600] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isTranslating && isSelected) ...[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isSelected ? Colors.white : Colors.blue[600]!,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Translated text
          if (_translatedText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Translated (${_supportedLanguages[_selectedLanguage!]}):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _translatedText!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Message Sentiment Indicator
class MessageSentimentWidget extends StatelessWidget {
  final String messageContent;
  final bool showDetails;

  const MessageSentimentWidget({
    super.key,
    required this.messageContent,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MessageSentiment>(
      future: AdvancedMessagingService().analyzeSentiment(messageContent),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final sentiment = snapshot.data!;
        final sentimentData = _getSentimentData(sentiment);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: sentimentData.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sentimentData.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sentimentData.icon,
                size: 14,
                color: sentimentData.color,
              ),
              if (showDetails) ...[
                const SizedBox(width: 4),
                Text(
                  sentimentData.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: sentimentData.color,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  _SentimentData _getSentimentData(MessageSentiment sentiment) {
    switch (sentiment) {
      case MessageSentiment.positive:
        return _SentimentData(
          icon: Icons.sentiment_satisfied,
          label: 'Positive',
          color: Colors.green[600]!,
        );
      case MessageSentiment.negative:
        return _SentimentData(
          icon: Icons.sentiment_dissatisfied,
          label: 'Negative',
          color: Colors.red[600]!,
        );
      case MessageSentiment.neutral:
        return _SentimentData(
          icon: Icons.sentiment_neutral,
          label: 'Neutral',
          color: Colors.grey[600]!,
        );
    }
  }
}

class _SentimentData {
  final IconData icon;
  final String label;
  final Color color;

  _SentimentData({
    required this.icon,
    required this.label,
    required this.color,
  });
}