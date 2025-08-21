import 'package:flutter/material.dart';
import '../services/localization_service.dart';

class LocalizationProvider extends ChangeNotifier {
  final LocalizationService _localizationService = LocalizationService();
  
  bool _isInitialized = false;
  bool _isLoading = false;

  Locale get currentLocale => _localizationService.currentLocale;
  List<Locale> get supportedLocales => LocalizationService.supportedLocales;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// Initialize the localization provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      await _localizationService.initialize();
      _isInitialized = true;
      debugPrint('✅ Localization initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Error initializing localization: $e');
      // Continue with default locale on error
      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Change the app language
  Future<void> changeLanguage(Locale newLocale) async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      await _localizationService.changeLanguage(newLocale);
    } catch (e) {
      debugPrint('Error changing language: $e');
      // Show error to user if needed
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get display name for a locale
  String getLanguageDisplayName(Locale locale) {
    return _localizationService.getLanguageDisplayName(locale);
  }

  /// Get current language display name
  String get currentLanguageDisplayName {
    return _localizationService.currentLanguageDisplayName;
  }

  /// Check if a locale is supported
  bool isLocaleSupported(Locale locale) {
    return _localizationService.isLocaleSupported(locale);
  }

  /// Reset to device default language
  Future<void> resetToDeviceLanguage() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      await _localizationService.resetToDeviceLanguage();
    } catch (e) {
      debugPrint('Error resetting to device language: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear language preference
  Future<void> clearLanguagePreference() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      await _localizationService.clearLanguagePreference();
    } catch (e) {
      debugPrint('Error clearing language preference: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}