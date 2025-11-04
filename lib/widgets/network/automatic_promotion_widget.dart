import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/automatic_promotion_service.dart';

/// Widget that displays real-time promotion progress and handles automatic promotion
class AutomaticPromotionWidget extends StatefulWidget {
  final String? userId;
  final VoidCallback? onPromotionTriggered;

  const AutomaticPromotionWidget({
    super.key,
    this.userId,
    this.onPromotionTriggered,
  });

  @override
  State<AutomaticPromotionWidget> createState() => _AutomaticPromotionWidgetState();
}

class _AutomaticPromotionWidgetState extends State<AutomaticPromotionWidget>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _celebrationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _celebrationAnimation;

  String? _currentUserId;
  bool _hasTriggeredCelebration = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

    // Initialize animations
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  void _triggerCelebration() {
    if (!_hasTriggeredCelebration) {
      _hasTriggeredCelebration = true;
      _celebrationController.forward();
      widget.onPromotionTriggered?.call();

      // Show celebration dialog
      _showPromotionCelebration();
    }
  }

  void _showPromotionCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PromotionCelebrationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Please log in to view promotion progress'),
        ),
      );
    }

    return StreamBuilder<PromotionProgress>(
      stream: AutomaticPromotionService.listenToPromotionProgress(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final progress = snapshot.data!;

        // Trigger celebration if 100% achieved
        if (progress.hasAchieved100Percent && progress.nextRole != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerCelebration();
          });
        }

        // Animate progress bar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _progressController.animateTo(progress.overallProgress / 100);
        });

        return AnimatedBuilder(
          animation: _celebrationAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_celebrationAnimation.value * 0.05),
              child: Card(
                elevation: 4 + (_celebrationAnimation.value * 4),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: progress.hasAchieved100Percent
                        ? LinearGradient(
                            colors: [
                              Colors.green.withOpacity(0.1),
                              Colors.amber.withOpacity(0.1),
                            ],
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(progress),
                        const SizedBox(height: 16),
                        _buildProgressSection(progress),
                        const SizedBox(height: 16),
                        _buildStatsSection(progress),
                        if (progress.readyForPromotion) ...[
                          const SizedBox(height: 16),
                          _buildReadyBanner(progress),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(PromotionProgress progress) {
    return Row(
      children: [
        Icon(
          Icons.star,
          color: progress.hasAchieved100Percent ? Colors.amber : Colors.blue,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progress.currentRole.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Current Role',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (progress.nextRole != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Next: ${progress.nextRole!.name}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                progress.progressPercentage,
                style: TextStyle(
                  fontSize: 12,
                  color: progress.hasAchieved100Percent ? Colors.green : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildProgressSection(PromotionProgress progress) {
    if (progress.nextRole == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Highest Role Achieved!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overall Progress: ${progress.progressPercentage}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: _progressAnimation.value * (progress.overallProgress / 100),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.hasAchieved100Percent ? Colors.green : Colors.blue,
              ),
              minHeight: 8,
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricProgress(
                'Direct Referrals',
                progress.directReferrals,
                progress.nextRole!.directRequirement,
                progress.directProgress,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricProgress(
                'Team Size',
                progress.teamReferrals,
                progress.nextRole!.teamRequirement,
                progress.teamProgress,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricProgress(String label, int current, int required, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$current / $required',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: progress >= 100 ? Colors.green : Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (progress / 100).clamp(0.0, 1.0),
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 100 ? Colors.green : Colors.blue,
          ),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildStatsSection(PromotionProgress progress) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Direct', progress.directReferrals.toString()),
          _buildStatItem('Team', progress.teamReferrals.toString()),
          _buildStatItem('Level', progress.currentRole.level.toString()),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildReadyBanner(PromotionProgress progress) {
    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.withOpacity(0.8 + _celebrationAnimation.value * 0.2),
                Colors.amber.withOpacity(0.8 + _celebrationAnimation.value * 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.celebration,
                color: Colors.white,
                size: 24 + _celebrationAnimation.value * 4,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'READY!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'You qualify for promotion to ${progress.nextRole!.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Celebration dialog shown when user reaches 100%
class PromotionCelebrationDialog extends StatefulWidget {
  const PromotionCelebrationDialog({super.key});

  @override
  State<PromotionCelebrationDialog> createState() => _PromotionCelebrationDialogState();
}

class _PromotionCelebrationDialogState extends State<PromotionCelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: _rotationAnimation.value * 2 * 3.14159,
                    child: const Icon(
                      Icons.celebration,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🎉 Congratulations! 🎉',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You have achieved 100% progress!\nAutomatic promotion is being processed...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange,
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}