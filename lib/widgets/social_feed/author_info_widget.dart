// Author Info Widget - Display post author information with role badges
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

/// Widget for displaying post author information
class AuthorInfoWidget extends StatelessWidget {
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final Function(String)? onUserTapped;
  
  const AuthorInfoWidget({
    Key? key,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
    required this.createdAt,
    this.onUserTapped,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onUserTapped?.call(authorId),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          // Author avatar
          _buildAuthorAvatar(),
          
          const SizedBox(width: 12),
          
          // Author info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name and role badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    if (authorRole != null) ...[
                      const SizedBox(width: 8),
                      _buildRoleBadge(),
                    ],
                  ],
                ),
                
                const SizedBox(height: 2),
                
                // Timestamp
                Text(
                  _formatTimestamp(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAuthorAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _getRoleColor().withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: authorAvatarUrl != null && authorAvatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: authorAvatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }
  
  Widget _buildDefaultAvatar() {
    return Container(
      color: _getRoleColor().withOpacity(0.1),
      child: Center(
        child: Text(
          authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _getRoleColor(),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRoleBadge() {
    final roleInfo = _getRoleInfo();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: roleInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: roleInfo['color'].withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            roleInfo['icon'],
            size: 10,
            color: roleInfo['color'],
          ),
          const SizedBox(width: 4),
          Text(
            roleInfo['label'],
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: roleInfo['color'],
            ),
          ),
        ],
      ),
    );
  }
  
  Map<String, dynamic> _getRoleInfo() {
    switch (authorRole?.toLowerCase()) {
      case 'founder':
        return {
          'label': 'Founder',
          'icon': Icons.star,
          'color': Colors.purple,
        };
      case 'admin':
        return {
          'label': 'Admin',
          'icon': Icons.admin_panel_settings,
          'color': Colors.red,
        };
      case 'coordinator':
      case 'district_coordinator':
        return {
          'label': 'District Coordinator',
          'icon': Icons.account_balance,
          'color': Colors.blue,
        };
      case 'mandal_coordinator':
        return {
          'label': 'Mandal Coordinator',
          'icon': Icons.location_city,
          'color': Colors.green,
        };
      case 'village_coordinator':
        return {
          'label': 'Village Coordinator',
          'icon': Icons.home,
          'color': Colors.orange,
        };
      case 'legal_advisor':
        return {
          'label': 'Legal Advisor',
          'icon': Icons.gavel,
          'color': Colors.indigo,
        };
      case 'volunteer':
        return {
          'label': 'Volunteer',
          'icon': Icons.volunteer_activism,
          'color': Colors.teal,
        };
      default:
        return {
          'label': 'Member',
          'icon': Icons.person,
          'color': Colors.grey,
        };
    }
  }
  
  Color _getRoleColor() {
    return _getRoleInfo()['color'];
  }
  
  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
}