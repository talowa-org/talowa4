// Security Dashboard Widget for TALOWA
// Displays security metrics, audit logs, and compliance status

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/security/enterprise_security_service.dart';

class SecurityDashboardWidget extends StatefulWidget {
  final bool isCompact;
  final VoidCallback? onViewDetails;
  
  const SecurityDashboardWidget({
    Key? key,
    this.isCompact = true,
    this.onViewDetails,
  }) : super(key: key);
  
  @override
  State<SecurityDashboardWidget> createState() => _SecurityDashboardWidgetState();
}

class _SecurityDashboardWidgetState extends State<SecurityDashboardWidget>
    with TickerProviderStateMixin {
  final EnterpriseSecurityService _securityService = EnterpriseSecurityService();
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Data
  Map<String, dynamic> _securityMetrics = {};
  List<AuditEvent> _recentAuditEvents = [];
  SecurityStatus _securityStatus = SecurityStatus.secure;
  
  // State
  bool _isLoading = true;
  Timer? _refreshTimer;
  StreamSubscription<AuditEvent>? _auditSubscription;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSecurityMonitoring();
    _loadSecurityData();
    _startPeriodicRefresh();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _slideController.forward();
  }
  
  void _initializeSecurityMonitoring() {
    _auditSubscription = _securityService.auditEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _recentAuditEvents.insert(0, event);
          if (_recentAuditEvents.length > 10) {
            _recentAuditEvents.removeLast();
          }
          _updateSecurityStatus();
        });
        
        // Trigger pulse animation for critical events
        if (event.severity == AuditSeverity.critical) {
          _pulseController.repeat(reverse: true);
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _pulseController.stop();
          });
        }
      }
    });
  }
  
  Future<void> _loadSecurityData() async {
    try {
      final metrics = await _securityService.getSecurityMetrics();
      
      if (mounted) {
        setState(() {
          _securityMetrics = metrics;
          _isLoading = false;
          _updateSecurityStatus();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _securityStatus = SecurityStatus.warning;
        });
      }
    }
  }
  
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadSecurityData();
      }
    });
  }
  
  void _updateSecurityStatus() {
    final failedLogins = _securityMetrics['failed_logins_24h'] ?? 0;
    final detectedThreats = _securityMetrics['detected_threats'] ?? 0;
    final criticalEvents = _recentAuditEvents
        .where((e) => e.severity == AuditSeverity.critical)
        .length;
    
    if (criticalEvents > 0 || detectedThreats > 5) {
      _securityStatus = SecurityStatus.critical;
    } else if (failedLogins > 10 || detectedThreats > 0) {
      _securityStatus = SecurityStatus.warning;
    } else {
      _securityStatus = SecurityStatus.secure;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: widget.isCompact ? _buildCompactView() : _buildDetailedView(),
    );
  }
  
  Widget _buildCompactView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getStatusColor().withOpacity(0.1),
            _getStatusColor().withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _securityStatus == SecurityStatus.critical
                        ? _pulseAnimation.value
                        : 1.0,
                    child: Icon(
                      _getStatusIcon(),
                      color: _getStatusColor(),
                      size: 24,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getStatusText(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onViewDetails != null)
                IconButton(
                  onPressed: widget.onViewDetails,
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  tooltip: 'View Details',
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            _buildMetricsRow(),
        ],
      ),
    );
  }
  
  Widget _buildDetailedView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailedHeader(),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else ...[
            _buildDetailedMetrics(),
            const SizedBox(height: 20),
            _buildRecentAuditEvents(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDetailedHeader() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _securityStatus == SecurityStatus.critical
                  ? _pulseAnimation.value
                  : 1.0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 32,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enterprise Security Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Status: ${_getStatusText()}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _getStatusColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
            'Active Sessions',
            '${_securityMetrics['active_sessions'] ?? 0}',
            Icons.people_outline,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricItem(
            'Failed Logins',
            '${_securityMetrics['failed_logins_24h'] ?? 0}',
            Icons.warning_outlined,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricItem(
            'Threats',
            '${_securityMetrics['detected_threats'] ?? 0}',
            Icons.security,
            Colors.red,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailedMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Metrics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildDetailedMetricCard(
              'Active Sessions',
              '${_securityMetrics['active_sessions'] ?? 0}',
              Icons.people_outline,
              Colors.blue,
            ),
            _buildDetailedMetricCard(
              'Recent Events',
              '${_securityMetrics['recent_audit_events'] ?? 0}',
              Icons.event_note,
              Colors.green,
            ),
            _buildDetailedMetricCard(
              'Failed Logins (24h)',
              '${_securityMetrics['failed_logins_24h'] ?? 0}',
              Icons.warning_outlined,
              Colors.orange,
            ),
            _buildDetailedMetricCard(
              'Security Threats',
              '${_securityMetrics['detected_threats'] ?? 0}',
              Icons.security,
              Colors.red,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildRecentAuditEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Audit Events',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_recentAuditEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No recent audit events'),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentAuditEvents.length.clamp(0, 5),
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = _recentAuditEvents[index];
              return _buildAuditEventTile(event);
            },
          ),
      ],
    );
  }
  
  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailedMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAuditEventTile(AuditEvent event) {
    return ListTile(
      dense: true,
      leading: Icon(
        _getEventIcon(event.eventType),
        color: _getSeverityColor(event.severity),
        size: 20,
      ),
      title: Text(
        event.description,
        style: const TextStyle(fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatTimestamp(event.timestamp),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _getSeverityColor(event.severity).withOpacity(0.1),
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
    );
  }
  
  Color _getStatusColor() {
    switch (_securityStatus) {
      case SecurityStatus.secure:
        return Colors.green;
      case SecurityStatus.warning:
        return Colors.orange;
      case SecurityStatus.critical:
        return Colors.red;
    }
  }
  
  IconData _getStatusIcon() {
    switch (_securityStatus) {
      case SecurityStatus.secure:
        return Icons.security;
      case SecurityStatus.warning:
        return Icons.warning;
      case SecurityStatus.critical:
        return Icons.error;
    }
  }
  
  String _getStatusText() {
    switch (_securityStatus) {
      case SecurityStatus.secure:
        return 'All Systems Secure';
      case SecurityStatus.warning:
        return 'Monitoring Issues';
      case SecurityStatus.critical:
        return 'Critical Threats Detected';
    }
  }
  
  IconData _getEventIcon(AuditEventType eventType) {
    switch (eventType) {
      case AuditEventType.userLogin:
        return Icons.login;
      case AuditEventType.userLogout:
        return Icons.logout;
      case AuditEventType.loginFailed:
        return Icons.error_outline;
      case AuditEventType.securityThreat:
        return Icons.warning;
      case AuditEventType.dataAccess:
        return Icons.folder_open;
      case AuditEventType.dataModification:
        return Icons.edit;
      case AuditEventType.complianceReport:
        return Icons.assessment;
      case AuditEventType.configurationChange:
        return Icons.settings;
      default:
        return Icons.info;
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
  
  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _refreshTimer?.cancel();
    _auditSubscription?.cancel();
    super.dispose();
  }
}

// Security status enum
enum SecurityStatus {
  secure,
  warning,
  critical,
}

