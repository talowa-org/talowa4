// Enhanced Gesture Service - Advanced gesture recognition and interactions
// Comprehensive gesture handling for TALOWA platform

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GestureService {
  static GestureService? _instance;
  static GestureService get instance => _instance ??= GestureService._internal();
  
  GestureService._internal();
  
  // Gesture configuration
  static const double swipeThreshold = 100.0;
  static const double velocityThreshold = 1000.0;
  static const Duration doubleTapTimeout = Duration(milliseconds: 300);
  static const Duration longPressTimeout = Duration(milliseconds: 500);
  
  // Gesture tracking
  final Map<String, GestureState> _gestureStates = {};
  final Map<String, Timer> _gestureTimers = {};
  
  // Gesture callbacks
  final Map<String, List<GestureCallback>> _gestureCallbacks = {};
  
  /// Initialize gesture service
  void initialize() {
    debugPrint('ðŸ¤ Initializing Enhanced Gesture Service...');
    
    // Setup gesture recognition
    _setupGestureRecognition();
    
    debugPrint('âœ… Enhanced Gesture Service initialized');
  }
  
  /// Register gesture callback
  void registerGestureCallback(String gestureId, GestureCallback callback) {
    if (!_gestureCallbacks.containsKey(gestureId)) {
      _gestureCallbacks[gestureId] = [];
    }
    _gestureCallbacks[gestureId]!.add(callback);
    
    debugPrint('ðŸ“ Registered gesture callback: $gestureId');
  }
  
  /// Unregister gesture callback
  void unregisterGestureCallback(String gestureId, GestureCallback callback) {
    _gestureCallbacks[gestureId]?.remove(callback);
    
    if (_gestureCallbacks[gestureId]?.isEmpty == true) {
      _gestureCallbacks.remove(gestureId);
    }
    
    debugPrint('ðŸ—‘ï¸ Unregistered gesture callback: $gestureId');
  }
  
  /// Create enhanced gesture detector
  Widget createGestureDetector({
    required Widget child,
    required String gestureId,
    Function(SwipeDirection)? onSwipe,
    Function()? onDoubleTap,
    Function()? onLongPress,
    Function(Offset)? onPinchStart,
    Function(double)? onPinchUpdate,
    Function()? onPinchEnd,
    Function(Offset)? onPanStart,
    Function(Offset)? onPanUpdate,
    Function()? onPanEnd,
    bool enableHapticFeedback = true,
  }) {
    return GestureDetector(
      onTap: () => _handleTap(gestureId, enableHapticFeedback),
      onDoubleTap: onDoubleTap != null 
          ? () => _handleDoubleTap(gestureId, onDoubleTap, enableHapticFeedback)
          : null,
      onLongPress: onLongPress != null
          ? () => _handleLongPress(gestureId, onLongPress, enableHapticFeedback)
          : null,
      onPanStart: (details) => _handlePanStart(
        gestureId, 
        details, 
        onPanStart, 
        enableHapticFeedback,
      ),
      onPanUpdate: (details) => _handlePanUpdate(
        gestureId, 
        details, 
        onPanUpdate, 
        onSwipe,
      ),
      onPanEnd: (details) => _handlePanEnd(
        gestureId, 
        details, 
        onPanEnd, 
        onSwipe, 
        enableHapticFeedback,
      ),
      onScaleStart: onPinchStart != null
          ? (details) => _handleScaleStart(gestureId, details, onPinchStart)
          : null,
      onScaleUpdate: onPinchUpdate != null
          ? (details) => _handleScaleUpdate(gestureId, details, onPinchUpdate)
          : null,
      onScaleEnd: onPinchEnd != null
          ? (details) => _handleScaleEnd(gestureId, onPinchEnd)
          : null,
      child: child,
    );
  }
  
  /// Create swipe-to-action widget
  Widget createSwipeToActionWidget({
    required Widget child,
    required String gestureId,
    Widget? leftAction,
    Widget? rightAction,
    Function()? onLeftSwipe,
    Function()? onRightSwipe,
    double actionWidth = 80.0,
    Color leftActionColor = Colors.green,
    Color rightActionColor = Colors.red,
    bool enableHapticFeedback = true,
  }) {
    return SwipeToActionWidget(
      gestureId: gestureId,
      leftAction: leftAction,
      rightAction: rightAction,
      onLeftSwipe: onLeftSwipe,
      onRightSwipe: onRightSwipe,
      actionWidth: actionWidth,
      leftActionColor: leftActionColor,
      rightActionColor: rightActionColor,
      enableHapticFeedback: enableHapticFeedback,
      child: child,
    );
  }
  
  /// Create pull-to-refresh widget
  Widget createPullToRefreshWidget({
    required Widget child,
    required Future<void> Function() onRefresh,
    String refreshText = 'Pull to refresh',
    String releaseText = 'Release to refresh',
    String refreshingText = 'Refreshing...',
    bool enableHapticFeedback = true,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        if (enableHapticFeedback) {
          HapticFeedback.mediumImpact();
        }
        await onRefresh();
      },
      child: child,
    );
  }
  
  /// Handle tap gesture
  void _handleTap(String gestureId, bool enableHapticFeedback) {
    if (enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    
    _triggerGestureCallbacks(gestureId, GestureType.tap, null);
  }
  
  /// Handle double tap gesture
  void _handleDoubleTap(
    String gestureId, 
    Function() callback, 
    bool enableHapticFeedback,
  ) {
    if (enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }
    
    callback();
    _triggerGestureCallbacks(gestureId, GestureType.doubleTap, null);
  }
  
  /// Handle long press gesture
  void _handleLongPress(
    String gestureId, 
    Function() callback, 
    bool enableHapticFeedback,
  ) {
    if (enableHapticFeedback) {
      HapticFeedback.heavyImpact();
    }
    
    callback();
    _triggerGestureCallbacks(gestureId, GestureType.longPress, null);
  }
  
  /// Handle pan start
  void _handlePanStart(
    String gestureId,
    DragStartDetails details,
    Function(Offset)? callback,
    bool enableHapticFeedback,
  ) {
    _gestureStates[gestureId] = GestureState(
      startPosition: details.localPosition,
      currentPosition: details.localPosition,
      startTime: DateTime.now(),
    );
    
    callback?.call(details.localPosition);
  }
  
  /// Handle pan update
  void _handlePanUpdate(
    String gestureId,
    DragUpdateDetails details,
    Function(Offset)? callback,
    Function(SwipeDirection)? onSwipe,
  ) {
    final state = _gestureStates[gestureId];
    if (state == null) return;
    
    _gestureStates[gestureId] = state.copyWith(
      currentPosition: details.localPosition,
    );
    
    callback?.call(details.localPosition);
  }
  
  /// Handle pan end
  void _handlePanEnd(
    String gestureId,
    DragEndDetails details,
    Function()? callback,
    Function(SwipeDirection)? onSwipe,
    bool enableHapticFeedback,
  ) {
    final state = _gestureStates[gestureId];
    if (state == null) return;
    
    // Calculate swipe direction and distance
    final delta = state.currentPosition - state.startPosition;
    final distance = delta.distance;
    final velocity = details.velocity.pixelsPerSecond.distance;
    
    if (distance > swipeThreshold || velocity > velocityThreshold) {
      final direction = _calculateSwipeDirection(delta);
      
      if (enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }
      
      onSwipe?.call(direction);
      _triggerGestureCallbacks(gestureId, GestureType.swipe, direction);
    }
    
    callback?.call();
    _gestureStates.remove(gestureId);
  }
  
  /// Handle scale start (pinch)
  void _handleScaleStart(
    String gestureId,
    ScaleStartDetails details,
    Function(Offset) callback,
  ) {
    callback(details.localFocalPoint);
  }
  
  /// Handle scale update (pinch)
  void _handleScaleUpdate(
    String gestureId,
    ScaleUpdateDetails details,
    Function(double) callback,
  ) {
    callback(details.scale);
  }
  
  /// Handle scale end (pinch)
  void _handleScaleEnd(String gestureId, Function() callback) {
    callback();
  }
  
  /// Calculate swipe direction
  SwipeDirection _calculateSwipeDirection(Offset delta) {
    final angle = atan2(delta.dy, delta.dx);
    final degrees = angle * 180 / pi;
    
    if (degrees >= -45 && degrees <= 45) {
      return SwipeDirection.right;
    } else if (degrees >= 45 && degrees <= 135) {
      return SwipeDirection.down;
    } else if (degrees >= -135 && degrees <= -45) {
      return SwipeDirection.up;
    } else {
      return SwipeDirection.left;
    }
  }
  
  /// Trigger gesture callbacks
  void _triggerGestureCallbacks(
    String gestureId,
    GestureType type,
    dynamic data,
  ) {
    final callbacks = _gestureCallbacks[gestureId];
    if (callbacks == null) return;
    
    for (final callback in callbacks) {
      try {
        callback(type, data);
      } catch (e) {
        debugPrint('âŒ Gesture callback error: $e');
      }
    }
  }
  
  /// Setup gesture recognition
  void _setupGestureRecognition() {
    // This would include advanced gesture recognition setup
    debugPrint('ðŸ¤ Gesture recognition setup complete');
  }
  
  /// Dispose resources
  void dispose() {
    _gestureStates.clear();
    
    for (final timer in _gestureTimers.values) {
      timer.cancel();
    }
    _gestureTimers.clear();
    
    _gestureCallbacks.clear();
    
    debugPrint('ðŸ—‘ï¸ Gesture Service disposed');
  }
}

// Swipe-to-Action Widget
class SwipeToActionWidget extends StatefulWidget {
  final Widget child;
  final String gestureId;
  final Widget? leftAction;
  final Widget? rightAction;
  final Function()? onLeftSwipe;
  final Function()? onRightSwipe;
  final double actionWidth;
  final Color leftActionColor;
  final Color rightActionColor;
  final bool enableHapticFeedback;

  const SwipeToActionWidget({
    super.key,
    required this.child,
    required this.gestureId,
    this.leftAction,
    this.rightAction,
    this.onLeftSwipe,
    this.onRightSwipe,
    this.actionWidth = 80.0,
    this.leftActionColor = Colors.green,
    this.rightActionColor = Colors.red,
    this.enableHapticFeedback = true,
  });

  @override
  State<SwipeToActionWidget> createState() => _SwipeToActionWidgetState();
}

class _SwipeToActionWidgetState extends State<SwipeToActionWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  double _dragOffset = 0.0;
  bool _isDragging = false;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Stack(
        children: [
          // Background actions
          if (widget.leftAction != null || widget.rightAction != null)
            _buildActionBackground(),
          
          // Main content
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: widget.child,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionBackground() {
    return Row(
      children: [
        if (widget.leftAction != null)
          Container(
            width: widget.actionWidth,
            color: widget.leftActionColor,
            child: widget.leftAction,
          ),
        const Spacer(),
        if (widget.rightAction != null)
          Container(
            width: widget.actionWidth,
            color: widget.rightActionColor,
            child: widget.rightAction,
          ),
      ],
    );
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _animationController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-widget.actionWidth, widget.actionWidth);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    
    _isDragging = false;
    
    final velocity = details.velocity.pixelsPerSecond.dx;
    final shouldTriggerAction = _dragOffset.abs() > widget.actionWidth * 0.5 ||
        velocity.abs() > 1000;
    
    if (shouldTriggerAction) {
      if (_dragOffset > 0 && widget.onLeftSwipe != null) {
        if (widget.enableHapticFeedback) {
          HapticFeedback.mediumImpact();
        }
        widget.onLeftSwipe!();
      } else if (_dragOffset < 0 && widget.onRightSwipe != null) {
        if (widget.enableHapticFeedback) {
          HapticFeedback.mediumImpact();
        }
        widget.onRightSwipe!();
      }
    }
    
    // Animate back to center
    _animationController.forward().then((_) {
      setState(() {
        _dragOffset = 0.0;
      });
      _animationController.reset();
    });
  }
}

// Data Classes and Enums

class GestureState {
  final Offset startPosition;
  final Offset currentPosition;
  final DateTime startTime;

  const GestureState({
    required this.startPosition,
    required this.currentPosition,
    required this.startTime,
  });

  GestureState copyWith({
    Offset? startPosition,
    Offset? currentPosition,
    DateTime? startTime,
  }) {
    return GestureState(
      startPosition: startPosition ?? this.startPosition,
      currentPosition: currentPosition ?? this.currentPosition,
      startTime: startTime ?? this.startTime,
    );
  }
}

enum SwipeDirection {
  up,
  down,
  left,
  right,
}

enum GestureType {
  tap,
  doubleTap,
  longPress,
  swipe,
  pinch,
  pan,
}

typedef GestureCallback = void Function(GestureType type, dynamic data);

