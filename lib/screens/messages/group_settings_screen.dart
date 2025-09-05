// Group Settings Screen for TALOWA Messaging System
// Reference: in-app-communication/requirements.md - Group Settings

import 'package:flutter/material.dart';
import '../../models/messaging/group_model.dart';
import '../../services/messaging/group_service.dart';
import '../../core/constants/app_constants.dart';

class GroupSettingsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupSettingsScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final GroupService _groupService = GroupService();
  late GroupSettings _settings;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.group.settings;
  }

  Future<void> _saveSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _groupService.updateGroupSettings(
        groupId: widget.group.id,
        settings: _settings,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings updated successfully!'),
            backgroundColor: Color(AppConstants.successGreenValue),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: const Color(AppConstants.emergencyRedValue),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateSettings(GroupSettings newSettings) {
    setState(() {
      _settings = newSettings;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
        backgroundColor: const Color(AppConstants.talowaGreenValue),
        foregroundColor: Colors.white,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveSettings,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'SAVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPermissionsSection(),
          const SizedBox(height: 24),
          _buildSecuritySection(),
          const SizedBox(height: 24),
          _buildRetentionSection(),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permissions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionSetting(
              'Who can add members',
              _settings.whoCanAddMembers,
              (permission) => _updateSettings(
                _settings.copyWith(whoCanAddMembers: permission),
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionSetting(
              'Who can send messages',
              _settings.whoCanSendMessages,
              (permission) => _updateSettings(
                _settings.copyWith(whoCanSendMessages: permission),
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionSetting(
              'Who can share media',
              _settings.whoCanShareMedia,
              (permission) => _updateSettings(
                _settings.copyWith(whoCanShareMedia: permission),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security & Privacy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Require approval to join'),
              subtitle: const Text('New members need admin approval'),
              value: _settings.requireApprovalToJoin,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(requireApprovalToJoin: value),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Allow anonymous messages'),
              subtitle: const Text('Members can send anonymous reports'),
              value: _settings.allowAnonymousMessages,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(allowAnonymousMessages: value),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            _buildEncryptionSetting(),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message Retention',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Messages will be automatically deleted after:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [30, 90, 180, 365].map((days) {
                final isSelected = _settings.messageRetention == days;
                return FilterChip(
                  label: Text('$days days'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _updateSettings(
                        _settings.copyWith(messageRetention: days),
                      );
                    }
                  },
                  selectedColor: const Color(AppConstants.talowaGreenValue).withOpacity(0.2),
                  checkmarkColor: const Color(AppConstants.talowaGreenValue),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSetting(
    String title,
    GroupPermission currentValue,
    Function(GroupPermission) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GroupPermission.values.map((permission) {
            final isSelected = currentValue == permission;
            return FilterChip(
              label: Text(permission.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onChanged(permission);
                }
              },
              selectedColor: const Color(AppConstants.talowaGreenValue).withOpacity(0.2),
              checkmarkColor: const Color(AppConstants.talowaGreenValue),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEncryptionSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encryption Level',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['standard', 'high_security'].map((level) {
            final isSelected = _settings.encryptionLevel == level;
            final displayName = level == 'standard' ? 'Standard' : 'High Security';
            
            return FilterChip(
              label: Text(displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _updateSettings(
                    _settings.copyWith(encryptionLevel: level),
                  );
                }
              },
              selectedColor: const Color(AppConstants.talowaGreenValue).withOpacity(0.2),
              checkmarkColor: const Color(AppConstants.talowaGreenValue),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          _settings.encryptionLevel == 'high_security'
              ? 'Messages are encrypted with AES-256 + RSA-4096'
              : 'Messages are encrypted with standard AES-256',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
