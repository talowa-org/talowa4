// Role Model for Talowa Referral System
// Adapted from BSS webapp but simplified for Talowa's needs

import 'package:flutter/material.dart';

class RoleModel {
  final int level;
  final String name;
  final IconData icon;
  final int directReferralsNeeded;
  final int teamReferralsNeeded;
  final Color color;

  const RoleModel({
    required this.level,
    required this.name,
    required this.icon,
    required this.directReferralsNeeded,
    required this.teamReferralsNeeded,
    required this.color,
  });
}

// Talowa Role Definitions (Simplified from BSS's 9 levels to 3 levels)
class TalowaRoles {
  static const List<RoleModel> roles = [
    RoleModel(
      level: 0,
      name: 'Admin',
      icon: Icons.admin_panel_settings,
      directReferralsNeeded: 0,
      teamReferralsNeeded: 0,
      color: Colors.purple,
    ),
    RoleModel(
      level: 1,
      name: 'Member',
      icon: Icons.person,
      directReferralsNeeded: 0,
      teamReferralsNeeded: 0,
      color: Colors.blue,
    ),
    RoleModel(
      level: 2,
      name: 'Volunteer',
      icon: Icons.star,
      directReferralsNeeded: 5, // Need 5 direct referrals
      teamReferralsNeeded: 0,
      color: Colors.orange,
    ),
    RoleModel(
      level: 3,
      name: 'Leader',
      icon: Icons.groups,
      directReferralsNeeded: 0,
      teamReferralsNeeded: 50, // Need 50 team members
      color: Colors.green,
    ),
  ];

  static RoleModel? getRoleByLevel(int level) {
    try {
      return roles.firstWhere((role) => role.level == level);
    } catch (e) {
      return null;
    }
  }

  static RoleModel? getNextRole(int currentLevel) {
    try {
      return roles.firstWhere((role) => role.level == currentLevel + 1);
    } catch (e) {
      return null;
    }
  }
}