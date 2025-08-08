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
  final int teamSize;
  final bool membershipPaid;
  final String? paymentTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final UserPreferences preferences;
  final bool isActive;

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
    required this.membershipPaid,
    this.paymentTransactionId,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    required this.preferences,
    this.isActive = true,
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
      membershipPaid: data['membershipPaid'] ?? false,
      paymentTransactionId: data['paymentTransactionId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      preferences: UserPreferences.fromMap(data['preferences'] ?? {}),
      isActive: data['isActive'] ?? true,
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
      'membershipPaid': membershipPaid,
      'paymentTransactionId': paymentTransactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'preferences': preferences.toMap(),
      'isActive': isActive,
    };
  }

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
      notifications: NotificationPreferences.fromMap(map['notifications'] ?? {}),
      privacy: PrivacyPreferences.fromMap(map['privacy'] ?? {}),
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

  Map<String, dynamic> toMap() {
    return {
      'push': push,
      'sms': sms,
      'email': email,
    };
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

  Map<String, dynamic> toMap() {
    return {
      'showLocation': showLocation,
      'allowDirectContact': allowDirectContact,
    };
  }
}