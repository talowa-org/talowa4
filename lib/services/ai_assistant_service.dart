// AI Assistant Service for TALOWA
// Implements intelligent text assistance for land rights queries
// Reference: TALOWA_APP_BLUEPRINT.md - AI Assistant Features

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'remote_config_service.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';
import 'remote_config_service.dart';
import 'universal_voice_service.dart';

// Data models for AI Assistant
enum QueryIntent {
  viewLandRecords,
  addLandRecord,
  pattaApplication,
  landInformation,
  legalHelp,
  legalInformation,
  networkInformation,
  emergency,
  navigation,
  general,
}

enum AIActionType {
  navigate,
  call,
  share,
  suggestions,
  form,
}

class AIAction {
  final AIActionType type;
  final String label;
  final Map<String, dynamic> data;

  AIAction({
    required this.type,
    required this.label,
    required this.data,
  });
}

class AIResponse {
  final String text;
  final List<AIAction> actions;
  final double confidence;

  AIResponse({
    required this.text,
    required this.actions,
    required this.confidence,
  });
}

class AIAssistantService {
  static final AIAssistantService _instance = AIAssistantService._internal();
  factory AIAssistantService() => _instance;
  AIAssistantService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UniversalVoiceService _voiceService = UniversalVoiceService();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isInitialized = false;
  bool _speechAvailable = false;
  String _currentLanguage = 'en-US';
  UserModel? _currentUser;

  // Voice recognition status
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get speechAvailable => _speechAvailable;

  /// Initialize AI Assistant with user context
  Future<bool> initialize() async {
    try {
      // Initialize voice recognition service
      _speechAvailable = await _voiceService.initialize();

      if (_speechAvailable) {
        debugPrint('Voice recognition initialized successfully');
        await _voiceService.setLanguage(_currentLanguage);
      } else {
        debugPrint('Voice recognition not available on this device');
      }

      // Initialize text-to-speech
      await _tts.setLanguage(_currentLanguage);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(0.8);
      await _tts.setPitch(1.0);

      // Load user context
      await _loadUserContext();

      _isInitialized = true;
      debugPrint('AI Assistant initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing AI Assistant: $e');
      _isInitialized = true; // Still allow text input even if voice fails
      _speechAvailable = false;
      return true;
    }
  }

  /// Set language for voice recognition and TTS
  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = _mapLanguageCode(languageCode);

    if (_isInitialized) {
      await _tts.setLanguage(_currentLanguage);
      if (_speechAvailable) {
        await _voiceService.setLanguage(_currentLanguage);
      }
    }
  }

  /// Start listening for voice input
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
  }) async {
    if (!_isInitialized) {
      onError('AI Assistant not initialized');
      return;
    }

    if (!_speechAvailable) {
      onError('Voice recognition is not available on this device. Please use text input instead.');
      return;
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;

      // Start listening with custom voice recognition service
      await _voiceService.startListening(
        onResult: (result) {
          _isListening = false;
          onResult(result);
        },
        onError: (error) {
          _isListening = false;
          onError(error);
        },
      );

    } catch (e) {
      _isListening = false;
      debugPrint('Error starting voice recognition: $e');
      onError('Voice recognition encountered an error. Please try again or use text input.');
    }
  }

  /// Stop listening for voice input
  Future<void> stopListening() async {
    if (_isListening && _speechAvailable) {
      await _voiceService.stopListening();
      _isListening = false;
    }
  }

  /// Process user query and return intelligent response
  Future<AIResponse> processQuery(String query, {bool isVoice = false}) async {
    try {
      // Normalize and analyze query
      final normalizedQuery = _normalizeQuery(query);
      final intent = await _analyzeIntent(normalizedQuery);

      // If backend is enabled (Remote Config) and intent is complex, call server for GPT-5 response
      if (RemoteConfigService.aiEnabled && intent != QueryIntent.navigation && intent != QueryIntent.emergency) {
        final backendResp = await _callBackend(query: query, isVoice: isVoice);
        if (backendResp != null) {
          await _logInteraction(query, backendResp, isVoice);
          return backendResp;
        }
      }

      // Fallback: generate local contextual response
      final response = await _generateResponse(intent, normalizedQuery);

      // Log interaction for learning
      await _logInteraction(query, response, isVoice);

      return response;
    } catch (e) {
      debugPrint('Error processing query: $e');
      return AIResponse(
        text: 'I apologize, but I encountered an error processing your request. Please try again.',
        actions: [],
        confidence: 0.0,
      );
    }
  }

  Future<AIResponse?> _callBackend({required String query, required bool isVoice}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final uri = Uri.parse('${RemoteConfigService.aiUrl}/aiRespond');
      final body = jsonEncode({
        'query': query,
        'lang': _currentLanguage.startsWith('en') ? 'en' : (_currentLanguage.startsWith('hi') ? 'hi' : 'te'),
        'isVoice': isVoice,
        'context': {
          'userId': _currentUser?.id,
          'role': _currentUser?.role,
          'state': _currentUser?.address.state,
          'district': _currentUser?.address.district,
        },
        'client': {
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      });

      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(Duration(milliseconds: RemoteConfigService.aiTimeoutMs));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return _mapAIResponse(data);
      } else {
        debugPrint('AI backend error ${resp.statusCode}: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('AI backend call failed: $e');
      return null;
    }
  }

  AIResponse _mapAIResponse(Map<String, dynamic> json) {
    final actionsJson = (json['actions'] as List<dynamic>? ?? []);
    final actions = actionsJson.map((a) {
      final typeStr = (a['type'] as String? ?? 'suggestions');
      AIActionType type;
      switch (typeStr) {
        case 'navigate':
          type = AIActionType.navigate; break;
        case 'call':
          type = AIActionType.call; break;
        case 'share':
          type = AIActionType.share; break;
        case 'form':
          type = AIActionType.form; break;
        default:
          type = AIActionType.suggestions;
      }
      return AIAction(type: type, label: a['label'] ?? '', data: Map<String, dynamic>.from(a['data'] ?? {}));
    }).toList();

    return AIResponse(
      text: json['text'] ?? '',
      actions: actions,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }


  /// Speak response using text-to-speech
  Future<void> speakResponse(String text) async {
    if (!_isInitialized) return;

    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Error speaking response: $e');
    }
  }

  /// Get contextual suggestions based on user profile
  Future<List<String>> getContextualSuggestions() async {
    if (_currentUser == null) {
      return _getDefaultSuggestions();
    }

    List<String> suggestions = [];

    // Role-based suggestions
    switch (_currentUser!.role) {
      case AppConstants.roleVillageCoordinator:
        suggestions.addAll([
          'How do I organize a village meeting?',
          'Show me my team members',
          'Help with patta applications',
        ]);
        break;
      case AppConstants.roleMember:
        suggestions.addAll([
          'Check my land records',
          'How to apply for patta?',
          'Find my coordinator',
        ]);
        break;
      default:
        suggestions.addAll(_getDefaultSuggestions());
    }

    // Add location-based suggestions
    if (_currentUser!.address.villageCity.isNotEmpty) {
      suggestions.add('Show updates for ${_currentUser!.address.villageCity}');
    }

    return suggestions.take(6).toList();
  }

  // Private methods

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

  Future<void> _loadUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _currentUser = UserModel.fromFirestore(doc);
        }
      }
    } catch (e) {
      debugPrint('Error loading user context: $e');
    }
  }

  String _normalizeQuery(String query) {
    return query.toLowerCase().trim();
  }

  Future<QueryIntent> _analyzeIntent(String query) async {
    debugPrint('Analyzing intent for query: "$query"');

    // Emergency queries (highest priority)
    if (_containsKeywords(query, ['emergency', 'urgent', 'help me', 'grabbing', 'threat', 'danger'])) {
      debugPrint('Intent: Emergency detected');
      return QueryIntent.emergency;
    }

    // Land-related queries
    if (_containsKeywords(query, ['land', 'patta', 'survey', 'acre', 'plot', 'property'])) {
      if (_containsKeywords(query, ['show', 'view', 'check', 'see', 'my'])) {
        debugPrint('Intent: View land records');
        return QueryIntent.viewLandRecords;
      } else if (_containsKeywords(query, ['add', 'register', 'new', 'create'])) {
        debugPrint('Intent: Add land record');
        return QueryIntent.addLandRecord;
      } else if (_containsKeywords(query, ['apply', 'application', 'get', 'obtain'])) {
        debugPrint('Intent: Patta application');
        return QueryIntent.pattaApplication;
      } else if (_containsKeywords(query, ['rights', 'ownership', 'documents'])) {
        debugPrint('Intent: Land information');
        return QueryIntent.landInformation;
      }
      debugPrint('Intent: General land information');
      return QueryIntent.landInformation;
    }

    // Legal queries
    if (_containsKeywords(query, ['legal', 'case', 'court', 'lawyer', 'advocate', 'dispute'])) {
      if (_containsKeywords(query, ['help', 'support', 'need', 'urgent'])) {
        debugPrint('Intent: Legal help');
        return QueryIntent.legalHelp;
      }
      debugPrint('Intent: Legal information');
      return QueryIntent.legalInformation;
    }

    // Network queries
    if (_containsKeywords(query, ['team', 'network', 'referral', 'members', 'group'])) {
      debugPrint('Intent: Network information');
      return QueryIntent.networkInformation;
    }

    // Navigation queries
    if (_containsKeywords(query, ['go to', 'open', 'show me', 'navigate', 'take me'])) {
      debugPrint('Intent: Navigation');
      return QueryIntent.navigation;
    }

    // Greeting and general help
    if (_containsKeywords(query, ['hello', 'hi', 'hey', 'help', 'what can', 'how are'])) {
      debugPrint('Intent: General/Greeting');
      return QueryIntent.general;
    }

    debugPrint('Intent: Default general');
    return QueryIntent.general;
  }

  bool _containsKeywords(String query, List<String> keywords) {
    final normalizedQuery = query.toLowerCase();
    return keywords.any((keyword) {
      final normalizedKeyword = keyword.toLowerCase();
      return normalizedQuery.contains(normalizedKeyword);
    });
  }

  Future<AIResponse> _generateResponse(QueryIntent intent, String query) async {
    debugPrint('Processing query: "$query" with intent: $intent');

    switch (intent) {
      case QueryIntent.viewLandRecords:
        return _generateLandRecordsResponse();

      case QueryIntent.addLandRecord:
        return _generateAddLandRecordResponse(query);

      case QueryIntent.pattaApplication:
        return _generatePattaApplicationResponse(query);

      case QueryIntent.legalHelp:
        return _generateLegalHelpResponse(query);

      case QueryIntent.landInformation:
        return _generateLandInformationResponse(query);

      case QueryIntent.legalInformation:
        return _generateLegalInformationResponse(query);

      case QueryIntent.networkInformation:
        return _generateNetworkResponse();

      case QueryIntent.emergency:
        return _generateEmergencyResponse(query);

      case QueryIntent.navigation:
        return _generateNavigationResponse(query);

      default:
        return await _generateGeneralResponse(query);
    }
  }

  Future<AIResponse> _generateLandRecordsResponse() async {
    if (_currentUser == null) {
      return AIResponse(
        text: 'Please log in to view your land records.',
        actions: [],
        confidence: 0.8,
      );
    }

    return AIResponse(
      text: 'I can help you view your land records. Let me take you to the land records section.',
      actions: [
        AIAction(
          type: AIActionType.navigate,
          label: 'View Land Records',
          data: {'route': '/land/records'},
        ),
      ],
      confidence: 0.9,
    );
  }

  AIResponse _generateAddLandRecordResponse(String query) {
    return AIResponse(
      text: 'I can help you add a new land record. You\'ll need your survey number, village details, and ownership documents. Would you like me to guide you through the process?',
      actions: [
        AIAction(
          type: AIActionType.navigate,
          label: 'Add Land Record',
          data: {'route': '/land/add'},
        ),
      ],
      confidence: 0.8,
    );
  }

  AIResponse _generatePattaApplicationResponse(String query) {
    return AIResponse(
      text: 'To apply for a patta, you need to submit your land documents to the revenue department. The process typically takes 30-60 days. I can guide you through each step.',
      actions: [
        AIAction(
          type: AIActionType.navigate,
          label: 'Patta Application Guide',
          data: {'route': '/legal/patta-guide'},
        ),
      ],
      confidence: 0.85,
    );
  }

  AIResponse _generateLegalHelpResponse(String query) {
    return AIResponse(
      text: 'I can connect you with our legal support network. We have lawyers specializing in land rights, patta applications, and dispute resolution. What specific legal help do you need?',
      actions: [
        AIAction(
          type: AIActionType.navigate,
          label: 'Legal Support',
          data: {'route': '/legal/support'},
        ),
      ],
      confidence: 0.85,
    );
  }

  AIResponse _generateLandInformationResponse(String query) {
    return AIResponse(
      text: 'I can help you understand land-related information including rights, documentation, survey numbers, and legal procedures. What specific aspect would you like to know about?',
      actions: [
        AIAction(
          type: AIActionType.suggestions,
          label: 'Land Topics',
          data: {'suggestions': ['Land rights', 'Survey numbers', 'Patta documents', 'Land disputes']},
        ),
      ],
      confidence: 0.7,
    );
  }

  AIResponse _generateLegalInformationResponse(String query) {
    return AIResponse(
      text: 'I can provide information about legal procedures, court processes, dispute resolution, and your legal rights regarding land. What specific legal information do you need?',
      actions: [
        AIAction(
          type: AIActionType.suggestions,
          label: 'Legal Topics',
          data: {'suggestions': ['Court procedures', 'Dispute resolution', 'Legal rights', 'Documentation']},
        ),
      ],
      confidence: 0.7,
    );
  }

  Future<AIResponse> _generateNetworkResponse() async {
    if (_currentUser == null) {
      return AIResponse(
        text: 'Please log in to view your network information.',
        actions: [],
        confidence: 0.8,
      );
    }

    return AIResponse(
      text: 'Your network has ${_currentUser!.directReferrals} direct referrals and ${_currentUser!.teamSize} total team members.',
      actions: [
        AIAction(
          type: AIActionType.navigate,
          label: 'View Network',
          data: {'route': '/network'},
        ),
      ],
      confidence: 0.9,
    );
  }

  AIResponse _generateEmergencyResponse(String query) {
    return AIResponse(
      text: 'This seems urgent. I can help you report an incident, connect with emergency contacts, or guide you through immediate safety steps. What emergency assistance do you need?',
      actions: [
        AIAction(
          type: AIActionType.navigate,
          label: 'Report Incident',
          data: {'route': '/emergency/report'},
        ),
        AIAction(
          type: AIActionType.call,
          label: 'Emergency Helpline',
          data: {'phone': '100'},
        ),
      ],
      confidence: 0.9,
    );
  }

  AIResponse _generateNavigationResponse(String query) {
    if (query.contains('home')) {
      return AIResponse(
        text: 'Taking you to the home screen.',
        actions: [
          AIAction(
            type: AIActionType.navigate,
            label: 'Go to Home',
            data: {'route': '/home'},
          ),
        ],
        confidence: 0.9,
      );
    }

    return AIResponse(
      text: 'I can help you navigate to different sections of the app. What would you like to see?',
      actions: [],
      confidence: 0.6,
    );
  }

  Future<AIResponse> _generateGeneralResponse(String query) async {
    // Analyze query for better general responses
    if (_containsKeywords(query, ['hello', 'hi', 'hey'])) {
      final greeting = _getTimeBasedGreeting();
      final userName = _currentUser?.fullName ?? 'there';

      return AIResponse(
        text: '$greeting $userName! I can help you with land records, legal support, network management, and app navigation. What would you like to know?',
        actions: [
          AIAction(
            type: AIActionType.suggestions,
            label: 'Popular Questions',
            data: {'suggestions': _getDefaultSuggestions()},
          ),
        ],
        confidence: 0.9,
      );
    } else if (_containsKeywords(query, ['test voice', 'voice test'])) {
      return AIResponse(
        text: '🧪 Voice Recognition Test\n\nI\'ll start listening in a moment. Please say "Hello TALOWA" clearly when you see the microphone button turn red and start pulsing.\n\nMake sure you:\n• Speak clearly and at normal volume\n• Are in a quiet environment\n• Have granted microphone permission\n• Have a stable internet connection',
        actions: [],
        confidence: 0.95,
      );
    } else if (_containsKeywords(query, ['voice help', 'voice problem', 'microphone help'])) {
      String helpText = '🎤 Voice Recognition Help\n\n';

      if (_speechAvailable) {
        helpText += '✅ Voice recognition is available on your device.\n\n';
        helpText += 'How to use voice input:\n';
        helpText += '1. Tap the green microphone button\n';
        helpText += '2. Wait for it to turn red and start pulsing\n';
        helpText += '3. Speak clearly in English, Hindi, or Telugu\n';
        helpText += '4. Wait for the response\n\n';
        helpText += 'Troubleshooting:\n';
        helpText += '• Ensure microphone permission is granted\n';
        helpText += '• Check your internet connection\n';
        helpText += '• Speak in a quiet environment\n';
        helpText += '• Try speaking louder or closer to the microphone';
      } else {
        helpText += '❌ Voice recognition is not available on your device.\n\n';
        helpText += 'This could be because:\n';
        helpText += '• Your device doesn\'t support speech recognition\n';
        helpText += '• Microphone permission was denied\n';
        helpText += '• No internet connection available\n\n';
        helpText += 'Please use the text input box to chat with me instead.';
      }

      return AIResponse(
        text: helpText,
        actions: [
          AIAction(
            type: AIActionType.suggestions,
            label: 'Try These',
            data: {'suggestions': ['Test voice recognition', 'Show my land records', 'Get help']},
          ),
        ],
        confidence: 0.9,
      );
    } else if (_containsKeywords(query, ['help'])) {
      return AIResponse(
        text: 'I\'m here to help! I can assist you with:\n• Land records and patta applications\n• Legal support and court procedures\n• Network and referral management\n• Emergency reporting\n• App navigation\n\nWhat specific help do you need?',
        actions: [
          AIAction(
            type: AIActionType.suggestions,
            label: 'Help Topics',
            data: {'suggestions': ['Land records', 'Legal help', 'My network', 'Emergency support']},
          ),
        ],
        confidence: 0.85,
      );
    } else if (_containsKeywords(query, ['thank', 'thanks'])) {
      return AIResponse(
        text: 'You\'re welcome! I\'m always here to help you with your land rights and TALOWA app needs. Is there anything else I can assist you with?',
        actions: [],
        confidence: 0.9,
      );
    } else if (_containsKeywords(query, ['what', 'how', 'where', 'when', 'why', 'can you', 'tell me'])) {
      // Handle question-type queries
      return AIResponse(
        text: 'I understand you have a question! I can help you with:\n\n• Land Records: View, add, or manage your land documents\n• Legal Support: Find lawyers, understand procedures\n• Patta Applications: Step-by-step guidance\n• Network Management: View your referrals and team\n• Emergency Help: Report issues or get immediate assistance\n\nWhat specific topic would you like to know about?',
        actions: [
          AIAction(
            type: AIActionType.suggestions,
            label: 'Choose Topic',
            data: {'suggestions': ['Land records', 'Legal help', 'Patta application', 'My network', 'Emergency support']},
          ),
        ],
        confidence: 0.8,
      );
    }

    // Default response for unrecognized queries
    return AIResponse(
      text: 'I\'m here to help you with land rights and TALOWA app features. I can assist with:\n\n🏞️ Land Records Management\n⚖️ Legal Support & Guidance\n📋 Patta Applications\n👥 Network & Referrals\n🚨 Emergency Reporting\n\nPlease ask me about any of these topics, or type "help" for more information.',
      actions: [
        AIAction(
          type: AIActionType.suggestions,
          label: 'Popular Topics',
          data: {'suggestions': _getDefaultSuggestions()},
        ),
      ],
      confidence: 0.6,
    );
  }

  List<String> _getDefaultSuggestions() {
    List<String> suggestions = [
      'Show my land records',
      'How to apply for patta?',
      'Get legal help',
      'View my network',
      'Report an incident',
      'Contact coordinator',
    ];

    // Add voice-related suggestions if voice is available
    if (_speechAvailable) {
      suggestions.addAll([
        'Test voice recognition',
        'Voice help',
      ]);
    }

    return suggestions;
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  Future<void> _logInteraction(String query, AIResponse response, bool isVoice) async {
    try {
      await _firestore.collection('ai_interactions').add({
        'userId': _currentUser?.id ?? 'anonymous',
        'query': query,
        'response': response.text,
        'confidence': response.confidence,
        'isVoice': isVoice,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging interaction: $e');
    }
  }
}