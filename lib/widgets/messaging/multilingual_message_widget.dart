// Multilingual Message Widget for TALOWA
// Displays messages with translation, RTL support, and voice transcription

import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../services/rtl_support_service.dart';
import '../../services/messaging/message_translation_service.dart';
import '../../services/messaging/voice_transcription_service.dart';
import '../../core/theme/app_theme.dart';

class MultilingualMessageWidget extends StatefulWidget {
  final String messageId;
  final String content;
  final String senderName;
  final String? detectedLanguage;
  final bool isSender;
  final bool isVoiceMessage;
  final String? voiceFilePath;
  final DateTime timestamp;
  final bool showTranslation;
  final VoidCallback? onTranslate;
  final VoidCallback? onPlayVoice;

  const MultilingualMessageWidget({
    super.key,
    required this.messageId,
    required this.content,
    required this.senderName,
    this.detectedLanguage,
    required this.isSender,
    this.isVoiceMessage = false,
    this.voiceFilePath,
    required this.timestamp,
    this.showTranslation = false,
    this.onTranslate,
    this.onPlayVoice,
  });

  @override
  State<MultilingualMessageWidget> createState() => _MultilingualMessageWidgetState();
}

class _MultilingualMessageWidgetState extends State<MultilingualMessageWidget> {
  TranslationResult? _translationResult;
  TranscriptionResult? _transcriptionResult;
  bool _isTranslating = false;
  bool _isTranscribing = false;
  final bool _showOriginalText = true;

  @override
  void initState() {
    super.initState();
    _initializeMessage();
  }

  Future<void> _initializeMessage() async {
    // Auto-transcribe voice messages
    if (widget.isVoiceMessage && widget.voiceFilePath != null) {
      await _transcribeVoiceMessage();
    }

    // Auto-translate if needed
    final currentLanguage = LocalizationService.currentLanguage;
    final messageLanguage = widget.detectedLanguage ?? 
        LocalizationService.detectLanguage(widget.content);

    if (messageLanguage != currentLanguage && widget.showTranslation) {
      await _translateMessage();
    }
  }

  Future<void> _transcribeVoiceMessage() async {
    if (widget.voiceFilePath == null) return;

    setState(() {
      _isTranscribing = true;
    });

    try {
      final result = await VoiceTranscriptionService.transcribeVoiceMessage(
        audioFilePath: widget.voiceFilePath!,
        targetLanguage: LocalizationService.currentLanguage,
      );

      setState(() {
        _transcriptionResult = result;
        _isTranscribing = false;
      });
    } catch (e) {
      setState(() {
        _isTranscribing = false;
      });
    }
  }

  Future<void> _translateMessage() async {
    setState(() {
      _isTranslating = true;
    });

    try {
      final result = await MessageTranslationService.translateMessage(
        message: widget.content,
        targetLanguage: LocalizationService.currentLanguage,
        sourceLanguage: widget.detectedLanguage,
      );

      setState(() {
        _translationResult = result;
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: RTLSupportService.currentTextDirection,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: RTLSupportService.getMessageAlignment(
            isSender: widget.isSender,
          ),
          children: [
            _buildMessageBubble(),
            if (_translationResult != null || _transcriptionResult != null)
              _buildAdditionalInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble() {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isSender ? AppTheme.talowaGreen : Colors.grey.shade200,
        borderRadius: RTLSupportService.getMessageBubbleBorderRadius(
          isSender: widget.isSender,
        ),
      ),
      child: Column(
        crossAxisAlignment: RTLSupportService.crossAxisAlignment,
        children: [
          if (!widget.isSender) _buildSenderName(),
          _buildMessageContent(),
          _buildMessageFooter(),
        ],
      ),
    );
  }

  Widget _buildSenderName() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RTLSupportService.createDirectionalText(
        widget.senderName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    return Column(
      crossAxisAlignment: RTLSupportService.crossAxisAlignment,
      children: [
        if (widget.isVoiceMessage) _buildVoiceMessageContent(),
        if (!widget.isVoiceMessage) _buildTextMessageContent(),
        if (_translationResult != null && _translationResult!.isTranslated)
          _buildTranslationContent(),
      ],
    );
  }

  Widget _buildTextMessageContent() {
    final messageLanguage = widget.detectedLanguage ?? 
        LocalizationService.detectLanguage(widget.content);
    
    return RTLSupportService.createDirectionalText(
      widget.content,
      languageCode: messageLanguage,
      style: TextStyle(
        fontSize: 16,
        color: widget.isSender ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildVoiceMessageContent() {
    return Column(
      crossAxisAlignment: RTLSupportService.crossAxisAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: widget.onPlayVoice,
              icon: Icon(
                Icons.play_arrow,
                color: widget.isSender ? Colors.white : AppTheme.talowaGreen,
              ),
            ),
            Icon(
              Icons.graphic_eq,
              color: widget.isSender ? Colors.white70 : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              'Voice Message',
              style: TextStyle(
                fontSize: 14,
                color: widget.isSender ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        if (_isTranscribing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isSender ? Colors.white : AppTheme.talowaGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Transcribing...',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isSender ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        if (_transcriptionResult != null && _transcriptionResult!.isSuccessful)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isSender 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: RTLSupportService.crossAxisAlignment,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.text_fields,
                        size: 14,
                        color: widget.isSender ? Colors.white70 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Transcription:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.isSender ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RTLSupportService.createDirectionalText(
                    _transcriptionResult!.transcribedText,
                    languageCode: _transcriptionResult!.detectedLanguage,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isSender ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTranslationContent() {
    if (_translationResult == null || !_translationResult!.isTranslated) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isSender 
              ? Colors.white.withOpacity(0.2)
              : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isSender 
                ? Colors.white.withOpacity(0.3)
                : Colors.blue.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: RTLSupportService.crossAxisAlignment,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate,
                  size: 14,
                  color: widget.isSender ? Colors.white70 : Colors.blue.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Translation:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.isSender ? Colors.white70 : Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(_translationResult!.confidence),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_translationResult!.confidence * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            RTLSupportService.createDirectionalText(
              _translationResult!.translatedText,
              languageCode: _translationResult!.targetLanguage,
              style: TextStyle(
                fontSize: 14,
                color: widget.isSender ? Colors.white : Colors.black87,
              ),
            ),
            if (_showOriginalText && _translationResult!.originalText != _translationResult!.translatedText) ...[
              const SizedBox(height: 4),
              RTLSupportService.createDirectionalText(
                'Original: ${_translationResult!.originalText}',
                languageCode: _translationResult!.sourceLanguage,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: widget.isSender ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageIndicator(),
          const SizedBox(width: 8),
          Text(
            _formatTime(widget.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: widget.isSender ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          if (_isTranslating) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.isSender ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageIndicator() {
    final messageLanguage = widget.detectedLanguage ?? 
        LocalizationService.detectLanguage(widget.content);
    final languageName = LocalizationService.supportedLanguages[messageLanguage] ?? 
        messageLanguage.toUpperCase();
    final isRTL = LocalizationService.rtlLanguages.contains(messageLanguage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: widget.isSender 
            ? Colors.white.withOpacity(0.2)
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            languageName,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: widget.isSender ? Colors.white : Colors.black54,
            ),
          ),
          if (isRTL) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.format_textdirection_r_to_l,
              size: 10,
              color: widget.isSender ? Colors.white70 : Colors.orange.shade600,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: widget.isSender 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (_translationResult != null && !_translationResult!.isTranslated)
            _buildActionChip(
              icon: Icons.translate,
              label: 'Translate',
              onTap: _translateMessage,
            ),
          if (widget.isVoiceMessage && _transcriptionResult == null)
            _buildActionChip(
              icon: Icons.text_fields,
              label: 'Transcribe',
              onTap: _transcribeVoiceMessage,
            ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.blue.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

