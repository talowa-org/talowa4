// Permission Service for TALOWA
// Handles runtime permissions for voice recognition and other features

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request microphone permission for voice recognition
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      
      switch (status) {
        case PermissionStatus.granted:
          debugPrint('Microphone permission granted');
          return true;
        case PermissionStatus.denied:
          debugPrint('Microphone permission denied');
          return false;
        case PermissionStatus.permanentlyDenied:
          debugPrint('Microphone permission permanently denied');
          // Open app settings
          await openAppSettings();
          return false;
        default:
          debugPrint('Microphone permission status: $status');
          return false;
      }
    } catch (e) {
      debugPrint('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request speech recognition permission (if needed on some devices)
  Future<bool> requestSpeechPermission() async {
    try {
      final status = await Permission.speech.request();
      
      switch (status) {
        case PermissionStatus.granted:
          debugPrint('Speech permission granted');
          return true;
        case PermissionStatus.denied:
          debugPrint('Speech permission denied');
          return false;
        case PermissionStatus.permanentlyDenied:
          debugPrint('Speech permission permanently denied');
          await openAppSettings();
          return false;
        default:
          debugPrint('Speech permission status: $status');
          return false;
      }
    } catch (e) {
      debugPrint('Error requesting speech permission: $e');
      return false;
    }
  }

  /// Check if speech permission is granted
  Future<bool> hasSpeechPermission() async {
    try {
      final status = await Permission.speech.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error checking speech permission: $e');
      return false;
    }
  }

  /// Request all voice-related permissions
  Future<bool> requestVoicePermissions() async {
    try {
      final micPermission = await requestMicrophonePermission();
      
      // Speech permission might not be available on all devices
      bool speechPermission = true;
      try {
        speechPermission = await requestSpeechPermission();
      } catch (e) {
        debugPrint('Speech permission not available on this device: $e');
        // This is okay, microphone permission is usually sufficient
      }

      return micPermission; // Speech permission is optional
    } catch (e) {
      debugPrint('Error requesting voice permissions: $e');
      return false;
    }
  }

  /// Check if all voice-related permissions are granted
  Future<bool> hasVoicePermissions() async {
    try {
      final micPermission = await hasMicrophonePermission();
      
      // Speech permission check is optional
      bool speechPermission = true;
      try {
        speechPermission = await hasSpeechPermission();
      } catch (e) {
        // Speech permission might not be available on all devices
        speechPermission = true;
      }

      return micPermission; // Speech permission is optional
    } catch (e) {
      debugPrint('Error checking voice permissions: $e');
      return false;
    }
  }
}