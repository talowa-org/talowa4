// Enhanced Moderation Screen - Complete content moderation system
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin/enhanced_admin_auth_service.dart';

class EnhancedModerationScreen extends StatefulWidget {
  const EnhancedModerationScreen({super.key});

  @override
  State<EnhancedModerationScreen> createState() => _EnhancedModerationScreenState();
}

class _EnhancedModerationScreenState extends State<EnhancedModerationScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _flaggedActivities = [];
  List<Map<String, dynamic>> _reportedUsers = [];
  List<Map<String, dynamic>> _moderationHistory = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadModerationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadModerationData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load data in parallel
      final futures = await Future.wait([
        _loadFlaggedActivities(),
        _loadReportedUsers(),
        _loadModerationHistory(),
      ]);

      setState(() {
        _flaggedActivities = futures[0];
        _reportedUsers = futures[1];
        _moderationHistory = futures[2];
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }  Future<
List<Map<String, dynamic>>> _loadFlaggedActivities() async {
    try {
      final snapshot = await _firestore
          .collection('flagged_activities')
          .where('resolved', isEqualTo: false)
          .orderBy('flaggedAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

    } catch (e) {
      debugPrint('Error loading flagged activities: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadReportedUsers() async {
    try {
      // Get users with high referral counts or suspicious patterns
      final usersSnapshot = await _firestore.collection('users').get();
      final reportedUsers = <Map<String, dynamic>>[];

      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        final referralStats = userData['referralStats'] as Map<String, dynamic>? ?? {};
        final directReferrals = referralStats['directReferrals'] as int? ?? 0;
        final teamSize = referralStats['teamSize'] as int? ?? 0;
        
        // Flag users with suspicious activity
        if (directReferrals > 20 || teamSize > 100 || userData['status'] == 'flagged') {
          reportedUsers.add({
            'id': doc.id,
            'phoneNumber': userData['phoneNumber'],
            'name': userData['name'] ?? 'Unknown',
            'directReferrals': directReferrals,
            'teamSize': teamSize,
            'status': userData['status'] ?? 'active',
            'createdAt': userData['createdAt'],
            'lastLogin': userData['lastLogin'],
            'suspicionLevel': _calculateSuspicionLevel(directReferrals, teamSize, userData),
          });
        }
      }

      // Sort by suspicion level
      reportedUsers.sort((a, b) => (b['suspicionLevel'] as int).compareTo(a['suspicionLevel'] as int));
      
      return reportedUsers.take(30).toList();

    } catch (e) {
      debugPrint('Error loading reported users: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadModerationHistory() async {
    try {
      final snapshot = await _firestore
          .collection('moderation_actions')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

    } catch (e) {
      debugPrint('Error loading moderation history: $e');
      return [];
    }
  }

  int _calculateSuspicionLevel(int directReferrals, int teamSize, Map<String, dynamic> userData) {
    int suspicion = 0;
    
    // High referral count
    if (directReferrals > 50) suspicion += 3;
    else if (directReferrals > 20) suspicion += 2;
    else if (directReferrals > 10) suspicion += 1;
    
    // Large team size
    if (teamSize > 200) suspicion += 3;
    else if (teamSize > 100) suspicion += 2;
    else if (teamSize > 50) suspicion += 1;
    
    // Account age vs referrals
    final createdAt = userData['createdAt'] as Timestamp?;
    if (createdAt != null && directReferrals > 0) {
      final accountAge = DateTime.now().difference(createdAt.toDate()).inDays;
      if (accountAge < 7 && directReferrals > 10) suspicion += 2;
      else if (accountAge < 30 && directReferrals > 30) suspicion += 1;
    }
    
    // Already flagged
    if (userData['status'] == 'flagged') suspicion += 2;
    
    return suspicion.clamp(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Moderation'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.flag),
              text: 'Flagged (${_flaggedActivities.length})',
            ),
            Tab(
              icon: const Icon(Icons.report_problem),
              text: 'Reported (${_reportedUsers.length})',
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: 'History (${_moderationHistory.length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadModerationData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading moderation data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadModerationData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildFlaggedActivitiesTab(),
        _buildReportedUsersTab(),
        _buildModerationHistoryTab(),
      ],
    );
  }

  Widget _buildFlaggedActivitiesTab() {
    if (_flaggedActivities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No flagged activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('All activities have been reviewed'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadModerationData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _flaggedActivities.length,
        itemBuilder: (context, index) {
          final activity = _flaggedActivities[index];
          return _buildFlaggedActivityCard(activity);
        },
      ),
    );
  }

  Widget _buildFlaggedActivityCard(Map<String, dynamic> activity) {
    final type = activity['type'] as String? ?? 'unknown';
    final details = activity['details'] as Map<String, dynamic>? ?? {};
    final flaggedAt = activity['flaggedAt'] as Timestamp?;
    
    Color typeColor = Colors.orange;
    IconData typeIcon = Icons.flag;
    
    switch (type) {
      case 'high_referral_count':
        typeColor = Colors.red;
        typeIcon = Icons.trending_up;
        break;
      case 'rapid_referral_growth':
        typeColor = Colors.deepOrange;
        typeIcon = Icons.speed;
        break;
      case 'suspicious_pattern':
        typeColor = Colors.purple;
        typeIcon = Icons.pattern;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(typeIcon, color: typeColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatActivityType(type),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (flaggedAt != null)
                        Text(
                          'Flagged: ${_formatDateTime(flaggedAt.toDate())}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'FLAGGED',
                    style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Activity details
            if (details.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Details:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...details.entries.map((entry) => Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 12),
                    )).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _resolveFlag(activity['id'], false),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _investigateActivity(activity),
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Investigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportedUsersTab() {
    if (_reportedUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No reported users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('No users require moderation'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadModerationData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reportedUsers.length,
        itemBuilder: (context, index) {
          final user = _reportedUsers[index];
          return _buildReportedUserCard(user);
        },
      ),
    );
  }

  Widget _buildReportedUserCard(Map<String, dynamic> user) {
    final suspicionLevel = user['suspicionLevel'] as int? ?? 0;
    final status = user['status'] as String? ?? 'active';
    
    Color suspicionColor = Colors.green;
    String suspicionText = 'Low';
    
    if (suspicionLevel >= 7) {
      suspicionColor = Colors.red;
      suspicionText = 'High';
    } else if (suspicionLevel >= 4) {
      suspicionColor = Colors.orange;
      suspicionText = 'Medium';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: suspicionColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: suspicionColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] as String? ?? 'Unknown User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        user['phoneNumber'] as String? ?? 'No phone',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: suspicionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$suspicionText Risk',
                    style: TextStyle(color: suspicionColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // User stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${user['directReferrals'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const Text('Direct Referrals', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${user['teamSize'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const Text('Team Size', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: status == 'banned' ? Colors.red : Colors.green,
                          ),
                        ),
                        const Text('Status', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewUserDetails(user),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                if (status != 'banned')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showModerationDialog(user),
                      icon: const Icon(Icons.gavel, size: 16),
                      label: const Text('Moderate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _unbanUser(user['id']),
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Unban'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationHistoryTab() {
    if (_moderationHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No moderation history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('No moderation actions have been taken'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadModerationData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _moderationHistory.length,
        itemBuilder: (context, index) {
          final action = _moderationHistory[index];
          return _buildModerationHistoryCard(action);
        },
      ),
    );
  }

  Widget _buildModerationHistoryCard(Map<String, dynamic> action) {
    final actionType = action['action'] as String? ?? 'unknown';
    final timestamp = action['timestamp'] as Timestamp?;
    final reason = action['reason'] as String? ?? 'No reason provided';
    
    IconData actionIcon = Icons.gavel;
    Color actionColor = Colors.blue;
    
    switch (actionType) {
      case 'ban_user':
        actionIcon = Icons.block;
        actionColor = Colors.red;
        break;
      case 'unban_user':
        actionIcon = Icons.restore;
        actionColor = Colors.green;
        break;
      case 'warn_user':
        actionIcon = Icons.warning;
        actionColor = Colors.orange;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(actionIcon, color: actionColor),
        title: Text(_formatActionType(actionType)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reason: $reason'),
            if (timestamp != null)
              Text(
                _formatDateTime(timestamp.toDate()),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: actionColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            actionType.toUpperCase(),
            style: TextStyle(color: actionColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // Helper methods
  String _formatActivityType(String type) {
    switch (type) {
      case 'high_referral_count':
        return 'High Referral Count';
      case 'rapid_referral_growth':
        return 'Rapid Referral Growth';
      case 'suspicious_pattern':
        return 'Suspicious Pattern';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatActionType(String action) {
    switch (action) {
      case 'ban_user':
        return 'User Banned';
      case 'unban_user':
        return 'User Unbanned';
      case 'warn_user':
        return 'User Warned';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Action methods
  Future<void> _resolveFlag(String flagId, bool actionTaken) async {
    try {
      await _firestore.collection('flagged_activities').doc(flagId).update({
        'resolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
        'actionTaken': actionTaken,
      });

      _loadModerationData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flag resolved successfully'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resolving flag: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _investigateActivity(Map<String, dynamic> activity) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Investigation Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Activity Type: ${_formatActivityType(activity['type'] ?? 'unknown')}'),
              const SizedBox(height: 8),
              Text('User ID: ${activity['uid'] ?? 'Unknown'}'),
              const SizedBox(height: 8),
              Text('Phone: ${activity['phoneNumber'] ?? 'Unknown'}'),
              const SizedBox(height: 8),
              const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...((activity['details'] as Map<String, dynamic>? ?? {}).entries.map((entry) =>
                Text('${entry.key}: ${entry.value}')
              )).toList(),
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
              Navigator.of(context).pop();
              _resolveFlag(activity['id'], true);
            },
            child: const Text('Take Action'),
          ),
        ],
      ),
    );
  }

  void _viewUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? 'User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Phone: ${user['phoneNumber'] ?? 'Unknown'}'),
              Text('Direct Referrals: ${user['directReferrals'] ?? 0}'),
              Text('Team Size: ${user['teamSize'] ?? 0}'),
              Text('Status: ${user['status'] ?? 'active'}'),
              Text('Suspicion Level: ${user['suspicionLevel'] ?? 0}/10'),
              if (user['createdAt'] != null)
                Text('Joined: ${_formatDateTime((user['createdAt'] as Timestamp).toDate())}'),
              if (user['lastLogin'] != null)
                Text('Last Login: ${_formatDateTime((user['lastLogin'] as Timestamp).toDate())}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showModerationDialog(Map<String, dynamic> user) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Moderate User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('User: ${user['name'] ?? 'Unknown'}'),
            Text('Phone: ${user['phoneNumber'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for action',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _banUser(user['id'], reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ban User'),
          ),
        ],
      ),
    );
  }

  Future<void> _banUser(String userId, String reason) async {
    try {
      // For now, just update the user status directly
      await _firestore.collection('users').doc(userId).update({
        'status': 'banned',
        'bannedAt': FieldValue.serverTimestamp(),
        'banReason': reason.isEmpty ? 'Suspicious activity detected' : reason,
      });

      _loadModerationData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User banned successfully'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error banning user: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _unbanUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'active',
        'unbannedAt': FieldValue.serverTimestamp(),
        'banReason': FieldValue.delete(),
      });

      _loadModerationData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unbanned successfully'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unbanning user: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}