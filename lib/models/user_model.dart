// User Model for TALOWA
// Reference: TECHNICAL_ARCHITECTURE.md - Database Design

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class UserModel {
  final String id;
  final String phoneNumber;
  final String email;
  final String fullName;
  final String role;
  final String memberId;
  final String referralCode;
  final String? referredBy;
  final Address address;
  final int directReferrals;
  final int teamSize; // This will be renamed to teamReferrals for consistency with BSS
  final int teamReferrals; // New field for BSS compatibility
  final int currentRoleLevel; // New field for role level tracking
  final bool membershipPaid;
  final String? paymentTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final UserPreferences preferences;
  final bool isActive;
  final String? pinHash; // For phone auth users

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.email,
    required this.fullName,
    required this.role,
    required this.memberId,
    required this.referralCode,
    this.referredBy,
    required this.address,
    required this.directReferrals,
    required this.teamSize,
    required this.teamReferrals,
    required this.currentRoleLevel,
    required this.membershipPaid,
    this.paymentTransactionId,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    required this.preferences,
    this.isActive = true,
    this.pinHash,
  });

  // Convert from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      role: data['role'] ?? AppConstants.roleMember,
      memberId: data['memberId'] ?? '',
      referralCode: data['referralCode'] ?? '',
      referredBy: data['referredBy'],
      address: Address.fromMap(data['address'] ?? {}),
      directReferrals: data['directReferrals'] ?? 0,
      teamSize: data['teamSize'] ?? 0,
      teamReferrals: data['teamReferrals'] ?? data['teamSize'] ?? 0, // Use teamSize as fallback
      currentRoleLevel: data['currentRoleLevel'] ?? 1, // Default to Member level
      membershipPaid: data['membershipPaid'] ?? false,
      paymentTransactionId: data['paymentTransactionId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      preferences: UserPreferences.fromMap(data['preferences'] ?? {}),
      isActive: data['isActive'] ?? true,
      pinHash: data['pinHash'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
      'email': email,
      'fullName': fullName,
      'role': role,
      'memberId': memberId,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'address': address.toMap(),
      'directReferrals': directReferrals,
      'teamSize': teamSize,
      'teamReferrals': teamReferrals,
      'currentRoleLevel': currentRoleLevel,
      'membershipPaid': membershipPaid,
      'paymentTransactionId': paymentTransactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
      'preferences': preferences.toMap(),
      'isActive': isActive,
      'pinHash': pinHash,
    };
  }

  // Convert to Map for caching
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'email': email,
      'fullName': fullName,
      'role': role,
      'memberId': memberId,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'address': address.toMap(),
      'directReferrals': directReferrals,
      'teamSize': teamSize,
      'teamReferrals': teamReferrals,
      'currentRoleLevel': currentRoleLevel,
      'membershipPaid': membershipPaid,
      'paymentTransactionId': paymentTransactionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'preferences': preferences.toMap(),
      'isActive': isActive,
    };
  }

  // Convert from Map for caching
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? AppConstants.roleMember,
      memberId: map['memberId'] ?? '',
      referralCode: map['referralCode'] ?? '',
      referredBy: map['referredBy'],
      address: Address.fromMap(Map<String, dynamic>.from(map['address'] ?? {})),
      directReferrals: map['directReferrals'] ?? 0,
      teamSize: map['teamSize'] ?? 0,
      teamReferrals: map['teamReferrals'] ?? map['teamSize'] ?? 0,
      currentRoleLevel: map['currentRoleLevel'] ?? 1,
      membershipPaid: map['membershipPaid'] ?? false,
      paymentTransactionId: map['paymentTransactionId'],
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : null,
      preferences: UserPreferences.fromMap(
        Map<String, dynamic>.from(map['preferences'] ?? {}),
      ),
      isActive: map['isActive'] ?? true,
    );
  }

  // Add profileImageUrl getter for compatibility
  String? get profileImageUrl => null; // Can be added later if needed

  // Create copy with updated fields
  UserModel copyWith({
    String? phoneNumber,
    String? email,
    String? fullName,
    String? role,
    String? memberId,
    String? referralCode,
    String? referredBy,
    Address? address,
    int? directReferrals,
    int? teamSize,
    int? teamReferrals,
    int? currentRoleLevel,
    bool? membershipPaid,
    String? paymentTransactionId,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    UserPreferences? preferences,
    bool? isActive,
  }) {
    return UserModel(
      id: id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      memberId: memberId ?? this.memberId,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      address: address ?? this.address,
      directReferrals: directReferrals ?? this.directReferrals,
      teamSize: teamSize ?? this.teamSize,
      teamReferrals: teamReferrals ?? this.teamReferrals,
      currentRoleLevel: currentRoleLevel ?? this.currentRoleLevel,
      membershipPaid: membershipPaid ?? this.membershipPaid,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      isActive: isActive ?? this.isActive,
    );
  }
}

class Address {
  final String? houseNo;
  final String? street;
  final String villageCity;
  final String mandal;
  final String district;
  final String state;
  final String? pincode;

  Address({
    this.houseNo,
    this.street,
    required this.villageCity,
    required this.mandal,
    required this.district,
    required this.state,
    this.pincode,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      houseNo: map['houseNo'],
      street: map['street'],
      villageCity: map['villageCity'] ?? '',
      mandal: map['mandal'] ?? '',
      district: map['district'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'houseNo': houseNo,
      'street': street,
      'villageCity': villageCity,
      'mandal': mandal,
      'district': district,
      'state': state,
      'pincode': pincode,
    };
  }
}

class UserPreferences {
  final String language;
  final NotificationPreferences notifications;
  final PrivacyPreferences privacy;

  UserPreferences({
    required this.language,
    required this.notifications,
    required this.privacy,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      language: map['language'] ?? AppConstants.languageEnglish,
      notifications: NotificationPreferences.fromMap(
        map['notifications'] ?? {},
      ),
      privacy: PrivacyPreferences.fromMap(map['privacy'] ?? {}),
    );
  }

  factory UserPreferences.defaultPreferences() {
    return UserPreferences(
      language: AppConstants.languageEnglish,
      notifications: NotificationPreferences.defaultPreferences(),
      privacy: PrivacyPreferences.defaultPreferences(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'language': language,
      'notifications': notifications.toMap(),
      'privacy': privacy.toMap(),
    };
  }
}

class NotificationPreferences {
  final bool push;
  final bool sms;
  final bool email;

  NotificationPreferences({
    required this.push,
    required this.sms,
    required this.email,
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      push: map['push'] ?? true,
      sms: map['sms'] ?? true,
      email: map['email'] ?? false,
    );
  }

  factory NotificationPreferences.defaultPreferences() {
    return NotificationPreferences(push: true, sms: true, email: false);
  }

  Map<String, dynamic> toMap() {
    return {'push': push, 'sms': sms, 'email': email};
  }
}

class PrivacyPreferences {
  final bool showLocation;
  final bool allowDirectContact;

  PrivacyPreferences({
    required this.showLocation,
    required this.allowDirectContact,
  });

  factory PrivacyPreferences.fromMap(Map<String, dynamic> map) {
    return PrivacyPreferences(
      showLocation: map['showLocation'] ?? false,
      allowDirectContact: map['allowDirectContact'] ?? true,
    );
  }

  factory PrivacyPreferences.defaultPreferences() {
    return PrivacyPreferences(showLocation: false, allowDirectContact: true);
  }

  Map<String, dynamic> toMap() {
    return {
      'showLocation': showLocation,
      'allowDirectContact': allowDirectContact,
    };
  }
}
