// Notification Badge Widget - Show notification count with badge
// Real-time notification counter for app bar

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'notification_center_widget.dart';

class NotificationBadgeWidget extends StatefulWidget {
  final VoidCallback? onTap;
  final bool showAsBottomSheet;

  const NotificationBadgeWidget({
    super.key,
    this.onTap,
    this.showAsBottomSheet = true,
  });

  @override
  State<NotificationBadgeWidget> createState() => _NotificationBadgeWidgetState();
}

class _NotificationBadgeWidgetState extends State<NotificationBadgeWidget> {
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationListener() {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadCount = snapshot.docs.length;
        });
      }
    });
  }

  void _showNotifications() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    if (widget.showAsBottomSheet) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => NotificationCenterWidget(
          showAsBottomSheet: true,
          onClose: () => Navigator.pop(context),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NotificationCenterWidget(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: _showNotifications,
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// In-App Notification Banner Widget
class InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final IconData? icon;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Duration duration;

  const InAppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.backgroundColor,
    this.onTap,
    this.onDismiss,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Start animation
    _animationController.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (widget.icon != null)
                      Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    if (widget.icon != null) const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.body,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _dismiss,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Notification Overlay Manager
class NotificationOverlayManager {
  static OverlayEntry? _currentOverlay;

  static void showInAppNotification(
    BuildContext context, {
    required String title,
    required String body,
    IconData? icon,
    Color? backgroundColor,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Remove existing notification if any
    hideCurrentNotification();

    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top,
        left: 0,
        right: 0,
        child: InAppNotificationBanner(
          title: title,
          body: body,
          icon: icon,
          backgroundColor: backgroundColor,
          onTap: onTap,
          onDismiss: hideCurrentNotification,
          duration: duration,
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  static void hideCurrentNotification() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}


