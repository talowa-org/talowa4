// User Avatar Widget - Display user profile pictures with fallbacks
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';

class UserAvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final VoidCallback? onTap;
  final bool showOnlineIndicator;
  final bool isOnline;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget? badge;

  const UserAvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
    this.onTap,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.backgroundColor,
    this.textColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor ?? _getBackgroundColor(),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: ClipOval(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildPlaceholder(),
                      errorWidget: (context, url, error) => _buildInitials(),
                    )
                  : _buildInitials(),
            ),
          ),

          // Online indicator
          if (showOnlineIndicator)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),

          // Badge (e.g., role indicator)
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: badge!,
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            AppTheme.talowaGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildInitials() {
    final initials = _getInitials();
    final fontSize = size * 0.4;

    return Container(
      width: size,
      height: size,
      color: backgroundColor ?? _getBackgroundColor(),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor ?? Colors.white,
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    if (name.isEmpty) return '?';

    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }
  }

  Color _getBackgroundColor() {
    // Generate a consistent color based on the name
    final hash = name.hashCode;
    final colors = [
      AppTheme.talowaGreen,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.brown,
    ];

    return colors[hash.abs() % colors.length];
  }
}

// Group avatar widget for multiple users
class GroupAvatarWidget extends StatelessWidget {
  final List<String> imageUrls;
  final List<String> names;
  final double size;
  final int maxAvatars;
  final VoidCallback? onTap;

  const GroupAvatarWidget({
    super.key,
    required this.imageUrls,
    required this.names,
    this.size = 40,
    this.maxAvatars = 3,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayCount = imageUrls.length > maxAvatars ? maxAvatars : imageUrls.length;
    final remainingCount = imageUrls.length - maxAvatars;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + (displayCount - 1) * (size * 0.7),
        height: size,
        child: Stack(
          children: [
            // Display avatars
            ...List.generate(displayCount, (index) {
              final offset = index * (size * 0.7);
              return Positioned(
                left: offset,
                child: UserAvatarWidget(
                  imageUrl: index < imageUrls.length ? imageUrls[index] : null,
                  name: index < names.length ? names[index] : 'User',
                  size: size,
                ),
              );
            }),

            // Show remaining count
            if (remainingCount > 0)
              Positioned(
                left: displayCount * (size * 0.7),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '+$remainingCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Avatar with status indicator
class StatusAvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final String status; // 'online', 'away', 'busy', 'offline'
  final VoidCallback? onTap;

  const StatusAvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatarWidget(
      imageUrl: imageUrl,
      name: name,
      size: size,
      onTap: onTap,
      showOnlineIndicator: true,
      isOnline: status == 'online',
      badge: _buildStatusBadge(),
    );
  }

  Widget? _buildStatusBadge() {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'online':
        statusColor = Colors.green;
        break;
      case 'away':
        statusColor = Colors.orange;
        break;
      case 'busy':
        statusColor = Colors.red;
        break;
      case 'offline':
      default:
        statusColor = Colors.grey;
        break;
    }

    return Container(
      width: size * 0.3,
      height: size * 0.3,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
    );
  }
}