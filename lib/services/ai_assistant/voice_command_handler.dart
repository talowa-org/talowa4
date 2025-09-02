import 'package:flutter/material.dart';

enum VoiceCommandAction {
  navigateToLand,
  navigateToPayments,
  navigateToCommunity,
  navigateToProfile,
  showEmergencyHelp,
  showMessage,
  showError,
  unknown,
}

class VoiceCommandResponse {
  final String message;
  final VoiceCommandAction action;
  final Map<String, dynamic>? data;

  VoiceCommandResponse({
    required this.message,
    required this.action,
    this.data,
  });
}

class VoiceCommandHandler {
  /// Process voice command and return appropriate response
  Future<VoiceCommandResponse> processCommand(String command) async {
    final normalizedCommand = command.toLowerCase().trim();
    
    // Navigation commands
    if (_containsAny(normalizedCommand, ['land', 'जमीन', 'भूमि', 'లాండ్'])) {
      return VoiceCommandResponse(
        message: 'Opening Land Records',
        action: VoiceCommandAction.navigateToLand,
      );
    }
    
    if (_containsAny(normalizedCommand, ['payment', 'पेमेंट', 'भुगतान', 'పేమెంట్'])) {
      return VoiceCommandResponse(
        message: 'Opening Payments',
        action: VoiceCommandAction.navigateToPayments,
      );
    }
    
    if (_containsAny(normalizedCommand, ['community', 'समुदाय', 'कम्युनिटी', 'కమ్యూనిటీ'])) {
      return VoiceCommandResponse(
        message: 'Opening Community',
        action: VoiceCommandAction.navigateToCommunity,
      );
    }
    
    if (_containsAny(normalizedCommand, ['profile', 'प्रोफाइल', 'प्रोफ़ाइल', 'ప్రొఫైల్'])) {
      return VoiceCommandResponse(
        message: 'Opening Profile',
        action: VoiceCommandAction.navigateToProfile,
      );
    }
    
    // Emergency commands
    if (_containsAny(normalizedCommand, ['emergency', 'help', 'इमरजेंसी', 'मदद', 'ఎమర్జెన్సీ', 'సహాయం'])) {
      return VoiceCommandResponse(
        message: 'Opening Emergency Help',
        action: VoiceCommandAction.showEmergencyHelp,
      );
    }
    
    // Default response
    return VoiceCommandResponse(
      message: 'Command processed. How else can I help?',
      action: VoiceCommandAction.showMessage,
    );
  }
  
  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}