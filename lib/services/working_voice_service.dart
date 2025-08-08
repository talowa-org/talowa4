// Working Voice Recognition Service for TALOWA
// Implements proper speech-to-text with error handling and permissions

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'permission_service.dart';

class WorkingVoiceService {
  static final WorkingVoiceService _instance = WorkingVoiceService._internal();
  factory WorkingVoiceService() => _instance;
  WorkingVoiceService._internal();

  static const MethodChannel _channel = MethodChannel('com.talowa.speech_recognition');
  final PermissionService _permissionService = PermissionService();
  
  bool _isListening = false;
  bool _isInitialized = false;
  bool _isAvailable = false;
  String _currentLanguage = 'en-US';
  
  // Voice recognition status
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;

  /// Initialize voice recognition service with proper error handling
  Future<bool> initialize() async {
    try {
      debugPrint('Initializing voice recognition service...');
      
      // Check if device supports speech recognition
      _isAvailable = await _checkDeviceSupport();
      
      if (!_isAvailable) {
        debugPrint('Voice recognition not supported on this device');
        _isInitialized = true; // Mark as initialized but not available
        return true;
      }

      // Check permissions
      final hasPermissions = await _permissionService.hasVoicePermissions();
      if (!hasPermissions) {
        debugPrint('Voice permissions not granted');
        _isAvailable = false;
        _isInitialized = true;
        return true;
      }

      // Test the service
      await _testVoiceService();
      
      _isInitialized = true;
      _isAvailable = true;
      debugPrint('Voice recognition service initialized successfully');
      return true;
      
    } catch (e) {
      debugPrint('Error initializing voice recognition: $e');
      _isInitialized = true;
      _isAvailable = false;
      return true; // Still return true to allow text input
    }
  }

  /// Check if device supports speech recognition
  Future<bool> _checkDeviceSupport() async {
    try {
      // Try to check if speech recognition is available
      final result = await _channel.invokeMethod('isAvailable');
      return result == true;
    } catch (e) {
      debugPrint('Device speech recognition check failed: $e');
      return false; // Assume not available if check fails
    }
  }

  /// Test voice service functionality
  Future<void> _testVoiceService() async {
    try {
      await _channel.invokeMethod('test');
      debugPrint('Voice service test passed');
    } catch (e) {
      debugPrint('Voice service test failed: $e');
      _isAvailable = false;
    }
  }

  /// Set language for voice recognition
  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = _mapLanguageCode(languageCode);
    
    if (_isInitialized && _isAvailable) {
      try {
        await _channel.invokeMethod('setLanguage', {'language': _currentLanguage});
      } catch (e) {
        debugPrint('Error setting language: $e');
      }
    }
  }

  /// Start listening for voice input with comprehensive error handling
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
  }) async {
    if (!_isInitialized) {
      onError('Voice service not initialized. Please restart the app.');
      return;
    }

    if (!_isAvailable) {
      onError('Voice recognition is not available on this device. Please use text input.');
      return;
    }

    // Check permissions before starting
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
      debugPrint('Starting voice recognition...');
      
      // Start voice recognition with timeout
      final result = await _channel.invokeMethod('startListening', {
        'language': _currentLanguage,
        'timeout': 10000, // 10 seconds timeout
      }).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('Voice recognition timed out', const Duration(seconds: 12));
        },
      );
      
      _isListening = false;
      
      if (result != null && result.toString().trim().isNotEmpty) {
        final recognizedText = result.toString().trim();
        debugPrint('Voice recognition result: $recognizedText');
        onResult(recognizedText);
      } else {
        onError('🔇 No speech detected. Please speak clearly and try again.');
      }
      
    } on TimeoutException catch (e) {
      _isListening = false;
      debugPrint('Voice recognition timeout: $e');
      onError('⏱️ Voice recognition timed out. Please try again.');
      
    } on PlatformException catch (e) {
      _isListening = false;
      debugPrint('Platform exception in voice recognition: $e');
      
      switch (e.code) {
        case 'PERMISSION_DENIED':
          onError('🎤 Microphone permission denied. Please enable it in device settings.');
          break;
        case 'NETWORK_ERROR':
          onError('🌐 Network error. Voice recognition needs internet connection.');
          break;
        case 'NO_MATCH':
          onError('🔇 Could not understand what you said. Please speak clearly in English, Hindi, or Telugu.');
          break;
        case 'AUDIO_ERROR':
          onError('🎤 Microphone error. Please check if another app is using the microphone.');
          break;
        case 'SERVICE_NOT_AVAILABLE':
          onError('🔧 Voice recognition service unavailable. Please try again later.');
          break;
        default:
          onError('🎤 Voice recognition error. Please try again or use text input.');
      }
      
    } catch (e) {
      _isListening = false;
      debugPrint('Unexpected error in voice recognition: $e');
      onError('🎤 Voice recognition encountered an error. Please try text input instead.');
    }
  }

  /// Stop listening for voice input
  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _channel.invokeMethod('stopListening');
        debugPrint('Voice recognition stopped');
      } catch (e) {
        debugPrint('Error stopping voice recognition: $e');
      } finally {
        _isListening = false;
      }
    }
  }

  /// Check if voice recognition is available on this device
  Future<bool> checkAvailability() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      return _isAvailable;
    } catch (e) {
      debugPrint('Error checking voice availability: $e');
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
      debugPrint('Error getting supported languages: $e');
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

  /// Test microphone functionality
  Future<bool> testMicrophone() async {
    try {
      final hasPermission = await _permissionService.hasMicrophonePermission();
      if (!hasPermission) {
        return false;
      }
      
      // Try a quick test
      await _channel.invokeMethod('testMicrophone');
      return true;
    } catch (e) {
      debugPrint('Microphone test failed: $e');
      return false;
    }
  }
}