// Comment Input Widget - Text input for comments and replies
// Part of Task 7: Build post engagement interface

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class CommentInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;
  final String hintText;
  final int maxLines;

  const CommentInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onSubmit,
    this.onCancel,
    this.hintText = 'Add a comment...',
    this.maxLines = 4,
  });

  @override
  State<CommentInputWidget> createState() => _CommentInputWidgetState();
}

class _CommentInputWidgetState extends State<CommentInputWidget> 
    with TickerProviderStateMixin {
  late AnimationController _submitAnimationController;
  late Animation<double> _submitAnimation;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _submitAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _submitAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _submitAnimationController, curve: Curves.easeOut),
    );
    
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.isNotEmpty;
    if (_hasText) _submitAnimationController.forward();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _submitAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
      
      if (hasText) {
        _submitAnimationController.forward();
      } else {
        _submitAnimationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // User avatar (current user)
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.talowaGreen,
            child: Icon(
              Icons.person,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.focusNode.hasFocus 
                      ? AppTheme.talowaGreen 
                      : Colors.grey[300]!,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                maxLines: null,
                minLines: 1,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  counterText: '', // Hide character counter
                ),
                style: Theme.of(context).textTheme.bodyMedium,
                onSubmitted: (_) => _handleSubmit(),
              ),
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingSmall),
          
          // Action buttons
          Row(
            children: [
              // Cancel button (for replies)
              if (widget.onCancel != null)
                IconButton(
                  onPressed: widget.onCancel,
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  tooltip: 'Cancel',
                ),
              
              // Submit button
              ScaleTransition(
                scale: _submitAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: _hasText && !widget.isSubmitting
                        ? AppTheme.talowaGreen
                        : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _hasText && !widget.isSubmitting 
                        ? _handleSubmit 
                        : null,
                    icon: widget.isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                    tooltip: 'Send',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    if (!_hasText || widget.isSubmitting) return;
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
    
    // Call the submit callback
    widget.onSubmit();
  }
}