// Post Scheduling Widget - Interface for scheduling posts
// Part of Task 11: Add post editing and management

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/social_feed/post_management_service.dart';

/// Widget for scheduling posts for later publishing
class PostSchedulingWidget extends StatefulWidget {
  final Function(DateTime scheduledTime) onScheduled;
  final DateTime? initialDateTime;
  final bool enabled;
  
  const PostSchedulingWidget({
    super.key,
    required this.onScheduled,
    this.initialDateTime,
    this.enabled = true,
  });
  
  @override
  State<PostSchedulingWidget> createState() => _PostSchedulingWidgetState();
}

class _PostSchedulingWidgetState extends State<PostSchedulingWidget> {
  DateTime? _selectedDateTime;
  bool _isSchedulingEnabled = false;
  
  @override
  void initState() {
    super.initState();
    _selectedDateTime = widget.initialDateTime;
    _isSchedulingEnabled = widget.initialDateTime != null;
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Schedule Post',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _isSchedulingEnabled,
                  onChanged: widget.enabled ? _toggleScheduling : null,
                ),
              ],
            ),
            
            if (_isSchedulingEnabled) ...[
              const SizedBox(height: 16),
              
              // Date and time selection
              _buildDateTimeSelection(),
              
              const SizedBox(height: 16),
              
              // Quick schedule options
              _buildQuickScheduleOptions(),
              
              const SizedBox(height: 16),
              
              // Schedule summary
              if (_selectedDateTime != null)
                _buildScheduleSummary(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date and Time',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            // Date selection
            Expanded(
              child: InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDateTime != null
                            ? DateFormat('MMM d, yyyy').format(_selectedDateTime!)
                            : 'Select Date',
                        style: TextStyle(
                          color: _selectedDateTime != null
                              ? Colors.black
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Time selection
            Expanded(
              child: InkWell(
                onTap: _selectTime,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDateTime != null
                            ? DateFormat('h:mm a').format(_selectedDateTime!)
                            : 'Select Time',
                        style: TextStyle(
                          color: _selectedDateTime != null
                              ? Colors.black
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildQuickScheduleOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Schedule',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickOption('In 1 hour', DateTime.now().add(const Duration(hours: 1))),
            _buildQuickOption('Tomorrow 9 AM', _getTomorrowAt(9)),
            _buildQuickOption('Tomorrow 6 PM', _getTomorrowAt(18)),
            _buildQuickOption('Next Monday 9 AM', _getNextMondayAt(9)),
          ],
        ),
      ],
    );
  }
  
  Widget _buildQuickOption(String label, DateTime dateTime) {
    final isSelected = _selectedDateTime != null &&
        _selectedDateTime!.isAtSameMomentAs(dateTime);
    
    return InkWell(
      onTap: () => _setDateTime(dateTime),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildScheduleSummary() {
    final now = DateTime.now();
    final timeDiff = _selectedDateTime!.difference(now);
    
    String timeUntil;
    if (timeDiff.inDays > 0) {
      timeUntil = '${timeDiff.inDays} day${timeDiff.inDays == 1 ? '' : 's'}';
    } else if (timeDiff.inHours > 0) {
      timeUntil = '${timeDiff.inHours} hour${timeDiff.inHours == 1 ? '' : 's'}';
    } else if (timeDiff.inMinutes > 0) {
      timeUntil = '${timeDiff.inMinutes} minute${timeDiff.inMinutes == 1 ? '' : 's'}';
    } else {
      timeUntil = 'less than a minute';
    }
    
    final isInPast = _selectedDateTime!.isBefore(now);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInPast
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isInPast
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInPast ? Icons.warning : Icons.schedule,
                size: 16,
                color: isInPast ? Colors.red : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                isInPast ? 'Invalid Schedule Time' : 'Scheduled for',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isInPast ? Colors.red : Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMM d, yyyy \'at\' h:mm a').format(_selectedDateTime!),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isInPast
                ? 'Please select a future date and time'
                : 'Post will be published in $timeUntil',
            style: TextStyle(
              fontSize: 12,
              color: isInPast ? Colors.red : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  void _toggleScheduling(bool enabled) {
    setState(() {
      _isSchedulingEnabled = enabled;
      if (!enabled) {
        _selectedDateTime = null;
      } else {
        _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
      }
    });
    
    if (_selectedDateTime != null) {
      widget.onScheduled(_selectedDateTime!);
    }
  }
  
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    
    if (!mounted) return;
    
    if (selectedDate != null) {
      final currentTime = _selectedDateTime?.timeOfDay ?? TimeOfDay.now();
      _setDateTime(DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        currentTime.hour,
        currentTime.minute,
      ));
    }
  }
  
  Future<void> _selectTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDateTime?.timeOfDay ?? TimeOfDay.now(),
    );
    
    if (!mounted) return;
    
    if (selectedTime != null) {
      final currentDate = _selectedDateTime ?? DateTime.now().add(const Duration(days: 1));
      _setDateTime(DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        selectedTime.hour,
        selectedTime.minute,
      ));
    }
  }
  
  void _setDateTime(DateTime dateTime) {
    setState(() {
      _selectedDateTime = dateTime;
    });
    widget.onScheduled(dateTime);
  }
  
  DateTime _getTomorrowAt(int hour) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, 0);
  }
  
  DateTime _getNextMondayAt(int hour) {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    final nextMonday = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day, hour, 0);
  }
}

extension on DateTime {
  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);
}

/// Scheduled posts list widget
class ScheduledPostsListWidget extends StatefulWidget {
  final String userId;
  final Function(Map<String, dynamic>)? onPostSelected;
  
  const ScheduledPostsListWidget({
    super.key,
    required this.userId,
    this.onPostSelected,
  });
  
  @override
  State<ScheduledPostsListWidget> createState() => _ScheduledPostsListWidgetState();
}

class _ScheduledPostsListWidgetState extends State<ScheduledPostsListWidget> {
  List<Map<String, dynamic>> _scheduledPosts = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadScheduledPosts();
  }
  
  Future<void> _loadScheduledPosts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final posts = await PostManagementService.getScheduledPosts(widget.userId);
      if (!mounted) return;
      setState(() {
        _scheduledPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_scheduledPosts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Scheduled Posts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your scheduled posts will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _scheduledPosts.length,
      itemBuilder: (context, index) {
        final post = _scheduledPosts[index];
        return _buildScheduledPostCard(post);
      },
    );
  }
  
  Widget _buildScheduledPostCard(Map<String, dynamic> post) {
    final title = post['title'] as String?;
    final content = post['content'] as String? ?? '';
    final scheduledTime = (post['scheduledTime'] as Timestamp).toDate();
    final isOverdue = scheduledTime.isBefore(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue ? Colors.red : Colors.blue,
          child: Icon(
            isOverdue ? Icons.warning : Icons.schedule,
            color: Colors.white,
          ),
        ),
        title: Text(
          title?.isNotEmpty == true ? title! : 'Untitled Post',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.length > 100 ? '${content.substring(0, 100)}...' : content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Scheduled: ${DateFormat('MMM d, h:mm a').format(scheduledTime)}',
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? Colors.red : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        onTap: () => widget.onPostSelected?.call(post),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(action, post),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'publish',
              child: Row(
                children: [
                  Icon(Icons.publish, size: 16),
                  SizedBox(width: 8),
                  Text('Publish Now'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'cancel',
              child: Row(
                children: [
                  Icon(Icons.cancel, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Cancel', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _handleAction(String action, Map<String, dynamic> post) async {
    switch (action) {
      case 'publish':
        // TODO: Implement publish now
        break;
      case 'edit':
        widget.onPostSelected?.call(post);
        break;
      case 'cancel':
        await _cancelPost(post);
        break;
    }
  }
  
  Future<void> _cancelPost(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Scheduled Post'),
        content: const Text('Are you sure you want to cancel this scheduled post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Post'),
          ),
        ],
      ),
    );
    
    if (!mounted) return;
    
    if (confirmed == true) {
      try {
        await PostManagementService.cancelScheduledPost(post['id']);
        if (!mounted) return;
        _loadScheduledPosts();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

