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
  SharedPreferences? _prefs;
  final Map<String, Map<String, String>> _translationCache = {};
  final Set<String> _preloadedLanguages = {};
  bool _isInitialized = false;
  Timer? _memoryCleanupTimer;

  Locale get currentLocale => _currentLocale;

  /// Initialize the localization service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    await _loadSavedLanguage();
    await _preloadCachedLanguages();
    _startMemoryCleanupTimer();
    _isInitialized = true;
  }

  /// Preload cached language resources
  Future<void> _preloadCachedLanguages() async {
    final cachedLanguages = _prefs?.getStringList(_cachedLanguagesKey) ?? [];
    for (final languageCode in cachedLanguages) {
      await _loadLanguageResources(languageCode);
    }
  }

  /// Load language resources with caching
  Future<void> _loadLanguageResources(String languageCode) async {
    if (_translationCache.containsKey(languageCode)) return;
    
    try {
      // Simulate loading translation resources
      // In a real implementation, this would load from assets or network
      final translations = <String, String>{};
      
      // Add to cache and preloaded set
      _translationCache[languageCode] = translations;
      _preloadedLanguages.add(languageCode);
      
      // Update cached languages list
      final cachedLanguages = _prefs?.getStringList(_cachedLanguagesKey) ?? [];
      if (!cachedLanguages.contains(languageCode)) {
        cachedLanguages.add(languageCode);
        await _prefs?.setStringList(_cachedLanguagesKey, cachedLanguages);
      }
    } catch (e) {
      debugPrint('Failed to load language resources for $languageCode: $e');
    }
  }

  /// Start memory cleanup timer
  void _startMemoryCleanupTimer() {
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _cleanupUnusedLanguageData(),
    );
  }

  /// Clean up unused language data from memory
  void _cleanupUnusedLanguageData() {
    final currentLanguageCode = _currentLocale.languageCode;
    final keysToRemove = <String>[];
    
    for (final languageCode in _translationCache.keys) {
      if (languageCode != currentLanguageCode && 
          !_preloadedLanguages.contains(languageCode)) {
        keysToRemove.add(languageCode);
      }
    }
    
    for (final key in keysToRemove) {
      _translationCache.remove(key);
    }
    
    debugPrint('Cleaned up ${keysToRemove.length} unused language resources');
  }

  /// Load saved language preference or detect device locale
  Future<void> _loadSavedLanguage() async {
    final savedLanguageCode = _prefs?.getString(_languageKey);
    
    if (savedLanguageCode != null) {
      // Use saved language preference
      final savedLocale = supportedLocales.firstWhere(
        (locale) => locale.languageCode == savedLanguageCode,
        orElse: () => const Locale('en', 'US'),
      );
      _currentLocale = savedLocale;
    } else {
      // Auto-detect from device locale
      final deviceLocale = PlatformDispatcher.instance.locale;
      _currentLocale = _getBestMatchingLocale(deviceLocale);
    }
    
    notifyListeners();
  }

  /// Find the best matching supported locale for device locale
  Locale _getBestMatchingLocale(Locale deviceLocale) {
    // Try exact match first
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == deviceLocale.languageCode &&
          supportedLocale.countryCode == deviceLocale.countryCode) {
        return supportedLocale;
      }
    }
    
    // Try language code match
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == deviceLocale.languageCode) {
        return supportedLocale;
      }
    }
    
    // Fallback to English
    return const Locale('en', 'US');
  }

  /// Change the app language with performance optimization
  Future<void> changeLanguage(Locale newLocale) async {
    if (!supportedLocales.contains(newLocale)) {
      throw ArgumentError('Unsupported locale: $newLocale');
    }

    // Preload language resources if not already cached
    await _loadLanguageResources(newLocale.languageCode);

    _currentLocale = newLocale;
    await _prefs?.setString(_languageKey, newLocale.languageCode);
    
    // Notify listeners with a slight delay to ensure smooth UI transitions
    Future.microtask(() => notifyListeners());
  }

  /// Preload language for faster switching
  Future<void> preloadLanguage(Locale locale) async {
    if (supportedLocales.contains(locale)) {
      await _loadLanguageResources(locale.languageCode);
    }
  }

  /// Check if language is preloaded
  bool isLanguagePreloaded(Locale locale) {
    return _preloadedLanguages.contains(locale.languageCode);
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryStats() {
    return {
      'cachedLanguages': _translationCache.length,
      'preloadedLanguages': _preloadedLanguages.length,
      'currentLanguage': _currentLocale.languageCode,
      'memoryCleanupActive': _memoryCleanupTimer?.isActive ?? false,
    };
  }

  /// Get display name for a locale
  String getLanguageDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी';
      case 'te':
        return 'తెలుగు';
      case 'ta':
        return 'தமிழ்';
      default:
        return locale.languageCode.toUpperCase();
    }
  }

  /// Get native display name for current locale
  String get currentLanguageDisplayName => getLanguageDisplayName(_currentLocale);

  /// Check if a locale is supported
  bool isLocaleSupported(Locale locale) {
    return supportedLocales.any((supportedLocale) =>
        supportedLocale.languageCode == locale.languageCode);
  }

  /// Get locale by language code
  Locale? getLocaleByLanguageCode(String languageCode) {
    try {
      return supportedLocales.firstWhere(
        (locale) => locale.languageCode == languageCode,
      );
    } catch (e) {
      return null;
    }
  }

  /// Reset to device default language
  Future<void> resetToDeviceLanguage() async {
    final deviceLocale = PlatformDispatcher.instance.locale;
    final bestMatch = _getBestMatchingLocale(deviceLocale);
    await changeLanguage(bestMatch);
  }

  /// Clear saved language preference
  Future<void> clearLanguagePreference() async {
    await _prefs?.remove(_languageKey);
    await resetToDeviceLanguage();
  }

  /// Dispose resources
  @override
  void dispose() {
    _memoryCleanupTimer?.cancel();
    _translationCache.clear();
    _preloadedLanguages.clear();
    super.dispose();
  }
}