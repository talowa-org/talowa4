import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_to_text.dart';  // Temporarily disabled
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/localization_service.dart';
import '../services/cultural_service.dart';
import '../services/location_service.dart';

class VoiceAssistantWidget extends StatefulWidget {
  final Function(String) onQueryReceived;
  final String currentLanguage;
  
  const VoiceAssistantWidget({
    super.key,
    required this.onQueryReceived,
    this.currentLanguage = 'en',
  });

  @override
  State<VoiceAssistantWidget> createState() => _VoiceAssistantWidgetState();
}

class _VoiceAssistantWidgetState extends State<VoiceAssistantWidget>
    with TickerProviderStateMixin {
  // final SpeechToText _speechToText = SpeechToText();  // Temporarily disabled
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String _lastWords = '';
  
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTTS();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  void _initSpeech() async {
    final micPermission = await Permission.microphone.request();
    if (micPermission.isGranted) {
      // _speechEnabled = await _speechToText.initialize(  // Temporarily disabled
      //   onError: (error) {
      //     debugPrint('Speech recognition error: $error');
      //     _stopListening();
      //   },
      //   onStatus: (status) {
      //     debugPrint('Speech recognition status: $status');
      //     if (status == 'done' || status == 'notListening') {
      //       _stopListening();
      //     }
      //   },
      // );
      _speechEnabled = false;  // Temporarily disabled
    }
    setState(() {});
  }

  void _initTTS() async {
    await _flutterTts.setLanguage(widget.currentLanguage);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(0.8);
    await _flutterTts.setPitch(1.0);
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    
    setState(() {
      _isListening = true;
      _lastWords = '';
    });
    
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
    
    // Provide haptic feedback
    CulturalService.provideFeedback('selection');
    
    // Speak instruction in local language
    await _speak(_getListeningPrompt());
    
    // await _speechToText.listen(  // Temporarily disabled
    //   onResult: _onSpeechResult,
    //   listenFor: const Duration(seconds: 30),
    //   pauseFor: const Duration(seconds: 3),
    //   partialResults: true,
    //   localeId: widget.currentLanguage,
    //   cancelOnError: true,
    //   listenMode: ListenMode.confirmation,
    // );
  }

  void _stopListening() async {
    // await _speechToText.stop();  // Temporarily disabled
    setState(() {
      _isListening = false;
    });
    
    _pulseController.stop();
    _waveController.stop();
    
    if (_lastWords.isNotEmpty) {
      _processVoiceInput(_lastWords);
    }
  }

  void _onSpeechResult(result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  Future<void> _processVoiceInput(String input) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Process voice input through cultural service
      final extractedData = await CulturalService.voiceFormFiller(input);
      
      // Create response based on extracted data
      String response = await _generateResponse(input, extractedData);
      
      // Speak the response
      await _speak(response);
      
      // Send to parent widget
      widget.onQueryReceived(input);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error processing voice input: $e');
      }
      await _speak(_getErrorMessage());
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<String> _generateResponse(String input, Map<String, dynamic> data) async {
    if (data['category'] == 'land_issue') {
      if (data['type'] == 'land_grabbing') {
        return LocalizationService.getVoiceResponse('land_issue_registered');
      }
      return LocalizationService.getVoiceResponse('land_help');
    }
    
    // Check for common queries
    final lowerInput = input.toLowerCase();
    if (lowerInput.contains('coordinator') || lowerInput.contains('support')) {
      final location = await LocationService.getCurrentLocation();
      if (location != null) {
        final nearby = await LocationService.findNearbyCoordinators(
          latitude: location.latitude,
          longitude: location.longitude,
        );
        
        if (nearby.isNotEmpty) {
          final coordinator = nearby.first;
          return 'आपके पास ${coordinator['fullName']} हैं। वे ${coordinator['role']} हैं।';
        }
      }
      return LocalizationService.getVoiceResponse('coordinator_search');
    }
    
    if (lowerInput.contains('help')) {
      return LocalizationService.getVoiceResponse('general_help');
    }
    
    return 'मैं आपकी बात समझने की कोशिश कर रहा हूं। कृपया फिर से कहें या टाइप करें।';
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  String _getListeningPrompt() {
    return LocalizationService.getVoiceResponse('listening');
  }

  String _getErrorMessage() {
    return LocalizationService.getVoiceResponse('error');
  }
  
  IconData _getIconForAction(String label) {
    // Map action labels to icons
    if (label.toLowerCase().contains('land') || label.contains('जमीन') || label.contains('భూమి')) {
      return Icons.report_problem;
    } else if (label.toLowerCase().contains('network') || label.contains('नेटवर्क') || label.contains('నెట్‌వర్క్')) {
      return Icons.people;
    } else if (label.toLowerCase().contains('legal') || label.toLowerCase().contains('help') || label.contains('कानूनी') || label.contains('न्याय')) {
      return Icons.gavel;
    } else {
      return Icons.contact_phone;
    }
  }

  void _handleTextInput() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      _processVoiceInput(text);
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Voice input area
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: _getHintText(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _handleTextInput,
                    ),
                  ),
                  onSubmitted: (_) => _handleTextInput(),
                ),
              ),
              const SizedBox(width: 12),
              
              // Voice button
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isListening
                                ? [Colors.red.shade400, Colors.red.shade600]
                                : [Colors.green.shade400, Colors.green.shade600],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening ? Colors.red : Colors.green)
                                  .withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          
          // Status indicator
          if (_isListening || _isProcessing) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isListening) ...[
                  AnimatedBuilder(
                    animation: _waveAnimation,
                    builder: (context, child) {
                      return Row(
                        children: List.generate(3, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 4,
                            height: 20 + (10 * _waveAnimation.value * 
                              (index % 2 == 0 ? 1 : -1)),
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _lastWords.isEmpty ? 'सुन रहा हूं...' : _lastWords,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
                
                if (_isProcessing) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  const Text('प्रोसेसिंग...'),
                ],
              ],
            ),
          ],
          
          // Quick action buttons
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LocalizationService.getQuickActions().map((action) {
              return _buildQuickAction(
                action['label']!,
                _getIconForAction(action['label']!),
                () => widget.onQueryReceived(action['query']!),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHintText() {
    return LocalizationService.getText({
      'en': 'Ask me anything...',
      'hi': 'कुछ भी पूछें...',
      'te': 'ఏదైనా అడగండి...',
    });
  }
}