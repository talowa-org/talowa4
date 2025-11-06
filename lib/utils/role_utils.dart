// TALOWA Role Utilities
// Centralized role management for consistent display and behavior across all tabs

import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../services/referral/role_progression_service.dart';

/// Centralized role utility for consistent role handling across the application
class RoleUtils {
  /// Role key to display name mapping (standardized)
  static const Map<String, String> _roleDisplayNames = {
    'member': 'Member',
    'volunteer': 'Volunteer', 
    'team_leader': 'Team Leader',
    'area_coordinator': 'Area Coordinator',
    'mandal_coordinator': 'Mandal Coordinator',
    'village_coordinator': 'Village Coordinator', // Legacy support
    'constituency_coordinator': 'Constituency Coordinator',
    'district_coordinator': 'District Coordinator',
    'zonal_regional_coordinator': 'Zonal Regional Coordinator',
    'regional_coordinator': 'Regional Coordinator', // Legacy support
    'state_coordinator': 'State Coordinator',
    'national_leadership': 'National Leadership', // Legacy support
    'legal_advisor': 'Legal Advisor',
    'media_coordinator': 'Media Coordinator',
    'founder': 'Founder',
    'admin': 'Administrator',
    'root_admin': 'Root Administrator',
  };

  /// Role key to color mapping (standardized)
  static const Map<String, Color> _roleColors = {
    'member': Colors.blue,
    'volunteer': Colors.lightBlue,
    'team_leader': Colors.green,
    'area_coordinator': Colors.orange,
    'mandal_coordinator': Colors.deepOrange,
    'village_coordinator': Colors.deepOrange, // Same as mandal_coordinator
    'constituency_coordinator': Colors.red,
    'district_coordinator': Colors.purple,
    'zonal_regional_coordinator': Colors.indigo,
    'regional_coordinator': Colors.indigo, // Same as zonal_regional_coordinator
    'state_coordinator': Colors.amber,
    'national_leadership': Colors.amber, // Same as state_coordinator
    'legal_advisor': Color(AppConstants.legalBlueValue),
    'media_coordinator': Colors.pink,
    'founder': Colors.deepPurple,
    'admin': Colors.purple,
    'root_admin': Colors.deepPurple,
  };

  /// Get standardized display name for any role
  static String getDisplayName(String? role) {
    if (role == null || role.isEmpty) return 'Member';
    
    // Normalize role key (handle both snake_case and display names)
    final normalizedRole = _normalizeRoleKey(role);
    
    return _roleDisplayNames[normalizedRole] ?? 'Member';
  }

  /// Get standardized color for any role
  static Color getColor(String? role) {
    if (role == null || role.isEmpty) return Colors.blue;
    
    // Normalize role key
    final normalizedRole = _normalizeRoleKey(role);
    
    return _roleColors[normalizedRole] ?? Colors.blue;
  }

  /// Get role level from RoleProgressionService
  static int getLevel(String? role) {
    if (role == null || role.isEmpty) return 1;
    
    final normalizedRole = _normalizeRoleKey(role);
    final roleDefinition = RoleProgressionService.getRoleDefinition(normalizedRole);
    
    return roleDefinition?.level ?? 1;
  }

  /// Check if a role is higher than another in the hierarchy
  static bool isRoleHigher(String roleA, String roleB) {
    final levelA = getLevel(roleA);
    final levelB = getLevel(roleB);
    return levelA > levelB;
  }

  /// Get role permissions from RoleProgressionService
  static List<String> getPermissions(String? role) {
    if (role == null || role.isEmpty) return ['basic_access'];
    
    final normalizedRole = _normalizeRoleKey(role);
    final roleDefinition = RoleProgressionService.getRoleDefinition(normalizedRole);
    
    return roleDefinition?.permissions ?? ['basic_access'];
  }

  /// Check if user has specific permission
  static bool hasPermission(String? role, String permission) {
    final permissions = getPermissions(role);
    return permissions.contains(permission);
  }

  /// Get next role in hierarchy
  static String? getNextRole(String? currentRole) {
    if (currentRole == null || currentRole.isEmpty) return 'volunteer';
    
    final normalizedRole = _normalizeRoleKey(currentRole);
    const hierarchy = RoleProgressionService.ROLE_HIERARCHY;
    final currentIndex = hierarchy.indexOf(normalizedRole);
    
    if (currentIndex == -1 || currentIndex >= hierarchy.length - 1) {
      return null; // Already at highest role or role not found
    }
    
    return hierarchy[currentIndex + 1];
  }

  /// Check if role is coordinator level or above
  static bool isCoordinator(String? role) {
    if (role == null || role.isEmpty) return false;
    
    final level = getLevel(role);
    return level >= 4; // Area Coordinator and above
  }

  /// Check if role is admin level
  static bool isAdmin(String? role) {
    if (role == null || role.isEmpty) return false;
    
    final normalizedRole = _normalizeRoleKey(role);
    return ['admin', 'root_admin', 'founder', 'national_leadership'].contains(normalizedRole);
  }

  /// Normalize role key to snake_case format used by RoleProgressionService
  static String _normalizeRoleKey(String role) {
    // Handle common variations and convert to snake_case
    final lowerRole = role.toLowerCase().trim();
    
    // Direct mappings for common variations
    const mappings = {
      'member': 'member',
      'volunteer': 'volunteer',
      'team leader': 'team_leader',
      'area coordinator': 'area_coordinator',
      'mandal coordinator': 'mandal_coordinator',
      'village coordinator': 'mandal_coordinator', // Map to mandal_coordinator
      'constituency coordinator': 'constituency_coordinator',
      'district coordinator': 'district_coordinator',
      'zonal regional coordinator': 'zonal_regional_coordinator',
      'regional coordinator': 'zonal_regional_coordinator', // Map to zonal
      'state coordinator': 'state_coordinator',
      'national leadership': 'state_coordinator', // Map to state_coordinator
      'legal advisor': 'legal_advisor',
      'media coordinator': 'media_coordinator',
      'founder': 'founder',
      'admin': 'admin',
      'administrator': 'admin',
      'root administrator': 'root_admin',
      'root admin': 'root_admin',
    };
    
    // Check direct mappings first
    if (mappings.containsKey(lowerRole)) {
      return mappings[lowerRole]!;
    }
    
    // Convert spaces to underscores and return
    return lowerRole.replaceAll(' ', '_');
  }

  /// Get all available roles in hierarchy order
  static List<Map<String, dynamic>> getAllRoles() {
    return RoleProgressionService.ROLE_HIERARCHY.map((roleKey) {
      final definition = RoleProgressionService.getRoleDefinition(roleKey);
      return {
        'key': roleKey,
        'name': getDisplayName(roleKey),
        'level': definition?.level ?? 1,
        'color': getColor(roleKey),
        'permissions': definition?.permissions ?? ['basic_access'],
      };
    }).toList();
  }

  /// Format role for display with proper capitalization
  static String formatRoleForDisplay(String? role) {
    final displayName = getDisplayName(role);
    return displayName;
  }

  /// Get role badge widget for consistent UI display
  static Widget getRoleBadge(String? role, {double fontSize = 12}) {
    final displayName = getDisplayName(role);
    final color = getColor(role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}