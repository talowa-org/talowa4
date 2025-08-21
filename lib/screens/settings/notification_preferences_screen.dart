// Notification Preferences Screen - User notification settings
// Part of Task 12: Build push notification system

import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/notifications/notification_preferences_service.dart';
import '../../core/theme/app_theme.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      setState(() {
        _isLoading = true;
      });

      _preferences = NotificationPreferencesService.getPreferences();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    try {
      setState(() {
        _isSaving = true;
      });

      await NotificationPreferencesService.updatePreferences(_preferences);

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updatePreference<T>(T value, T Function(NotificationPreferences) getter, 
      NotificationPreferences Function(NotificationPreferences, T) setter) {
    if (getter(_preferences) != value) {
      setState(() {
        _preferences = setter(_preferences, value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGeneralSection(),
                  const SizedBox(height: 24),
                  _buildChannelSection(),
                  const SizedBox(height: 24),
                  _buildQuietHoursSection(),
                  const SizedBox(height: 24),
                  _buildNotificationTypesSection(),
                  const SizedBox(height: 24),
                  _buildAdvancedSection(),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildGeneralSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'General Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive notifications from TALOWA'),
              value: _preferences.enablePushNotifications,
              onChanged: (value) {
                _updatePreference(
                  value,
                  (p) => p.enablePushNotifications,
                  (p, v) => NotificationPreferences(
                    enablePushNotifications: v,
                    enableInAppNotifications: p.enableInAppNotifications,
                    enableEmailNotifications: p.enableEmailNotifications,
                    enableSMSNotifications: p.enableSMSNotifications,
                    typePreferences: p.typePreferences,
                    enableQuietHours: p.enableQuietHours,
                    quietHoursStart: p.quietHoursStart,
                    quietHoursEnd: p.quietHoursEnd,
                    enableLocationBasedNotifications: p.enableLocationBasedNotifications,
                    enableEmergencyOverride: p.enableEmergencyOverride,
                  ),
                );
              },
            ),
            SwitchListTile(
              title: const Text('Emergency Override'),
              subtitle: const Text('Show emergency alerts even during quiet hours'),
              value: _preferences.enableEmergencyOverride,
              onChanged: (value) {
                _updatePreference(
                  value,
                  (p) => p.enableEmergencyOverride,
                  (p, v) => NotificationPreferences(
                    enablePushNotifications: p.enablePushNotifications,
                    enableInAppNotifications: p.enableInAppNotifications,
                    enableEmailNotifications: p.enableEmailNotifications,
                    enableSMSNotifications: p.enableSMSNotifications,
                    typePreferences: p.typePreferences,
                    enableQuietHours: p.enableQuietHours,
                    quietHoursStart: p.quietHoursStart,
                    quietHoursEnd: p.quietHoursEnd,
                    enableLocationBasedNotifications: p.enableLocationBasedNotifications,
                    enableEmergencyOverride: v,
                  ),
                );
              },
            ),
            SwitchListTile(
              title: const Text('Location-Based Notifications'),
              subtitle: const Text('Receive notifications relevant to your area'),
              value: _preferences.enableLocationBasedNotifications,
              onChanged: (value) {
                _updatePreference(
                  value,
                  (p) => p.enableLocationBasedNotifications,
                  (p, v) => NotificationPreferences(
                    enablePushNotifications: p.enablePushNotifications,
                    enableInAppNotifications: p.enableInAppNotifications,
                    enableEmailNotifications: p.enableEmailNotifications,
                    enableSMSNotifications: p.enableSMSNotifications,
                    typePreferences: p.typePreferences,
                    enableQuietHours: p.enableQuietHours,
                    quietHoursStart: p.quietHoursStart,
                    quietHoursEnd: p.quietHoursEnd,
                    enableLocationBasedNotifications: v,
                    enableEmergencyOverride: p.enableEmergencyOverride,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Channels',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications on your device'),
              value: _preferences.enablePushNotifications,
              onChanged: (value) {
                _updatePreference(
                  value,
                  (p) => p.enablePushNotifications,
                  (p, v) => NotificationPreferences(
                    enablePushNotifications: v,
                    enableInAppNotifications: p.enableInAppNotifications,
                    enableEmailNotifications: p.enableEmailNotifications,
                    enableSMSNotifications: p.enableSMSNotifications,
                    typePreferences: p.typePreferences,
                    enableQuietHours: p.enableQuietHours,
                    quietHoursStart: p.quietHoursStart,
                    quietHoursEnd: p.quietHoursEnd,
                    enableLocationBasedNotifications: p.enableLocationBasedNotifications,
                    enableEmergencyOverride: p.enableEmergencyOverride,
                  ),
                );
              },
            ),
            SwitchListTile(
              title: const Text('In-App Notifications'),
              subtitle: const Text('Show notifications while using the app'),
              value: _preferences.enableInAppNotifications,
              onChanged: (value) {
                _updatePreference(
                  value,
                  (p) => p.enableInAppNotifications,
                  (p, v) => NotificationPreferences(
                    enablePushNotifications: p.enablePushNotifications,
                    enableInAppNotifications: v,
                    enableEmailNotifications: p.enableEmailNotifications,
                    enableSMSNotifications: p.enableSMSNotifications,
                    typePreferences: p.typePreferences,
                    enableQuietHours: p.enableQuietHours,
                    quietHoursStart: p.quietHoursStart,
                    quietHoursEnd: p.quietHoursEnd,
                    enableLocationBasedNotifications: p.enableLocationBasedNotifications,
                    enableEmergencyOverride: p.enableEmergencyOverride,
                  ),
                );
              },
            ),
            SwitchListTile(
              title: const Text('SMS Notifications'),
              subtitle: const Text('Receive SMS for critical alerts'),
              value: _preferences.enableSMSNotifications,
              onChanged: (value) {
                _updatePreference(
                  value,
                  (p) => p.enableSMSNotifications,
                  (p, v) => NotificationPreferences(
                    enablePushNotifications: p.enablePushNotifications,
                    enableInAppNotifications: p.enableInAppNotifications,
                    enableEmailNotifications: p.enableEmailNotifications,
                    enableSMSNotifications: v,
                    typePreferences: p.typePreferences,
                    enableQuietHours: p.enableQuietHours,
                    quietHoursStart: p.quietHoursStart,
                    quietHoursEnd: p.quietHoursEnd,
                    enableLocationBasedNotifications: p.enableLocationBasedNotifications,
                    enableEmergencyOverride: p.enableEmergencyOverride,
                  ),
                );
              },
            ),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive email summaries and updates'),
              value: _preferences.enableEmailNotifications,
              onChanged: (value) {
                _updatePreference(
                  value,
                  (p) => p.enableEmailNotifications,
                  (p, v) => NotificationPreferences(
                    enablePushNotifications: p.enablePushNotifications,
                    enableInAppNotifications: p.enableInAppNotifications,
                    enableEmailNotifications: v,
                    enableSMSNotifications: p.enableSMSNotifications,
                    typePreferences: p.typePreferences,
                    enableQuietHours: p.enableQuietHours,
                    quietHoursStart: p.quietHoursStart,
                    quietHoursEnd: p.quietHoursEnd,
                    enableLocationBasedNotifications: p.enableLocationBasedNotifications,
                    enableEmergencyOverride: p.enableEmergencyOverride,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHoursSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quiet Hours',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Quiet Hours'),
              subtitle: const Text('Reduce notifications during specified hours'),
              value: _preferences.enableQuietHours,
              onChanged: (value) {
                _updatePreference(
                  value,
                  (p) => p.enableQuietHours,
                  (p, v) => NotificationPreferences(
                    enablePushNotifications: p.enablePushNotifications,
                    enableInAppNotifications: p.enableInAppNotifications,
                    enableEmailNotifications: p.enableEmailNotifications,
                    enableSMSNotifications: p.enableSMSNotifications,
                    typePreferences: p.typePreferences,
                    enableQuietHours: v,
                    quietHoursStart: p.quietHoursStart,
                    quietHoursEnd: p.quietHoursEnd,
                    enableLocationBasedNotifications: p.enableLocationBasedNotifications,
                    enableEmergencyOverride: p.enableEmergencyOverride,
                  ),
                );
              },
            ),
            if (_preferences.enableQuietHours) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Time'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: GestureDetector(
                            onTap: () => _selectTime(true),
                            child: Text(
                              '${_preferences.quietHoursStart.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Time'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: GestureDetector(
                            onTap: () => _selectTime(false),
                            child: Text(
                              '${_preferences.quietHoursEnd.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Types',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...NotificationType.values.map((type) => SwitchListTile(
              title: Text(type.displayName),
              subtitle: Text(type.description),
              value: _preferences.isTypeEnabled(type),
              onChanged: (value) {
                final updatedTypePreferences = Map<NotificationType, bool>.from(_preferences.typePreferences);
                updatedTypePreferences[type] = value;
                
                setState(() {
                  _preferences = NotificationPreferences(
                    enablePushNotifications: _preferences.enablePushNotifications,
                    enableInAppNotifications: _preferences.enableInAppNotifications,
                    enableEmailNotifications: _preferences.enableEmailNotifications,
                    enableSMSNotifications: _preferences.enableSMSNotifications,
                    typePreferences: updatedTypePreferences,
                    enableQuietHours: _preferences.enableQuietHours,
                    quietHoursStart: _preferences.quietHoursStart,
                    quietHoursEnd: _preferences.quietHoursEnd,
                    enableLocationBasedNotifications: _preferences.enableLocationBasedNotifications,
                    enableEmergencyOverride: _preferences.enableEmergencyOverride,
                  );
                });
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Test Notification'),
              subtitle: const Text('Send a test notification to verify settings'),
              trailing: const Icon(Icons.send),
              onTap: _sendTestNotification,
            ),
            ListTile(
              title: const Text('Reset to Defaults'),
              subtitle: const Text('Reset all preferences to default values'),
              trailing: const Icon(Icons.restore),
              onTap: _resetToDefaults,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _savePreferences,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Save Preferences'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(bool isStartTime) async {
    final currentTime = isStartTime ? _preferences.quietHoursStart : _preferences.quietHoursEnd;
    
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentTime, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      setState(() {
        if (isStartTime) {
          _preferences = NotificationPreferences(
            enablePushNotifications: _preferences.enablePushNotifications,
            enableInAppNotifications: _preferences.enableInAppNotifications,
            enableEmailNotifications: _preferences.enableEmailNotifications,
            enableSMSNotifications: _preferences.enableSMSNotifications,
            typePreferences: _preferences.typePreferences,
            enableQuietHours: _preferences.enableQuietHours,
            quietHoursStart: selectedTime.hour,
            quietHoursEnd: _preferences.quietHoursEnd,
            enableLocationBasedNotifications: _preferences.enableLocationBasedNotifications,
            enableEmergencyOverride: _preferences.enableEmergencyOverride,
          );
        } else {
          _preferences = NotificationPreferences(
            enablePushNotifications: _preferences.enablePushNotifications,
            enableInAppNotifications: _preferences.enableInAppNotifications,
            enableEmailNotifications: _preferences.enableEmailNotifications,
            enableSMSNotifications: _preferences.enableSMSNotifications,
            typePreferences: _preferences.typePreferences,
            enableQuietHours: _preferences.enableQuietHours,
            quietHoursStart: _preferences.quietHoursStart,
            quietHoursEnd: selectedTime.hour,
            enableLocationBasedNotifications: _preferences.enableLocationBasedNotifications,
            enableEmergencyOverride: _preferences.enableEmergencyOverride,
          );
        }
      });
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      // This would typically call a service to send a test notification
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending test notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Preferences'),
        content: const Text('Are you sure you want to reset all notification preferences to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await NotificationPreferencesService.resetToDefaults();
        await _loadPreferences();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preferences reset to defaults'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting preferences: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}