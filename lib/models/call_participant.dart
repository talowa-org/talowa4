/// Call participant model
class CallParticipant {
  final String userId;
  final String name;
  final String role;
  bool isMuted;
  String connectionQuality; // 'excellent', 'good', 'poor', 'disconnected'
  int? joinedAt;
  int? leftAt;

  CallParticipant({
    required this.userId,
    required this.name,
    required this.role,
    this.isMuted = false,
    this.connectionQuality = 'connecting',
    this.joinedAt,
    this.leftAt,
  });

  /// Check if participant is currently connected
  bool get isConnected => 
      connectionQuality != 'disconnected' && leftAt == null;

  /// Get connection quality as a numeric score (0-100)
  int get connectionScore {
    switch (connectionQuality) {
      case 'excellent':
        return 100;
      case 'good':
        return 75;
      case 'poor':
        return 25;
      case 'disconnected':
        return 0;
      default:
        return 50; // connecting
    }
  }

  /// Get connection quality color for UI
  String get connectionColor {
    switch (connectionQuality) {
      case 'excellent':
        return '#4CAF50'; // Green
      case 'good':
        return '#FFC107'; // Amber
      case 'poor':
        return '#FF9800'; // Orange
      case 'disconnected':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'role': role,
      'isMuted': isMuted,
      'connectionQuality': connectionQuality,
      'joinedAt': joinedAt,
      'leftAt': leftAt,
    };
  }

  /// Create from JSON
  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      userId: json['userId'],
      name: json['name'],
      role: json['role'],
      isMuted: json['isMuted'] ?? false,
      connectionQuality: json['connectionQuality'] ?? 'connecting',
      joinedAt: json['joinedAt'],
      leftAt: json['leftAt'],
    );
  }

  /// Create a copy with updated fields
  CallParticipant copyWith({
    String? name,
    String? role,
    bool? isMuted,
    String? connectionQuality,
    int? joinedAt,
    int? leftAt,
  }) {
    return CallParticipant(
      userId: userId,
      name: name ?? this.name,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallParticipant && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() {
    return 'CallParticipant(userId: $userId, name: $name, role: $role, '
           'isMuted: $isMuted, connectionQuality: $connectionQuality)';
  }
}
