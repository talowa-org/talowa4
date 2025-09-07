// Audit Trail Widget for TALOWA
// Displays detailed audit logs and security events

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/security/enterprise_security_service.dart';

class AuditTrailWidget extends StatefulWidget {
  final bool showFilters;
  final int maxEvents;
  
  const AuditTrailWidget({
    super.key,
    this.showFilters = true,
    this.maxEvents = 50,
  });
  
  @override
  State<AuditTrailWidget> createState() => _AuditTrailWidgetState();
}

class _AuditTrailWidgetState extends State<AuditTrailWidget>
    with TickerProviderStateMixin {
  final EnterpriseSecurityService _securityService = EnterpriseSecurityService();
  final ScrollController _scrollController = ScrollController();
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _listAnimation;
  
  // State
  List<AuditEvent> _auditEvents = [];
  List<AuditEvent> _filteredEvents = [];
  bool _isLoading = true;
  bool _isAutoScrollEnabled = true;
  StreamSubscription<AuditEvent>? _auditSubscription;
  
  // Filters
  AuditEventType? _selectedEventType;
  AuditSeverity? _selectedSeverity;
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAuditStream();
    _loadInitialEvents();
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _listAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
  }
  
  void _initializeAuditStream() {
    _auditSubscription = _securityService.auditEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _auditEvents.insert(0, event);
          if (_auditEvents.length > widget.maxEvents) {
            _auditEvents.removeLast();
          }
          _applyFilters();
        });
        
        // Auto-scroll to top for new events
        if (_isAutoScrollEnabled && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        
        // Trigger list animation for new events
        _listController.reset();
        _listController.forward();
      }
    });
  }
  
  Future<void> _loadInitialEvents() async {
    try {
      // In a real implementation, this would load from the database
      // For now, we'll simulate with some sample events
      await Future.delayed(const Duration(seconds: 1));
      
      final sampleEvents = _generateSampleEvents();
      
      if (mounted) {
        setState(() {
          _auditEvents = sampleEvents;
          _isLoading = false;
          _applyFilters();
        });
        
        _listController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  List<AuditEvent> _generateSampleEvents() {
    final events = <AuditEvent>[];
    final now = DateTime.now();
    
    // Generate sample audit events
    events.add(AuditEvent(
      eventType: AuditEventType.systemStart,
      description: 'Enterprise Security Service initialized',
      severity: AuditSeverity.info,
      timestamp: now.subtract(const Duration(minutes: 5)),
    ));
    
    events.add(AuditEvent(
      eventType: AuditEventType.userLogin,
      userId: 'user123',
      description: 'User logged in successfully',
      severity: AuditSeverity.info,
      ipAddress: '192.168.1.100',
      timestamp: now.subtract(const Duration(minutes: 10)),
    ));
    
    events.add(AuditEvent(
      eventType: AuditEventType.loginFailed,
      description: 'Failed login attempt for user: admin',
      severity: AuditSeverity.warning,
      ipAddress: '192.168.1.200',
      timestamp: now.subtract(const Duration(minutes: 15)),
    ));
    
    events.add(AuditEvent(
      eventType: AuditEventType.dataAccess,
      userId: 'user456',
      description: 'User accessed sensitive data',
      severity: AuditSeverity.high,
      timestamp: now.subtract(const Duration(minutes: 20)),
    ));
    
    events.add(AuditEvent(
      eventType: AuditEventType.securityThreat,
      description: 'Brute force attack detected from IP: 10.0.0.1',
      severity: AuditSeverity.critical,
      ipAddress: '10.0.0.1',
      timestamp: now.subtract(const Duration(minutes: 25)),
    ));
    
    return events;
  }
  
  void _applyFilters() {
    _filteredEvents = _auditEvents.where((event) {
      // Event type filter
      if (_selectedEventType != null && event.eventType != _selectedEventType) {
        return false;
      }
      
      // Severity filter
      if (_selectedSeverity != null && event.severity != _selectedSeverity) {
        return false;
      }
      
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!event.description.toLowerCase().contains(query) &&
            !(event.userId?.toLowerCase().contains(query) ?? false) &&
            !(event.ipAddress?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      
      // Date range filter
      if (_startDate != null && event.timestamp.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && event.timestamp.isAfter(_endDate!)) {
        return false;
      }
      
      return true;
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            if (widget.showFilters) ...[
              _buildFilters(),
              const SizedBox(height: 20),
            ],
            _buildEventsList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.history,
            color: Colors.indigo,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audit Trail',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Real-time security events and audit logs',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _isAutoScrollEnabled = !_isAutoScrollEnabled;
                });
              },
              icon: Icon(
                _isAutoScrollEnabled ? Icons.pause : Icons.play_arrow,
                color: _isAutoScrollEnabled ? Colors.orange : Colors.green,
              ),
              tooltip: _isAutoScrollEnabled ? 'Pause Auto-scroll' : 'Enable Auto-scroll',
            ),
            IconButton(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear Filters',
            ),
            IconButton(
              onPressed: _exportAuditLog,
              icon: const Icon(Icons.download),
              tooltip: 'Export Audit Log',
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Search bar
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search events, users, or IP addresses...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Filter dropdowns
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown<AuditEventType>(
                  'Event Type',
                  _selectedEventType,
                  AuditEventType.values,
                  (value) => setState(() {
                    _selectedEventType = value;
                    _applyFilters();
                  }),
                  (type) => _getEventTypeName(type),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown<AuditSeverity>(
                  'Severity',
                  _selectedSeverity,
                  AuditSeverity.values,
                  (value) => setState(() {
                    _selectedSeverity = value;
                    _applyFilters();
                  }),
                  (severity) => severity.name.toUpperCase(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterDropdown<T>(
    String label,
    T? selectedValue,
    List<T> options,
    Function(T?) onChanged,
    String Function(T) getDisplayName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T?>(
              value: selectedValue,
              isExpanded: true,
              hint: Text('All ${label}s'),
              items: [
                DropdownMenuItem<T?>(
                  value: null,
                  child: Text('All ${label}s'),
                ),
                ...options.map((option) => DropdownMenuItem<T?>(
                  value: option,
                  child: Text(getDisplayName(option)),
                )),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEventsList() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Events (${_filteredEvents.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_filteredEvents.isNotEmpty)
                Text(
                  'Last updated: ${_formatTime(DateTime.now())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredEvents.isEmpty
                    ? _buildEmptyState()
                    : AnimatedBuilder(
                        animation: _listAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _listAnimation.value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - _listAnimation.value)),
                              child: _buildEventList(),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventList() {
    return ListView.separated(
      controller: _scrollController,
      itemCount: _filteredEvents.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = _filteredEvents[index];
        return _buildEventTile(event, index);
      },
    );
  }
  
  Widget _buildEventTile(AuditEvent event, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: index == 0 && _isAutoScrollEnabled
            ? _getSeverityColor(event.severity).withValues(alpha: 0.05)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _showEventDetails(event),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getSeverityColor(event.severity).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getEventIcon(event.eventType),
                color: _getSeverityColor(event.severity),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getSeverityColor(event.severity).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.severity.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getSeverityColor(event.severity),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (event.userId != null) ...[
                        Icon(
                          Icons.person,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.userId!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (event.ipAddress != null) ...[
                        Icon(
                          Icons.computer,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.ipAddress!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(event.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showEventDetails(event),
              icon: const Icon(Icons.info_outline, size: 16),
              tooltip: 'View Details',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No audit events found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedEventType != null || _selectedSeverity != null
                ? 'Try adjusting your filters'
                : 'Audit events will appear here as they occur',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  void _showEventDetails(AuditEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getEventIcon(event.eventType),
              color: _getSeverityColor(event.severity),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getEventTypeName(event.eventType),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Event ID', event.id),
              _buildDetailRow('Description', event.description),
              _buildDetailRow('Severity', event.severity.name.toUpperCase()),
              _buildDetailRow('Timestamp', _formatDateTime(event.timestamp)),
              if (event.userId != null)
                _buildDetailRow('User ID', event.userId!),
              if (event.sessionId != null)
                _buildDetailRow('Session ID', event.sessionId!),
              if (event.ipAddress != null)
                _buildDetailRow('IP Address', event.ipAddress!),
              if (event.userAgent != null)
                _buildDetailRow('User Agent', event.userAgent!),
              if (event.deviceFingerprint != null)
                _buildDetailRow('Device', event.deviceFingerprint!),
              if (event.metadata != null && event.metadata!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Additional Data',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.metadata.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: event.id));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Event ID copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copy ID'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  void _clearFilters() {
    setState(() {
      _selectedEventType = null;
      _selectedSeverity = null;
      _searchQuery = '';
      _startDate = null;
      _endDate = null;
      _applyFilters();
    });
  }
  
  void _exportAuditLog() {
    // In a real implementation, this would export the audit log
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audit log export functionality would be implemented here'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // Helper methods
  IconData _getEventIcon(AuditEventType eventType) {
    switch (eventType) {
      case AuditEventType.systemStart:
        return Icons.power_settings_new;
      case AuditEventType.systemStop:
        return Icons.power_off;
      case AuditEventType.userLogin:
        return Icons.login;
      case AuditEventType.userLogout:
        return Icons.logout;
      case AuditEventType.loginFailed:
        return Icons.error_outline;
      case AuditEventType.dataAccess:
        return Icons.folder_open;
      case AuditEventType.dataModification:
        return Icons.edit;
      case AuditEventType.securityThreat:
        return Icons.warning;
      case AuditEventType.complianceReport:
        return Icons.assessment;
      case AuditEventType.configurationChange:
        return Icons.settings;
    }
  }
  
  Color _getSeverityColor(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.info:
        return Colors.blue;
      case AuditSeverity.warning:
        return Colors.orange;
      case AuditSeverity.high:
        return Colors.red;
      case AuditSeverity.critical:
        return Colors.red[800]!;
    }
  }
  
  String _getEventTypeName(AuditEventType eventType) {
    switch (eventType) {
      case AuditEventType.systemStart:
        return 'System Start';
      case AuditEventType.systemStop:
        return 'System Stop';
      case AuditEventType.userLogin:
        return 'User Login';
      case AuditEventType.userLogout:
        return 'User Logout';
      case AuditEventType.loginFailed:
        return 'Login Failed';
      case AuditEventType.dataAccess:
        return 'Data Access';
      case AuditEventType.dataModification:
        return 'Data Modification';
      case AuditEventType.securityThreat:
        return 'Security Threat';
      case AuditEventType.complianceReport:
        return 'Compliance Report';
      case AuditEventType.configurationChange:
        return 'Configuration Change';
    }
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
  
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _listController.dispose();
    _scrollController.dispose();
    _auditSubscription?.cancel();
    super.dispose();
  }
}
