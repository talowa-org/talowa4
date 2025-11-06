// User Profile Tile Widget for TALOWA Messaging System
// Requirements: 1.1, 1.2, 1.3, 1.6
// Task: Build user profile display with names, profile pictures, and role information

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';


/// Widget for displaying individual user profile information in lists
class UserProfileTile extends StatelessWidget {
  final UserModel user;
  final bool showOnlineStatus;
  final bool showRole;
  final bool showLocation;
  final bool showLastSeen;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const UserProfileTile({
    super.key,
    required this.user,
    this.showOnlineStatus = true,
    this.showRole = true,
    this.showLocation = true,
    this.showLastSeen = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildProfileAvatar(),
        title: _buildUserName(),
        subtitle: _buildUserInfo(),
        trailing: trailing ?? _buildTrailingWidget(),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _getRoleColor().withOpacity(0.2),
          backgroundImage: user.profileImageUrl != null 
              ? NetworkImage(user.profileImageUrl!)
              : null,
          child: user.profileImageUrl == null
              ? Text(
                  _getInitials(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(),
                  ),
                )
              : null,
        ),
        if (showOnlineStatus) _buildOnlineStatusIndicator(),
      ],
    );
  }

  Widget _buildOnlineStatusIndicator() {
    final isOnline = _isUserOnline();
    
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: isOnline ? Colors.green : Colors.grey,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildUserName() {
    return Row(
      children: [
        Expanded(
          child: Text(
            user.fullName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'NotoSansTelugu',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showRole) _buildRoleBadge(),
      ],
    );
  }

  Widget _buildRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getRoleColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getRoleColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        _getRoleDisplayName(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _getRoleColor(),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final infoItems = <String>[];
    
    // Add phone number (partially masked for privacy)
    if (user.phoneNumber.isNotEmpty) {
      infoItems.add(_maskPhoneNumber(user.phoneNumber));
    }
    
    // Add location information
    if (showLocation) {
      final location = _getLocationString();
      if (location.isNotEmpty) {
        infoItems.add(location);
      }
    }
    
    // Add last seen information
    if (showLastSeen && user.lastLoginAt != null) {
      infoItems.add(_getLastSeenString());
    }
    
    // Add member ID
    if (user.memberId.isNotEmpty) {
      infoItems.add('ID: ${user.memberId}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (infoItems.isNotEmpty)
          Text(
            infoItems.join(' • '),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (_shouldShowStats()) _buildUserStats(),
      ],
    );
  }

  Widget _buildUserStats() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (user.directReferrals > 0) ...[
            Icon(
              Icons.people,
              size: 12,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 2),
            Text(
              '${user.directReferrals}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (user.teamSize > 0) ...[
            Icon(
              Icons.group,
              size: 12,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 2),
            Text(
              '${user.teamSize}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrailingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isUserOnline())
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Online',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else if (showLastSeen && user.lastLoginAt != null)
          Text(
            _getLastSeenString(),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        const SizedBox(height: 4),
        Icon(
          Icons.chevron_right,
          color: Colors.grey[400],
          size: 16,
        ),
      ],
    );
  }

  // Helper methods

  String _getInitials() {
    final names = user.fullName.trim().split(' ');
    if (names.isEmpty) return 'U';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }

  Color _getRoleColor() {
    switch (user.role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return Colors.red;
      case 'coordinator':
      case 'district_coordinator':
      case 'mandal_coordinator':
      case 'village_coordinator':
        return AppTheme.talowaGreen;
      case 'legal_advisor':
      case 'lawyer':
        return Colors.blue;
      case 'activist':
        return Colors.orange;
      case 'member':
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName() {
    switch (user.role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return 'Admin';
      case 'district_coordinator':
        return 'DC';
      case 'mandal_coordinator':
        return 'MC';
      case 'village_coordinator':
        return 'VC';
      case 'coordinator':
        return 'Coord';
      case 'legal_advisor':
        return 'Legal';
      case 'lawyer':
        return 'Lawyer';
      case 'activist':
        return 'Activist';
      case 'member':
        return 'Member';
      default:
        return user.role;
    }
  }

  String _getLocationString() {
    final locationParts = <String>[];
    
    if (user.address.villageCity.isNotEmpty) {
      locationParts.add(user.address.villageCity);
    }
    if (user.address.mandal.isNotEmpty && user.address.mandal != user.address.villageCity) {
      locationParts.add(user.address.mandal);
    }
    if (user.address.district.isNotEmpty && user.address.district != user.address.mandal) {
      locationParts.add(user.address.district);
    }
    
    return locationParts.take(2).join(', '); // Show max 2 location levels
  }

  String _maskPhoneNumber(String phoneNumber) {
    if (phoneNumber.length <= 4) return phoneNumber;
    
    final visibleStart = phoneNumber.substring(0, 2);
    final visibleEnd = phoneNumber.substring(phoneNumber.length - 2);
    final maskedMiddle = '*' * (phoneNumber.length - 4);
    
    return '$visibleStart$maskedMiddle$visibleEnd';
  }

  bool _isUserOnline() {
    if (user.lastLoginAt == null) return false;
    
    final now = DateTime.now();
    final lastLogin = user.lastLoginAt!;
    final difference = now.difference(lastLogin);
    
    // Consider user online if last login was within 15 minutes
    return difference.inMinutes <= 15;
  }

  String _getLastSeenString() {
    if (user.lastLoginAt == null) return 'Never';
    
    final now = DateTime.now();
    final lastLogin = user.lastLoginAt!;
    final difference = now.difference(lastLogin);
    
    if (difference.inMinutes <= 15) {
      return 'Online';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return 'Long ago';
    }
  }

  bool _shouldShowStats() {
    // Show stats for coordinators and above
    final role = user.role.toLowerCase();
    return role.contains('coordinator') || 
           role.contains('admin') || 
           role.contains('legal') ||
           user.directReferrals > 0 ||
           user.teamSize > 0;
  }
}