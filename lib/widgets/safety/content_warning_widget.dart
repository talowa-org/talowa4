// Content Warning Widget for TALOWA
// Implements Task 18: Add security and content safety - Content Warnings

import 'package:flutter/material.dart';

class ContentWarningWidget extends StatefulWidget {
  final Widget child;
  final ContentWarningType warningType;
  final String reason;
  final bool showByDefault;
  final VoidCallback? onShow;
  final VoidCallback? onHide;

  const ContentWarningWidget({
    super.key,
    required this.child,
    required this.warningType,
    required this.reason,
    this.showByDefault = false,
    this.onShow,
    this.onHide,
  });

  @override
  State<ContentWarningWidget> createState() => _ContentWarningWidgetState();
}

class _ContentWarningWidgetState extends State<ContentWarningWidget>
    with SingleTickerProviderStateMixin {
  late bool _isContentVisible;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _isContentVisible = widget.showByDefault;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (_isContentVisible) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWarningHeader(),
        if (_isContentVisible) ...[
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _fadeAnimation,
            child: widget.child,
          ),
        ],
      ],
    );
  }

  Widget _buildWarningHeader() {
    final warningInfo = _getWarningInfo(widget.warningType);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warningInfo.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: warningInfo.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                warningInfo.icon,
                color: warningInfo.color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warningInfo.title,
                  style: TextStyle(
                    color: warningInfo.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              _buildToggleButton(warningInfo.color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.reason,
            style: TextStyle(
              color: warningInfo.color.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          if (!_isContentVisible) ...[
            const SizedBox(height: 8),
            Text(
              warningInfo.description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleButton(Color color) {
    return InkWell(
      onTap: _toggleContent,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isContentVisible ? 'Hide' : 'Show',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _isContentVisible ? Icons.visibility_off : Icons.visibility,
              color: color,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleContent() {
    setState(() {
      _isContentVisible = !_isContentVisible;
    });

    if (_isContentVisible) {
      _animationController.forward();
      widget.onShow?.call();
    } else {
      _animationController.reverse();
      widget.onHide?.call();
    }
  }

  _WarningInfo _getWarningInfo(ContentWarningType type) {
    switch (type) {
      case ContentWarningType.sensitiveContent:
        return _WarningInfo(
          title: 'Sensitive Content',
          description: 'This content may be sensitive or disturbing to some users.',
          icon: Icons.warning_amber,
          color: Colors.orange,
        );
      case ContentWarningType.violence:
        return _WarningInfo(
          title: 'Violence Warning',
          description: 'This content contains descriptions or depictions of violence.',
          icon: Icons.dangerous,
          color: Colors.red,
        );
      case ContentWarningType.adultContent:
        return _WarningInfo(
          title: 'Adult Content',
          description: 'This content is intended for mature audiences only.',
          icon: Icons.adult_content,
          color: Colors.purple,
        );
      case ContentWarningType.disturbing:
        return _WarningInfo(
          title: 'Disturbing Content',
          description: 'This content may be disturbing or upsetting to some users.',
          icon: Icons.psychology_alt,
          color: Colors.red[700]!,
        );
      case ContentWarningType.spoilers:
        return _WarningInfo(
          title: 'Spoiler Alert',
          description: 'This content contains spoilers that may ruin surprises.',
          icon: Icons.visibility_off,
          color: Colors.blue,
        );
    }
  }
}

class _WarningInfo {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  _WarningInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// Helper widget for posts with content warnings
class SafePostWidget extends StatelessWidget {
  final Widget child;
  final bool hasContentWarning;
  final ContentWarningType? warningType;
  final String? warningReason;
  final bool showWarningByDefault;

  const SafePostWidget({
    super.key,
    required this.child,
    required this.hasContentWarning,
    this.warningType,
    this.warningReason,
    this.showWarningByDefault = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasContentWarning || warningType == null || warningReason == null) {
      return child;
    }

    return ContentWarningWidget(
      warningType: warningType!,
      reason: warningReason!,
      showByDefault: showWarningByDefault,
      child: child,
    );
  }
}

// Utility function to check if content should show warning
bool shouldShowContentWarning({
  required bool hasContentWarning,
  required ContentWarningType? warningType,
  required List<String> userAllowedWarnings,
}) {
  if (!hasContentWarning || warningType == null) {
    return false;
  }

  return !userAllowedWarnings.contains(warningType.toString());
}

