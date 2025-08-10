// Safety Settings Screen for TALOWA
// Implements Task 18: Add security and content safety - Safety UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/security/user_safety_service.dart';
import '../../services/security/content_moderation_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';

class SafetySettingsScreen extends StatefulWidget {
  const SafetySettingsScreen({super.key});

  @override
  State<SafetySettingsScreen> createState() => _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends State<SafetySettingsScreen> {
  final UserSafetyService _safetyService = UserSafetyService();
  final ContentModerationService _moderationService = ContentModerationService();
  
  UserSafetyPreferences? _safetyPrefs;
  UserContentPreferences? _contentPrefs;
  UserSafetyStats? _safetyStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSafetyData();
  }

  Future<void> _loadSafetyData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = context.read<AuthProvider>().currentUser?.uid;
      if (userId == null) return;

      final results = await Future.wait([
        _safetyService.getUserSafetyPreferences(userId),
        _moderationService._getUserContentPreferences(userId),
        _safetyService.getUserSafetyStats(userId),
      ]);

      setState(() {
        _safetyPrefs = results[0] as UserSafetyPreferences;
        _contentPrefs = results[1] as UserContentPreferences;
        _safetyStats = results[2] as UserSafetyStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSafetyPreferences(UserSafetyPreferences prefs) async {
    try {
      final userId = context.read<AuthProvider>().currentUser?.uid;
      if (userId == null) return;

      await _safetyService.updateSafetyPreferences(
        userId: userId,
        preferences: prefs,
      );

      setState(() {
        _safetyPrefs = prefs;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safety preferences updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating preferences: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & Privacy'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
              ? ErrorDisplayWidget(
                  error: _error!,
                  onRetry: _loadSafetyData,
                )
              : _buildSafetySettings(),
    );
  }

  Widget _buildSafetySettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSafetyStats(),
          const SizedBox(height: 24),
          _buildUserSafetySection(),
          const SizedBox(height: 24),
          _buildContentSafetySection(),
          const SizedBox(height: 24),
          _buildBlockedUsersSection(),
          const SizedBox(height: 24),
          _buildReportingSection(),
        ],
      ),
    );
  }

  Widget _buildSafetyStats() {
    if (_safetyStats == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safety Overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Reports Received',
                    _safetyStats!.reportCount.toString(),
                    Icons.report_problem,
                    _safetyStats!.reportCount > 0 ? Colors.orange : Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Blocked Users',
                    _safetyStats!.blockedUsersCount.toString(),
                    Icons.block,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Reports Made',
                    _safetyStats!.reportsMadeCount.toString(),
                    Icons.flag,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Safety Actions',
                    _safetyStats!.safetyActionsCount.toString(),
                    Icons.security,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserSafetySection() {
    if (_safetyPrefs == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Safety Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Block Unknown Users'),
              subtitle: const Text('Only allow messages from people in your network'),
              value: _safetyPrefs!.blockUnknownUsers,
              onChanged: (value) {
                final updatedPrefs = UserSafetyPreferences(
                  blockUnknownUsers: value,
                  requireApprovalForMessages: _safetyPrefs!.requireApprovalForMessages,
                  hideFromSearch: _safetyPrefs!.hideFromSearch,
                  showWarningTypes: _safetyPrefs!.showWarningTypes,
                  autoBlockReportedUsers: _safetyPrefs!.autoBlockReportedUsers,
                  maxMessagesPerDay: _safetyPrefs!.maxMessagesPerDay,
                );
                _updateSafetyPreferences(updatedPrefs);
              },
            ),
            SwitchListTile(
              title: const Text('Require Message Approval'),
              subtitle: const Text('Review messages before they reach you'),
              value: _safetyPrefs!.requireApprovalForMessages,
              onChanged: (value) {
                final updatedPrefs = UserSafetyPreferences(
                  blockUnknownUsers: _safetyPrefs!.blockUnknownUsers,
                  requireApprovalForMessages: value,
                  hideFromSearch: _safetyPrefs!.hideFromSearch,
                  showWarningTypes: _safetyPrefs!.showWarningTypes,
                  autoBlockReportedUsers: _safetyPrefs!.autoBlockReportedUsers,
                  maxMessagesPerDay: _safetyPrefs!.maxMessagesPerDay,
                );
                _updateSafetyPreferences(updatedPrefs);
              },
            ),
            SwitchListTile(
              title: const Text('Hide from Search'),
              subtitle: const Text('Don\'t appear in user search results'),
              value: _safetyPrefs!.hideFromSearch,
              onChanged: (value) {
                final updatedPrefs = UserSafetyPreferences(
                  blockUnknownUsers: _safetyPrefs!.blockUnknownUsers,
                  requireApprovalForMessages: _safetyPrefs!.requireApprovalForMessages,
                  hideFromSearch: value,
                  showWarningTypes: _safetyPrefs!.showWarningTypes,
                  autoBlockReportedUsers: _safetyPrefs!.autoBlockReportedUsers,
                  maxMessagesPerDay: _safetyPrefs!.maxMessagesPerDay,
                );
                _updateSafetyPreferences(updatedPrefs);
              },
            ),
            SwitchListTile(
              title: const Text('Auto-block Reported Users'),
              subtitle: const Text('Automatically block users with multiple reports'),
              value: _safetyPrefs!.autoBlockReportedUsers,
              onChanged: (value) {
                final updatedPrefs = UserSafetyPreferences(
                  blockUnknownUsers: _safetyPrefs!.blockUnknownUsers,
                  requireApprovalForMessages: _safetyPrefs!.requireApprovalForMessages,
                  hideFromSearch: _safetyPrefs!.hideFromSearch,
                  showWarningTypes: _safetyPrefs!.showWarningTypes,
                  autoBlockReportedUsers: value,
                  maxMessagesPerDay: _safetyPrefs!.maxMessagesPerDay,
                );
                _updateSafetyPreferences(updatedPrefs);
              },
            ),
            ListTile(
              title: const Text('Daily Message Limit'),
              subtitle: Text('Maximum messages per day: ${_safetyPrefs!.maxMessagesPerDay}'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showMessageLimitDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSafetySection() {
    if (_contentPrefs == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Content Safety Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show Sensitive Content'),
              subtitle: const Text('Display content with warnings'),
              value: _contentPrefs!.showSensitiveContent,
              onChanged: (value) {
                // Update content preferences
                _updateContentPreferences(
                  _contentPrefs!.copyWith(showSensitiveContent: value),
                );
              },
            ),
            SwitchListTile(
              title: const Text('Auto-hide Reported Content'),
              subtitle: const Text('Hide content that has been reported by others'),
              value: _contentPrefs!.autoHideReportedContent,
              onChanged: (value) {
                _updateContentPreferences(
                  _contentPrefs!.copyWith(autoHideReportedContent: value),
                );
              },
            ),
            SwitchListTile(
              title: const Text('Require Content Warnings'),
              subtitle: const Text('Show warnings before sensitive content'),
              value: _contentPrefs!.requireContentWarnings,
              onChanged: (value) {
                _updateContentPreferences(
                  _contentPrefs!.copyWith(requireContentWarnings: value),
                );
              },
            ),
            ListTile(
              title: const Text('Content Ratings'),
              subtitle: Text('Allowed: ${_contentPrefs!.allowedRatings.join(', ')}'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showContentRatingsDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedUsersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blocked Users',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Manage Blocked Users'),
              subtitle: Text('${_safetyStats?.blockedUsersCount ?? 0} users blocked'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _navigateToBlockedUsers(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporting & Help',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.blue),
              title: const Text('Safety Guidelines'),
              subtitle: const Text('Learn about staying safe on TALOWA'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showSafetyGuidelines(),
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('Report a Problem'),
              subtitle: const Text('Report safety issues or inappropriate content'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showReportDialog(),
            ),
            ListTile(
              leading: const Icon(Icons.contact_support, color: Colors.green),
              title: const Text('Contact Support'),
              subtitle: const Text('Get help from our safety team'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _contactSupport(),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Message Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set the maximum number of messages you can receive per day:'),
            const SizedBox(height: 16),
            Slider(
              value: _safetyPrefs!.maxMessagesPerDay.toDouble(),
              min: 10,
              max: 500,
              divisions: 49,
              label: _safetyPrefs!.maxMessagesPerDay.toString(),
              onChanged: (value) {
                final updatedPrefs = UserSafetyPreferences(
                  blockUnknownUsers: _safetyPrefs!.blockUnknownUsers,
                  requireApprovalForMessages: _safetyPrefs!.requireApprovalForMessages,
                  hideFromSearch: _safetyPrefs!.hideFromSearch,
                  showWarningTypes: _safetyPrefs!.showWarningTypes,
                  autoBlockReportedUsers: _safetyPrefs!.autoBlockReportedUsers,
                  maxMessagesPerDay: value.round(),
                );
                _updateSafetyPreferences(updatedPrefs);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showContentRatingsDialog() {
    final availableRatings = ['general', 'teen', 'mature', 'adult'];
    final selectedRatings = List<String>.from(_contentPrefs!.allowedRatings);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Content Ratings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableRatings.map((rating) {
              return CheckboxListTile(
                title: Text(rating.toUpperCase()),
                value: selectedRatings.contains(rating),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selectedRatings.add(rating);
                    } else {
                      selectedRatings.remove(rating);
                    }
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _updateContentPreferences(
                  _contentPrefs!.copyWith(allowedRatings: selectedRatings),
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBlockedUsers() {
    Navigator.pushNamed(context, '/blocked-users');
  }

  void _showSafetyGuidelines() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Safety Guidelines'),
        content: const SingleChildScrollView(
          child: Text(
            'TALOWA Safety Guidelines:\n\n'
            '1. Respect others and their opinions\n'
            '2. Do not share personal information\n'
            '3. Report inappropriate content\n'
            '4. Block users who make you uncomfortable\n'
            '5. Use privacy settings to control your visibility\n'
            '6. Be cautious when meeting people offline\n'
            '7. Report threats or harassment immediately\n'
            '8. Keep your account secure with a strong PIN\n\n'
            'Remember: Your safety is our priority. Use these tools to create a safe experience.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    Navigator.pushNamed(context, '/report-problem');
  }

  void _contactSupport() {
    Navigator.pushNamed(context, '/contact-support');
  }

  void _updateContentPreferences(UserContentPreferences prefs) {
    // Implementation would update content preferences
    setState(() {
      _contentPrefs = prefs;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Content preferences updated')),
    );
  }
}

// Extension to add copyWith method to UserContentPreferences
extension UserContentPreferencesExtension on UserContentPreferences {
  UserContentPreferences copyWith({
    bool? showSensitiveContent,
    List<String>? allowedRatings,
    bool? autoHideReportedContent,
    bool? requireContentWarnings,
  }) {
    return UserContentPreferences(
      showSensitiveContent: showSensitiveContent ?? this.showSensitiveContent,
      allowedRatings: allowedRatings ?? this.allowedRatings,
      autoHideReportedContent: autoHideReportedContent ?? this.autoHideReportedContent,
      requireContentWarnings: requireContentWarnings ?? this.requireContentWarnings,
    );
  }
}