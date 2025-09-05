// Localization Service - Multi-language support for TALOWA platform
// Complete localization system for Hindi, Bengali, and regional languages

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  static LocalizationService? _instance;
  static LocalizationService get instance => _instance ??= LocalizationService._internal();
  
  LocalizationService._internal();
  
  // Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'à¤¹à¤¿à¤‚à¤¦à¥€',
    'bn': 'à¦¬à¦¾à¦‚à¦²à¦¾',
    'te': 'à°¤à±†à°²à±à°—à±',
    'ta': 'à®¤à®®à®¿à®´à¯',
    'mr': 'à¤®à¤°à¤¾à¤ à¥€',
    'gu': 'àª—à«àªœàª°àª¾àª¤à«€',
    'kn': 'à²•à²¨à³à²¨à²¡',
    'ml': 'à´®à´²à´¯à´¾à´³à´‚',
    'pa': 'à¨ªà©°à¨œà¨¾à¨¬à©€',
    'or': 'à¬“à¬¡à¬¼à¬¿à¬†',
    'as': 'à¦…à¦¸à¦®à§€à¦¯à¦¼à¦¾',
  };
  
  // Current language and locale
  String _currentLanguage = 'en';
  Map<String, String> _localizedStrings = {};
  
  // Language change notifier
  final StreamController<String> _languageController = StreamController<String>.broadcast();
  Stream<String> get languageStream => _languageController.stream;
  
  // Initialization status
  bool _isInitialized = false;
  
  /// Initialize localization service
  Future<void> initialize() async {
    try {
      debugPrint('ðŸŒ Initializing Localization Service...');
      
      // Load saved language preference
      await _loadSavedLanguage();
      
      // Load localized strings for current language
      await _loadLocalizedStrings(_currentLanguage);
      
      _isInitialized = true;
      debugPrint('âœ… Localization Service initialized with language: $_currentLanguage');
      
    } catch (e) {
      debugPrint('âŒ Failed to initialize Localization Service: $e');
      // Fallback to English
      _currentLanguage = 'en';
      await _loadLocalizedStrings('en');
      _isInitialized = true;
    }
  }
  
  /// Get current language code
  String get currentLanguage => _currentLanguage;
  
  /// Get current language display name
  String get currentLanguageDisplayName => 
      supportedLanguages[_currentLanguage] ?? 'English';
  
  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Change language
  Future<void> changeLanguage(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      throw ArgumentError('Unsupported language: $languageCode');
    }
    
    if (_currentLanguage == languageCode) return;
    
    try {
      debugPrint('ðŸŒ Changing language to: $languageCode');
      
      // Load new language strings
      await _loadLocalizedStrings(languageCode);
      
      // Update current language
      _currentLanguage = languageCode;
      
      // Save preference
      await _saveLanguagePreference(languageCode);
      
      // Notify listeners
      _languageController.add(languageCode);
      
      debugPrint('âœ… Language changed to: ${supportedLanguages[languageCode]}');
      
    } catch (e) {
      debugPrint('âŒ Failed to change language: $e');
      rethrow;
    }
  }
  
  /// Get localized string
  String getString(String key, {Map<String, String>? params}) {
    if (!_isInitialized) {
      debugPrint('âš ï¸ LocalizationService not initialized, returning key: $key');
      return key;
    }
    
    String localizedString = _localizedStrings[key] ?? key;
    
    // Replace parameters if provided
    if (params != null) {
      params.forEach((paramKey, paramValue) {
        localizedString = localizedString.replaceAll('{$paramKey}', paramValue);
      });
    }
    
    return localizedString;
  }
  
  /// Get localized string with fallback
  String getStringWithFallback(String key, String fallback, {Map<String, String>? params}) {
    if (!_isInitialized) return fallback;
    
    String localizedString = _localizedStrings[key] ?? fallback;
    
    if (params != null) {
      params.forEach((paramKey, paramValue) {
        localizedString = localizedString.replaceAll('{$paramKey}', paramValue);
      });
    }
    
    return localizedString;
  }
  
  /// Check if string exists for current language
  bool hasString(String key) {
    return _localizedStrings.containsKey(key);
  }
  
  /// Get all available languages
  Map<String, String> getAvailableLanguages() {
    return Map.from(supportedLanguages);
  }
  
  /// Get language direction (LTR/RTL)
  TextDirection getTextDirection() {
    // All supported languages are LTR
    // Add RTL languages like Arabic/Urdu here if needed
    return TextDirection.ltr;
  }
  
  /// Get language-specific number format
  String formatNumber(num number) {
    switch (_currentLanguage) {
      case 'hi':
        return _formatHindiNumber(number);
      case 'bn':
        return _formatBengaliNumber(number);
      default:
        return number.toString();
    }
  }
  
  /// Get language-specific date format
  String formatDate(DateTime date) {
    switch (_currentLanguage) {
      case 'hi':
        return _formatHindiDate(date);
      case 'bn':
        return _formatBengaliDate(date);
      default:
        return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  /// Get localized currency format
  String formatCurrency(double amount) {
    switch (_currentLanguage) {
      case 'hi':
        return 'â‚¹${_formatHindiNumber(amount)}';
      case 'bn':
        return 'à§³${_formatBengaliNumber(amount)}';
      default:
        return 'â‚¹${amount.toStringAsFixed(2)}';
    }
  }
  
  /// Load saved language preference
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('selected_language');
      
      if (savedLanguage != null && supportedLanguages.containsKey(savedLanguage)) {
        _currentLanguage = savedLanguage;
        debugPrint('ðŸ“± Loaded saved language: $savedLanguage');
      } else {
        // Detect system language
        _currentLanguage = _detectSystemLanguage();
        debugPrint('ðŸ” Detected system language: $_currentLanguage');
      }
    } catch (e) {
      debugPrint('âŒ Failed to load saved language: $e');
      _currentLanguage = 'en';
    }
  }
  
  /// Save language preference
  Future<void> _saveLanguagePreference(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', languageCode);
      debugPrint('ðŸ’¾ Saved language preference: $languageCode');
    } catch (e) {
      debugPrint('âŒ Failed to save language preference: $e');
    }
  }
  
  /// Load localized strings from assets
  Future<void> _loadLocalizedStrings(String languageCode) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/localization/$languageCode.json',
      );
      
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
      
      debugPrint('ðŸ“š Loaded ${_localizedStrings.length} strings for $languageCode');
      
    } catch (e) {
      debugPrint('âŒ Failed to load strings for $languageCode: $e');
      
      // Fallback to English if not already English
      if (languageCode != 'en') {
        await _loadLocalizedStrings('en');
      } else {
        // Use default strings if English also fails
        _localizedStrings = _getDefaultStrings();
      }
    }
  }
  
  /// Detect system language
  String _detectSystemLanguage() {
    try {
      final systemLocale = PlatformDispatcher.instance.locale;
      final languageCode = systemLocale.languageCode;
      
      if (supportedLanguages.containsKey(languageCode)) {
        return languageCode;
      }
      
      // Check for regional variants
      switch (languageCode) {
        case 'hi':
        case 'mr':
        case 'gu':
          return 'hi'; // Default to Hindi for North Indian languages
        case 'bn':
        case 'as':
          return 'bn'; // Default to Bengali for Eastern languages
        case 'te':
        case 'ta':
        case 'kn':
        case 'ml':
          return 'te'; // Default to Telugu for South Indian languages
        default:
          return 'en';
      }
    } catch (e) {
      debugPrint('âŒ Failed to detect system language: $e');
      return 'en';
    }
  }
  
  /// Format number in Hindi (Devanagari numerals)
  String _formatHindiNumber(num number) {
    final hindiDigits = ['à¥¦', 'à¥§', 'à¥¨', 'à¥©', 'à¥ª', 'à¥«', 'à¥¬', 'à¥­', 'à¥®', 'à¥¯'];
    final numberString = number.toString();
    
    return numberString.split('').map((char) {
      final digit = int.tryParse(char);
      return digit != null ? hindiDigits[digit] : char;
    }).join();
  }
  
  /// Format number in Bengali numerals
  String _formatBengaliNumber(num number) {
    final bengaliDigits = ['à§¦', 'à§§', 'à§¨', 'à§©', 'à§ª', 'à§«', 'à§¬', 'à§­', 'à§®', 'à§¯'];
    final numberString = number.toString();
    
    return numberString.split('').map((char) {
      final digit = int.tryParse(char);
      return digit != null ? bengaliDigits[digit] : char;
    }).join();
  }
  
  /// Format date in Hindi
  String _formatHindiDate(DateTime date) {
    final hindiMonths = [
      'à¤œà¤¨à¤µà¤°à¥€', 'à¤«à¤°à¤µà¤°à¥€', 'à¤®à¤¾à¤°à¥à¤š', 'à¤…à¤ªà¥à¤°à¥ˆà¤²', 'à¤®à¤ˆ', 'à¤œà¥‚à¤¨',
      'à¤œà¥à¤²à¤¾à¤ˆ', 'à¤…à¤—à¤¸à¥à¤¤', 'à¤¸à¤¿à¤¤à¤‚à¤¬à¤°', 'à¤…à¤•à¥à¤Ÿà¥‚à¤¬à¤°', 'à¤¨à¤µà¤‚à¤¬à¤°', 'à¤¦à¤¿à¤¸à¤‚à¤¬à¤°'
    ];
    
    return '${_formatHindiNumber(date.day)} ${hindiMonths[date.month - 1]} ${_formatHindiNumber(date.year)}';
  }
  
  /// Format date in Bengali
  String _formatBengaliDate(DateTime date) {
    final bengaliMonths = [
      'à¦œà¦¾à¦¨à§à¦¯à¦¼à¦¾à¦°à¦¿', 'à¦«à§‡à¦¬à§à¦°à§à¦¯à¦¼à¦¾à¦°à¦¿', 'à¦®à¦¾à¦°à§à¦š', 'à¦à¦ªà§à¦°à¦¿à¦²', 'à¦®à§‡', 'à¦œà§à¦¨',
      'à¦œà§à¦²à¦¾à¦‡', 'à¦†à¦—à¦¸à§à¦Ÿ', 'à¦¸à§‡à¦ªà§à¦Ÿà§‡à¦®à§à¦¬à¦°', 'à¦…à¦•à§à¦Ÿà§‹à¦¬à¦°', 'à¦¨à¦­à§‡à¦®à§à¦¬à¦°', 'à¦¡à¦¿à¦¸à§‡à¦®à§à¦¬à¦°'
    ];
    
    return '${_formatBengaliNumber(date.day)} ${bengaliMonths[date.month - 1]} ${_formatBengaliNumber(date.year)}';
  }
  
  /// Get default English strings
  Map<String, String> _getDefaultStrings() {
    return {
      // App basics
      'app_name': 'TALOWA',
      'app_tagline': 'Land Rights Activism Platform',
      
      // Navigation
      'nav_home': 'Home',
      'nav_search': 'Search',
      'nav_notifications': 'Notifications',
      'nav_profile': 'Profile',
      
      // Common actions
      'action_search': 'Search',
      'action_cancel': 'Cancel',
      'action_save': 'Save',
      'action_delete': 'Delete',
      'action_edit': 'Edit',
      'action_share': 'Share',
      'action_like': 'Like',
      'action_comment': 'Comment',
      
      // Authentication
      'auth_login': 'Login',
      'auth_register': 'Register',
      'auth_logout': 'Logout',
      'auth_email': 'Email',
      'auth_password': 'Password',
      'auth_forgot_password': 'Forgot Password?',
      
      // Search
      'search_placeholder': 'Search for land rights information...',
      'search_no_results': 'No results found',
      'search_results_count': '{count} results found',
      
      // Notifications
      'notifications_title': 'Notifications',
      'notifications_empty': 'No notifications yet',
      'notifications_mark_read': 'Mark as read',
      'notifications_mark_all_read': 'Mark all as read',
      
      // Profile
      'profile_title': 'Profile',
      'profile_edit': 'Edit Profile',
      'profile_settings': 'Settings',
      'profile_language': 'Language',
      
      // Land rights specific
      'land_rights': 'Land Rights',
      'land_dispute': 'Land Dispute',
      'legal_help': 'Legal Help',
      'find_lawyer': 'Find Lawyer',
      'success_stories': 'Success Stories',
      'government_schemes': 'Government Schemes',
      
      // Error messages
      'error_network': 'Network error. Please check your connection.',
      'error_server': 'Server error. Please try again later.',
      'error_unknown': 'An unknown error occurred.',
      
      // Success messages
      'success_saved': 'Saved successfully',
      'success_updated': 'Updated successfully',
      'success_deleted': 'Deleted successfully',
    };
  }
  
  /// Dispose resources
  void dispose() {
    _languageController.close();
    debugPrint('ðŸ—‘ï¸ LocalizationService disposed');
  }
  
  /// Get service statistics
  Map<String, dynamic> getServiceStats() {
    return {
      'isInitialized': _isInitialized,
      'currentLanguage': _currentLanguage,
      'currentLanguageDisplayName': currentLanguageDisplayName,
      'supportedLanguagesCount': supportedLanguages.length,
      'loadedStringsCount': _localizedStrings.length,
      'supportedLanguages': supportedLanguages,
    };
  }
}

