// Voice Message Widget for Premium Messaging
import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';

class VoiceMessageWidget extends StatefulWidget {
  final String audioUrl;
  final Duration duration;
  final bool isCurrentUser;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final Function(Duration)? onSeek;

  const VoiceMessageWidget({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.isCurrentUser,
    this.onPlay,
    this.onPause,
    this.onSeek,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget>
    with TickerProviderStateMixin {
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  late AnimationController _waveAnimationController;
  late AnimationController _playButtonController;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _waveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    _playButtonController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _playButtonController.forward();
      _waveAnimationController.repeat();
      widget.onPlay?.call();
      _startProgressTimer();
    } else {
      _playButtonController.reverse();
      _waveAnimationController.stop();
      widget.onPause?.call();
      _progressTimer?.cancel();
    }
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isPlaying && _currentPosition < widget.duration) {
        setState(() {
          _currentPosition = _currentPosition + const Duration(milliseconds: 100);
        });
      } else if (_currentPosition >= widget.duration) {
        _togglePlayback();
      }
    });
  }

  void _onSeek(double value) {
    final newPosition = Duration(
      milliseconds: (value * widget.duration.inMilliseconds).round(),
    );
    setState(() {
      _currentPosition = newPosition;
    });
    widget.onSeek?.call(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isCurrentUser 
            ? AppTheme.talowaGreen.withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isCurrentUser 
              ? AppTheme.talowaGreen.withValues(alpha: 0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isCurrentUser ? AppTheme.talowaGreen : Colors.grey[600],
                shape: BoxShape.circle,
              ),
              child: AnimatedBuilder(
                animation: _playButtonController,
                builder: (context, child) {
                  return Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Waveform and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform visualization
                SizedBox(
                  height: 30,
                  child: AnimatedBuilder(
                    animation: _waveAnimationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: WaveformPainter(
                          progress: _currentPosition.inMilliseconds / widget.duration.inMilliseconds,
                          isPlaying: _isPlaying,
                          animationValue: _waveAnimationController.value,
                          color: widget.isCurrentUser ? AppTheme.talowaGreen : Colors.grey[600]!,
                        ),
                        size: const Size(double.infinity, 30),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 4),

                // Progress slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: widget.isCurrentUser ? AppTheme.talowaGreen : Colors.grey[600],
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: widget.isCurrentUser ? AppTheme.talowaGreen : Colors.grey[600],
                  ),
                  child: Slider(
                    value: widget.duration.inMilliseconds > 0
                        ? _currentPosition.inMilliseconds / widget.duration.inMilliseconds
                        : 0.0,
                    onChanged: _onSeek,
                    min: 0.0,
                    max: 1.0,
                  ),
                ),

                // Time display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_currentPosition),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      _formatDuration(widget.duration),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Speed control
          PopupMenuButton<double>(
            icon: Icon(
              Icons.speed,
              size: 16,
              color: Colors.grey[600],
            ),
            onSelected: (speed) {
              // Handle playback speed change
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playback speed: ${speed}x'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0.5, child: Text('0.5x')),
              const PopupMenuItem(value: 1.0, child: Text('1.0x')),
              const PopupMenuItem(value: 1.25, child: Text('1.25x')),
              const PopupMenuItem(value: 1.5, child: Text('1.5x')),
              const PopupMenuItem(value: 2.0, child: Text('2.0x')),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// Voice Recording Widget
class VoiceRecordingWidget extends StatefulWidget {
  final Function(String audioPath, Duration duration) onRecordingComplete;
  final VoidCallback? onCancel;

  const VoiceRecordingWidget({
    super.key,
    required this.onRecordingComplete,
    this.onCancel,
  });

  @override
  State<VoiceRecordingWidget> createState() => _VoiceRecordingWidgetState();
}

class _VoiceRecordingWidgetState extends State<VoiceRecordingWidget>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    _pulseController.repeat();
    _waveController.repeat();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration = Duration(seconds: timer.tick);
      });

      // Auto-stop after 5 minutes
      if (_recordingDuration.inMinutes >= 5) {
        _stopRecording();
      }
    });

    // TODO: Start actual audio recording
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });

    _pulseController.stop();
    _waveController.stop();
    _recordingTimer?.cancel();

    // TODO: Stop actual audio recording and get file path
    const mockAudioPath = 'path/to/recorded/audio.m4a';
    widget.onRecordingComplete(mockAudioPath, _recordingDuration);
  }

  void _cancelRecording() {
    setState(() {
      _isRecording = false;
    });

    _pulseController.stop();
    _waveController.stop();
    _recordingTimer?.cancel();

    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Recording status
          Text(
            _isRecording ? 'Recording...' : 'Tap to record',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 20),

          // Recording visualization
          SizedBox(
            height: 100,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _waveController]),
              builder: (context, child) {
                return CustomPaint(
                  painter: RecordingVisualizationPainter(
                    pulseValue: _pulseController.value,
                    waveValue: _waveController.value,
                    isRecording: _isRecording,
                  ),
                  size: const Size(double.infinity, 100),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Recording duration
          if (_isRecording)
            Text(
              _formatDuration(_recordingDuration),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
            ),

          const SizedBox(height: 30),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel button
              if (_isRecording)
                FloatingActionButton(
                  onPressed: _cancelRecording,
                  backgroundColor: Colors.grey[600],
                  heroTag: "cancel_recording",
                  child: const Icon(Icons.close, color: Colors.white),
                ),

              // Record/Stop button
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red[600] : AppTheme.talowaGreen,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  blurRadius: 20 * (1 + _pulseController.value),
                                  spreadRadius: 5 * _pulseController.value,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 32,
                      ),
                    );
                  },
                ),
              ),

              // Send button
              if (_isRecording)
                FloatingActionButton(
                  onPressed: _stopRecording,
                  backgroundColor: AppTheme.talowaGreen,
                  heroTag: "send_recording",
                  child: const Icon(Icons.send, color: Colors.white),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Instructions
          Text(
            _isRecording
                ? 'Tap stop when finished, or swipe up to cancel'
                : 'Hold to record, release to send',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// Custom painters for visualizations
class WaveformPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final double animationValue;
  final Color color;

  WaveformPainter({
    required this.progress,
    required this.isPlaying,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Generate waveform bars
    const barCount = 40;
    final barWidth = size.width / barCount;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final normalizedX = i / barCount;
      
      // Generate pseudo-random heights for waveform
      final baseHeight = (i % 3 + 1) * 8.0;
      final animatedHeight = isPlaying 
          ? baseHeight * (1 + 0.5 * (animationValue + normalizedX) % 1)
          : baseHeight;

      final isActive = normalizedX <= progress;
      final currentPaint = isActive ? activePaint : paint;

      canvas.drawLine(
        Offset(x, centerY - animatedHeight / 2),
        Offset(x, centerY + animatedHeight / 2),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class RecordingVisualizationPainter extends CustomPainter {
  final double pulseValue;
  final double waveValue;
  final bool isRecording;

  RecordingVisualizationPainter({
    required this.pulseValue,
    required this.waveValue,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    if (isRecording) {
      // Draw pulsing circles
      final paint = Paint()
        ..color = Colors.red.withValues(alpha: 0.3 * (1 - pulseValue))
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 3; i++) {
        final radius = 20 + (i * 15) + (pulseValue * 20);
        canvas.drawCircle(center, radius, paint);
      }

      // Draw sound waves
      final wavePaint = Paint()
        ..color = Colors.red[600]!
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < 5; i++) {
        final waveRadius = 30 + (i * 10) + (waveValue * 15);
        canvas.drawCircle(center, waveRadius, wavePaint);
      }
    }

    // Draw microphone icon
    final micPaint = Paint()
      ..color = isRecording ? Colors.red[600]! : Colors.grey[600]!
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 15, micPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}