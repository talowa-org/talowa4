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
    if (_containsAny(normalizedCommand, ['land', 'à¤œà¤®à¥€à¤¨', 'à¤­à¥‚à¤®à¤¿', 'à°²à°¾à°‚à°¡à±'])) {
      return VoiceCommandResponse(
        message: 'Opening Land Records',
        action: VoiceCommandAction.navigateToLand,
      );
    }
    
    if (_containsAny(normalizedCommand, ['payment', 'à¤ªà¥‡à¤®à¥‡à¤‚à¤Ÿ', 'à¤­à¥à¤—à¤¤à¤¾à¤¨', 'à°ªà±‡à°®à±†à°‚à°Ÿà±'])) {
      return VoiceCommandResponse(
        message: 'Opening Payments',
        action: VoiceCommandAction.navigateToPayments,
      );
    }
    
    if (_containsAny(normalizedCommand, ['community', 'à¤¸à¤®à¥à¤¦à¤¾à¤¯', 'à¤•à¤®à¥à¤¯à¥à¤¨à¤¿à¤Ÿà¥€', 'à°•à°®à±à°¯à±‚à°¨à°¿à°Ÿà±€'])) {
      return VoiceCommandResponse(
        message: 'Opening Community',
        action: VoiceCommandAction.navigateToCommunity,
      );
    }
    
    if (_containsAny(normalizedCommand, ['profile', 'à¤ªà¥à¤°à¥‹à¤«à¤¾à¤‡à¤²', 'à¤ªà¥à¤°à¥‹à¤«à¤¼à¤¾à¤‡à¤²', 'à°ªà±à°°à±Šà°«à±ˆà°²à±'])) {
      return VoiceCommandResponse(
        message: 'Opening Profile',
        action: VoiceCommandAction.navigateToProfile,
      );
    }
    
    // Emergency commands
    if (_containsAny(normalizedCommand, ['emergency', 'help', 'à¤‡à¤®à¤°à¤œà¥‡à¤‚à¤¸à¥€', 'à¤®à¤¦à¤¦', 'à°Žà°®à°°à±à°œà±†à°¨à±à°¸à±€', 'à°¸à°¹à°¾à°¯à°‚'])) {
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
