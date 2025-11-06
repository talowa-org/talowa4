// Voice Recording Widget for TALOWA Messaging
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class VoiceRecordingWidget extends StatefulWidget {
  final Function(String audioPath, Duration duration) onRecordingComplete;
  final VoidCallback onCancel;

  const VoiceRecordingWidget({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecordingWidget> createState() => _VoiceRecordingWidgetState();
}

class _VoiceRecordingWidgetState extends State<VoiceRecordingWidget>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Title
          Text(
            _isRecording ? 'Recording...' : 'Voice Message',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Recording duration
          if (_isRecording)
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.talowaGreen,
              ),
            ),
          
          const Spacer(),
          
          // Recording button
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isRecording ? _pulseAnimation.value : 1.0,
                child: GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : AppTheme.talowaGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : AppTheme.talowaGreen)
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),
          
          Text(
            _isRecording ? 'Tap to stop recording' : 'Tap to start recording',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          
          const Spacer(),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              if (_recordingDuration.inSeconds > 0 && !_isRecording)
                ElevatedButton(
                  onPressed: _sendRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.talowaGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Send'),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      _startRecording();
    } else {
      _stopRecording();
    }
  }

  void _startRecording() {
    _pulseController.repeat(reverse: true);
    
    // Simulate recording timer
    Stream.periodic(const Duration(seconds: 1), (count) => count + 1)
        .takeWhile((_) => _isRecording)
        .listen((seconds) {
      setState(() {
        _recordingDuration = Duration(seconds: seconds);
      });
    });
  }

  void _stopRecording() {
    _pulseController.stop();
  }

  void _sendRecording() {
    // Simulate audio file path
    final audioPath = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
    widget.onRecordingComplete(audioPath, _recordingDuration);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}