class UserProfile {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? profileImageUrl;
  final String role;
  final int roleLevel;
  final Map<String, dynamic> stats;
  final int directReferrals;
  final int teamSize;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.profileImageUrl,
    required this.role,
    required this.roleLevel,
    required this.stats,
    this.directReferrals = 0,
    this.teamSize = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      profileImageUrl: map['profileImageUrl'],
      role: map['role'] ?? 'member',
      roleLevel: map['roleLevel'] ?? 1,
      stats: Map<String, dynamic>.from(map['stats'] ?? {}),
      directReferrals: map['directReferrals'] ?? 0,
      teamSize: map['teamSize'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'roleLevel': roleLevel,
      'stats': stats,
      'directReferrals': directReferrals,
      'teamSize': teamSize,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? profileImageUrl,
    String? role,
    int? roleLevel,
    Map<String, dynamic>? stats,
    int? directReferrals,
    int? teamSize,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      roleLevel: roleLevel ?? this.roleLevel,
      stats: stats ?? this.stats,
      directReferrals: directReferrals ?? this.directReferrals,
      teamSize: teamSize ?? this.teamSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}