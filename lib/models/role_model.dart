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

// Talowa Role Definitions (Complete 9-level hierarchy)
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
      name: 'Active Member',
      icon: Icons.person_outline,
      directReferralsNeeded: 10,
      teamReferralsNeeded: 10,
      color: Colors.lightBlue,
    ),
    RoleModel(
      level: 3,
      name: 'Team Leader',
      icon: Icons.groups,
      directReferralsNeeded: 20,
      teamReferralsNeeded: 100,
      color: Colors.green,
    ),
    RoleModel(
      level: 4,
      name: 'Area Coordinator',
      icon: Icons.location_city,
      directReferralsNeeded: 40,
      teamReferralsNeeded: 700,
      color: Colors.orange,
    ),
    RoleModel(
      level: 5,
      name: 'Mandal Coordinator',
      icon: Icons.account_balance,
      directReferralsNeeded: 80,
      teamReferralsNeeded: 6000,
      color: Colors.deepOrange,
    ),
    RoleModel(
      level: 6,
      name: 'Constituency Coordinator',
      icon: Icons.business,
      directReferralsNeeded: 160,
      teamReferralsNeeded: 50000,
      color: Colors.red,
    ),
    RoleModel(
      level: 7,
      name: 'District Coordinator',
      icon: Icons.domain,
      directReferralsNeeded: 320,
      teamReferralsNeeded: 500000,
      color: Colors.indigo,
    ),
    RoleModel(
      level: 8,
      name: 'Zonal Coordinator',
      icon: Icons.public,
      directReferralsNeeded: 500,
      teamReferralsNeeded: 1000000,
      color: Colors.deepPurple,
    ),
    RoleModel(
      level: 9,
      name: 'State Coordinator',
      icon: Icons.flag,
      directReferralsNeeded: 1000,
      teamReferralsNeeded: 3000000,
      color: Colors.amber,
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
