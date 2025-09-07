// TALOWA More Screen - Additional Features & Settings
// Reference: complete-app-structure.md - More Tab

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/more/profile_summary_card.dart';
import '../../widgets/more/feature_section_card.dart';
import '../../widgets/common/loading_widget.dart';
// Admin entry points removed from More screen
// import '../../widgets/more/admin_access_widget.dart';
// import '../../routes/admin_route.dart';
import '../settings/language_settings_screen.dart';
import '../help/help_center_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/coordinator_training_screen.dart';
// Removed enterprise Security Center access for end-users per product requirements
import '../home/payments_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _isLoading = false;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'More',
          style: TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.talowaGreen,
        elevation: AppTheme.elevationLow,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _openAppSettings,
            tooltip: 'App Settings',
          ),
          IconButton(
            icon: const Icon(Icons.analytics, color: Colors.white),
            onPressed: _openAnalytics,
            tooltip: 'Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.help, color: Colors.white),
            onPressed: _openHelp,
            tooltip: 'Help & Support',
          ),
          // AI Test entry removed per Option B (retain file, remove references)
          // Hidden admin access button (long press)
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {}, // Regular tap does nothing
            onLongPress: null,
            tooltip: 'More Options (Long press for admin)',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading profile...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Summary
                  if (_userProfile != null)
                    ProfileSummaryCard(
                      userProfile: _userProfile!,
                      onTap: _openFullProfile,
                    ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Admin Access (shows only for admin/coordinator users)
                  // const AdminAccessWidget(),

                  // Cases & Land Records Section
                  FeatureSectionCard(
                    title: 'Cases & Land Records',
                    icon: Icons.gavel,
                    iconColor: AppTheme.legalBlue,
                    items: [
                      FeatureItem(
                        title: 'My Land Records',
                        subtitle: '${_userProfile?.landRecords ?? 0} plots',
                        icon: Icons.landscape,
                        onTap: _openLandRecords,
                      ),
                      FeatureItem(
                        title: 'Legal Cases',
                        subtitle: '${_userProfile?.activeCases ?? 0} active',
                        icon: Icons.balance,
                        onTap: _openLegalCases,
                      ),
                      FeatureItem(
                        title: 'Report Issue',
                        subtitle: 'Report land problems',
                        icon: Icons.report_problem,
                        onTap: _reportIssue,
                      ),
                      FeatureItem(
                        title: 'Legal Support',
                        subtitle: 'Get legal help',
                        icon: Icons.support_agent,
                        onTap: _getLegalSupport,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Analytics & Reports Section
                  FeatureSectionCard(
                    title: 'Analytics & Reports',
                    icon: Icons.analytics,
                    iconColor: AppTheme.warningOrange,
                    items: [
                      FeatureItem(
                        title: 'Network Analytics',
                        subtitle: 'Growth and performance',
                        icon: Icons.trending_up,
                        onTap: _openNetworkAnalytics,
                      ),
                      FeatureItem(
                        title: 'Goal Progress',
                        subtitle: '${(_userProfile?.goalProgress ?? 0 * 100).toInt()}% to next rank',
                        icon: Icons.emoji_events,
                        onTap: _openGoalProgress,
                      ),
                      FeatureItem(
                        title: 'Engagement Score',
                        subtitle: '${_userProfile?.engagementScore ?? 0}/10',
                        icon: Icons.favorite,
                        onTap: _openEngagementDetails,
                      ),
                      FeatureItem(
                        title: 'Generate Report',
                        subtitle: 'Export your data',
                        icon: Icons.file_download,
                        onTap: _generateReport,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // App Settings Section
                  FeatureSectionCard(
                    title: 'App Settings',
                    icon: Icons.settings,
                    iconColor: AppTheme.secondaryText,
                    items: [
                      FeatureItem(
                        title: 'Notifications',
                        subtitle: 'Push, SMS, email settings',
                        icon: Icons.notifications,
                        onTap: _openNotificationSettings,
                      ),
                      FeatureItem(
                        title: 'Privacy & Security',
                        subtitle: 'Contact visibility, encryption',
                        icon: Icons.privacy_tip,
                        onTap: _openPrivacySettings,
                      ),
                      // Enterprise Security Center removed from More screen for end-users
                      FeatureItem(
                        title: 'Language & Region',
                        subtitle: 'English, à¤¹à¤¿à¤‚à¤¦à¥€, à°¤à±†à°²à±à°—à±',
                        icon: Icons.language,
                        onTap: _openLanguageSettings,
                      ),
                      FeatureItem(
                        title: 'Data & Storage',
                        subtitle: 'Offline, sync, usage',
                        icon: Icons.storage,
                        onTap: _openDataSettings,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Support & Help Section
                  FeatureSectionCard(
                    title: 'Support & Help',
                    icon: Icons.help,
                    iconColor: AppTheme.legalBlue,
                    items: [
                      FeatureItem(
                        title: 'Help Center',
                        subtitle: 'Comprehensive help and tutorials',
                        icon: Icons.help_center,
                        onTap: _openKnowledgeCenter,
                      ),
                      FeatureItem(
                        title: 'Messaging Tutorial',
                        subtitle: 'Learn messaging features',
                        icon: Icons.message,
                        onTap: _openMessagingTutorial,
                      ),
                      FeatureItem(
                        title: 'Voice Calling Tutorial',
                        subtitle: 'Learn calling features',
                        icon: Icons.call,
                        onTap: _openCallingTutorial,
                      ),
                      if (_userProfile?.role == AppConstants.roleVillageCoordinator ||
                          _userProfile?.role == AppConstants.roleMandalCoordinator ||
                          _userProfile?.role == AppConstants.roleDistrictCoordinator)
                        FeatureItem(
                          title: 'Coordinator Training',
                          subtitle: 'Group management training',
                          icon: Icons.admin_panel_settings,
                          onTap: _openCoordinatorTraining,
                        ),
                      FeatureItem(
                        title: 'Emergency Contacts',
                        subtitle: 'Police, legal aid, coordinators',
                        icon: Icons.emergency,
                        onTap: _openEmergencyContacts,
                      ),
                      FeatureItem(
                        title: 'Support TALOWA',
                        subtitle: 'Optional contribution to the movement',
                        icon: Icons.favorite,
                        onTap: _supportTalowa,
                      ),
                      FeatureItem(
                        title: 'Contact Support',
                        subtitle: 'Get help with the app',
                        icon: Icons.support,
                        onTap: _contactSupport,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Achievements & Sharing Section
                  FeatureSectionCard(
                    title: 'Achievements & Sharing',
                    icon: Icons.star,
                    iconColor: AppTheme.warningOrange,
                    items: [
                      FeatureItem(
                        title: 'My Achievements',
                        subtitle: '${_userProfile?.achievements ?? 0} unlocked',
                        icon: Icons.emoji_events,
                        onTap: _openAchievements,
                      ),
                      FeatureItem(
                        title: 'Share TALOWA App',
                        subtitle: 'Invite others to join',
                        icon: Icons.share,
                        onTap: _shareApp,
                      ),
                      FeatureItem(
                        title: 'Rate App',
                        subtitle: 'Rate us on app store',
                        icon: Icons.star_rate,
                        onTap: _rateApp,
                      ),
                      FeatureItem(
                        title: 'About TALOWA',
                        subtitle: 'Mission, vision, team',
                        icon: Icons.info,
                        onTap: _openAbout,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingXLarge),

                  // App Version and Legal
                  _buildAppInfoSection(),


                ],
              ),
            ),
    );
  }

  Widget _buildAppInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.eco,
                  color: AppTheme.talowaGreen,
                  size: 32,
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: AppTheme.heading2Style.copyWith(
                          color: AppTheme.talowaGreen,
                        ),
                      ),
                      const Text(
                        AppConstants.appFullName,
                        style: AppTheme.captionStyle,
                      ),
                      const Text(
                        'Version ${AppConstants.appVersion}',
                        style: AppTheme.captionStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _openPrivacyPolicy,
                    child: const Text('Privacy Policy', textAlign: TextAlign.center),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _openTermsOfService,
                    child: const Text('Terms of Service', textAlign: TextAlign.center),
                  ),
                ),
                TextButton(
                  onPressed: _openLicenses,
                  child: const Text('Licenses'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Data Loading
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement actual API call
      await Future.delayed(const Duration(seconds: 1));

      _userProfile = UserProfile(
        name: 'Ravi Kumar',
        role: AppConstants.roleVillageCoordinator,
        memberId: 'MBR-20240115-0123',
        phoneNumber: '+91 9876543210',
        location: 'Kondapur Village',
        landRecords: 3,
        activeCases: 2,
        teamSize: 47,
        directReferrals: 12,
        goalProgress: 0.63,
        engagementScore: 8.2,
        achievements: 5,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading user profile: $e');
    }
  }

  // Action Methods
  void _openAppSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                _openNotificationSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacy'),
              onTap: () {
                Navigator.pop(context);
                _openPrivacySettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              onTap: () {
                Navigator.pop(context);
                _openLanguageSettings();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openAnalytics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Usage Statistics:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('â€¢ Daily Active Users: 1,234'),
            Text('â€¢ Posts Created: 567'),
            Text('â€¢ Messages Sent: 2,345'),
            Text('â€¢ Network Growth: +15%'),
            SizedBox(height: 16),
            Text('Your Activity:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('â€¢ Posts: 12'),
            Text('â€¢ Likes Received: 89'),
            Text('â€¢ Comments: 34'),
            Text('â€¢ Referrals: 5'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpCenterScreen(),
      ),
    );
  }

  void _openFullProfile() {
    debugPrint('Opening full profile');
  }

  void _openLandRecords() {
    debugPrint('Opening land records');
  }

  void _openLegalCases() {
    debugPrint('Opening legal cases');
  }

  void _reportIssue() {
    debugPrint('Reporting issue');
  }

  void _getLegalSupport() {
    debugPrint('Getting legal support');
  }

  void _openNetworkAnalytics() {
    debugPrint('Opening network analytics');
  }

  void _openGoalProgress() {
    debugPrint('Opening goal progress');
  }

  void _openEngagementDetails() {
    debugPrint('Opening engagement details');
  }

  void _generateReport() {
    debugPrint('Generating report');
  }

  void _openNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications'),
              value: true,
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Push notifications ${value ? 'enabled' : 'disabled'}')),
                );
              },
            ),
            SwitchListTile(
              title: const Text('SMS Notifications'),
              subtitle: const Text('Receive SMS alerts'),
              value: false,
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('SMS notifications ${value ? 'enabled' : 'disabled'}')),
                );
              },
            ),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive email updates'),
              value: true,
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Email notifications ${value ? 'enabled' : 'disabled'}')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Profile Visibility'),
              subtitle: const Text('Make profile visible to others'),
              value: true,
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Profile ${value ? 'visible' : 'hidden'}')),
                );
              },
            ),
            SwitchListTile(
              title: const Text('Location Sharing'),
              subtitle: const Text('Share location with network'),
              value: false,
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Location sharing ${value ? 'enabled' : 'disabled'}')),
                );
              },
            ),
            SwitchListTile(
              title: const Text('Contact Visibility'),
              subtitle: const Text('Allow others to see contact info'),
              value: true,
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Contact visibility ${value ? 'enabled' : 'disabled'}')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // void _openSecurityCenter() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => SecurityScreen(
  //         isAdminMode: false, // Regular users get view-only mode
  //       ),
  //     ),
  //   );
  // }

  void _openLanguageSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LanguageSettingsScreen(),
      ),
    );
  }

  void _openDataSettings() {
    debugPrint('Opening data settings');
  }

  void _openKnowledgeCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpCenterScreen(),
      ),
    );
  }

  void _openEmergencyContacts() {
    debugPrint('Opening emergency contacts');
  }

  void _supportTalowa() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaymentsScreen(),
      ),
    );
  }

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Get help with your TALOWA account:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Support'),
              subtitle: const Text('support@talowa.org'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening email client...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone Support'),
              subtitle: const Text('+91-800-TALOWA'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling support...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Live Chat'),
              subtitle: const Text('Chat with our team'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Starting live chat...')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openFAQ() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frequently Asked Questions'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView(
            children: const [
              ExpansionTile(
                title: Text('How do I register my land?'),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('To register your land, go to the Land Records section and follow the step-by-step guide. You\'ll need your survey number, village details, and ownership documents.'),
                  ),
                ],
              ),
              ExpansionTile(
                title: Text('How does the referral system work?'),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Share your referral code with others. When they join using your code, they become part of your network. You can track your referrals in the Network tab.'),
                  ),
                ],
              ),
              ExpansionTile(
                title: Text('How do I report land grabbing?'),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Use the Emergency button on the Home screen or go to More > Emergency Contacts. You can report incidents anonymously with photo evidence.'),
                  ),
                ],
              ),
              ExpansionTile(
                title: Text('How do I get legal help?'),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Access our legal support network through the Legal Cases section. We connect you with lawyers specializing in land rights.'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openAchievements() {
    debugPrint('Opening achievements');
  }

  void _shareApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share TALOWA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Help others join the land rights movement!'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.talowaGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Join TALOWA - Fighting for Land Rights Together!\n\nDownload: https://talowa.org/download',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening WhatsApp...')),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('WhatsApp'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Link'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _rateApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate TALOWA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How would you rate your experience with TALOWA?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Thank you for rating us ${index + 1} stars!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your feedback helps us improve TALOWA for everyone!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening app store...')),
              );
            },
            child: const Text('Rate on Store'),
          ),
        ],
      ),
    );
  }

  void _openAbout() {
    debugPrint('Opening about');
  }

  void _openPrivacyPolicy() {
    debugPrint('Opening privacy policy');
  }

  void _openTermsOfService() {
    debugPrint('Opening terms of service');
  }

  void _openLicenses() {
    debugPrint('Opening licenses');
  }

  // void _showAdminAccessDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Row(
  //         children: [
  //           Icon(Icons.admin_panel_settings, color: Colors.red),
  //           SizedBox(width: 8),
  //           Text('Admin Access'),
  //         ],
  //       ),
  //       content: const Text(
  //         'Access the secure admin portal with Firebase Authentication and role-based access control.',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             AdminRoute.navigateToAdmin(context);
  //           },
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.red[800],
  //             foregroundColor: Colors.white,
  //           ),
  //           child: const Text('Secure Admin Portal'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  // void _showAdminAccessDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Row(
  //         children: [
  //           Icon(Icons.admin_panel_settings, color: Colors.red),
  //           SizedBox(width: 8),
  //           Text('Admin Access'),
  //         ],
  //       ),
  //       content: const Text(
  //         'Access the secure admin portal with Firebase Authentication and role-based access control.',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             AdminRoute.navigateToAdmin(context);
  //           },
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.red[800],
  //             foregroundColor: Colors.white,
  //           ),
  //           child: const Text('Secure Admin Portal'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Tutorial Methods
  void _openMessagingTutorial() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OnboardingScreen(
          tutorialType: 'messaging',
        ),
      ),
    );
  }

  void _openCallingTutorial() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OnboardingScreen(
          tutorialType: 'calling',
        ),
      ),
    );
  }

  void _openCoordinatorTraining() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CoordinatorTrainingScreen(),
      ),
    );
  }
}

// Data Models
class UserProfile {
  final String name;
  final String role;
  final String memberId;
  final String phoneNumber;
  final String location;
  final int landRecords;
  final int activeCases;
  final int teamSize;
  final int directReferrals;
  final double goalProgress;
  final double engagementScore;
  final int achievements;

  UserProfile({
    required this.name,
    required this.role,
    required this.memberId,
    required this.phoneNumber,
    required this.location,
    required this.landRecords,
    required this.activeCases,
    required this.teamSize,
    required this.directReferrals,
    required this.goalProgress,
    required this.engagementScore,
    required this.achievements,
  });
}

class FeatureItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}
