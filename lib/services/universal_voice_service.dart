// Universal Voice Recognition Service for TALOWA
// Works on both mobile and web platforms with graceful fallbacks

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class UniversalVoiceService {
  static final UniversalVoiceService _instance = UniversalVoiceService._internal();
  factory UniversalVoiceService() => _instance;
  UniversalVoiceService._internal();

  bool _isListening = false;
  bool _isInitialized = false;
  bool _isAvailable = false;
  String _currentLanguage = 'en-US';
  
  // Voice recognition status
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;

  /// Initialize voice recognition service with platform detection
  Future<bool> initialize() async {
    try {
      debugPrint('🎤 Initializing universal voice recognition service...');
      
      // Check platform and initialize accordingly
      if (kIsWeb) {
        return await _initializeWeb();
      } else {
        return await _initializeMobile();
      }
    } catch (e) {
      debugPrint('❌ Error initializing voice service: $e');
      _isInitialized = true;
      _isAvailable = false;
      return true; // Still return true to allow text input
    }
  }

  /// Initialize for web platform using Web Speech API
  Future<bool> _initializeWeb() async {
    try {
      debugPrint('🌐 Initializing web voice recognition...');
      
      // For web, we'll use a simple fallback approach
      // The Web Speech API would need to be implemented in JavaScript
      _isAvailable = false; // Disable for now on web
      _isInitialized = true;
      
      debugPrint('ℹ️ Voice recognition not available on web - text-only mode');
      return true;
    } catch (e) {
      debugPrint('❌ Web voice initialization error: $e');
      _isAvailable = false;
      _isInitialized = true;
      return true;
    }
  }

  /// Initialize for mobile platforms
  Future<bool> _initializeMobile() async {
    try {
      debugPrint('📱 Initializing mobile voice recognition...');
      
      // Check permissions first
      final permissionGranted = await _checkPermissions();
      if (!permissionGranted) {
        debugPrint('❌ Voice recognition: Permissions not granted');
        _isInitialized = true;
        _isAvailable = false;
        return true;
      }

      // Try to use the native voice service
      try {
        const MethodChannel channel = MethodChannel('com.talowa.speech_recognition');
        _isAvailable = await channel.invokeMethod('isAvailable');
        debugPrint('📱 Native voice recognition available: $_isAvailable');
      } catch (e) {
        debugPrint('❌ Native voice service not available: $e');
        _isAvailable = false;
      }

      _isInitialized = true;
      
      if (_isAvailable) {
        debugPrint('✅ Voice recognition initialized successfully');
      } else {
        debugPrint('ℹ️ Voice recognition not available - text-only mode');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Mobile voice initialization error: $e');
      _isAvailable = false;
      _isInitialized = true;
      return true;
    }
  }

  /// Check and request microphone permissions
  Future<bool> _checkPermissions() async {
    try {
      if (kIsWeb) {
        // Web permissions are handled by the browser
        return true;
      }

      final status = await Permission.microphone.status;
      if (status.isGranted) {
        debugPrint('🔒 Microphone permission granted');
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.microphone.request();
        if (result.isGranted) {
          debugPrint('✅ Microphone permission granted');
          return true;
        }
      }

      debugPrint('❌ Microphone permission denied');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Set language for voice recognition
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    debugPrint('🌍 Language set to: $language');
  }

  /// Start listening for voice input
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

    if (kIsWeb) {
      onError('🌐 Voice input not supported on web. Please type your question.');
      return;
    }

    // For mobile platforms, try to use native voice service
    try {
      _isListening = true;
      
      const MethodChannel channel = MethodChannel('com.talowa.speech_recognition');
      final String result = await channel.invokeMethod('startListening', {
        'language': _currentLanguage,
        'timeout': 15000,
      });
      
      _isListening = false;
      
      if (result.isNotEmpty && result.trim().length > 1) {
        onResult(result.trim());
      } else {
        onError('🔇 No clear speech detected. Please speak louder and more clearly.');
      }
      
    } catch (e) {
      _isListening = false;
      debugPrint('❌ Voice recognition error: $e');
      
      // Provide user-friendly error messages
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('permission')) {
        onError('🎤 Microphone permission required. Please enable it in Settings.');
      } else if (errorString.contains('network')) {
        onError('🌐 Internet connection needed. Please check your connection.');
      } else if (errorString.contains('not available') || errorString.contains('missing')) {
        onError('🎤 Voice recognition not supported on this device. Please use text input.');
      } else {
        onError('🎤 Voice input unavailable right now. Please type your question instead.');
      }
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      try {
        if (!kIsWeb) {
          const MethodChannel channel = MethodChannel('com.talowa.speech_recognition');
          await channel.invokeMethod('stopListening');
        }
      } catch (e) {
        debugPrint('Error stopping voice recognition: $e');
      }
      _isListening = false;
    }
  }

  /// Get supported languages
  Future<List<String>> getSupportedLanguages() async {
    try {
      if (kIsWeb) {
        return ['en-US', 'hi-IN', 'te-IN']; // Default supported languages
      }
      
      const MethodChannel channel = MethodChannel('com.talowa.speech_recognition');
      final List<dynamic> languages = await channel.invokeMethod('getSupportedLanguages');
      return languages.cast<String>();
    } catch (e) {
      debugPrint('Error getting supported languages: $e');
      return ['en-US', 'hi-IN', 'te-IN']; // Fallback
    }
  }

  /// Check if voice recognition is currently available
  Future<bool> checkAvailability() async {
    if (!_isInitialized) {
      return false;
    }
    
    if (kIsWeb) {
      return false; // Not available on web for now
    }
    
    try {
      const MethodChannel channel = MethodChannel('com.talowa.speech_recognition');
      return await channel.invokeMethod('isAvailable');
    } catch (e) {
      return false;
    }
  }
}
