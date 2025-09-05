/// TURN server credentials model
class TurnCredentials {
  final String urls;
  final String username;
  final String credential;
  final int? ttl; // Time to live in seconds
  final DateTime? expiresAt;

  TurnCredentials({
    required this.urls,
    required this.username,
    required this.credential,
    this.ttl,
    this.expiresAt,
  });

  /// Check if credentials are still valid
  bool get isValid {
    if (expiresAt != null) {
      return DateTime.now().isBefore(expiresAt!);
    }
    return true; // Assume valid if no expiration time
  }

  /// Get time remaining until expiration in seconds
  int get timeRemaining {
    if (expiresAt != null) {
      final remaining = expiresAt!.difference(DateTime.now()).inSeconds;
      return remaining > 0 ? remaining : 0;
    }
    return ttl ?? 3600; // Default 1 hour if no expiration
  }

  /// Check if credentials need refresh (less than 5 minutes remaining)
  bool get needsRefresh {
    return timeRemaining < 300; // 5 minutes
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'urls': urls,
      'username': username,
      'credential': credential,
      'ttl': ttl,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON
  factory TurnCredentials.fromJson(Map<String, dynamic> json) {
    return TurnCredentials(
      urls: json['urls'],
      username: json['username'],
      credential: json['credential'],
      ttl: json['ttl'],
      expiresAt: json['expiresAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['expiresAt'])
          : null,
    );
  }

  /// Create credentials with TTL
  factory TurnCredentials.withTtl({
    required String urls,
    required String username,
    required String credential,
    required int ttlSeconds,
  }) {
    return TurnCredentials(
      urls: urls,
      username: username,
      credential: credential,
      ttl: ttlSeconds,
      expiresAt: DateTime.now().add(Duration(seconds: ttlSeconds)),
    );
  }

  @override
  String toString() {
    return 'TurnCredentials(urls: $urls, username: $username, '
           'valid: $isValid, remaining: ${timeRemaining}s)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TurnCredentials &&
        other.urls == urls &&
        other.username == username &&
        other.credential == credential;
  }

  @override
  int get hashCode {
    return urls.hashCode ^ username.hashCode ^ credential.hashCode;
  }
}
