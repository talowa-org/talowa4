import 'package:cloud_firestore/cloud_firestore.dart';

/// Referral status enumeration
enum ReferralStatus {
  pending_payment,
  active,
  suspended,
  cancelled,
  auto_assigned,
  admin_assigned
}

/// User role enumeration for referral system
enum UserRole {
  member,
  team_leader,
  coordinator,
  area_coordinator_urban,
  village_coordinator_rural,
  mandal_coordinator,
  constituency_coordinator,
  district_coordinator,
  zonal_regional_coordinator,
  state_coordinator
}

/// Achievement type enumeration
enum AchievementType {
  role_promotion,
  referral_milestone,
  team_milestone,
  special_recognition
}

/// Milestone type enumeration
enum MilestoneType {
  direct_referrals,
  team_size,
  monthly_growth,
  retention_rate
}

/// Referral code lookup model
class ReferralCodeLookup {
  final String code;
  final String? uid;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? deactivatedAt;
  final int clickCount;
  final int conversionCount;

  const ReferralCodeLookup({
    required this.code,
    this.uid,
    required this.isActive,
    required this.createdAt,
    this.deactivatedAt,
    required this.clickCount,
    required this.conversionCount,
  });

  factory ReferralCodeLookup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReferralCodeLookup(
      code: data['code'] ?? '',
      uid: data['uid'],
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deactivatedAt: (data['deactivatedAt'] as Timestamp?)?.toDate(),
      clickCount: data['clickCount'] ?? 0,
      conversionCount: data['conversionCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'uid': uid,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'deactivatedAt': deactivatedAt != null ? Timestamp.fromDate(deactivatedAt!) : null,
      'clickCount': clickCount,
      'conversionCount': conversionCount,
    };
  }

  ReferralCodeLookup copyWith({
    String? code,
    String? uid,
    bool? isActive,
    DateTime? createdAt,
    DateTime? deactivatedAt,
    int? clickCount,
    int? conversionCount,
  }) {
    return ReferralCodeLookup(
      code: code ?? this.code,
      uid: uid ?? this.uid,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
      clickCount: clickCount ?? this.clickCount,
      conversionCount: conversionCount ?? this.conversionCount,
    );
  }
}

/// Achievement model
class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final DateTime earnedAt;
  final AchievementType type;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.earnedAt,
    required this.type,
  });

  factory Achievement.fromFirestore(Map<String, dynamic> data) {
    return Achievement(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      iconUrl: data['iconUrl'] ?? '',
      earnedAt: (data['earnedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: AchievementType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => AchievementType.special_recognition,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconUrl': iconUrl,
      'earnedAt': Timestamp.fromDate(earnedAt),
      'type': type.toString(),
    };
  }
}

/// Milestone model
class Milestone {
  final String id;
  final String title;
  final int targetValue;
  final int currentValue;
  final MilestoneType type;
  final bool isCompleted;
  final DateTime? completedAt;

  const Milestone({
    required this.id,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.type,
    required this.isCompleted,
    this.completedAt,
  });

  factory Milestone.fromFirestore(Map<String, dynamic> data) {
    return Milestone(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      targetValue: data['targetValue'] ?? 0,
      currentValue: data['currentValue'] ?? 0,
      type: MilestoneType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => MilestoneType.direct_referrals,
      ),
      isCompleted: data['isCompleted'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'type': type.toString(),
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  double get progress {
    if (targetValue == 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }
}

/// Referral analytics model
class ReferralAnalytics {
  final String userId;
  final String period; // daily, weekly, monthly
  final DateTime date;
  
  // Click Metrics
  final int linkClicks;
  final int uniqueClicks;
  final Map<String, int> clicksBySource;
  
  // Conversion Metrics
  final int registrations;
  final int paidConversions;
  final double conversionRate;
  
  // Geographic Data
  final Map<String, int> clicksByLocation;
  final Map<String, int> conversionsByLocation;
  
  // Performance
  final double viralCoefficient;
  final int networkGrowth;

  const ReferralAnalytics({
    required this.userId,
    required this.period,
    required this.date,
    required this.linkClicks,
    required this.uniqueClicks,
    required this.clicksBySource,
    required this.registrations,
    required this.paidConversions,
    required this.conversionRate,
    required this.clicksByLocation,
    required this.conversionsByLocation,
    required this.viralCoefficient,
    required this.networkGrowth,
  });

  factory ReferralAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReferralAnalytics(
      userId: data['userId'] ?? '',
      period: data['period'] ?? 'daily',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      linkClicks: data['linkClicks'] ?? 0,
      uniqueClicks: data['uniqueClicks'] ?? 0,
      clicksBySource: Map<String, int>.from(data['clicksBySource'] ?? {}),
      registrations: data['registrations'] ?? 0,
      paidConversions: data['paidConversions'] ?? 0,
      conversionRate: (data['conversionRate'] ?? 0.0).toDouble(),
      clicksByLocation: Map<String, int>.from(data['clicksByLocation'] ?? {}),
      conversionsByLocation: Map<String, int>.from(data['conversionsByLocation'] ?? {}),
      viralCoefficient: (data['viralCoefficient'] ?? 0.0).toDouble(),
      networkGrowth: data['networkGrowth'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'period': period,
      'date': Timestamp.fromDate(date),
      'linkClicks': linkClicks,
      'uniqueClicks': uniqueClicks,
      'clicksBySource': clicksBySource,
      'registrations': registrations,
      'paidConversions': paidConversions,
      'conversionRate': conversionRate,
      'clicksByLocation': clicksByLocation,
      'conversionsByLocation': conversionsByLocation,
      'viralCoefficient': viralCoefficient,
      'networkGrowth': networkGrowth,
    };
  }
}

