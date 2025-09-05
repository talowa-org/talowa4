// Notification Settings Screen - Manage notification preferences
// Complete notification preferences management

import 'package:flutter/material.dart';
import '../../services/notifications/notification_preferences_service.dart';
import '../../models/notification_preferences_model.dart';
import '../../core/theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationPreferences _preferences = NotificationPreferences();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      setState(() => _isLoading = true);
      
      _preferences = NotificationPreferencesService.getPreferences();
      
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    try {
      setState(() => _isSaving = true);
      
      await NotificationPreferencesService.updatePreferences(_preferences);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification preferences saved')),
        );
      }
      
    } catch (e) {
      debugPrint('Error saving notification preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save preferences')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _savePreferences,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSettingsContent(),
    );
  }

  Widget _buildSettingsContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGeneralSettings(),
        const SizedBox(height: 24),
        _buildNotificationTypes(),
        const SizedBox(height: 24),
        _buildQuietHours(),
        const SizedBox(height: 24),
        _buildAdvancedSettings(),
      ],
    );
  }

  Widget _buildGeneralSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'General Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications on this device'),
              value: _preferences.enablePushNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enablePushNotifications: value);
                });
              },
            ),
            SwitchListTile(
              title: const Text('In-App Notifications'),
              subtitle: const Text('Show notifications while using the app'),
              value: _preferences.enableInAppNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableInAppNotifications: value);
                });
              },
            ),
            SwitchListTile(
              title: const Text('Sound'),
              subtitle: const Text('Play sound for notifications'),
              value: _preferences.enableSound,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableSound: value);
                });
              },
            ),
            SwitchListTile(
              title: const Text('Vibration'),
              subtitle: const Text('Vibrate for notifications'),
              value: _preferences.enableVibration,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableVibration: value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Types',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Emergency Alerts'),
              subtitle: const Text('Critical safety and emergency notifications'),
              value: _preferences.enableEmergencyNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableEmergencyNotifications: value);
                });
              },
            ),
            SwitchListTile(
              title: const Text('Campaign Updates'),
              subtitle: const Text('Land rights campaigns and activism updates'),
              value: _preferences.enableCampaignNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableCampaignNotifications: value);
                });
              },
            ),
            SwitchListTile(
              title: const Text('Social Activity'),
              subtitle: const Text('Likes, comments, and shares on your posts'),
              value: _preferences.enableSocialNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableSocialNotifications: value);
                });
              },
            ),
            SwitchListTile(
              title: const Text('Referral Updates'),
              subtitle: const Text('New referrals and network growth'),
              value: _preferences.enableReferralNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableReferralNotifications: value);
                });
              },
            ),
            SwitchListTile(
              title: const Text('Announcements'),
              subtitle: const Text('App updates and important announcements'),
              value: _preferences.enableAnnouncementNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableAnnouncementNotifications: value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHours() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quiet Hours',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reduce notifications during specified hours',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Quiet Hours'),
              value: _preferences.quietHours.enabled,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(
                    quietHours: _preferences.quietHours.copyWith(enabled: value),
                  );
                });
              },
            ),
            if (_preferences.quietHours.enabled) ...[
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(_preferences.quietHours.startTime),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(true),
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(_preferences.quietHours.endTime),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Emergency Override'),
              subtitle: const Text('Allow emergency alerts during quiet hours'),
              value: _preferences.enableEmergencyOverride,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableEmergencyOverride: value);
                });
              },
            ),
            SwitchListTile(
              title: const Text('Batch Notifications'),
              subtitle: const Text('Group similar notifications together'),
              value: _preferences.enableBatching,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(enableBatching: value);
                });
              },
            ),
            ListTile(
              title: const Text('Notification Frequency'),
              subtitle: Text(_getFrequencyText(_preferences.maxNotificationsPerHour)),
              trailing: const Icon(Icons.tune),
              onTap: _showFrequencyDialog,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(bool isStartTime) async {
    final currentTime = isStartTime 
        ? _parseTime(_preferences.quietHours.startTime)
        : _parseTime(_preferences.quietHours.endTime);

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (selectedTime != null) {
      final timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      
      setState(() {
        if (isStartTime) {
          _preferences = _preferences.copyWith(
            quietHours: _preferences.quietHours.copyWith(startTime: timeString),
          );
        } else {
          _preferences = _preferences.copyWith(
            quietHours: _preferences.quietHours.copyWith(endTime: timeString),
          );
        }
      });
    }
  }

  TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _getFrequencyText(int maxPerHour) {
    if (maxPerHour >= 60) return 'No limit';
    if (maxPerHour >= 10) return 'High ($maxPerHour per hour)';
    if (maxPerHour >= 5) return 'Medium ($maxPerHour per hour)';
    return 'Low ($maxPerHour per hour)';
  }

  Future<void> _showFrequencyDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Frequency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Maximum notifications per hour:'),
            const SizedBox(height: 16),
            ...{
              2: 'Very Low (2 per hour)',
              5: 'Low (5 per hour)',
              10: 'Medium (10 per hour)',
              20: 'High (20 per hour)',
              60: 'No limit',
            }.entries.map((entry) => RadioListTile<int>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: _preferences.maxNotificationsPerHour,
              onChanged: (value) => Navigator.pop(context, value),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _preferences = _preferences.copyWith(maxNotificationsPerHour: result);
      });
    }
  }
}


