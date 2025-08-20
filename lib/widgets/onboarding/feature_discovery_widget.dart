// TALOWA Feature Discovery Widget
// Shows contextual tips and feature discovery prompts
// Reference: in-app-communication/requirements.md - Requirements 2.2, 3.1, 9.1

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/onboarding_service.dart';

class FeatureDiscoveryWidget extends StatefulWidget {
  final String featureKey;
  final String title;
  final String description;
  final Widget child;
  final IconData? icon;
  final Color? accentColor;
  final bool showOnce;

  const FeatureDiscoveryWidget({
    super.key,
    required this.featureKey,
    required this.title,
    required this.description,
    required this.child,
    this.icon,
    this.accentColor,
    this.showOnce = true,
  });

  @override
  State<FeatureDiscoveryWidget> createState() => _FeatureDiscoveryWidgetState();
}

class _FeatureDiscoveryWidgetState extends State<FeatureDiscoveryWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _shouldShow = false;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _checkShouldShow();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkShouldShow() {
    if (OnboardingService.shouldShowFeatureDiscovery(widget.featureKey)) {
      // Delay showing to allow the screen to settle
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _showFeatureDiscovery();
        }
      });
    }
  }

  void _showFeatureDiscovery() {
    setState(() {
      _shouldShow = true;
      _isShowing = true;
    });
    _animationController.forward();
  }

  void _hideFeatureDiscovery() async {
    await _animationController.reverse();
    if (mounted) {
      setState(() {
        _shouldShow = false;
        _isShowing = false;
      });
    }
    
    if (widget.showOnce) {
      await OnboardingService.markFeatureDiscoveryShown(widget.featureKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_shouldShow && _isShowing)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildOverlay(),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildOverlay() {
    return Material(
      color: Colors.black.withOpacity(0.7),
      child: Stack(
        children: [
          // Tap to dismiss
          GestureDetector(
            onTap: _hideFeatureDiscovery,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
          
          // Feature discovery popup
          Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  if (widget.icon != null)
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: (widget.accentColor ?? AppTheme.talowaGreen).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: 32,
                        color: widget.accentColor ?? AppTheme.talowaGreen,
                      ),
                    ),

                  if (widget.icon != null) const SizedBox(height: 16),

                  // Title
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    widget.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _hideFeatureDiscovery,
                          child: const Text('Got it'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _hideFeatureDiscovery();
                            _showMoreInfo();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.accentColor ?? AppTheme.talowaGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Learn More'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreInfo() {
    // This would typically navigate to help or show more detailed information
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('More info about ${widget.title}'),
        action: SnackBarAction(
          label: 'Help',
          onPressed: () {
            // Navigate to help center
          },
        ),
      ),
    );
  }
}

// Contextual Tips Widget
class FeatureContextualTipsWidget extends StatefulWidget {
  final String screenName;
  final Widget child;

  const FeatureContextualTipsWidget({
    super.key,
    required this.screenName,
    required this.child,
  });

  @override
  State<FeatureContextualTipsWidget> createState() => _FeatureContextualTipsWidgetState();
}

class _FeatureContextualTipsWidgetState extends State<FeatureContextualTipsWidget> {
  List<String> _tips = [];
  int _currentTipIndex = 0;
  bool _showTips = false;

  @override
  void initState() {
    super.initState();
    _loadContextualTips();
  }

  void _loadContextualTips() {
    _tips = OnboardingService.getContextualTips(widget.screenName);
    if (_tips.isNotEmpty && OnboardingService.shouldShowFeatureDiscovery('tips_${widget.screenName}')) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() {
            _showTips = true;
          });
        }
      });
    }
  }

  void _nextTip() {
    if (_currentTipIndex < _tips.length - 1) {
      setState(() {
        _currentTipIndex++;
      });
    } else {
      _hideTips();
    }
  }

  void _hideTips() {
    setState(() {
      _showTips = false;
    });
    OnboardingService.markFeatureDiscoveryShown('tips_${widget.screenName}');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showTips && _tips.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: AppTheme.talowaGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tip',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.talowaGreen,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_currentTipIndex + 1}/${_tips.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        IconButton(
                          onPressed: _hideTips,
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tips[_currentTipIndex],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_currentTipIndex < _tips.length - 1)
                          TextButton(
                            onPressed: _nextTip,
                            child: const Text('Next Tip'),
                          )
                        else
                          TextButton(
                            onPressed: _hideTips,
                            child: const Text('Got it'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}