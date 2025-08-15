// Voice Recognition Service for TALOWA
// Custom implementation using platform channels for reliable voice recognition

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'permission_service.dart';

class VoiceRecognitionService {
  static final VoiceRecognitionService _instance = VoiceRecognitionService._internal();
  factory VoiceRecognitionService() => _instance;
  VoiceRecognitionService._internal();

  static const MethodChannel _channel = MethodChannel('com.talowa.voice_recognition');
  final PermissionService _permissionService = PermissionService();
  
  bool _isListening = false;
  bool _isInitialized = false;
  String _currentLanguage = 'en-US';
  
  // Voice recognition status
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// Initialize voice recognition service
  Future<bool> initialize() async {
    try {
      // For web platform, use different initialization
      if (kIsWeb) {
        debugPrint('🌐 Initializing voice recognition for web platform...');
        _isInitialized = true;
        debugPrint('✅ Voice recognition service initialized for web');
        return true;
      }
      
      // Check if voice recognition is available on the platform
      final bool available = await _channel.invokeMethod('isVoiceRecognitionAvailable');
      
      if (available) {
        _isInitialized = true;
        debugPrint('✅ Voice recognition service initialized successfully');
        
        // Test the service connection
        try {
          await _channel.invokeMethod('getSupportedLanguages');
          debugPrint('✅ Voice recognition service connection verified');
        } catch (e) {
          debugPrint('⚠️ Voice recognition service connection issue: $e');
          // Still mark as initialized but with potential issues
        }
        
        return true;
      } else {
        debugPrint('❌ Voice recognition not available on this device');
        _isInitialized = false;
        return false;
      }
    } catch (e) {
      debugPrint('Error initializing voice recognition: $e');
      _isInitialized = false;
      
      // Try a fallback initialization
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final bool retryAvailable = await _channel.invokeMethod('isVoiceRecognitionAvailable');
        if (retryAvailable) {
          _isInitialized = true;
          debugPrint('Voice recognition initialized on retry');
          return true;
        }
      } catch (retryError) {
        debugPrint('Voice recognition retry failed: $retryError');
      }
      
      return false;
    }
  }

  /// Set language for voice recognition
  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = _mapLanguageCode(languageCode);
    
    if (_isInitialized) {
      try {
        await _channel.invokeMethod('setLanguage', {'language': _currentLanguage});
      } catch (e) {
        debugPrint('Error setting language: $e');
      }
    }
  }

  /// Start listening for voice input
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
  }) async {
    if (!_isInitialized) {
      onError('Voice recognition not initialized');
      return;
    }

    // Check permissions
    final hasPermissions = await _permissionService.hasVoicePermissions();
    if (!hasPermissions) {
      final granted = await _permissionService.requestVoicePermissions();
      if (!granted) {
        onError('🎤 Microphone permission required. Please enable it in Settings > Apps > TALOWA > Permissions.');
        return;
      }
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;
      
      // Start voice recognition using platform channel with improved settings
      final String result = await _channel.invokeMethod('startListening', {
        'language': _currentLanguage,
        'timeout': 15000, // Reduced to 15 seconds for better UX
      });
      
      _isListening = false;
      
      if (result.isNotEmpty && result.trim().length > 1) {
        // Only accept results with meaningful content
        onResult(result.trim());
      } else {
        onError('🔇 No clear speech detected. Please speak louder and more clearly.');
      }
      
    } catch (e) {
      _isListening = false;
      debugPrint('Voice recognition error: $e');
      
      // Provide user-friendly error messages based on error type
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('permission_denied') || errorString.contains('insufficient_permissions')) {
        onError('🎤 Microphone permission required. Please enable it in Settings > Apps > TALOWA > Permissions.');
      } else if (errorString.contains('network_error') || errorString.contains('network_timeout')) {
        onError('🌐 Internet connection needed. Please check your connection and try again.');
      } else if (errorString.contains('no_match')) {
        onError('🔇 Couldn\'t understand. Please speak clearly in English, Hindi, or Telugu.');
      } else if (errorString.contains('speech_timeout')) {
        onError('⏱️ No speech heard. Tap the microphone and start speaking immediately.');
      } else if (errorString.contains('audio_error')) {
        onError('🎤 Microphone busy. Close other apps using the microphone and try again.');
      } else if (errorString.contains('recognizer_busy')) {
        onError('🔄 Voice service busy. Please wait 2-3 seconds and try again.');
      } else if (errorString.contains('server_error')) {
        onError('🌐 Voice service error. Please try again or use text input.');
      } else if (errorString.contains('not_available') || errorString.contains('not connected')) {
        onError('🎤 Voice recognition not supported on this device. Please use text input.');
      } else {
        // Generic fallback message with helpful suggestion
        onError('🎤 Voice input unavailable right now. Please type your question instead.');
      }
    }
  }

  /// Stop listening for voice input
  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _channel.invokeMethod('stopListening');
      } catch (e) {
        debugPrint('Error stopping voice recognition: $e');
      } finally {
        _isListening = false;
      }
    }
  }

  /// Check if voice recognition is available on this device
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod('isVoiceRecognitionAvailable');
    } catch (e) {
      debugPrint('Error checking voice recognition availability: $e');
      return false;
    }
  }

  /// Get supported languages
  Future<List<String>> getSupportedLanguages() async {
    try {
      final List<dynamic> languages = await _channel.invokeMethod('getSupportedLanguages');
      return languages.cast<String>();
    } catch (e) {
      debugPrint('Error getting supported languages: $e');
      return ['en-US', 'hi-IN', 'te-IN'];
    }
  }

  String _mapLanguageCode(String code) {
    switch (code) {
      case 'te':
        return 'te-IN'; // Telugu
      case 'hi':
        return 'hi-IN'; // Hindi
      case 'en':
      default:
        return 'en-US'; // English
    }
  }
}