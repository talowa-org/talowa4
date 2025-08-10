// Hashtag Text Widget - Display text with clickable hashtags
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Widget for displaying text with clickable hashtags and mentions
class HashtagTextWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Function(String)? onHashtagTapped;
  final Function(String)? onMentionTapped;
  final Function(String)? onUrlTapped;
  final int? maxLines;
  final TextOverflow? overflow;
  
  const HashtagTextWidget({
    super.key,
    required this.text,
    this.style,
    this.onHashtagTapped,
    this.onMentionTapped,
    this.onUrlTapped,
    this.maxLines,
    this.overflow,
  });
  
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: _buildTextSpan(context),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.visible,
    );
  }
  
  TextSpan _buildTextSpan(BuildContext context) {
    final List<TextSpan> spans = [];
    final RegExp pattern = RegExp(
      r'(#\w+|@\w+|https?://[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );
    
    int lastMatchEnd = 0;
    
    for (final Match match in pattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }
      
      final String matchText = match.group(0)!;
      
      if (matchText.startsWith('#')) {
        // Hashtag
        spans.add(_buildHashtagSpan(context, matchText));
      } else if (matchText.startsWith('@')) {
        // Mention
        spans.add(_buildMentionSpan(context, matchText));
      } else if (matchText.startsWith('http') || matchText.startsWith('www')) {
        // URL
        spans.add(_buildUrlSpan(context, matchText));
      } else {
        // Regular text
        spans.add(TextSpan(
          text: matchText,
          style: style,
        ));
      }
      
      lastMatchEnd = match.end;
    }
    
    // Add remaining text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }
    
    return TextSpan(children: spans);
  }
  
  TextSpan _buildHashtagSpan(BuildContext context, String hashtag) {
    return TextSpan(
      text: hashtag,
      style: (style ?? const TextStyle()).copyWith(
        color: Theme.of(context).primaryColor,
        fontWeight: FontWeight.w600,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          final hashtagText = hashtag.substring(1); // Remove # symbol
          onHashtagTapped?.call(hashtagText);
        },
    );
  }
  
  TextSpan _buildMentionSpan(BuildContext context, String mention) {
    return TextSpan(
      text: mention,
      style: (style ?? const TextStyle()).copyWith(
        color: Colors.blue,
        fontWeight: FontWeight.w600,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          final mentionText = mention.substring(1); // Remove @ symbol
          onMentionTapped?.call(mentionText);
        },
    );
  }
  
  TextSpan _buildUrlSpan(BuildContext context, String url) {
    return TextSpan(
      text: url,
      style: (style ?? const TextStyle()).copyWith(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          onUrlTapped?.call(url);
        },
    );
  }
}

/// Widget for displaying hashtag chips
class HashtagChipsWidget extends StatelessWidget {
  final List<String> hashtags;
  final Function(String)? onHashtagTapped;
  final bool showHashSymbol;
  final int? maxChips;
  
  const HashtagChipsWidget({
    super.key,
    required this.hashtags,
    this.onHashtagTapped,
    this.showHashSymbol = true,
    this.maxChips,
  });
  
  @override
  Widget build(BuildContext context) {
    if (hashtags.isEmpty) return const SizedBox.shrink();
    
    final displayHashtags = maxChips != null && hashtags.length > maxChips!
        ? hashtags.take(maxChips!).toList()
        : hashtags;
    
    final hasMore = maxChips != null && hashtags.length > maxChips!;
    
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...displayHashtags.map((hashtag) => _buildHashtagChip(context, hashtag)),
        if (hasMore)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+${hashtags.length - maxChips!}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildHashtagChip(BuildContext context, String hashtag) {
    return InkWell(
      onTap: () => onHashtagTapped?.call(hashtag),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          showHashSymbol ? '#$hashtag' : hashtag,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Widget for trending hashtags display
class TrendingHashtagsWidget extends StatelessWidget {
  final List<String> trendingHashtags;
  final Function(String)? onHashtagTapped;
  final String title;
  
  const TrendingHashtagsWidget({
    super.key,
    required this.trendingHashtags,
    this.onHashtagTapped,
    this.title = 'Trending',
  });
  
  @override
  Widget build(BuildContext context) {
    if (trendingHashtags.isEmpty) return const SizedBox.shrink();
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            HashtagChipsWidget(
              hashtags: trendingHashtags,
              onHashtagTapped: onHashtagTapped,
              maxChips: 10,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for hashtag input with suggestions
class HashtagInputWidget extends StatefulWidget {
  final Function(List<String>) onHashtagsChanged;
  final List<String> initialHashtags;
  final List<String> suggestions;
  final int maxHashtags;
  
  const HashtagInputWidget({
    super.key,
    required this.onHashtagsChanged,
    this.initialHashtags = const [],
    this.suggestions = const [],
    this.maxHashtags = 10,
  });
  
  @override
  State<HashtagInputWidget> createState() => _HashtagInputWidgetState();
}

class _HashtagInputWidgetState extends State<HashtagInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _hashtags = [];
  List<String> _filteredSuggestions = [];
  bool _showSuggestions = false;
  
  @override
  void initState() {
    super.initState();
    _hashtags = List.from(widget.initialHashtags);
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _onTextChanged() {
    final text = _controller.text;
    
    if (text.isNotEmpty && !text.startsWith('#')) {
      _controller.text = '#$text';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      return;
    }
    
    if (text.length > 1) {
      final query = text.substring(1).toLowerCase();
      _filteredSuggestions = widget.suggestions
          .where((suggestion) => 
              suggestion.toLowerCase().contains(query) &&
              !_hashtags.contains(suggestion))
          .take(5)
          .toList();
    } else {
      _filteredSuggestions = [];
    }
    
    setState(() {
      _showSuggestions = _filteredSuggestions.isNotEmpty && _focusNode.hasFocus;
    });
  }
  
  void _onFocusChanged() {
    setState(() {
      _showSuggestions = _filteredSuggestions.isNotEmpty && _focusNode.hasFocus;
    });
  }
  
  void _addHashtag(String hashtag) {
    if (hashtag.isNotEmpty && 
        !_hashtags.contains(hashtag) && 
        _hashtags.length < widget.maxHashtags) {
      setState(() {
        _hashtags.add(hashtag);
        _controller.clear();
        _filteredSuggestions.clear();
        _showSuggestions = false;
      });
      widget.onHashtagsChanged(_hashtags);
    }
  }
  
  void _removeHashtag(String hashtag) {
    setState(() {
      _hashtags.remove(hashtag);
    });
    widget.onHashtagsChanged(_hashtags);
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current hashtags
        if (_hashtags.isNotEmpty) ...[
          HashtagChipsWidget(
            hashtags: _hashtags,
            onHashtagTapped: _removeHashtag,
          ),
          const SizedBox(height: 8),
        ],
        
        // Input field
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Add hashtags...',
            prefixIcon: const Icon(Icons.tag),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      final hashtag = _controller.text.replaceAll('#', '');
                      _addHashtag(hashtag);
                    },
                    icon: const Icon(Icons.add),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onSubmitted: (value) {
            final hashtag = value.replaceAll('#', '');
            _addHashtag(hashtag);
          },
        ),
        
        // Suggestions
        if (_showSuggestions) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _filteredSuggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.tag, size: 16),
                  title: Text('#$suggestion'),
                  onTap: () => _addHashtag(suggestion),
                );
              },
            ),
          ),
        ],
        
        // Helper text
        if (_hashtags.length >= widget.maxHashtags)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Maximum ${widget.maxHashtags} hashtags allowed',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade600,
              ),
            ),
          ),
      ],
    );
  }
}