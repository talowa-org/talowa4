// Expandable Text Widget for TALOWA
// Text widget that supports hashtags, mentions, and expand/collapse functionality
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class ExpandableTextWidget extends StatefulWidget {
  final String text;
  final String? authorName;
  final int maxLines;
  final TextStyle? style;
  final Function(String)? onHashtagTap;
  final Function(String)? onMentionTap;
  final Function(String)? onUrlTap;

  const ExpandableTextWidget({
    super.key,
    required this.text,
    this.authorName,
    this.maxLines = 3,
    this.style,
    this.onHashtagTap,
    this.onMentionTap,
    this.onUrlTap,
  });

  @override
  State<ExpandableTextWidget> createState() => _ExpandableTextWidgetState();
}

class _ExpandableTextWidgetState extends State<ExpandableTextWidget> {
  bool _isExpanded = false;
  bool _hasOverflow = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = _buildTextSpan();
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);
        
        _hasOverflow = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: textSpan,
              maxLines: _isExpanded ? null : widget.maxLines,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (_hasOverflow && !_isExpanded)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = true),
                child: Text(
                  'more',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: widget.style?.fontSize ?? 14,
                  ),
                ),
              ),
            if (_isExpanded)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = false),
                child: Text(
                  'less',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: widget.style?.fontSize ?? 14,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  TextSpan _buildTextSpan() {
    final List<TextSpan> spans = [];
    
    // Add author name if provided
    if (widget.authorName != null) {
      spans.add(TextSpan(
        text: '${widget.authorName} ',
        style: (widget.style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.bold,
        ),
      ));
    }

    // Parse the text for hashtags, mentions, and URLs
    final words = widget.text.split(' ');
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      
      if (word.startsWith('#') && word.length > 1) {
        // Hashtag
        spans.add(TextSpan(
          text: word,
          style: (widget.style ?? const TextStyle()).copyWith(
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => widget.onHashtagTap?.call(word.substring(1)),
        ));
      } else if (word.startsWith('@') && word.length > 1) {
        // Mention
        spans.add(TextSpan(
          text: word,
          style: (widget.style ?? const TextStyle()).copyWith(
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => widget.onMentionTap?.call(word.substring(1)),
        ));
      } else if (_isUrl(word)) {
        // URL
        spans.add(TextSpan(
          text: word,
          style: (widget.style ?? const TextStyle()).copyWith(
            color: Colors.blue[700],
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => widget.onUrlTap?.call(word),
        ));
      } else {
        // Regular text
        spans.add(TextSpan(
          text: word,
          style: widget.style,
        ));
      }
      
      // Add space between words (except for the last word)
      if (i < words.length - 1) {
        spans.add(TextSpan(
          text: ' ',
          style: widget.style,
        ));
      }
    }

    return TextSpan(children: spans);
  }

  bool _isUrl(String text) {
    final urlPattern = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(text);
  }
}