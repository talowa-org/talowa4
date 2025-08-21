// Bulk Message Screen for TALOWA Messaging System
// Reference: in-app-communication/requirements.md - Bulk Messaging

import 'package:flutter/material.dart';
import '../../models/messaging/group_model.dart';
import '../../models/messaging/message_model.dart';
import '../../services/messaging/group_service.dart';
import '../../core/constants/app_constants.dart';

class BulkMessageScreen extends StatefulWidget {
  final GroupModel group;

  const BulkMessageScreen({
    super.key,
    required this.group,
  });

  @override
  State<BulkMessageScreen> createState() => _BulkMessageScreenState();
}

class _BulkMessageScreenState extends State<BulkMessageScreen> {
  final _messageController = TextEditingController();
  final GroupService _groupService = GroupService();
  
  MessageType _selectedType = MessageType.text;
  bool _isLoading = false;
  bool _isEmergency = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBulkMessage() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      await _groupService.sendBulkMessage(
        groupId: widget.group.id,
        content: _messageController.text.trim(),
        messageType: _isEmergency ? MessageType.emergency : _selectedType,
        metadata: {
          'isEmergency': _isEmergency,
          'sentAt': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEmergency 
                  ? 'Emergency message sent to all members!'
                  : 'Message sent to all members!',
            ),
            backgroundColor: _isEmergency 
                ? const Color(AppConstants.emergencyRedValue)
                : const Color(AppConstants.successGreenValue),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Bulk Message'),
        backgroundColor: _isEmergency 
            ? const Color(AppConstants.emergencyRedValue)
            : const Color(AppConstants.talowaGreenValue),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _sendBulkMessage,
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
                    'SEND',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupInfo(),
            const SizedBox(height: 24),
            _buildMessageTypeSelector(),
            const SizedBox(height: 24),
            _buildEmergencyToggle(),
            const SizedBox(height: 24),
            _buildMessageInput(),
            const SizedBox(height: 24),
            _buildPreviewSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sending to: ${widget.group.name}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.group.memberCount} members will receive this message',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message Type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MessageType.text,
                MessageType.system,
              ].map((type) {
                final isSelected = _selectedType == type;
                return FilterChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  onSelected: _isEmergency ? null : (selected) {
                    if (selected) {
                      setState(() {
                        _selectedType = type;
                      });
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

  Widget _buildEmergencyToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text(
                'Emergency Message',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'High priority message that bypasses normal queues',
              ),
              value: _isEmergency,
              onChanged: (value) {
                setState(() {
                  _isEmergency = value;
                  if (value) {
                    _selectedType = MessageType.emergency;
                  } else {
                    _selectedType = MessageType.text;
                  }
                });
              },
              activeColor: const Color(AppConstants.emergencyRedValue),
              contentPadding: EdgeInsets.zero,
            ),
            if (_isEmergency) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.emergencyRedValue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(AppConstants.emergencyRedValue).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      color: Color(AppConstants.emergencyRedValue),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Emergency messages will be delivered immediately and may trigger push notifications even if the app is closed.',
                        style: TextStyle(
                          color: const Color(AppConstants.emergencyRedValue),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message Content',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _isEmergency 
                    ? 'Enter emergency message...'
                    : 'Enter your message...',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              maxLength: 1000,
              onChanged: (value) {
                setState(() {}); // Trigger rebuild for preview
              },
            ),
            const SizedBox(height: 8),
            if (_isEmergency)
              Text(
                'Emergency messages should be clear, concise, and actionable.',
                style: TextStyle(
                  color: const Color(AppConstants.emergencyRedValue),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    if (_messageController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isEmergency 
                    ? const Color(AppConstants.emergencyRedValue).withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: _isEmergency 
                    ? Border.all(
                        color: const Color(AppConstants.emergencyRedValue).withOpacity(0.3),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_isEmergency) ...[
                        const Icon(
                          Icons.warning,
                          color: Color(AppConstants.emergencyRedValue),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        _isEmergency ? 'EMERGENCY' : _selectedType.displayName.toUpperCase(),
                        style: TextStyle(
                          color: _isEmergency 
                              ? const Color(AppConstants.emergencyRedValue)
                              : Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _messageController.text.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      color: _isEmergency 
                          ? const Color(AppConstants.emergencyRedValue)
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From: ${widget.group.name}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
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