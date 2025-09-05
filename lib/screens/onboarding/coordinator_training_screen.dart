// TALOWA Coordinator Training Screen
// Specialized training materials for coordinators on group management
// Reference: in-app-communication/requirements.md - Requirements 2.2, 3.1, 9.1

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/onboarding/progress_indicator_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../help/help_center_screen.dart';

class CoordinatorTrainingScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const CoordinatorTrainingScreen({
    super.key,
    this.onCompleted,
  });

  @override
  State<CoordinatorTrainingScreen> createState() => _CoordinatorTrainingScreenState();
}

class _CoordinatorTrainingScreenState extends State<CoordinatorTrainingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  
  int _currentModuleIndex = 0;
  int _currentStepIndex = 0;
  final bool _isLoading = false;
  bool _isCompleting = false;

  final List<TrainingModule> _modules = [
    const TrainingModule(
      id: 'group_creation',
      title: 'Creating and Managing Groups',
      description: 'Learn how to create groups and organize your community',
      icon: Icons.group_add,
      color: Colors.blue,
      estimatedTime: 10,
      steps: [
        TrainingStep(
          title: 'Understanding Group Types',
          content: 'TALOWA has different types of groups for different purposes:\n\n'
                  '• Village Groups: For local community coordination\n'
                  '• Campaign Groups: For specific activism campaigns\n'
                  '• Legal Case Groups: For coordinating legal matters\n'
                  '• Emergency Groups: For crisis response',
          actionText: 'Continue',
          isInteractive: false,
        ),
        TrainingStep(
          title: 'Creating Your First Group',
          content: 'As a coordinator, you can create groups to organize your community. '
                  'Groups help you communicate with multiple people at once and coordinate activities.',
          actionText: 'Try Creating a Group',
          isInteractive: true,
        ),
        TrainingStep(
          title: 'Setting Group Permissions',
          content: 'Control who can:\n'
                  '• Add new members\n'
                  '• Send messages\n'
                  '• Share media files\n'
                  '• Access group settings',
          actionText: 'Learn More',
          isInteractive: false,
        ),
      ],
    ),
    const TrainingModule(
      id: 'member_management',
      title: 'Managing Group Members',
      description: 'Add, remove, and manage members effectively',
      icon: Icons.people,
      color: Colors.green,
      estimatedTime: 8,
      steps: [
        TrainingStep(
          title: 'Adding Members to Groups',
          content: 'You can add members to groups in several ways:\n\n'
                  '• Search by name or phone number\n'
                  '• Invite from your network\n'
                  '• Use location-based suggestions\n'
                  '• Share group invite links',
          actionText: 'Practice Adding',
          isInteractive: true,
        ),
        TrainingStep(
          title: 'Managing Member Roles',
          content: 'Assign different roles to group members:\n\n'
                  '• Admin: Full group management\n'
                  '• Moderator: Can manage messages\n'
                  '• Member: Can participate in discussions',
          actionText: 'Understand Roles',
          isInteractive: false,
        ),
        TrainingStep(
          title: 'Handling Difficult Members',
          content: 'Sometimes you need to moderate group behavior:\n\n'
                  '• Warn members about inappropriate behavior\n'
                  '• Temporarily restrict messaging\n'
                  '• Remove disruptive members\n'
                  '• Report serious violations',
          actionText: 'Learn Moderation',
          isInteractive: false,
        ),
      ],
    ),
    const TrainingModule(
      id: 'communication',
      title: 'Effective Communication',
      description: 'Best practices for group communication and broadcasting',
      icon: Icons.campaign,
      color: Colors.orange,
      estimatedTime: 12,
      steps: [
        TrainingStep(
          title: 'Broadcasting Important Messages',
          content: 'Use broadcast messages to reach multiple groups at once. '
                  'This is perfect for:\n\n'
                  '• Meeting announcements\n'
                  '• Campaign updates\n'
                  '• Legal case developments\n'
                  '• Community news',
          actionText: 'Try Broadcasting',
          isInteractive: true,
        ),
        TrainingStep(
          title: 'Emergency Communications',
          content: 'In emergencies, you can send priority messages that:\n\n'
                  '• Bypass normal message queues\n'
                  '• Send push notifications immediately\n'
                  '• Include SMS fallback\n'
                  '• Reach all members in your area',
          actionText: 'Learn Emergency Features',
          isInteractive: false,
        ),
        TrainingStep(
          title: 'Communication Best Practices',
          content: 'Follow these guidelines for effective communication:\n\n'
                  '• Keep messages clear and concise\n'
                  '• Use appropriate urgency levels\n'
                  '• Include relevant details and context\n'
                  '• Follow up on important messages',
          actionText: 'Review Guidelines',
          isInteractive: false,
        ),
      ],
    ),
    const TrainingModule(
      id: 'privacy_security',
      title: 'Privacy and Security',
      description: 'Protecting your community and sensitive information',
      icon: Icons.security,
      color: Colors.red,
      estimatedTime: 15,
      steps: [
        TrainingStep(
          title: 'Understanding Message Encryption',
          content: 'All TALOWA messages are encrypted, but as a coordinator you should understand:\n\n'
                  '• End-to-end encryption protects message content\n'
                  '• Anonymous messaging protects sender identity\n'
                  '• Legal case discussions use highest security\n'
                  '• Group settings control encryption levels',
          actionText: 'Learn About Encryption',
          isInteractive: false,
        ),
        TrainingStep(
          title: 'Handling Anonymous Reports',
          content: 'Anonymous reports help protect vulnerable community members:\n\n'
                  '• Reports come with unique case IDs\n'
                  '• Sender identity is completely protected\n'
                  '• You can respond without knowing who sent it\n'
                  '• Location is generalized for privacy',
          actionText: 'Practice Handling Reports',
          isInteractive: true,
        ),
        TrainingStep(
          title: 'Protecting Sensitive Information',
          content: 'As a coordinator, you handle sensitive information:\n\n'
                  '• Never share personal details without permission\n'
                  '• Use secure channels for legal discussions\n'
                  '• Be careful about screenshots and forwarding\n'
                  '• Report security concerns immediately',
          actionText: 'Review Security Practices',
          isInteractive: false,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _modules.length, vsync: this);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  TrainingModule get _currentModule => _modules[_currentModuleIndex];
  TrainingStep get _currentStep => _currentModule.steps[_currentStepIndex];

  void _nextStep() {
    if (_currentStepIndex < _currentModule.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _nextModule();
    }
  }

  void _nextModule() {
    if (_currentModuleIndex < _modules.length - 1) {
      setState(() {
        _currentModuleIndex++;
        _currentStepIndex = 0;
      });
      _tabController.animateTo(_currentModuleIndex);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTraining();
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
    } else if (_currentModuleIndex > 0) {
      setState(() {
        _currentModuleIndex--;
        _currentStepIndex = _modules[_currentModuleIndex].steps.length - 1;
      });
      _tabController.animateTo(_currentModuleIndex);
    }
  }

  Future<void> _completeTraining() async {
    setState(() {
      _isCompleting = true;
    });

    try {
      await OnboardingService.markGroupManagementTutorialCompleted();
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('🎉 Training Complete!'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Congratulations! You have completed the coordinator training program.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'You are now ready to effectively manage groups and lead your community in the fight for land rights.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpCenterScreen(),
                    ),
                  );
                },
                child: const Text('View Help Center'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.onCompleted != null) {
                    widget.onCompleted!();
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.talowaGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Leading'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing training: $e');
    } finally {
      setState(() {
        _isCompleting = false;
      });
    }
  }

  void _handleStepAction() {
    if (_currentStep.isInteractive) {
      _showInteractiveDemo();
    } else {
      _nextStep();
    }
  }

  void _showInteractiveDemo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Interactive: ${_currentStep.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _currentModule.icon,
              size: 48,
              color: _currentModule.color,
            ),
            const SizedBox(height: 16),
            const Text(
              'In the full app, this would open the actual feature for hands-on practice.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You would practice: ${_currentStep.title.toLowerCase()}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
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
            child: const Text('Continue Training'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading coordinator training...'),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Coordinator Training',
          style: TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (index) {
            setState(() {
              _currentModuleIndex = index;
              _currentStepIndex = 0;
            });
          },
          tabs: _modules.map((module) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(module.icon, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    module.title,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // Module header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _currentModule.color.withOpacity(0.1),
                  _currentModule.color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _currentModule.icon,
                      color: _currentModule.color,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentModule.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _currentModule.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_currentModule.estimatedTime} min',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ProgressIndicatorWidget(
                  currentStep: _currentStepIndex,
                  totalSteps: _currentModule.steps.length,
                  color: _currentModule.color,
                ),
              ],
            ),
          ),

          // Training content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStepIndex = index;
                });
              },
              itemCount: _currentModule.steps.length,
              itemBuilder: (context, index) {
                final step = _currentModule.steps[index];
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Step content
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              step.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(
                                step.content,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.secondaryText,
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleStepAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentModule.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (step.isInteractive) ...[
                                const Icon(Icons.touch_app, size: 20),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                step.actionText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
                TextButton(
                  onPressed: (_currentModuleIndex > 0 || _currentStepIndex > 0) 
                      ? _previousStep 
                      : null,
                  child: const Text('Previous'),
                ),
                Text(
                  'Module ${_currentModuleIndex + 1} of ${_modules.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                ElevatedButton(
                  onPressed: _isCompleting ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentModule.color,
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
                          (_currentModuleIndex == _modules.length - 1 && 
                           _currentStepIndex == _currentModule.steps.length - 1)
                              ? 'Complete'
                              : 'Next',
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Training Module Model
class TrainingModule {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int estimatedTime;
  final List<TrainingStep> steps;

  const TrainingModule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.estimatedTime,
    required this.steps,
  });
}

// Training Step Model
class TrainingStep {
  final String title;
  final String content;
  final String actionText;
  final bool isInteractive;

  const TrainingStep({
    required this.title,
    required this.content,
    required this.actionText,
    required this.isInteractive,
  });
}

