import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  static const String _languageKey = 'selected_language';
  static const String _cachedLanguagesKey = 'cached_languages';
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('hi', 'IN'), // Hindi
    Locale('te', 'IN'), // Telugu
    Locale('ta', 'IN'), // Tamil
  ];

  Locale _currentLocale = const Locale('en', 'US');
  
  // Static properties for compatibility
  static String currentLanguage = 'en';
  static bool isRTL = false;
  static List<String> rtlLanguages = ['ar', 'ur', 'he'];
  static Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'Hindi', 
    'te': 'Telugu',
  };
  static Map<String, List<String>> languageFamilies = {
    'indo_european': ['en', 'hi'],
    'dravidian': ['te'],
  };
  
  // Static methods for compatibility
  static Future<void> initializeStatic() async {
    // Initialize localization
  }
  
  static String detectLanguage(String text) {
    // Simple language detection
    if (text.contains(RegExp(r'[\u0900-\u097F]'))) return 'hi';
    if (text.contains(RegExp(r'[\u0C00-\u0C7F]'))) return 'te';
    return 'en';
  }
  
  static String getVoiceResponse(String key) {
    final responses = {
      'land_issue_registered': 'Land issue has been registered',
      'land_help': 'How can I help with your land issue?',
      'coordinator_search': 'Searching for coordinators in your area',
      'general_help': 'How can I help you today?',
      'listening': 'Listening...',
      'error': 'Sorry, I didn\'t understand that',
    };
    return responses[key] ?? 'How can I help you?';
  }
  
  static List<Map<String, String>> getQuickActions() {
    return [
      {'label': 'Land Issues', 'action': 'land'},
      {'label': 'Legal Help', 'action': 'legal'},
      {'label': 'My Network', 'action': 'network'},
      {'label': 'Support', 'action': 'support'},
    ];
  }
  
  static String getText(Map<String, String> translations) {
    return translations[currentLanguage] ?? translations['en'] ?? '';
  }

  Locale get currentLocale => _currentLocale;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey) ?? 'en';
    _currentLocale = Locale(languageCode);
    currentLanguage = languageCode;
    notifyListeners();
  }

  Future<void> changeLanguage(Locale newLocale) async {
    if (_currentLocale == newLocale) return;
    
    _currentLocale = newLocale;
    currentLanguage = newLocale.languageCode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, newLocale.languageCode);
    
    notifyListeners();
  }

  String getLanguageDisplayName(Locale locale) {
    return supportedLanguages[locale.languageCode] ?? locale.languageCode;
  }

  String get currentLanguageDisplayName {
    return getLanguageDisplayName(_currentLocale);
  }

  bool isLocaleSupported(Locale locale) {
    return supportedLocales.any((l) => l.languageCode == locale.languageCode);
  }

  Future<void> resetToDeviceLanguage() async {
    final deviceLocale = PlatformDispatcher.instance.locale;
    final supportedLocale = supportedLocales.firstWhere(
      (locale) => locale.languageCode == deviceLocale.languageCode,
      orElse: () => const Locale('en', 'US'),
    );
    await changeLanguage(supportedLocale);
  }

  Future<void> clearLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_languageKey);
    await resetToDeviceLanguage();
  }
}
