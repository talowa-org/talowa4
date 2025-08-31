// Reliable Voice Recognition Service for TALOWA
// Production-ready speech-to-text implementation with comprehensive error handling

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class ReliableVoiceService {
  static final ReliableVoiceService _instance = ReliableVoiceService._internal();
  factory ReliableVoiceService() => _instance;
  ReliableVoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isListening = false;
  bool _isInitialized = false;
  bool _isAvailable = false;
  String _currentLanguage = 'en_US';
  List<stt.LocaleName> _availableLocales = [];
  
  // Voice recognition status
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;
  List<stt.LocaleName> get availableLocales => _availableLocales;

  /// Initialize voice recognition service with comprehensive setup
  Future<bool> initialize() async {
    try {
      debugPrint('🎤 Initializing reliable voice recognition service...');
      
      // Step 1: Check and request permissions
      final permissionGranted = await _ensurePermissions();
      if (!permissionGranted) {
        debugPrint('❌ Voice recognition: Permissions not granted');
        _isInitialized = true;
        _isAvailable = false;
        return true; // Still return true to allow text input
      }

      // Step 2: Initialize speech recognition
      _isAvailable = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: kDebugMode,
        finalTimeout: const Duration(seconds: 3),
      );

      if (!_isAvailable) {
        debugPrint('❌ Voice recognition: Not available on this device');
        _isInitialized = true;
        return true;
      }

      // Step 3: Get available locales
      _availableLocales = await _speech.locales();
      debugPrint('🌍 Available locales: ${_availableLocales.length}');

      // Step 4: Set default language
      await _setOptimalLanguage();

      _isInitialized = true;
      debugPrint('✅ Voice recognition initialized successfully');
      debugPrint('🎯 Current language: $_currentLanguage');
      debugPrint('📱 Available: $_isAvailable');
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Error initializing voice recognition: $e');
      _isInitialized = true;
      _isAvailable = false;
      return true; // Still allow text input
    }
  }

  /// Ensure microphone permissions are granted
  Future<bool> _ensurePermissions() async {
    try {
      // Check current permission status
      final status = await Permission.microphone.status;
      
      if (status.isGranted) {
        debugPrint('✅ Microphone permission already granted');
        return true;
      }

      if (status.isDenied) {
        debugPrint('🔒 Requesting microphone permission...');
        final result = await Permission.microphone.request();
        
        if (result.isGranted) {
          debugPrint('✅ Microphone permission granted');
          return true;
        } else {
          debugPrint('❌ Microphone permission denied');
          return false;
        }
      }

      if (status.isPermanentlyDenied) {
        debugPrint('🚫 Microphone permission permanently denied');
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Set optimal language based on available locales
  Future<void> _setOptimalLanguage() async {
    try {
      // Priority order for languages
      final preferredLanguages = ['en_US', 'en_IN', 'hi_IN', 'te_IN'];
      
      for (final lang in preferredLanguages) {
        final locale = _availableLocales.firstWhere(
          (locale) => locale.localeId == lang,
          orElse: () => stt.LocaleName('', ''),
        );
        
        if (locale.localeId.isNotEmpty) {
          _currentLanguage = lang;
          debugPrint('🎯 Set language to: $lang (${locale.name})');
          return;
        }
      }
      
      // Fallback to first available English locale
      final englishLocale = _availableLocales.firstWhere(
        (locale) => locale.localeId.startsWith('en'),
        orElse: () => _availableLocales.isNotEmpty ? _availableLocales.first : stt.LocaleName('en_US', 'English'),
      );
      
      _currentLanguage = englishLocale.localeId.isNotEmpty ? englishLocale.localeId : 'en_US';
      debugPrint('🎯 Fallback language set to: $_currentLanguage');
      
    } catch (e) {
      debugPrint('❌ Error setting language: $e');
      _currentLanguage = 'en_US'; // Ultimate fallback
    }
  }

  /// Set language for voice recognition
  Future<void> setLanguage(String languageCode) async {
    try {
      final mappedLanguage = _mapLanguageCode(languageCode);
      
      // Check if the language is available
      final isAvailable = _availableLocales.any((locale) => locale.localeId == mappedLanguage);
      
      if (isAvailable) {
        _currentLanguage = mappedLanguage;
        debugPrint('🎯 Language changed to: $_currentLanguage');
      } else {
        debugPrint('⚠️ Language $mappedLanguage not available, keeping $_currentLanguage');
      }
    } catch (e) {
      debugPrint('❌ Error setting language: $e');
    }
  }

  /// Start listening for voice input with robust error handling
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
  }) async {
    if (!_isInitialized) {
      onError('🔧 Voice service not initialized. Please restart the app.');
      return;
    }

    if (!_isAvailable) {
      onError('🎤 Voice recognition is not available on this device. Please use text input.');
      return;
    }

    // Double-check permissions
    final hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) {
      onError('🔒 Microphone permission required. Please enable it in Settings > Apps > TALOWA > Permissions.');
      return;
    }

    if (_isListening) {
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 100)); // Brief pause
    }

    try {
      _isListening = true;
      debugPrint('🎤 Starting voice recognition...');
      debugPrint('🌍 Using language: $_currentLanguage');
      
      final success = await _speech.listen(
        onResult: (result) {
          debugPrint('🎯 Speech result: ${result.recognizedWords}');
          debugPrint('🎯 Confidence: ${result.confidence}');
          debugPrint('🎯 Final: ${result.finalResult}');
          
          if (result.finalResult) {
            _isListening = false;
            final recognizedText = result.recognizedWords.trim();
            
            if (recognizedText.isNotEmpty) {
              debugPrint('✅ Voice recognition successful: $recognizedText');
              onResult(recognizedText);
            } else {
              debugPrint('⚠️ Empty recognition result');
              onError('🔇 No speech detected. Please speak clearly and try again.');
            }
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        partialResults: false,
        localeId: _currentLanguage,
        onSoundLevelChange: (level) {
          // Optional: Could use this for visual feedback
          debugPrint('🔊 Sound level: $level');
        },
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      if (!success) {
        _isListening = false;
        debugPrint('❌ Failed to start speech recognition');
        onError('🎤 Could not start voice recognition. Please try again.');
      } else {
        debugPrint('✅ Speech recognition started successfully');
      }
      
    } catch (e) {
      _isListening = false;
      debugPrint('❌ Error starting voice recognition: $e');
      onError('🎤 Voice recognition error. Please try again or use text input.');
    }
  }

  /// Stop listening for voice input
  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _speech.stop();
        debugPrint('🛑 Voice recognition stopped');
      } catch (e) {
        debugPrint('❌ Error stopping voice recognition: $e');
      } finally {
        _isListening = false;
      }
    }
  }

  /// Cancel current listening session
  Future<void> cancel() async {
    if (_isListening) {
      try {
        await _speech.cancel();
        debugPrint('❌ Voice recognition cancelled');
      } catch (e) {
        debugPrint('❌ Error cancelling voice recognition: $e');
      } finally {
        _isListening = false;
      }
    }
  }

  /// Handle speech recognition status changes
  void _onSpeechStatus(String status) {
    debugPrint('📊 Speech status: $status');
    
    switch (status) {
      case 'listening':
        _isListening = true;
        break;
      case 'notListening':
      case 'done':
        _isListening = false;
        break;
    }
  }

  /// Handle speech recognition errors
  void _onSpeechError(dynamic error) {
    debugPrint('❌ Speech error: $error');
    _isListening = false;
    
    // Could emit specific error events here if needed
  }

  /// Map language codes to speech recognition locale IDs
  String _mapLanguageCode(String code) {
    switch (code.toLowerCase()) {
      case 'te':
      case 'telugu':
        return 'te_IN';
      case 'hi':
      case 'hindi':
        return 'hi_IN';
      case 'en':
      case 'english':
      default:
        return 'en_US';
    }
  }

  /// Get supported languages for the UI
  List<Map<String, String>> getSupportedLanguages() {
    return [
      {'code': 'en', 'name': 'English', 'locale': 'en_US'},
      {'code': 'hi', 'name': 'हिंदी', 'locale': 'hi_IN'},
      {'code': 'te', 'name': 'తెలుగు', 'locale': 'te_IN'},
    ];
  }

  /// Test voice recognition functionality
  Future<bool> testVoiceRecognition() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      return _isAvailable && await Permission.microphone.isGranted;
    } catch (e) {
      debugPrint('❌ Voice recognition test failed: $e');
      return false;
    }
  }

  /// Get current voice recognition status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isAvailable': _isAvailable,
      'isListening': _isListening,
      'currentLanguage': _currentLanguage,
      'availableLocales': _availableLocales.length,
    };
  }
}