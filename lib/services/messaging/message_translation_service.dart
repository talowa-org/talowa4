// Message Translation Service for TALOWA
// Handles automatic translation of messages in real-time communication

import 'package:flutter/foundation.dart';
import '../localization_service.dart';

class MessageTranslationService {
  static const String _cachePrefix = 'translation_cache_';
  static final Map<String, String> _translationCache = {};
  
  /// Initialize the translation service
  static Future<void> initialize() async {
    try {
      debugPrint('MessageTranslationService initialized');
    } catch (e) {
      debugPrint('Error initializing MessageTranslationService: $e');
    }
  }
  
  /// Translate message to target language
  static Future<TranslationResult> translateMessage({
    required String message,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      // Detect source language if not provided
      final detectedSource = sourceLanguage ?? LocalizationService.detectLanguage(message);
      
      // No translation needed if same language
      if (detectedSource == targetLanguage) {
        return TranslationResult(
          originalText: message,
          translatedText: message,
          sourceLanguage: detectedSource,
          targetLanguage: targetLanguage,
          confidence: 1.0,
          isTranslated: false,
        );
      }
      
      // Check cache first
      final cacheKey = '${detectedSource}_${targetLanguage}_${message.hashCode}';
      if (_translationCache.containsKey(cacheKey)) {
        return TranslationResult(
          originalText: message,
          translatedText: _translationCache[cacheKey]!,
          sourceLanguage: detectedSource,
          targetLanguage: targetLanguage,
          confidence: 0.9,
          isTranslated: true,
          isCached: true,
        );
      }
      
      // Perform translation
      final translatedText = await _performTranslation(
        message,
        detectedSource,
        targetLanguage,
      );
      
      // Cache the result
      _translationCache[cacheKey] = translatedText;
      
      return TranslationResult(
        originalText: message,
        translatedText: translatedText,
        sourceLanguage: detectedSource,
        targetLanguage: targetLanguage,
        confidence: 0.85,
        isTranslated: true,
      );
    } catch (e) {
      debugPrint('Error translating message: $e');
      return TranslationResult(
        originalText: message,
        translatedText: message,
        sourceLanguage: sourceLanguage ?? 'unknown',
        targetLanguage: targetLanguage,
        confidence: 0.0,
        isTranslated: false,
        error: e.toString(),
      );
    }
  }
  
  /// Translate multiple messages in batch
  static Future<List<TranslationResult>> translateMessages({
    required List<String> messages,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final results = <TranslationResult>[];
    
    for (final message in messages) {
      final result = await translateMessage(
        message: message,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
      );
      results.add(result);
    }
    
    return results;
  }
  
  /// Get supported translation pairs
  static Map<String, List<String>> getSupportedTranslations() {
    return {
      'en': ['hi', 'te', 'ur', 'ar'],
      'hi': ['en', 'te', 'ur'],
      'te': ['en', 'hi'],
      'ur': ['en', 'hi', 'ar'],
      'ar': ['en', 'ur'],
    };
  }
  
  /// Check if translation is supported
  static bool isTranslationSupported(String sourceLanguage, String targetLanguage) {
    final supported = getSupportedTranslations();
    return supported[sourceLanguage]?.contains(targetLanguage) ?? false;
  }
  
  /// Get translation confidence for language pair
  static double getTranslationConfidence(String sourceLanguage, String targetLanguage) {
    // Higher confidence for related languages
    final families = LocalizationService.languageFamilies;
    
    for (final family in families.values) {
      if (family.contains(sourceLanguage) && family.contains(targetLanguage)) {
        return 0.9; // High confidence for same family
      }
    }
    
    return 0.7; // Medium confidence for different families
  }
  
  /// Clear translation cache
  static void clearCache() {
    _translationCache.clear();
    debugPrint('Translation cache cleared');
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cache_size': _translationCache.length,
      'memory_usage': _translationCache.toString().length,
      'supported_pairs': getSupportedTranslations().length,
    };
  }
  
  /// Perform actual translation (placeholder for real implementation)
  static Future<String> _performTranslation(
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    // This is a placeholder implementation
    // In production, this would integrate with translation APIs like:
    // - Google Translate API
    // - Microsoft Translator
    // - AWS Translate
    // - Custom ML models for Indian languages
    
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate API call
    
    // For now, return basic translations for common phrases
    final commonTranslations = _getCommonTranslations();
    final key = '${sourceLanguage}_${targetLanguage}_${text.toLowerCase().trim()}';
    
    if (commonTranslations.containsKey(key)) {
      return commonTranslations[key]!;
    }
    
    // Return original text with language indicator if no translation available
    return '$text [${sourceLanguage.toUpperCase()}â†’${targetLanguage.toUpperCase()}]';
  }
  
  /// Get common phrase translations
  static Map<String, String> _getCommonTranslations() {
    return {
      // English to Hindi
      'en_hi_hello': 'à¤¨à¤®à¤¸à¥à¤¤à¥‡',
      'en_hi_thank you': 'à¤§à¤¨à¥à¤¯à¤µà¤¾à¤¦',
      'en_hi_yes': 'à¤¹à¤¾à¤',
      'en_hi_no': 'à¤¨à¤¹à¥€à¤‚',
      'en_hi_help': 'à¤®à¤¦à¤¦',
      'en_hi_land issue': 'à¤œà¤®à¥€à¤¨ à¤•à¥€ à¤¸à¤®à¤¸à¥à¤¯à¤¾',
      'en_hi_legal help': 'à¤•à¤¾à¤¨à¥‚à¤¨à¥€ à¤®à¤¦à¤¦',
      
      // English to Telugu
      'en_te_hello': 'à°¨à°®à°¸à±à°•à°¾à°°à°‚',
      'en_te_thank you': 'à°§à°¨à±à°¯à°µà°¾à°¦à°¾à°²à±',
      'en_te_yes': 'à°…à°µà±à°¨à±',
      'en_te_no': 'à°²à±‡à°¦à±',
      'en_te_help': 'à°¸à°¹à°¾à°¯à°‚',
      'en_te_land issue': 'à°­à±‚à°®à°¿ à°¸à°®à°¸à±à°¯',
      'en_te_legal help': 'à°¨à±à°¯à°¾à°¯ à°¸à°¹à°¾à°¯à°‚',
      
      // English to Urdu
      'en_ur_hello': 'Ø§Ù„Ø³Ù„Ø§Ù… Ø¹Ù„ÛŒÚ©Ù…',
      'en_ur_thank you': 'Ø´Ú©Ø±ÛŒÛ',
      'en_ur_yes': 'ÛØ§Úº',
      'en_ur_no': 'Ù†ÛÛŒÚº',
      'en_ur_help': 'Ù…Ø¯Ø¯',
      'en_ur_land issue': 'Ø²Ù…ÛŒÙ† Ú©Ø§ Ù…Ø³Ø¦Ù„Û',
      'en_ur_legal help': 'Ù‚Ø§Ù†ÙˆÙ†ÛŒ Ù…Ø¯Ø¯',
      
      // English to Arabic
      'en_ar_hello': 'Ø§Ù„Ø³Ù„Ø§Ù… Ø¹Ù„ÙŠÙƒÙ…',
      'en_ar_thank you': 'Ø´ÙƒØ±Ø§Ù‹',
      'en_ar_yes': 'Ù†Ø¹Ù…',
      'en_ar_no': 'Ù„Ø§',
      'en_ar_help': 'Ù…Ø³Ø§Ø¹Ø¯Ø©',
      'en_ar_land issue': 'Ù‚Ø¶ÙŠØ© Ø£Ø±Ø¶',
      'en_ar_legal help': 'Ù…Ø³Ø§Ø¹Ø¯Ø© Ù‚Ø§Ù†ÙˆÙ†ÙŠØ©',
      
      // Hindi to English
      'hi_en_à¤¨à¤®à¤¸à¥à¤¤à¥‡': 'Hello',
      'hi_en_à¤§à¤¨à¥à¤¯à¤µà¤¾à¤¦': 'Thank you',
      'hi_en_à¤¹à¤¾à¤': 'Yes',
      'hi_en_à¤¨à¤¹à¥€à¤‚': 'No',
      'hi_en_à¤®à¤¦à¤¦': 'Help',
      'hi_en_à¤œà¤®à¥€à¤¨ à¤•à¥€ à¤¸à¤®à¤¸à¥à¤¯à¤¾': 'Land issue',
      'hi_en_à¤•à¤¾à¤¨à¥‚à¤¨à¥€ à¤®à¤¦à¤¦': 'Legal help',
      
      // Telugu to English
      'te_en_à°¨à°®à°¸à±à°•à°¾à°°à°‚': 'Hello',
      'te_en_à°§à°¨à±à°¯à°µà°¾à°¦à°¾à°²à±': 'Thank you',
      'te_en_à°…à°µà±à°¨à±': 'Yes',
      'te_en_à°²à±‡à°¦à±': 'No',
      'te_en_à°¸à°¹à°¾à°¯à°‚': 'Help',
      'te_en_à°­à±‚à°®à°¿ à°¸à°®à°¸à±à°¯': 'Land issue',
      'te_en_à°¨à±à°¯à°¾à°¯ à°¸à°¹à°¾à°¯à°‚': 'Legal help',
    };
  }
}

/// Translation result model
class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double confidence;
  final bool isTranslated;
  final bool isCached;
  final String? error;
  
  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.confidence,
    required this.isTranslated,
    this.isCached = false,
    this.error,
  });
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'original_text': originalText,
      'translated_text': translatedText,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'confidence': confidence,
      'is_translated': isTranslated,
      'is_cached': isCached,
      'error': error,
    };
  }
  
  /// Create from JSON
  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      originalText: json['original_text'] ?? '',
      translatedText: json['translated_text'] ?? '',
      sourceLanguage: json['source_language'] ?? '',
      targetLanguage: json['target_language'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      isTranslated: json['is_translated'] ?? false,
      isCached: json['is_cached'] ?? false,
      error: json['error'],
    );
  }
  
  @override
  String toString() {
    return 'TranslationResult(original: $originalText, translated: $translatedText, '
           'confidence: $confidence, isTranslated: $isTranslated)';
  }
}

/// Translation preferences model
class TranslationPreferences {
  final bool autoTranslateEnabled;
  final String preferredLanguage;
  final bool showOriginalText;
  final double confidenceThreshold;
  final Set<String> disabledLanguages;
  
  const TranslationPreferences({
    this.autoTranslateEnabled = true,
    this.preferredLanguage = 'en',
    this.showOriginalText = false,
    this.confidenceThreshold = 0.7,
    this.disabledLanguages = const {},
  });
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'auto_translate_enabled': autoTranslateEnabled,
      'preferred_language': preferredLanguage,
      'show_original_text': showOriginalText,
      'confidence_threshold': confidenceThreshold,
      'disabled_languages': disabledLanguages.toList(),
    };
  }
  
  /// Create from JSON
  factory TranslationPreferences.fromJson(Map<String, dynamic> json) {
    return TranslationPreferences(
      autoTranslateEnabled: json['auto_translate_enabled'] ?? true,
      preferredLanguage: json['preferred_language'] ?? 'en',
      showOriginalText: json['show_original_text'] ?? false,
      confidenceThreshold: (json['confidence_threshold'] ?? 0.7).toDouble(),
      disabledLanguages: Set<String>.from(json['disabled_languages'] ?? []),
    );
  }
}
