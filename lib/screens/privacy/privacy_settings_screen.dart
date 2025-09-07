// Privacy Settings Screen for TALOWA Users
// Implements Task 17: Privacy protection system - User Interface

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/social_feed/privacy_protection_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final PrivacyProtectionService _privacyService = PrivacyProtectionService();
  
  Map<String, dynamic> _preferences = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacyPreferences();
  }

  Future<void> _loadPrivacyPreferences() async {
    try {
      final preferences = await _privacyService.getUserPrivacyPreferences('current_user_id');
      setState(() {
        _preferences = preferences;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading privacy settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: GestureDetector(
        onHorizontalDragStart: (details) => _showSwipeProtectionMessage(),
        onPanStart: (details) => _showSwipeProtectionMessage(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Privacy Settings'),
            backgroundColor: AppTheme.talowaGreen,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            leading: Navigator.of(context).canPop() ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handleBackNavigation,
            ) : null,
            actions: [
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: _savePreferences,
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPrivacyHeader(),
                  const SizedBox(height: 24),
                  _buildProfileVisibilitySection(),
                  const SizedBox(height: 24),
                  _buildContactVisibilitySection(),
                  const SizedBox(height: 24),
                  _buildPostPrivacySection(),
                  const SizedBox(height: 24),
                  _buildCommunicationSection(),
                  const SizedBox(height: 24),
                  _buildDataProcessingSection(),
                  const SizedBox(height: 24),
                  _buildAdvancedSection(),
                ],
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildPrivacyHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.talowaGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.talowaGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.privacy_tip, color: AppTheme.talowaGreen, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Privacy Matters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Control who can see your information and how it\'s used',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TALOWA follows strict privacy guidelines to protect your personal information.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileVisibilitySection() {
    return _buildSection(
      title: 'Profile Visibility',
      icon: Icons.person,
      description: 'Control who can see your profile information',
      children: [
        _buildPrivacyDropdown(
          label: 'Profile Visibility',
          value: _preferences['profileVisibility'] ?? PrivacyProtectionService.privacyNetwork,
          onChanged: (value) => _updatePreference('profileVisibility', value),
          options: const [
            {'value': PrivacyProtectionService.privacyPublic, 'label': 'Public - Everyone can see'},
            {'value': PrivacyProtectionService.privacyNetwork, 'label': 'Network - Only my network'},
            {'value': PrivacyProtectionService.privacyDirectReferrals, 'label': 'Direct Referrals - Only direct referrals'},
            {'value': PrivacyProtectionService.privacyCoordinators, 'label': 'Coordinators - Only coordinators'},
            {'value': PrivacyProtectionService.privacyPrivate, 'label': 'Private - Only me'},
          ],
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          title: 'Show Online Status',
          subtitle: 'Let others see when you\'re online',
          value: _preferences['showOnlineStatus'] ?? true,
          onChanged: (value) => _updatePreference('showOnlineStatus', value),
        ),
        _buildSwitchTile(
          title: 'Show in Search',
          subtitle: 'Allow others to find you in search results',
          value: _preferences['showInSearch'] ?? true,
          onChanged: (value) => _updatePreference('showInSearch', value),
        ),
      ],
    );
  }

  Widget _buildContactVisibilitySection() {
    return _buildSection(
      title: 'Contact Information',
      icon: Icons.contact_phone,
      description: 'Control who can see your contact details',
      children: [
        _buildPrivacyDropdown(
          label: 'Contact Visibility',
          value: _preferences['contactVisibility'] ?? PrivacyProtectionService.privacyDirectReferrals,
          onChanged: (value) => _updatePreference('contactVisibility', value),
          options: const [
            {'value': PrivacyProtectionService.privacyPublic, 'label': 'Public - Everyone can see'},
            {'value': PrivacyProtectionService.privacyNetwork, 'label': 'Network - Only my network'},
            {'value': PrivacyProtectionService.privacyDirectReferrals, 'label': 'Direct Referrals - Only direct referrals'},
            {'value': PrivacyProtectionService.privacyCoordinators, 'label': 'Coordinators - Only coordinators'},
            {'value': PrivacyProtectionService.privacyPrivate, 'label': 'Private - Only me'},
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.security, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your phone number and email are never shared publicly for security reasons.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostPrivacySection() {
    return _buildSection(
      title: 'Post Privacy',
      icon: Icons.post_add,
      description: 'Set default privacy for your posts',
      children: [
        _buildPrivacyDropdown(
          label: 'Default Post Privacy',
          value: _preferences['postDefaultPrivacy'] ?? PrivacyProtectionService.privacyPublic,
          onChanged: (value) => _updatePreference('postDefaultPrivacy', value),
          options: const [
            {'value': PrivacyProtectionService.privacyPublic, 'label': 'Public - Everyone can see'},
            {'value': PrivacyProtectionService.privacyNetwork, 'label': 'Network - Only my network'},
            {'value': PrivacyProtectionService.privacyDirectReferrals, 'label': 'Direct Referrals - Only direct referrals'},
            {'value': PrivacyProtectionService.privacyCoordinators, 'label': 'Coordinators - Only coordinators'},
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can change privacy for individual posts when creating them.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommunicationSection() {
    return _buildSection(
      title: 'Communication',
      icon: Icons.message,
      description: 'Control how others can communicate with you',
      children: [
        _buildSwitchTile(
          title: 'Allow Direct Messages',
          subtitle: 'Let others send you private messages',
          value: _preferences['allowDirectMessages'] ?? true,
          onChanged: (value) => _updatePreference('allowDirectMessages', value),
        ),
        _buildSwitchTile(
          title: 'Allow Group Invites',
          subtitle: 'Let others invite you to groups',
          value: _preferences['allowGroupInvites'] ?? true,
          onChanged: (value) => _updatePreference('allowGroupInvites', value),
        ),
      ],
    );
  }

  Widget _buildDataProcessingSection() {
    return _buildSection(
      title: 'Data Processing',
      icon: Icons.data_usage,
      description: 'Control how your data is processed',
      children: [
        _buildSwitchTile(
          title: 'Data Processing Consent',
          subtitle: 'Allow TALOWA to process your data for app functionality',
          value: _preferences['dataProcessingConsent'] ?? false,
          onChanged: (value) => _showDataConsentDialog(value),
          isRequired: true,
        ),
        _buildSwitchTile(
          title: 'Marketing Communications',
          subtitle: 'Receive updates about TALOWA features and events',
          value: _preferences['marketingConsent'] ?? false,
          onChanged: (value) => _updatePreference('marketingConsent', value),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Important',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Data processing consent is required for the app to function properly. Without it, some features may not work.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return _buildSection(
      title: 'Advanced',
      icon: Icons.settings_applications,
      description: 'Advanced privacy options',
      children: [
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Download My Data'),
          subtitle: const Text('Get a copy of your personal data'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _downloadUserData,
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Delete My Account'),
          subtitle: const Text('Permanently delete your account and data'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _showDeleteAccountDialog,
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Privacy Activity'),
          subtitle: const Text('View your privacy and security activity'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _viewPrivacyActivity,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String description,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.talowaGreen),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyDropdown({
    required String label,
    required String value,
    required Function(String) onChanged,
    required List<Map<String, String>> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: options.map((option) {
            return DropdownMenuItem(
              value: option['value'],
              child: Text(
                option['label']!,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool isRequired = false,
  }) {
    return SwitchListTile(
      title: Row(
        children: [
          Expanded(child: Text(title)),
          if (isRequired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.talowaGreen,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _updatePreference(String key, dynamic value) {
    setState(() {
      _preferences[key] = value;
    });
  }

  void _showDataConsentDialog(bool value) {
    if (value) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Data Processing Consent'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'By enabling data processing consent, you allow TALOWA to:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 12),
                Text('â€¢ Process your profile information'),
                Text('â€¢ Store your posts and messages'),
                Text('â€¢ Analyze usage patterns to improve the app'),
                Text('â€¢ Send you relevant notifications'),
                Text('â€¢ Maintain your network connections'),
                SizedBox(height: 12),
                Text(
                  'Your data will be processed securely and never shared with third parties without your explicit consent.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updatePreference('dataProcessingConsent', true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('I Consent'),
            ),
          ],
        ),
      );
    } else {
      _updatePreference('dataProcessingConsent', false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _privacyService.updatePrivacyPreferences(
        userId: 'current_user_id', // TODO: Get from auth service
        preferences: _preferences,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving privacy settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _downloadUserData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data download feature coming soon')),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion feature coming soon')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _viewPrivacyActivity() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy activity feature coming soon')),
    );
  }

  void _handleBackNavigation() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('You are already on the main screen. Use bottom navigation to switch tabs.'),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSwipeProtectionMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.swipe, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Swipe navigation is disabled to prevent accidental logout'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
