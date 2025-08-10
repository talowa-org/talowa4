// AI Assistant Widget for TALOWA
// Implements ChatGPT-style interface with voice + text input
// Voice + Text interface in local languages
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/developer_preferences.dart';
import 'dart:convert';

class AIAssistantWidget extends StatefulWidget {
  const AIAssistantWidget({super.key});

  @override
  State<AIAssistantWidget> createState() => _AIAssistantWidgetState();
}

class _AIAssistantWidgetState extends State<AIAssistantWidget>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIAssistantService _aiService = AIAssistantService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<ChatMessage> _messages = [];
  List<String> _suggestions = [];
  int _userMessageCount = 0;
  bool _suggestionsHidden = false;
  static const int _maxSuggestions = 6;

  // Developer-mode: capture last backend payload for debug panel
  String? _lastBackendRaw;
  String? _lastBackendModel;
  int? _lastBackendStatus;

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAI();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeAI() async {
    final success = await _aiService.initialize();
    setState(() {
      _isInitialized = success;
    });

    if (success) {
      String welcomeMessage = 'Hello! I\'m your TALOWA assistant. I can help you with land records, legal support, and navigating the app.';

      // Add voice status information
      if (_aiService.speechAvailable) {
        welcomeMessage += '\n\n🎤 Voice input is ready! You can:';
        welcomeMessage += '\n• Tap the microphone button and speak';
        welcomeMessage += '\n• Type your questions in the text box';
        welcomeMessage += '\n• Speak in English, Hindi, or Telugu';
      } else {
        welcomeMessage += '\n\n⌨️ Voice input is not available on this device.';
        welcomeMessage += '\nPlease type your questions in the text box below.';
      }

      welcomeMessage += '\n\nHow can I assist you today?';

      _addMessage(ChatMessage(
        text: welcomeMessage,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } else {
      _addMessage(ChatMessage(
        text: 'AI Assistant is currently unavailable. You can still type your questions and I\'ll do my best to help!',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _loadSuggestions() async {
    if (_isInitialized) {
      final suggestions = await _aiService.getContextualSuggestions();
      setState(() {
        _suggestions = suggestions;
      });
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
      if (message.isUser) {
        _userMessageCount++;
        if (_userMessageCount >= 2) _suggestionsHidden = true;
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      _showError('AI Assistant not initialized');
      return;
    }

    if (!_aiService.speechAvailable) {
      _showError('Voice recognition is not available on this device. Please use text input instead.');
      return;
    }

    // Add listening status message
    _addMessage(ChatMessage(
      text: '🎤 Listening... Please speak now.',
      isUser: false,
      timestamp: DateTime.now(),
    ));

    setState(() {
      _isListening = true;
    });

    _pulseController.repeat(reverse: true);
    HapticFeedback.lightImpact();

    await _aiService.startListening(
      onResult: (result) {
        setState(() {
          _isListening = false;
        });
        _pulseController.stop();

        if (result.trim().isNotEmpty) {
          // Add what the user said
          _addMessage(ChatMessage(
            text: result,
            isUser: true,
            timestamp: DateTime.now(),
          ));

          // Process the query
          _processQuery(result, isVoice: true);
        }
      },
      onError: (error) {
        setState(() {
          _isListening = false;
        });
        _pulseController.stop();
        _showError(error);
      },
    );
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _aiService.stopListening();
      setState(() {
        _isListening = false;
      });
      _pulseController.stop();
    }
  }

  Future<void> _processQuery(String query, {bool isVoice = false}) async {
    if (query.trim().isEmpty) return;

    // Add user message
    _addMessage(ChatMessage(
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    setState(() {
      _isProcessing = true;
    });

    try {
      // Process with AI service
      final response = await _aiService.processQuery(query, isVoice: isVoice);

      // Add AI response
      _addMessage(ChatMessage(
        text: response.text,
        isUser: false,
        timestamp: DateTime.now(),
        actions: response.actions,
        confidence: response.confidence,
        debugRaw: response.rawJson,
        debugModel: response.meta != null
            ? (response.meta!['usage']?['model'] ?? response.meta!['model'])?.toString()
            : null,
        debugHttp: response.httpStatus,
      ));

      // Speak response if it was a voice query
      if (isVoice && _isInitialized) {
        await _aiService.speakResponse(response.text);
      }

      // Execute actions if any
      _executeActions(response.actions);

    } catch (e) {
      _addMessage(ChatMessage(
        text: 'I apologize, but I encountered an error processing your request. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _executeActions(List<AIAction> actions) {
    for (final action in actions) {
      switch (action.type) {
        case AIActionType.navigate:
          _handleNavigation(action.data);
          break;
        case AIActionType.call:
          _handleCall(action.data);
          break;
        case AIActionType.share:
          _handleShare(action.data);
          break;
        case AIActionType.suggestions:
          _handleSuggestions(action.data);
          break;
        default:
          break;
      }
    }
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route == null || route.trim().isEmpty) return;

    try {
      debugPrint('AI navigation request: $route');

      switch (route) {
        case '/home':
        case '/main':
          Navigator.pushNamed(context, '/main');
          break;
        case '/ai-test':
          Navigator.pushNamed(context, '/ai-test');
          break;
        // Known future routes: map to main with hint
        case '/network':
        case '/land/records':
        case '/land/add':
        case '/legal/patta-guide':
        case '/legal/support':
        case '/emergency/report':
          Navigator.pushNamed(context, '/main');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening ${route.replaceAll('/', '')}... coming soon')),
          );
          break;
        default:
          // Attempt a direct named route; if it fails, show a toast
          Navigator.pushNamed(context, route).catchError((Object err) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Screen not available yet: $route')),
            );
            return err; // satisfy onError return type
          });
      }
    } catch (e) {
      debugPrint('Navigation failed for $route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not navigate. Please try again.')),
      );
    }
  }

  Future<void> _handleCall(Map<String, dynamic> data) async {
    final phone = data['phone'] as String?;
    if (phone == null || phone.trim().isEmpty) return;

    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to place call to $phone')),
        );
      }
    } catch (e) {
      debugPrint('Call launch failed for $phone: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer.')),
      );
    }
  }

  Future<void> _handleShare(Map<String, dynamic> data) async {
    final text = (data['text'] ?? data['message'] ?? data['code'])?.toString();
    if (text == null || text.trim().isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    } catch (e) {
      debugPrint('Share fallback failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy to clipboard')),
      );
    }
  }

  void _handleSuggestions(Map<String, dynamic> data) {
    // Accept only data.suggestions but gracefully handle categories sent by mistake
    final dynamic raw = data['suggestions'] ?? data['categories'];
    if (raw is List) {
      final normalized = raw
          .map((e) => e?.toString().trim())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet() // dedupe
          .toList(growable: false)
          .take(_maxSuggestions)
          .toList();
      if (normalized.isNotEmpty) {
        setState(() {
          _suggestions = normalized;
          _suggestionsHidden = false; // reveal if backend sends fresh suggestions
        });
      }
    }
  }

  /// Test voice recognition functionality
  Future<void> _testVoiceRecognition() async {
    if (!_isInitialized || !_aiService.speechAvailable) {
      _showError('Voice recognition is not available for testing.');
      return;
    }

    _addMessage(ChatMessage(
      text: '🧪 Testing voice recognition... Please say "Hello TALOWA" when you see the microphone turn red.',
      isUser: false,
      timestamp: DateTime.now(),
    ));

    await Future.delayed(const Duration(seconds: 1));
    await _startListening();
  }

  void _showError(String message) {
    // Show voice-related errors as chat messages for better UX
    if (message.contains('🎤') || message.contains('🌐') || message.contains('🔇') ||
        message.contains('⏱️') || message.contains('🔄') || message.contains('voice') ||
        message.contains('microphone') || message.contains('speech') ||
        message.contains('permission') || message.contains('recognition')) {
      _addMessage(ChatMessage(
        text: message,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } else {
      // Show other errors as snackbars
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      _textController.clear();
      _processQuery(text);
    }
  }

  void _useSuggestion(String suggestion) {
    _processQuery(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.talowaGreen,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'TALOWA AI Assistant',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeScreen()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Suggestions
          if (_suggestions.isNotEmpty && !_suggestionsHidden)
            _buildSuggestions(),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy,
            size: 64,
            color: AppTheme.talowaGreen.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to TALOWA AI Assistant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about land rights, legal support, or app navigation',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.talowaGreen,
              child: const Icon(
                Icons.smart_toy,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? AppTheme.talowaGreen
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  if (message.actions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...message.actions.map((action) => _buildActionButton(action)),
                  ],
                  if (!message.isUser && message.confidence < 0.7) ...[
                    const SizedBox(height: 4),
                    Text(
                      'I\'m not completely sure about this answer',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  // Developer debug panel
                  if (!message.isUser)
                    FutureBuilder<bool>(
                      future: DeveloperPreferences.isDeveloperMode(),
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done || snap.data != true) return const SizedBox.shrink();
                        if (message.debugRaw == null && message.debugModel == null) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.debugModel != null)
                                    Text('Model: ${message.debugModel}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                  if (message.debugHttp != null)
                                    Text('HTTP: ${message.debugHttp}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                  if (message.debugRaw != null) ...[
                                    const SizedBox(height: 6),
                                    Text('Raw JSON:', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      _prettyJson(message.debugRaw!),
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.talowaGreen.withOpacity(0.2),
              child: Icon(
                Icons.person,
                size: 16,
                color: AppTheme.talowaGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _prettyJson(String raw) {
    try {
      final obj = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return raw;
    }
  }

  Widget _buildActionButton(AIAction action) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ElevatedButton(
        onPressed: () => _executeActions([action]),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.talowaGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          action.label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                _suggestions[index],
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _useSuggestion(_suggestions[index]),
              backgroundColor: AppTheme.talowaGreen.withOpacity(0.1),
              labelStyle: TextStyle(color: AppTheme.talowaGreen),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // Voice button - show if voice is available
          if (_isInitialized && _aiService.speechAvailable) ...[
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: Tooltip(
                    message: _isListening
                        ? 'Listening... Tap to stop'
                        : 'Tap and speak clearly',
                    child: GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.red : AppTheme.talowaGreen,
                          shape: BoxShape.circle,
                          boxShadow: _isListening ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                          ] : [
                            BoxShadow(
                              color: AppTheme.talowaGreen.withOpacity(0.2),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
          ],

          // Text input
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Ask me about land records, legal help, or anything else...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onSubmitted: (_) => _sendTextMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),

          const SizedBox(width: 12),

          // Send button
          GestureDetector(
            onTap: _sendTextMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.talowaGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data model for chat messages
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AIAction> actions;
  final double confidence;
  final String? debugRaw;
  final String? debugModel;
  final int? debugHttp;


  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actions = const [],
    this.confidence = 1.0,
    this.debugRaw,
    this.debugModel,
    this.debugHttp,
  });
}

  });
}