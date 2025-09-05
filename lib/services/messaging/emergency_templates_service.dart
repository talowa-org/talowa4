// Emergency Templates Service - Pre-defined emergency broadcast templates
// Task 9: Build emergency broadcast system - Templates
// Requirements: 5.5 - Quick templates for coordinators

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'emergency_broadcast_service.dart';

class EmergencyTemplatesService {
  static final EmergencyTemplatesService _instance = EmergencyTemplatesService._internal();
  factory EmergencyTemplatesService() => _instance;
  EmergencyTemplatesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmergencyBroadcastService _broadcastService = EmergencyBroadcastService();

  /// Initialize default emergency templates
  Future<void> initializeDefaultTemplates() async {
    try {
      debugPrint('Initializing default emergency templates...');

      final templates = _getDefaultTemplates();
      
      for (final template in templates) {
        // Check if template already exists
        final existingQuery = await _firestore
            .collection('emergency_templates')
            .where('name', isEqualTo: template['name'])
            .limit(1)
            .get();

        if (existingQuery.docs.isEmpty) {
          await _firestore.collection('emergency_templates').add({
            ...template,
            'createdAt': FieldValue.serverTimestamp(),
            'isDefault': true,
            'isActive': true,
          });
          debugPrint('Created template: ${template['name']}');
        }
      }

      debugPrint('Default emergency templates initialized successfully');
    } catch (e) {
      debugPrint('Error initializing default templates: $e');
    }
  }

  /// Get default emergency templates
  List<Map<String, dynamic>> _getDefaultTemplates() {
    return [
      // Land Grabbing Templates
      {
        'name': 'Land Grabbing Alert',
        'title': 'URGENT: Land Grabbing Incident',
        'message': 'Land grabbing incident reported in your area. Farmers are being forcibly evicted. Immediate legal and community support needed. Contact local coordinator for assistance.',
        'priority': EmergencyPriority.critical.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator', 'district_coordinator'],
        'category': 'land_rights',
        'customFields': {
          'requiresLocation': true,
          'suggestedActions': ['Contact Legal Team', 'Gather Evidence', 'Mobilize Community'],
        },
      },
      {
        'name': 'Illegal Land Survey',
        'title': 'Illegal Survey Activity Detected',
        'message': 'Unauthorized land survey activities detected. Officials conducting surveys without proper notice. Document everything and contact legal team immediately.',
        'priority': EmergencyPriority.high.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator'],
        'category': 'land_rights',
        'customFields': {
          'requiresLocation': true,
          'suggestedActions': ['Document Survey', 'Contact Officials', 'Legal Consultation'],
        },
      },

      // Safety and Security Templates
      {
        'name': 'Farmer Harassment',
        'title': 'Farmer Under Threat',
        'message': 'TALOWA member facing harassment and threats. Immediate safety concerns. Community support and legal protection required urgently.',
        'priority': EmergencyPriority.critical.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator', 'district_coordinator'],
        'category': 'safety',
        'customFields': {
          'requiresLocation': true,
          'suggestedActions': ['Contact Police', 'Legal Protection', 'Community Mobilization'],
        },
      },
      {
        'name': 'Police Action Alert',
        'title': 'Police Action Against Farmers',
        'message': 'Police action being taken against farmers in your area. Arrests and intimidation reported. Legal support and media attention needed immediately.',
        'priority': EmergencyPriority.critical.toString(),
        'applicableRoles': ['mandal_coordinator', 'district_coordinator', 'state_coordinator'],
        'category': 'safety',
        'customFields': {
          'requiresLocation': true,
          'suggestedActions': ['Legal Support', 'Media Alert', 'Human Rights Groups'],
        },
      },

      // Legal and Court Templates
      {
        'name': 'Court Hearing Alert',
        'title': 'Urgent Court Hearing',
        'message': 'Important court hearing scheduled for land rights case. Community presence and support needed. Details will be shared separately.',
        'priority': EmergencyPriority.high.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator', 'district_coordinator'],
        'category': 'legal',
        'customFields': {
          'requiresDateTime': true,
          'suggestedActions': ['Attend Hearing', 'Bring Documents', 'Community Support'],
        },
      },
      {
        'name': 'Legal Deadline Warning',
        'title': 'Critical Legal Deadline Approaching',
        'message': 'Important legal deadline approaching for land documentation. Immediate action required to prevent loss of rights. Contact legal team urgently.',
        'priority': EmergencyPriority.high.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator'],
        'category': 'legal',
        'customFields': {
          'requiresDeadline': true,
          'suggestedActions': ['Contact Legal Team', 'Gather Documents', 'Submit Applications'],
        },
      },

      // Government and Administrative Templates
      {
        'name': 'Government Scheme Alert',
        'title': 'New Government Scheme Announced',
        'message': 'New government scheme for land rights announced. Limited time for applications. Gather required documents and apply immediately.',
        'priority': EmergencyPriority.medium.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator', 'district_coordinator'],
        'category': 'government',
        'customFields': {
          'requiresDeadline': true,
          'suggestedActions': ['Gather Documents', 'Submit Application', 'Spread Awareness'],
        },
      },
      {
        'name': 'Revenue Official Visit',
        'title': 'Revenue Officials in Area',
        'message': 'Revenue officials visiting area for land verification. Ensure all farmers have proper documents ready. Coordinate community response.',
        'priority': EmergencyPriority.medium.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator'],
        'category': 'government',
        'customFields': {
          'requiresDateTime': true,
          'suggestedActions': ['Prepare Documents', 'Community Meeting', 'Coordinate Response'],
        },
      },

      // Natural Disasters and Environmental Templates
      {
        'name': 'Crop Damage Alert',
        'title': 'Severe Crop Damage Reported',
        'message': 'Severe crop damage due to natural disaster. Farmers need immediate support for compensation claims and relief measures.',
        'priority': EmergencyPriority.high.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator', 'district_coordinator'],
        'category': 'disaster',
        'customFields': {
          'requiresLocation': true,
          'suggestedActions': ['Document Damage', 'File Claims', 'Relief Coordination'],
        },
      },
      {
        'name': 'Water Crisis Alert',
        'title': 'Water Crisis in Agricultural Area',
        'message': 'Severe water shortage affecting agricultural activities. Immediate intervention needed for irrigation and drinking water supply.',
        'priority': EmergencyPriority.high.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator'],
        'category': 'disaster',
        'customFields': {
          'requiresLocation': true,
          'suggestedActions': ['Contact Water Board', 'Emergency Supply', 'Long-term Solutions'],
        },
      },

      // Community Mobilization Templates
      {
        'name': 'Community Meeting Urgent',
        'title': 'Urgent Community Meeting',
        'message': 'Urgent community meeting called to address critical land rights issue. Your presence is essential for collective action.',
        'priority': EmergencyPriority.high.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator'],
        'category': 'mobilization',
        'customFields': {
          'requiresDateTime': true,
          'requiresLocation': true,
          'suggestedActions': ['Attend Meeting', 'Spread Word', 'Bring Documents'],
        },
      },
      {
        'name': 'Protest Mobilization',
        'title': 'Peaceful Protest Organized',
        'message': 'Peaceful protest organized against land rights violations. Join us to show solidarity and demand justice. Non-violent participation only.',
        'priority': EmergencyPriority.medium.toString(),
        'applicableRoles': ['mandal_coordinator', 'district_coordinator'],
        'category': 'mobilization',
        'customFields': {
          'requiresDateTime': true,
          'requiresLocation': true,
          'suggestedActions': ['Peaceful Participation', 'Bring Banners', 'Media Coverage'],
        },
      },

      // Success and Victory Templates
      {
        'name': 'Victory Announcement',
        'title': 'Major Victory for Land Rights!',
        'message': 'Celebrating a major victory in our fight for land rights! Court ruling in our favor. This success belongs to our entire community.',
        'priority': EmergencyPriority.medium.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator', 'district_coordinator'],
        'category': 'success',
        'customFields': {
          'suggestedActions': ['Celebrate Responsibly', 'Share Success', 'Plan Next Steps'],
        },
      },
      {
        'name': 'Patta Distribution',
        'title': 'Land Pattas Being Distributed',
        'message': 'Land pattas are being distributed in your area. Ensure all eligible farmers collect their documents. Historic moment for our community!',
        'priority': EmergencyPriority.high.toString(),
        'applicableRoles': ['village_coordinator', 'mandal_coordinator'],
        'category': 'success',
        'customFields': {
          'requiresDateTime': true,
          'requiresLocation': true,
          'suggestedActions': ['Collect Patta', 'Verify Details', 'Celebrate Achievement'],
        },
      },
    ];
  }

  /// Get templates by category
  Future<List<EmergencyTemplate>> getTemplatesByCategory(String category) async {
    try {
      final query = await _firestore
          .collection('emergency_templates')
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return query.docs
          .map((doc) => EmergencyTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting templates by category: $e');
      return [];
    }
  }

  /// Get templates by priority
  Future<List<EmergencyTemplate>> getTemplatesByPriority(EmergencyPriority priority) async {
    try {
      final query = await _firestore
          .collection('emergency_templates')
          .where('priority', isEqualTo: priority.toString())
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return query.docs
          .map((doc) => EmergencyTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting templates by priority: $e');
      return [];
    }
  }

  /// Search templates by keyword
  Future<List<EmergencyTemplate>> searchTemplates(String keyword) async {
    try {
      // Note: This is a simple search. For production, consider using Algolia or similar
      final query = await _firestore
          .collection('emergency_templates')
          .where('isActive', isEqualTo: true)
          .get();

      final templates = query.docs
          .map((doc) => EmergencyTemplate.fromFirestore(doc))
          .where((template) =>
              template.name.toLowerCase().contains(keyword.toLowerCase()) ||
              template.title.toLowerCase().contains(keyword.toLowerCase()) ||
              template.message.toLowerCase().contains(keyword.toLowerCase()))
          .toList();

      return templates;
    } catch (e) {
      debugPrint('Error searching templates: $e');
      return [];
    }
  }

  /// Create custom template
  Future<String?> createCustomTemplate({
    required String name,
    required String title,
    required String message,
    required EmergencyPriority priority,
    required List<String> applicableRoles,
    String category = 'custom',
    Map<String, dynamic>? customFields,
  }) async {
    try {
      return await _broadcastService.createEmergencyTemplate(
        name: name,
        title: title,
        message: message,
        priority: priority,
        applicableRoles: applicableRoles,
        customFields: {
          'category': category,
          ...customFields ?? {},
        },
      );
    } catch (e) {
      debugPrint('Error creating custom template: $e');
      return null;
    }
  }

  /// Update template
  Future<bool> updateTemplate({
    required String templateId,
    String? name,
    String? title,
    String? message,
    EmergencyPriority? priority,
    List<String>? applicableRoles,
    Map<String, dynamic>? customFields,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (name != null) updates['name'] = name;
      if (title != null) updates['title'] = title;
      if (message != null) updates['message'] = message;
      if (priority != null) updates['priority'] = priority.toString();
      if (applicableRoles != null) updates['applicableRoles'] = applicableRoles;
      if (customFields != null) updates['customFields'] = customFields;
      if (isActive != null) updates['isActive'] = isActive;
      
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('emergency_templates')
          .doc(templateId)
          .update(updates);

      return true;
    } catch (e) {
      debugPrint('Error updating template: $e');
      return false;
    }
  }

  /// Delete template (soft delete)
  Future<bool> deleteTemplate(String templateId) async {
    try {
      await _firestore
          .collection('emergency_templates')
          .doc(templateId)
          .update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error deleting template: $e');
      return false;
    }
  }

  /// Get template usage statistics
  Future<Map<String, int>> getTemplateUsageStats() async {
    try {
      final query = await _firestore
          .collection('emergency_broadcasts')
          .where('templateId', isNotEqualTo: null)
          .get();

      final usage = <String, int>{};
      
      for (final doc in query.docs) {
        final templateId = doc.data()['templateId'] as String?;
        if (templateId != null) {
          usage[templateId] = (usage[templateId] ?? 0) + 1;
        }
      }

      return usage;
    } catch (e) {
      debugPrint('Error getting template usage stats: $e');
      return {};
    }
  }

  /// Get all template categories
  Future<List<String>> getTemplateCategories() async {
    try {
      final query = await _firestore
          .collection('emergency_templates')
          .where('isActive', isEqualTo: true)
          .get();

      final categories = <String>{};
      
      for (final doc in query.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 
                        data['customFields']?['category'] as String? ?? 
                        'general';
        categories.add(category);
      }

      return categories.toList()..sort();
    } catch (e) {
      debugPrint('Error getting template categories: $e');
      return [];
    }
  }
}
