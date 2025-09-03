// Voice-First AI Assistant Widget for TALOWA
// Emphasizes voice input with visual feedback and cultural integration

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../services/cultural_service.dart';

class VoiceFirstAIWidget extends StatefulWidget {
  final Function(String)? onVoiceCommand;
  final Function(String)? onTextCommand;
  final bool isCollapsible;
  final double maxHeight;

  const VoiceFirstAIWidget({
    super.key,
    this.onVoiceCommand,
    this.onTextCommand,
    this.isCollapsible = true,
    this.maxHeight = 280,
  });

  @override
  State<VoiceFirstAIWidget> createState() => _VoiceFirstAIWidgetState();
}

class _VoiceFirstAIWidgetState extends State<VoiceFirstAIWidget>
    with TickerProviderStateMixin {

  // Voice Recognition State
  bool _isListening = false;
  bool _isProcessing = false;
  String _currentTranscript = '';
  String _lastResponse = '';

  // UI State
  bool _isExpanded = false;
  bool _showTextInput = false;
  final TextEditingController _textController = TextEditingController();

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  // Voice Recognition Timer
  Timer? _listeningTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialGreeting();
  }

  void _initializeAnimations() {
    // Pulse animation for voice button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Wave animation for listening state
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  void _loadInitialGreeting() {
    setState(() {
      _lastResponse = CulturalService.getCulturalGreeting();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _textController.dispose();
    _listeningTimer?.cancel();
    super.dispose();
  }

  // Voice Recognition Methods
  void _startListening() async {
    if (_isListening) return;

    try {
      setState(() {
        _isListening = true;
        _currentTranscript = '';
        _isProcessing = false;
      });

      // Start animations
      _pulseController.repeat(reverse: true);
      _waveController.repeat(reverse: true);

      // Provide haptic feedback
      HapticFeedback.lightImpact();

      // Simulate voice recognition (replace with actual implementation)
      _listeningTimer = Timer(const Duration(seconds: 3), () {
        _stopListening();
      });

      // Mock transcript updates
      _simulateVoiceRecognition();

    } catch (e) {
      debugPrint('Error starting voice recognition: $e');
      _stopListening();
    }
  }

  void _stopListening() {
    if (!_isListening) return;

    setState(() {
      _isListening = false;
      _isProcessing = true;
    });

    // Stop animations
    _pulseController.stop();
    _waveController.stop();

    _listeningTimer?.cancel();

    // Process the voice command
    if (_currentTranscript.isNotEmpty) {
      _processVoiceCommand(_currentTranscript);
    } else {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _simulateVoiceRecognition() {
    // Simulate real-time transcript updates
    const mockPhrases = [
      'मेरी',
      'मेरी जमीन',
      'मेरी जमीन की जानकारी',
      'मेरी जमीन की जानकारी दिखाओ'
    ];

    int phraseIndex = 0;
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isListening || phraseIndex >= mockPhrases.length) {
        timer.cancel();
        return;
      }

      setState(() {
        _currentTranscript = mockPhrases[phraseIndex];
      });
      phraseIndex++;
    });
  }

  void _processVoiceCommand(String command) async {
    try {
      // Process with cultural service
      final response = await CulturalService.voiceFormFiller(command);

      setState(() {
        _lastResponse = response['message'] ?? 'समझ गया! आपकी मदद कर रहा हूं।';
        _isProcessing = false;
        _currentTranscript = '';
      });

      // Provide success feedback
      HapticFeedback.selectionClick();

      // Notify parent widget
      widget.onVoiceCommand?.call(command);

    } catch (e) {
      setState(() {
        _lastResponse = 'माफ करें, कुछ गलत हुआ। कृपया फिर से कोशिश करें।';
        _isProcessing = false;
      });
      debugPrint('Error processing voice command: $e');
    }
  }

  void _processTextCommand(String command) async {
    if (command.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await CulturalService.voiceFormFiller(command);

      setState(() {
        _lastResponse = response['message'] ?? 'आपका संदेश मिल गया।';
        _isProcessing = false;
      });

      _textController.clear();
      widget.onTextCommand?.call(command);

    } catch (e) {
      setState(() {
        _lastResponse = 'टेक्स्ट प्रोसेसिंग में त्रुटि।';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsible) {
      return _buildCollapsibleWidget();
    } else {
      return _buildExpandedWidget();
    }
  }

  Widget _buildCollapsibleWidget() {
    return Card(
      elevation: AppTheme.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: ExpansionTile(
        leading: const Icon(
          Icons.assistant,
          color: AppTheme.talowaGreen,
          size: 28,
        ),
        title: const Text(
          'AI सहायक',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          _isListening ? 'सुन रहा हूं...' : 'आवाज़ से पूछें',
          style: TextStyle(
            color: _isListening ? AppTheme.talowaGreen : AppTheme.secondaryText,
            fontSize: 12,
          ),
        ),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        children: [
          Container(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: _buildExpandedWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedWidget() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Voice Interface Section
          _buildVoiceInterface(),

          const SizedBox(height: AppTheme.spacingMedium),

          // Response Display
          _buildResponseDisplay(),

          const SizedBox(height: AppTheme.spacingMedium),

          // Text Input Toggle
          _buildTextInputSection(),
        ],
      ),
    );
  }

  Widget _buildVoiceInterface() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.talowaGreen.withValues(alpha: 0.1),
            AppTheme.talowaGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: _isListening
              ? AppTheme.talowaGreen
              : AppTheme.borderColor,
          width: _isListening ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Voice Button with Animation
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isListening
                            ? [AppTheme.talowaGreen, AppTheme.talowaGreen.withValues(alpha: 0.7)]
                            : [AppTheme.talowaGreen.withValues(alpha: 0.8), AppTheme.talowaGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.talowaGreen.withValues(alpha: 0.3),
                          blurRadius: _isListening ? 20 : 10,
                          spreadRadius: _isListening ? 5 : 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppTheme.spacingMedium),

          // Status Text
          Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _isListening ? AppTheme.talowaGreen : AppTheme.primaryText,
            ),
            textAlign: TextAlign.center,
          ),

          // Current Transcript
          if (_currentTranscript.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMedium,
                vertical: AppTheme.spacingSmall,
              ),
              decoration: BoxDecoration(
                color: AppTheme.talowaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                '"$_currentTranscript"',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // Wave Animation for Listening
          if (_isListening)
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.only(top: AppTheme.spacingSmall),
                  height: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 4,
                        height: 20 * (0.3 + 0.7 * _waveAnimation.value *
                                (index % 2 == 0 ? 1 : 0.7)),
                        decoration: BoxDecoration(
                          color: AppTheme.talowaGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResponseDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assistant,
                color: AppTheme.talowaGreen,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              const Text(
                'AI सहायक का जवाब:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          if (_isProcessing)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.talowaGreen),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                const Text(
                  'प्रोसेसिंग...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            )
          else
            Text(
              _lastResponse,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.primaryText,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextInputSection() {
    return Column(
      children: [
        // Toggle Text Input Button
        TextButton.icon(
          onPressed: () {
            setState(() {
              _showTextInput = !_showTextInput;
            });
          },
          icon: Icon(
            _showTextInput ? Icons.keyboard_hide : Icons.keyboard,
            size: 18,
          ),
          label: Text(
            _showTextInput ? 'टेक्स्ट छुपाएं' : 'टेक्स्ट में लिखें',
            style: const TextStyle(fontSize: 12),
          ),
        ),

        // Text Input Field
        if (_showTextInput) ...[
          const SizedBox(height: AppTheme.spacingSmall),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'यहां अपना सवाल लिखें...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMedium,
                      vertical: AppTheme.spacingSmall,
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              IconButton(
                onPressed: _isProcessing
                    ? null
                    : () => _processTextCommand(_textController.text),
                icon: Icon(
                  Icons.send,
                  color: _isProcessing ? AppTheme.disabledText : AppTheme.talowaGreen,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _getStatusText() {
    if (_isProcessing) return 'प्रोसेसिंग कर रहा हूं...';
    if (_isListening) return 'सुन रहा हूं... बोलिए';
    return 'माइक दबाकर बोलें';
  }
}