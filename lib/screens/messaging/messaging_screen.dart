import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/voice_call.dart';
import '../../services/messaging/voice_calling_integration_service.dart';
import '../../services/messaging/user_discovery_service.dart';
import 'voice_call_screen.dart';

/// Main messaging screen with voice calling functionality
class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final VoiceCallingIntegrationService _voiceService = VoiceCallingIntegrationService();
  final UserDiscoveryService _userService = UserDiscoveryService();
  
  List<UserModel> _users = [];
  List<CallHistoryEntry> _callHistory = [];
  List<MissedCallNotification> _missedCalls = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
    _setupCallListeners();
  }

  Future<void> _initializeServices() async {
    try {
      await _voiceService.initialize();
      await _userService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize services: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      final users = await _userService.getAllActiveUsers(limit: 50);
      final callHistory = await _voiceService.getCallHistory(limit: 20);
      final missedCalls = await _voiceService.getMissedCalls(unreadOnly: true);
      
      setState(() {
        _users = users;
        _callHistory = callHistory;
        _missedCalls = missedCalls;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupCallListeners() {
    // Listen for incoming calls
    _voiceService.onIncomingCall.listen((incomingCall) {
      _showIncomingCallDialog(incomingCall);
    });

    // Listen for call status changes
    _voiceService.onCallStatusChange.listen((callStatus) {
      debugPrint('Call status changed: ${callStatus.status}');
      if (callStatus.status == 'connected') {
        final callSession = _voiceService.getCallSession(callStatus.callId);
        if (callSession != null) {
          _navigateToCallScreen(callSession);
        }
      }
    });
  }

  void _showIncomingCallDialog(IncomingCall incomingCall) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${incomingCall.callerName} is calling you'),
            Text('Role: ${incomingCall.callerRole}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _voiceService.rejectCall(incomingCall.id);
            },
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final callSession = await _voiceService.acceptCall(incomingCall.id);
                _navigateToCallScreen(callSession);
              } catch (e) {
                _showErrorSnackBar('Failed to accept call: $e');
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _navigateToCallScreen(CallSession callSession) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          callSession: callSession,
          isIncoming: true,
        ),
      ),
    );
  }

  Future<void> _initiateCall(UserModel user) async {
    try {
      // Check user availability first
      final availability = await _voiceService.checkUserAvailability(user.id);
      
      if (!availability.isAvailable) {
        _showErrorSnackBar(availability.message);
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Initiating call...'),
            ],
          ),
        ),
      );

      // Initiate the call
      final callSession = await _voiceService.initiateCall(user.id);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        _navigateToCallScreen(callSession);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showErrorSnackBar('Failed to initiate call: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  List<UserModel> _getFilteredUsers() {
    if (_searchQuery.isEmpty) {
      return _users;
    }
    
    return _users.where((user) {
      return user.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             user.phoneNumber.contains(_searchQuery) ||
             user.role.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages & Calls'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Users', icon: Icon(Icons.people)),
              Tab(text: 'History', icon: Icon(Icons.history)),
              Tab(text: 'Missed', icon: Icon(Icons.call_missed)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersTab(),
            _buildHistoryTab(),
            _buildMissedCallsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search users...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Users list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildUsersList(),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    final filteredUsers = _getFilteredUsers();
    
    if (filteredUsers.isEmpty) {
      return const Center(
        child: Text('No users found'),
      );
    }

    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(user.fullName.isNotEmpty ? user.fullName[0] : '?'),
          ),
          title: Text(user.fullName),
          subtitle: Text('${user.role} • ${user.phoneNumber}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  // TODO: Navigate to chat screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Messaging feature coming soon')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: () => _initiateCall(user),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    if (_callHistory.isEmpty) {
      return const Center(
        child: Text('No call history'),
      );
    }

    return ListView.builder(
      itemCount: _callHistory.length,
      itemBuilder: (context, index) {
        final call = _callHistory[index];
        return ListTile(
          leading: Icon(
            call.isIncoming ? Icons.call_received : Icons.call_made,
            color: _getCallStatusColor(call.status),
          ),
          title: Text(call.participantName),
          subtitle: Text('${call.participantRole} • ${call.formattedTime}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                call.status.toUpperCase(),
                style: TextStyle(
                  color: _getCallStatusColor(call.status),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (call.duration > 0)
                Text(
                  call.formattedDuration,
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          onTap: () {
            // TODO: Show call details or call back
          },
        );
      },
    );
  }

  Widget _buildMissedCallsTab() {
    if (_missedCalls.isEmpty) {
      return const Center(
        child: Text('No missed calls'),
      );
    }

    return ListView.builder(
      itemCount: _missedCalls.length,
      itemBuilder: (context, index) {
        final missedCall = _missedCalls[index];
        return ListTile(
          leading: const Icon(
            Icons.call_missed,
            color: Colors.red,
          ),
          title: Text(missedCall.callerName),
          subtitle: Text('${missedCall.callerRole} • ${_formatTimestamp(missedCall.timestamp)}'),
          trailing: IconButton(
            icon: const Icon(Icons.call_back),
            onPressed: () {
              // TODO: Call back the missed caller
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call back feature coming soon')),
              );
            },
          ),
          onTap: () async {
            // Mark as read
            await _voiceService.markMissedCallAsRead(missedCall.id);
            setState(() {
              _missedCalls.removeAt(index);
            });
          },
        );
      },
    );
  }

  Color _getCallStatusColor(String status) {
    switch (status) {
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