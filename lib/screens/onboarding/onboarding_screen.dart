// TALOWA Onboarding Screen
// Interactive tutorial for messaging and calling features
// Reference: in-app-communication/requirements.md - Requirements 2.2, 3.1, 9.1

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/onboarding/onboarding_step.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/onboarding/onboarding_step_widget.dart';
import '../../widgets/onboarding/progress_indicator_widget.dart';
import '../../widgets/common/loading_widget.dart';

class OnboardingScreen extends StatefulWidget {
  final String tutorialType; // 'messaging', 'calling', 'group_management'
  final VoidCallback? onCompleted;

  const OnboardingScreen({
    super.key,
    required this.tutorialType,
    this.onCompleted,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<OnboardingStep> _steps = [];
  int _currentStepIndex = 0;
  bool _isLoading = true;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _loadTutorialSteps();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTutorialSteps() async {
    setState(() {
      _isLoading = true;
    });

    try {
      switch (widget.tutorialType) {
        case 'messaging':
          _steps = OnboardingService.getMessagingTutorialSteps();
          break;
        case 'calling':
          _steps = OnboardingService.getCallingTutorialSteps();
          break;
        case 'group_management':
          _steps = OnboardingService.getGroupManagementTutorialSteps();
          break;
        default:
          _steps = OnboardingService.getMessagingTutorialSteps();
      }

      setState(() {
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading tutorial steps: $e');
    }
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipTutorial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Tutorial?'),
        content: const Text(
          'Are you sure you want to skip this tutorial? You can always access it later from the help section.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Tutorial'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeTutorial();
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTutorial() async {
    setState(() {
      _isCompleting = true;
    });

    try {
      // Mark tutorial as completed
      switch (widget.tutorialType) {
        case 'messaging':
          await OnboardingService.markMessagingTutorialCompleted();
          break;
        case 'calling':
          await OnboardingService.markCallingTutorialCompleted();
          break;
        case 'group_management':
          await OnboardingService.markGroupManagementTutorialCompleted();
          break;
      }

      // Show completion message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getTutorialTitle()} tutorial completed!'),
            backgroundColor: AppTheme.talowaGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Call completion callback or navigate back
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error completing tutorial: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error completing tutorial. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isCompleting = false;
      });
    }
  }

  String _getTutorialTitle() {
    switch (widget.tutorialType) {
      case 'messaging':
        return 'Messaging';
      case 'calling':
        return 'Voice Calling';
      case 'group_management':
        return 'Group Management';
      default:
        return 'Tutorial';
    }
  }

  void _handleStepAction(OnboardingStep step) {
    if (step.isInteractive) {
      // Handle interactive steps
      _showInteractiveDemo(step);
    } else {
      _nextStep();
    }
  }

  void _showInteractiveDemo(OnboardingStep step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Try: ${step.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              step.iconData,
              size: 48,
              color: AppTheme.talowaGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'This would normally open the ${step.title.toLowerCase()} interface for you to try.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'In the full app, you would be guided through the actual feature.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextStep();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading tutorial...'),
      );
    }

    if (_steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_getTutorialTitle()),
          backgroundColor: AppTheme.talowaGreen,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Tutorial not available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Please try again later or contact support.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_getTutorialTitle()),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skipTutorial,
            child: const Text(
              'Skip',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.talowaGreen,
              child: ProgressIndicatorWidget(
                currentStep: _currentStepIndex,
                totalSteps: _steps.length,
                color: Colors.white,
              ),
            ),

            // Tutorial content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentStepIndex = index;
                  });
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return OnboardingStepWidget(
                    step: _steps[index],
                    onAction: () => _handleStepAction(_steps[index]),
                  );
                },
              ),
            ),

            // Navigation controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous button
                  TextButton(
                    onPressed: _currentStepIndex > 0 ? _previousStep : null,
                    child: const Text('Previous'),
                  ),

                  // Step indicator
                  Text(
                    '${_currentStepIndex + 1} of ${_steps.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),

                  // Next/Complete button
                  ElevatedButton(
                    onPressed: _isCompleting ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.talowaGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: _isCompleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _currentStepIndex == _steps.length - 1 ? 'Complete' : 'Next',
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
