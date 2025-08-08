// TALOWA App Constants
// Reference: docs/TALOWA_APP_BLUEPRINT.md - App Vision & Strategy

class AppConstants {
  // App Information
  static const String appName = 'TALOWA';
  static const String appFullName = 'Telangana Assigned Land Owners Welfare Association';
  static const String appVersion = '1.0.0';
  
  // Colors - TALOWA Brand Colors
  static const int talowaGreenValue = 0xFF059669;
  static const int legalBlueValue = 0xFF1E40AF;
  static const int emergencyRedValue = 0xFFDC2626;
  static const int warningOrangeValue = 0xFFD97706;
  static const int successGreenValue = 0xFF10B981;
  
  // User Roles
  static const String roleMember = 'Member';
  static const String roleVillageCoordinator = 'Village Coordinator';
  static const String roleMandalCoordinator = 'Mandal Coordinator';
  static const String roleDistrictCoordinator = 'District Coordinator';
  static const String roleStateCoordinator = 'State Coordinator';
  static const String roleLegalAdvisor = 'Legal Advisor';
  static const String roleMediaCoordinator = 'Media Coordinator';
  static const String roleFounder = 'Founder';
  static const String roleRootAdmin = 'Root Administrator';
  
  // Geographic Levels
  static const String levelVillage = 'village';
  static const String levelMandal = 'mandal';
  static const String levelDistrict = 'district';
  static const String levelState = 'state';
  static const String levelNational = 'national';
  
  // Message Types
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeVideo = 'video';
  static const String messageTypeDocument = 'document';
  static const String messageTypeVoice = 'voice';
  static const String messageTypeLocation = 'location';
  
  // Post Types for Social Feed
  static const String postTypeSuccessStory = 'success_story';
  static const String postTypeCampaignUpdate = 'campaign_update';
  static const String postTypeLegalUpdate = 'legal_update';
  static const String postTypeEmergencyAlert = 'emergency_alert';
  static const String postTypeMeetingAnnouncement = 'meeting_announcement';
  static const String postTypeEducationalContent = 'educational_content';
  
  // Privacy Levels
  static const String privacyPublic = 'public';
  static const String privacyNetwork = 'network';
  static const String privacyDirectReferrals = 'direct_referrals';
  static const String privacyCoordinators = 'coordinators';
  static const String privacyPrivate = 'private';
  
  // File Size Limits
  static const int maxImageSizeBytes = 25 * 1024 * 1024; // 25MB
  static const int maxDocumentSizeBytes = 50 * 1024 * 1024; // 50MB
  static const int maxVideoSizeBytes = 100 * 1024 * 1024; // 100MB
  
  // Performance Targets
  static const int maxLoadTimeMs = 3000; // 3 seconds
  static const int maxQueryTimeMs = 500; // 500ms
  static const double targetUptimePercent = 99.9;
  
  // Supported Languages
  static const String languageTelugu = 'te';
  static const String languageHindi = 'hi';
  static const String languageEnglish = 'en';
  
  // Emergency Contacts
  static const String policeNumber = '100';
  static const String emergencyHelpline = '1098';
  
  // Database Collections
  static const String collectionUsers = 'users';
  static const String collectionUserRegistry = 'user_registry';
  static const String collectionMessages = 'messages';
  static const String collectionGroups = 'groups';
  static const String collectionLandRecords = 'land_records';
  static const String collectionLegalCases = 'legal_cases';
  static const String collectionCampaigns = 'campaigns';
  static const String collectionFeedPosts = 'feed_posts';
  static const String collectionFeedStories = 'feed_stories';
  static const String collectionStates = 'states';
  static const String collectionDistricts = 'districts';
  static const String collectionMandals = 'mandals';
  static const String collectionVillages = 'villages';
}