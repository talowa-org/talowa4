// Emergency Service for TALOWA
// Comprehensive emergency response and incident reporting system
// Reference: TALOWA_APP_BLUEPRINT.md - Emergency Features

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Emergency contact numbers
  static const Map<String, String> emergencyContacts = {
    'police': '100',
    'fire': '101',
    'ambulance': '108',
    'women_helpline': '1091',
    'child_helpline': '1098',
    'disaster_management': '1070',
    'talowa_helpline': '+91-800-TALOWA',
  };

  /// Trigger SOS alert with GPS location
  Future<String?> triggerSOS({
    required EmergencyType type,
    String? description,
    List<String>? mediaUrls,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get current location
      final position = await _getCurrentLocation();
      
      // Create emergency incident
      final incident = EmergencyIncident(
        id: '', // Will be set by Firestore
        reporterId: user.uid,
        type: type,
        description: description ?? 'SOS Alert triggered',
        location: position != null
            ? GeoPoint(position.latitude, position.longitude)
            : null,
        mediaUrls: mediaUrls ?? [],
        status: IncidentStatus.active,
        isAnonymous: false,
        priority: EmergencyPriority.critical,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('emergency_incidents')
          .add(incident.toMap());

      final incidentId = docRef.id;

      // Send immediate alerts
      await Future.wait([
        _notifyEmergencyContacts(incidentId, incident),
        _broadcastEmergencyAlert(incidentId, incident),
        _notifyNearbyCoordinators(incident),
      ]);

      // Log SOS activity
      await _logEmergencyActivity(
        incidentId: incidentId,
        action: 'sos_triggered',
        details: 'SOS alert triggered by user',
      );

      return incidentId;
    } catch (e) {
      debugPrint('Error triggering SOS: $e');
      return null;
    }
  }

  /// Report incident (can be anonymous)
  Future<String?> reportIncident({
    required EmergencyType type,
    required String description,
    String? location,
    List<String>? mediaUrls,
    bool isAnonymous = false,
    EmergencyPriority priority = EmergencyPriority.medium,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null && !isAnonymous) {
        throw Exception('User not authenticated');
      }

      // Get GPS location if not provided
      Position? position;
      if (location == null) {
        position = await _getCurrentLocation();
      }

      // Create incident
      final incident = EmergencyIncident(
        id: '', // Will be set by Firestore
        reporterId: isAnonymous ? null : user?.uid,
        type: type,
        description: description,
        location: position != null
            ? GeoPoint(position.latitude, position.longitude)
            : null,
        locationDescription: location,
        mediaUrls: mediaUrls ?? [],
        status: IncidentStatus.reported,
        isAnonymous: isAnonymous,
        priority: priority,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('emergency_incidents')
          .add(incident.toMap());

      final incidentId = docRef.id;

      // Notify coordinators based on priority
      if (priority == EmergencyPriority.critical ||
          priority == EmergencyPriority.high) {
        await _notifyNearbyCoordinators(incident);
      }

      // Log activity
      await _logEmergencyActivity(
        incidentId: incidentId,
        action: 'incident_reported',
        details: isAnonymous
            ? 'Anonymous incident reported'
            : 'Incident reported by user',
      );

      return incidentId;
    } catch (e) {
      debugPrint('Error reporting incident: $e');
      return null;
    }
  }

  /// Get emergency contacts for user's location
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return _getDefaultEmergencyContacts();
      }

      // Get user's location info
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return _getDefaultEmergencyContacts();
      }

      final userData = userDoc.data()!;
      final district = userData['district'] as String?;
      final mandal = userData['mandal'] as String?;

      // Get location-specific contacts
      final contacts = await _getLocationSpecificContacts(district, mandal);
      
      // Add default contacts
      contacts.addAll(_getDefaultEmergencyContacts());

      return contacts;
    } catch (e) {
      debugPrint('Error getting emergency contacts: $e');
      return _getDefaultEmergencyContacts();
    }
  }

  /// Get user's emergency incidents
  Stream<List<EmergencyIncident>> getUserIncidents() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('emergency_incidents')
        .where('reporterId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmergencyIncident.fromFirestore(doc))
            .toList());
  }

  /// Get nearby incidents (for coordinators)
  Stream<List<EmergencyIncident>> getNearbyIncidents({
    required String district,
    String? mandal,
    int limit = 20,
  }) {
    // Use simpler query to avoid index requirements
    Query query = _firestore
        .collection('emergency_incidents')
        .orderBy('createdAt', descending: true)
        .limit(limit * 2); // Get more to filter locally

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => EmergencyIncident.fromFirestore(doc))
        .where((incident) => 
          // Filter active incidents locally
          (incident.status == IncidentStatus.active ||
           incident.status == IncidentStatus.reported ||
           incident.status == IncidentStatus.investigating) &&
          _isIncidentNearby(incident, district, mandal))
        .take(limit)
        .toList());
  }

  /// Update incident status (for coordinators)
  Future<bool> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus status,
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is coordinator
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;
      
      if (!_isCoordinator(role)) {
        throw Exception('Only coordinators can update incident status');
      }

      // Update incident
      await _firestore
          .collection('emergency_incidents')
          .doc(incidentId)
          .update({
        'status': status.toString(),
        'handledBy': user.uid,
        'handlerNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log activity
      await _logEmergencyActivity(
        incidentId: incidentId,
        action: 'status_updated',
        details: 'Status updated to ${status.toString()} by coordinator',
      );

      // Notify reporter if not anonymous
      await _notifyIncidentUpdate(incidentId, status);

      return true;
    } catch (e) {
      debugPrint('Error updating incident status: $e');
      return false;
    }
  }

  /// Make emergency call
  Future<bool> makeEmergencyCall(String contactType) async {
    try {
      final phoneNumber = emergencyContacts[contactType];
      if (phoneNumber == null) {
        throw Exception('Contact type not found');
      }

      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        
        // Log emergency call
        await _logEmergencyActivity(
          incidentId: null,
          action: 'emergency_call',
          details: 'Emergency call made to $contactType ($phoneNumber)',
        );
        
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error making emergency call: $e');
      return false;
    }
  }

  /// Send emergency broadcast to area
  Future<bool> sendEmergencyBroadcast({
    required String title,
    required String message,
    required String district,
    String? mandal,
    String? village,
    EmergencyPriority priority = EmergencyPriority.high,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is coordinator
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;
      
      if (!_isCoordinator(role)) {
        throw Exception('Only coordinators can send emergency broadcasts');
      }

      // Create broadcast
      final broadcast = EmergencyBroadcast(
        id: '', // Will be set by Firestore
        senderId: user.uid,
        title: title,
        message: message,
        district: district,
        mandal: mandal,
        village: village,
        priority: priority,
        createdAt: DateTime.now(),
      );

      // Save broadcast
      final docRef = await _firestore
          .collection('emergency_broadcasts')
          .add(broadcast.toMap());

      // Send notifications to users in the area
      await _sendBroadcastNotifications(broadcast);

      // Log activity
      await _logEmergencyActivity(
        incidentId: null,
        action: 'broadcast_sent',
        details: 'Emergency broadcast sent to $district',
      );

      return true;
    } catch (e) {
      debugPrint('Error sending emergency broadcast: $e');
      return false;
    }
  }

  // Private helper methods

  Future<Position?> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Future<void> _notifyEmergencyContacts(
    String incidentId,
    EmergencyIncident incident,
  ) async {
    try {
      // Get emergency contacts for the area
      final contacts = await getEmergencyContacts();
      
      // Send notifications to relevant contacts
      for (final contact in contacts) {
        if (contact.type == ContactType.coordinator ||
            contact.type == ContactType.police) {
          // Send push notification or SMS
          await _sendEmergencyNotification(
            contact.phoneNumber,
            'Emergency Alert',
            'SOS triggered: ${incident.description}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error notifying emergency contacts: $e');
    }
  }

  Future<void> _broadcastEmergencyAlert(
    String incidentId,
    EmergencyIncident incident,
  ) async {
    try {
      // Create emergency post in social feed
      await _firestore.collection('feed_posts').add({
        'authorId': incident.reporterId,
        'title': '🚨 EMERGENCY ALERT',
        'content': incident.description,
        'category': 'emergency',
        'isEmergency': true,
        'priority': 'critical',
        'incidentId': incidentId,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': 'public',
      });
    } catch (e) {
      debugPrint('Error broadcasting emergency alert: $e');
    }
  }

  Future<void> _notifyNearbyCoordinators(EmergencyIncident incident) async {
    try {
      // Find coordinators in the area
      final coordinators = await _firestore
          .collection('users')
          .where('role', whereIn: [
            'village_coordinator',
            'mandal_coordinator',
            'district_coordinator',
          ])
          .get();

      // Send notifications to relevant coordinators
      for (final doc in coordinators.docs) {
        final coordinator = doc.data();
        // Check if coordinator is in the same area
        // Send notification
        await _sendPushNotification(
          doc.id,
          'Emergency Incident',
          'New ${incident.type.toString()} reported in your area',
        );
      }
    } catch (e) {
      debugPrint('Error notifying coordinators: $e');
    }
  }

  List<EmergencyContact> _getDefaultEmergencyContacts() {
    return [
      EmergencyContact(
        name: 'Police',
        phoneNumber: '100',
        type: ContactType.police,
        isAvailable24x7: true,
      ),
      EmergencyContact(
        name: 'Fire Department',
        phoneNumber: '101',
        type: ContactType.fire,
        isAvailable24x7: true,
      ),
      EmergencyContact(
        name: 'Ambulance',
        phoneNumber: '108',
        type: ContactType.medical,
        isAvailable24x7: true,
      ),
      EmergencyContact(
        name: 'TALOWA Helpline',
        phoneNumber: '+91-800-TALOWA',
        type: ContactType.coordinator,
        isAvailable24x7: true,
      ),
    ];
  }

  Future<List<EmergencyContact>> _getLocationSpecificContacts(
    String? district,
    String? mandal,
  ) async {
    try {
      Query query = _firestore.collection('emergency_contacts');
      
      if (district != null) {
        query = query.where('district', isEqualTo: district);
      }
      
      if (mandal != null) {
        query = query.where('mandal', isEqualTo: mandal);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => EmergencyContact.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting location-specific contacts: $e');
      return [];
    }
  }

  bool _isIncidentNearby(
    EmergencyIncident incident,
    String district,
    String? mandal,
  ) {
    // This would use GPS coordinates in production
    // For now, use simple location matching
    return true; // Simplified for demo
  }

  bool _isCoordinator(String? role) {
    return role != null && role.contains('coordinator');
  }

  Future<void> _notifyIncidentUpdate(
    String incidentId,
    IncidentStatus status,
  ) async {
    try {
      // Get incident details
      final doc = await _firestore
          .collection('emergency_incidents')
          .doc(incidentId)
          .get();

      if (!doc.exists) return;

      final incident = EmergencyIncident.fromFirestore(doc);
      if (incident.isAnonymous || incident.reporterId == null) return;

      // Send notification to reporter
      await _sendPushNotification(
        incident.reporterId!,
        'Incident Update',
        'Your incident report has been updated to: ${status.toString()}',
      );
    } catch (e) {
      debugPrint('Error notifying incident update: $e');
    }
  }

  Future<void> _sendEmergencyNotification(
    String phoneNumber,
    String title,
    String message,
  ) async {
    // This would integrate with SMS service in production
    debugPrint('Emergency notification: $title - $message to $phoneNumber');
  }

  Future<void> _sendPushNotification(
    String userId,
    String title,
    String message,
  ) async {
    // This would send FCM notification in production
    debugPrint('Push notification to $userId: $title - $message');
  }

  Future<void> _sendBroadcastNotifications(EmergencyBroadcast broadcast) async {
    // This would send notifications to all users in the specified area
    debugPrint('Broadcasting: ${broadcast.title} to ${broadcast.district}');
  }

  Future<void> _logEmergencyActivity({
    String? incidentId,
    required String action,
    required String details,
  }) async {
    try {
      final user = _auth.currentUser;
      await _firestore.collection('emergency_activities').add({
        'incidentId': incidentId,
        'userId': user?.uid,
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging emergency activity: $e');
    }
  }
}

// Data models for emergency system

enum EmergencyType {
  landGrabbing,
  harassment,
  violence,
  naturalDisaster,
  medicalEmergency,
  fire,
  accident,
  other,
}

enum IncidentStatus {
  reported,
  active,
  investigating,
  resolved,
  closed,
}

enum EmergencyPriority {
  low,
  medium,
  high,
  critical,
}

enum ContactType {
  police,
  fire,
  medical,
  coordinator,
  legal,
  government,
}

class EmergencyIncident {
  final String id;
  final String? reporterId;
  final EmergencyType type;
  final String description;
  final GeoPoint? location;
  final String? locationDescription;
  final List<String> mediaUrls;
  final IncidentStatus status;
  final bool isAnonymous;
  final EmergencyPriority priority;
  final String? handledBy;
  final String? handlerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmergencyIncident({
    required this.id,
    this.reporterId,
    required this.type,
    required this.description,
    this.location,
    this.locationDescription,
    required this.mediaUrls,
    required this.status,
    required this.isAnonymous,
    required this.priority,
    this.handledBy,
    this.handlerNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'type': type.toString(),
      'description': description,
      'location': location,
      'locationDescription': locationDescription,
      'mediaUrls': mediaUrls,
      'status': status.toString(),
      'isAnonymous': isAnonymous,
      'priority': priority.toString(),
      'handledBy': handledBy,
      'handlerNotes': handlerNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EmergencyIncident.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyIncident(
      id: doc.id,
      reporterId: data['reporterId'],
      type: EmergencyType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => EmergencyType.other,
      ),
      description: data['description'] ?? '',
      location: data['location'],
      locationDescription: data['locationDescription'],
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      status: IncidentStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => IncidentStatus.reported,
      ),
      isAnonymous: data['isAnonymous'] ?? false,
      priority: EmergencyPriority.values.firstWhere(
        (e) => e.toString() == data['priority'],
        orElse: () => EmergencyPriority.medium,
      ),
      handledBy: data['handledBy'],
      handlerNotes: data['handlerNotes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

class EmergencyContact {
  final String name;
  final String phoneNumber;
  final ContactType type;
  final bool isAvailable24x7;
  final String? district;
  final String? mandal;

  EmergencyContact({
    required this.name,
    required this.phoneNumber,
    required this.type,
    required this.isAvailable24x7,
    this.district,
    this.mandal,
  });

  factory EmergencyContact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyContact(
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      type: ContactType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => ContactType.coordinator,
      ),
      isAvailable24x7: data['isAvailable24x7'] ?? false,
      district: data['district'],
      mandal: data['mandal'],
    );
  }
}

class EmergencyBroadcast {
  final String id;
  final String senderId;
  final String title;
  final String message;
  final String district;
  final String? mandal;
  final String? village;
  final EmergencyPriority priority;
  final DateTime createdAt;

  EmergencyBroadcast({
    required this.id,
    required this.senderId,
    required this.title,
    required this.message,
    required this.district,
    this.mandal,
    this.village,
    required this.priority,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'title': title,
      'message': message,
      'district': district,
      'mandal': mandal,
      'village': village,
      'priority': priority.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}