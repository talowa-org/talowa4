import 'package:flutter/material.dart';
import '../../models/voice_call.dart';
import '../../services/messaging/call_history_service.dart';
import '../../services/messaging/webrtc_service.dart';
import '../../widgets/messaging/participant_avatar.dart';
import '../../models/call_participant.dart';
import 'voice_call_screen.dart';

/// Call history screen showing past calls and missed calls
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen>
    with SingleTickerProviderStateMixin {
  final CallHistoryService _callHistoryService = CallHistoryService();
  final WebRTCService _webrtcService = WebRTCService();

  late TabController _tabController;
  List<CallHistoryEntry> _allCalls = [];
  List<MissedCallNotification> _missedCalls = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCallHistory();
    _loadMissedCalls();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCallHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final calls = await _callHistoryService.getCallHistory(limit: 100);
      
      setState(() {
        _allCalls = calls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load call history: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMissedCalls() async {
    try {
      final missed = await _callHistoryService.getMissedCalls(limit: 50);
      
      setState(() {
        _missedCalls = missed;
      });
    } catch (e) {
      debugPrint('Failed to load missed calls: $e');
    }
  }

  Future<void> _makeCall(String participantId, String participantName) async {
    try {
      final callSession = await _webrtcService.initiateCall(participantId, 'voice');
      
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VoiceCallScreen(
              callSession: callSession,
              isIncoming: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to make call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCall(String callId) async {
    try {
      await _callHistoryService.deleteCallFromHistory(callId);
      await _loadCallHistory();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call deleted from history')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markMissedCallAsRead(String callId) async {
    try {
      await _callHistoryService.markMissedCallAsRead(callId);
      await _loadMissedCalls();
    } catch (e) {
      debugPrint('Failed to mark missed call as read: $e');
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Call History'),
        content: const Text('Are you sure you want to clear all call history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _callHistoryService.clearCallHistory();
        await _loadCallHistory();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call history cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear history: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'All Calls',
              icon: Badge(
                isLabelVisible: _allCalls.isNotEmpty,
                label: Text('${_allCalls.length}'),
                child: const Icon(Icons.call),
              ),
            ),
            Tab(
              text: 'Missed',
              icon: Badge(
                isLabelVisible: _missedCalls.where((c) => !c.isRead).isNotEmpty,
                label: Text('${_missedCalls.where((c) => !c.isRead).length}'),
                child: const Icon(Icons.call_missed),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _clearAllHistory();
                  break;
                case 'refresh':
                  _loadCallHistory();
                  _loadMissedCalls();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all, color: Colors.red),
                  title: Text('Clear History', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllCallsTab(),
          _buildMissedCallsTab(),
        ],
      ),
    );
  }

  Widget _buildAllCallsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCallHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_allCalls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No call history',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your call history will appear here',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCallHistory,
      child: ListView.builder(
        itemCount: _allCalls.length,
        itemBuilder: (context, index) {
          final call = _allCalls[index];
          return _buildCallHistoryItem(call);
        },
      ),
    );
  }

  Widget _buildMissedCallsTab() {
    if (_missedCalls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_missed_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No missed calls',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Missed calls will appear here',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMissedCalls,
      child: ListView.builder(
        itemCount: _missedCalls.length,
        itemBuilder: (context, index) {
          final missedCall = _missedCalls[index];
          return _buildMissedCallItem(missedCall);
        },
      ),
    );
  }

  Widget _buildCallHistoryItem(CallHistoryEntry call) {
    final participant = CallParticipant(
      userId: call.participantId,
      name: call.participantName,
      role: call.participantRole,
    );

    return Dismissible(
      key: Key(call.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteCall(call.id),
      child: ListTile(
        leading: ParticipantAvatar(
          participant: participant,
          size: 48,
        ),
        title: Text(
          call.participantName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCallStatusIcon(call),
                  size: 16,
                  color: _getCallStatusColor(call),
                ),
                const SizedBox(width: 4),
                Text(
                  call.participantRole.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  call.formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (call.duration > 0)
              Text(
                'Duration: ${call.formattedDuration}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.call),
          onPressed: () => _makeCall(call.participantId, call.participantName),
        ),
        onTap: () => _makeCall(call.participantId, call.participantName),
      ),
    );
  }

  Widget _buildMissedCallItem(MissedCallNotification missedCall) {
    final participant = CallParticipant(
      userId: missedCall.callerId,
      name: missedCall.callerName,
      role: missedCall.callerRole,
    );

    return ListTile(
      leading: ParticipantAvatar(
        participant: participant,
        size: 48,
      ),
      title: Text(
        missedCall.callerName,
        style: TextStyle(
          fontWeight: missedCall.isRead ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.call_missed,
                size: 16,
                color: Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                missedCall.callerRole.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(missedCall.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (!missedCall.isRead)
            const Text(
              'Missed call',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.call),
        onPressed: () => _makeCall(missedCall.callerId, missedCall.callerName),
      ),
      onTap: () {
        if (!missedCall.isRead) {
          _markMissedCallAsRead(missedCall.id);
        }
        _makeCall(missedCall.callerId, missedCall.callerName);
      },
    );
  }

  IconData _getCallStatusIcon(CallHistoryEntry call) {
    switch (call.status) {
      case 'completed':
        return call.isIncoming ? Icons.call_received : Icons.call_made;
      case 'missed':
        return Icons.call_missed;
      case 'rejected':
        return Icons.call_end;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.call;
    }
  }

  Color _getCallStatusColor(CallHistoryEntry call) {
    switch (call.status) {
      case 'completed':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'rejected':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}