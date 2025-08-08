// Native Voice Recognition Service for TALOWA
// Uses platform channels for reliable speech recognition

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class NativeVoiceService {
  static final NativeVoiceService _instance = NativeVoiceService._internal();
  factory NativeVoiceService() => _instance;
  NativeVoiceService._internal();

  static const MethodChannel _channel = MethodChannel('com.talowa.speech_recognition');
  
  bool _isListening = false;
  bool _isInitialized = false;
  bool _isAvailable = false;
  String _currentLanguage = 'en-US';
  
  // Voice recognition status
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;

  /// Initialize voice recognition service
  Future<bool> initialize() async {
    try {
      debugPrint('🎤 Initializing native voice recognition service...');
      
      // Step 1: Check permissions
      final permissionGranted = await _checkPermissions();
      if (!permissionGranted) {
        debugPrint('❌ Voice recognition: Permissions not granted');
        _isInitialized = true;
        _isAvailable = false;
        return true; // Still return true to allow text input
      }

      // Step 2: Check if voice recognition is available on device
      try {
        _isAvailable = await _channel.invokeMethod('isAvailable');
        debugPrint('📱 Voice recognition available: $_isAvailable');
      } catch (e) {
        debugPrint('❌ Error checking voice availability: $e');
        _isAvailable = false;
      }

      // Step 3: Test the service if available
      if (_isAvailable) {
        try {
          await _channel.invokeMethod('test');
          debugPrint('✅ Voice service test passed');
        } catch (e) {
          debugPrint('⚠️ Voice service test failed: $e');
          _isAvailable = false;
        }
      }

      _isInitialized = true;
      
      if (_isAvailable) {
        debugPrint('✅ Native voice recognition initialized successfully');
      } else {
        debugPrint('ℹ️ Voice recognition not available - text-only mode');
      }
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Error initializing native voice recognition: $e');
      _isInitialized = true;
      _isAvailable = false;
      return true; // Still allow text input
    }
  }

  /// Check and request microphone permissions
  Future<bool> _checkPermissions() async {
    try {
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

  /// Set language for voice recognition
  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = _mapLanguageCode(languageCode);
    debugPrint('🌍 Language set to: $_currentLanguage');
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

    // Double-check permissions
    final hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) {
      final granted = await Permission.microphone.request();
      if (!granted.isGranted) {
        onError('🔒 Microphone permission required. Please enable it in Settings > Apps > TALOWA > Permissions.');
        return;
      }
    }

    if (_isListening) {
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 200)); // Brief pause
    }

    try {
      _isListening = true;
      debugPrint('🎤 Starting native voice recognition...');
      debugPrint('🌍 Using language: $_currentLanguage');
      
      final result = await _channel.invokeMethod('startListening', {
        'language': _currentLanguage,
        'timeout': 10000, // 10 seconds
      }).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('Voice recognition timed out', const Duration(seconds: 12));
        },
      );
      
      _isListening = false;
      
      if (result != null && result.toString().trim().isNotEmpty) {
        final recognizedText = result.toString().trim();
        debugPrint('✅ Voice recognition successful: $recognizedText');
        onResult(recognizedText);
      } else {
        debugPrint('⚠️ Empty recognition result');
        onError('🔇 No speech detected. Please speak clearly and try again.');
      }
      
    } on TimeoutException catch (e) {
      _isListening = false;
      debugPrint('⏱️ Voice recognition timeout: $e');
      onError('⏱️ Voice recognition timed out. Please try again.');
      
    } on PlatformException catch (e) {
      _isListening = false;
      debugPrint('❌ Platform exception in voice recognition: $e');
      
      final errorMessage = _handlePlatformError(e);
      onError(errorMessage);
      
    } catch (e) {
      _isListening = false;
      debugPrint('❌ Unexpected error in voice recognition: $e');
      onError('🎤 Voice recognition error. Please try again or use text input.');
    }
  }

  /// Handle platform-specific errors
  String _handlePlatformError(PlatformException e) {
    switch (e.code) {
      case 'PERMISSION_DENIED':
        return '🔒 Microphone permission denied. Please enable it in device settings.';
      case 'NETWORK_ERROR':
        return '🌐 Network error. Voice recognition needs internet connection.';
      case 'NO_MATCH':
        return '🔇 Could not understand what you said. Please speak clearly in English, Hindi, or Telugu.';
      case 'AUDIO_ERROR':
        return '🎤 Microphone error. Please check if another app is using the microphone.';
      case 'SERVICE_NOT_AVAILABLE':
        return '🔧 Voice recognition service unavailable. Please try again later.';
      case 'NOT_AVAILABLE':
        return '📱 Voice recognition not supported on this device. Please use text input.';
      case 'SPEECH_TIMEOUT':
        return '⏱️ No speech detected within time limit. Please try again.';
      case 'SERVICE_BUSY':
        return '🔄 Voice recognition service is busy. Please wait and try again.';
      default:
        return '🎤 Voice recognition error: ${e.message ?? 'Unknown error'}. Please try text input.';
    }
  }

  /// Stop listening for voice input
  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _channel.invokeMethod('stopListening');
        debugPrint('🛑 Voice recognition stopped');
      } catch (e) {
        debugPrint('❌ Error stopping voice recognition: $e');
      } finally {
        _isListening = false;
      }
    }
  }

  /// Test microphone functionality
  Future<bool> testMicrophone() async {
    try {
      if (!_isAvailable) return false;
      
      await _channel.invokeMethod('testMicrophone');
      debugPrint('✅ Microphone test passed');
      return true;
    } catch (e) {
      debugPrint('❌ Microphone test failed: $e');
      return false;
    }
  }

  /// Get supported languages
  Future<List<String>> getSupportedLanguages() async {
    try {
      if (_isAvailable) {
        final List<dynamic> languages = await _channel.invokeMethod('getSupportedLanguages');
        return languages.cast<String>();
      }
    } catch (e) {
      debugPrint('❌ Error getting supported languages: $e');
    }
    
    // Return default supported languages
    return ['en-US', 'hi-IN', 'te-IN'];
  }

  /// Map language codes to proper locale identifiers
  String _mapLanguageCode(String code) {
    switch (code.toLowerCase()) {
      case 'te':
      case 'telugu':
        return 'te-IN'; // Telugu (India)
      case 'hi':
      case 'hindi':
        return 'hi-IN'; // Hindi (India)
      case 'en':
      case 'english':
      default:
        return 'en-US'; // English (US)
    }
  }

  /// Get current voice recognition status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isAvailable': _isAvailable,
      'isListening': _isListening,
      'currentLanguage': _currentLanguage,
    };
  }

  /// Get user-friendly language options
  List<Map<String, String>> getLanguageOptions() {
    return [
      {'code': 'en', 'name': 'English', 'locale': 'en-US'},
      {'code': 'hi', 'name': 'हिंदी (Hindi)', 'locale': 'hi-IN'},
      {'code': 'te', 'name': 'తెలుగు (Telugu)', 'locale': 'te-IN'},
    ];
  }
}