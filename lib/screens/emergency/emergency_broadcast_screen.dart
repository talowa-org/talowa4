// Emergency Broadcast Screen for TALOWA Coordinators
// Task 9: Build emergency broadcast system - UI Implementation
// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5

import 'package:flutter/material.dart';
import '../../services/messaging/emergency_broadcast_service.dart';

class EmergencyBroadcastScreen extends StatefulWidget {
  const EmergencyBroadcastScreen({super.key});

  @override
  State<EmergencyBroadcastScreen> createState() => _EmergencyBroadcastScreenState();
}

class _EmergencyBroadcastScreenState extends State<EmergencyBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _emergencyService = EmergencyBroadcastService();
  
  EmergencyPriority _selectedPriority = EmergencyPriority.high;
  GeographicLevel _selectedLevel = GeographicLevel.district;
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedMandal;
  String? _selectedVillage;
  List<String> _selectedRoles = [];
  EmergencyTemplate? _selectedTemplate;
  
  bool _isLoading = false;
  List<EmergencyTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await _emergencyService.getEmergencyTemplates();
      setState(() {
        _templates = templates;
      });
    } catch (e) {
      debugPrint('Error loading templates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Broadcast'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showBroadcastHistory(),
            tooltip: 'Broadcast History',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emergency Alert Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Broadcast',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            'Send priority alerts with multi-channel delivery',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Quick Templates Section
              if (_templates.isNotEmpty) ...[
                const Text(
                  'Quick Templates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      return _buildTemplateCard(template);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Priority Selection
              const Text(
                'Priority Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: EmergencyPriority.values.map((priority) {
                  return Expanded(
                    child: RadioListTile<EmergencyPriority>(
                      title: Text(_getPriorityLabel(priority)),
                      value: priority,
                      groupValue: _selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                      dense: true,
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),

              // Geographic Scope
              const Text(
                'Geographic Scope',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<GeographicLevel>(
                value: _selectedLevel,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: GeographicLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(_getGeographicLevelLabel(level)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value!;
                  });
                },
              ),

              const SizedBox(height: 16),
              
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Alert Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                  hintText: 'Enter emergency alert title',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter alert title';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Message
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Alert Message',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                  alignLabelWithHint: true,
                  hintText: 'Enter detailed emergency message',
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter alert message';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Delivery Channels Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Channels',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_getDeliveryChannelsText()),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendEmergencyBroadcast,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Sending Emergency Alert...' : 'Send Emergency Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(EmergencyTemplate template) {
    final isSelected = _selectedTemplate?.id == template.id;
    
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        color: isSelected ? Colors.red.withOpacity(0.1) : null,
        child: InkWell(
          onTap: () => _applyTemplate(template),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.flash_on,
                      color: _getPriorityColor(template.priority),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        template.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  template.title,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  _getPriorityLabel(template.priority),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getPriorityColor(template.priority),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _applyTemplate(EmergencyTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _titleController.text = template.title;
      _messageController.text = template.message;
      _selectedPriority = template.priority;
    });
  }

  String _getPriorityLabel(EmergencyPriority priority) {
    switch (priority) {
      case EmergencyPriority.low:
        return 'Low';
      case EmergencyPriority.medium:
        return 'Medium';
      case EmergencyPriority.high:
        return 'High';
      case EmergencyPriority.critical:
        return 'Critical';
    }
  }

  Color _getPriorityColor(EmergencyPriority priority) {
    switch (priority) {
      case EmergencyPriority.low:
        return Colors.green;
      case EmergencyPriority.medium:
        return Colors.orange;
      case EmergencyPriority.high:
        return Colors.red;
      case EmergencyPriority.critical:
        return Colors.purple;
    }
  }

  String _getGeographicLevelLabel(GeographicLevel level) {
    switch (level) {
      case GeographicLevel.village:
        return 'Village';
      case GeographicLevel.mandal:
        return 'Mandal';
      case GeographicLevel.district:
        return 'District';
      case GeographicLevel.state:
        return 'State';
      case GeographicLevel.national:
        return 'National';
    }
  }

  String _getDeliveryChannelsText() {
    switch (_selectedPriority) {
      case EmergencyPriority.critical:
        return 'Push Notifications + SMS + Email (All channels for maximum reach)';
      case EmergencyPriority.high:
        return 'Push Notifications + Email (High priority delivery)';
      case EmergencyPriority.medium:
      case EmergencyPriority.low:
        return 'Push Notifications (Standard delivery)';
    }
  }

  void _showBroadcastHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BroadcastHistoryScreen(),
      ),
    );
  }

  Future<void> _sendEmergencyBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog for critical broadcasts
    if (_selectedPriority == EmergencyPriority.critical) {
      final confirmed = await _showConfirmationDialog();
      if (!confirmed) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final scope = EmergencyBroadcastScope(
        level: _selectedLevel,
        state: _selectedState,
        district: _selectedDistrict,
        mandal: _selectedMandal,
        village: _selectedVillage,
        targetRoles: _selectedRoles,
      );

      final broadcastId = await _emergencyService.sendEmergencyBroadcast(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        scope: scope,
        priority: _selectedPriority,
        templateId: _selectedTemplate?.id,
      );

      if (mounted && broadcastId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency broadcast sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Show delivery tracking
        _showDeliveryTracking(broadcastId);
      } else {
        throw Exception('Failed to send broadcast');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send emergency broadcast: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Critical Emergency Alert'),
          ],
        ),
        content: const Text(
          'You are about to send a CRITICAL emergency alert that will be delivered via push notifications, SMS, and email to all targeted users. This should only be used for life-threatening emergencies.\n\nAre you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send Critical Alert'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showDeliveryTracking(String broadcastId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryTrackingScreen(broadcastId: broadcastId),
      ),
    );
  }
}

// Broadcast History Screen
class BroadcastHistoryScreen extends StatelessWidget {
  const BroadcastHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emergencyService = EmergencyBroadcastService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast History'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<EmergencyBroadcast>>(
        stream: emergencyService.getUserBroadcasts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final broadcasts = snapshot.data ?? [];

          if (broadcasts.isEmpty) {
            return const Center(
              child: Text('No broadcasts sent yet'),
            );
          }

          return ListView.builder(
            itemCount: broadcasts.length,
            itemBuilder: (context, index) {
              final broadcast = broadcasts[index];
              return _buildBroadcastCard(context, broadcast);
            },
          );
        },
      ),
    );
  }

  Widget _buildBroadcastCard(BuildContext context, EmergencyBroadcast broadcast) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(broadcast.status),
          child: Icon(
            _getStatusIcon(broadcast.status),
            color: Colors.white,
          ),
        ),
        title: Text(broadcast.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(broadcast.message, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              'Sent: ${_formatDateTime(broadcast.createdAt)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPriorityColor(broadcast.priority),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getPriorityLabel(broadcast.priority),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryTrackingScreen(broadcastId: broadcast.id),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(BroadcastStatus status) {
    switch (status) {
      case BroadcastStatus.pending:
        return Colors.orange;
      case BroadcastStatus.processing:
        return Colors.blue;
      case BroadcastStatus.completed:
        return Colors.green;
      case BroadcastStatus.failed:
        return Colors.red;
      case BroadcastStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(BroadcastStatus status) {
    switch (status) {
      case BroadcastStatus.pending:
        return Icons.schedule;
      case BroadcastStatus.processing:
        return Icons.sync;
      case BroadcastStatus.completed:
        return Icons.check;
      case BroadcastStatus.failed:
        return Icons.error;
      case BroadcastStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getPriorityLabel(EmergencyPriority priority) {
    switch (priority) {
      case EmergencyPriority.low:
        return 'Low';
      case EmergencyPriority.medium:
        return 'Medium';
      case EmergencyPriority.high:
        return 'High';
      case EmergencyPriority.critical:
        return 'Critical';
    }
  }

  Color _getPriorityColor(EmergencyPriority priority) {
    switch (priority) {
      case EmergencyPriority.low:
        return Colors.green;
      case EmergencyPriority.medium:
        return Colors.orange;
      case EmergencyPriority.high:
        return Colors.red;
      case EmergencyPriority.critical:
        return Colors.purple;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// Delivery Tracking Screen
class DeliveryTrackingScreen extends StatelessWidget {
  final String broadcastId;

  const DeliveryTrackingScreen({
    super.key,
    required this.broadcastId,
  });

  @override
  Widget build(BuildContext context) {
    final emergencyService = EmergencyBroadcastService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Tracking'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<BroadcastDeliveryTracking?>(
        future: emergencyService.getBroadcastDeliveryStatus(broadcastId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final tracking = snapshot.data;
          if (tracking == null) {
            return const Center(
              child: Text('No delivery tracking data available'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Overview
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: tracking.deliveryRate,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            tracking.isCompleted ? Colors.green : Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(tracking.deliveryRate * 100).toStringAsFixed(1)}% delivered',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Statistics
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Targets',
                        tracking.totalTargets.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Delivered',
                        tracking.deliveredCount.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Failed',
                        tracking.failedCount.toString(),
                        Icons.error,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Pending',
                        tracking.pendingCount.toString(),
                        Icons.schedule,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Delivery Channels
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Channels',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...tracking.channels.map((channel) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(_getChannelIcon(channel), size: 16),
                              const SizedBox(width: 8),
                              Text(_getChannelLabel(channel)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Timing Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Timing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Started: ${_formatDateTime(tracking.deliveryStarted)}'),
                        if (tracking.deliveryCompleted != null)
                          Text('Completed: ${_formatDateTime(tracking.deliveryCompleted!)}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getChannelIcon(DeliveryChannel channel) {
    switch (channel) {
      case DeliveryChannel.push:
        return Icons.notifications;
      case DeliveryChannel.sms:
        return Icons.sms;
      case DeliveryChannel.email:
        return Icons.email;
    }
  }

  String _getChannelLabel(DeliveryChannel channel) {
    switch (channel) {
      case DeliveryChannel.push:
        return 'Push Notifications';
      case DeliveryChannel.sms:
        return 'SMS';
      case DeliveryChannel.email:
        return 'Email';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}