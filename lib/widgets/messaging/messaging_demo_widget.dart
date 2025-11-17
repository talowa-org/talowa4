// Demo Widget for TALOWA Messaging Error Handling and Loading States
// Demonstrates Task 8 implementation

import 'package:flutter/material.dart';
import '../../services/messaging/messaging_error_integration.dart';
import '../../services/messaging/loading_state_service.dart';
import 'messaging_error_widget.dart';
import 'loading_indicator_widget.dart';

/// Demo widget showing error handling and loading states
class MessagingDemoWidget extends StatefulWidget {
  const MessagingDemoWidget({super.key});

  @override
  State<MessagingDemoWidget> createState() => _MessagingDemoWidgetState();
}

class _MessagingDemoWidgetState extends State<MessagingDemoWidget> {
  final MessagingErrorIntegration _errorIntegration = MessagingErrorIntegration();
  final Map<String, LoadingState?> _loadingStates = {};
  final Map<String, dynamic> _results = {};
  final Map<String, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _errorIntegration.initialize();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging Error Handling Demo'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNetworkStatus(),
            const SizedBox(height: 24),
            _buildOperationButtons(),
            const SizedBox(height: 24),
            _buildLoadingStates(),
            const SizedBox(height: 24),
            _buildResults(),
            const SizedBox(height: 24),
            _buildSystemStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStatus() {
    return StreamBuilder<bool>(
      stream: _errorIntegration.networkStatusStream,
      initialData: _errorIntegration.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOnline ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? Colors.green.shade600 : Colors.red.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isOnline ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
              const Spacer(),
              StreamBuilder<NetworkQuality>(
                stream: _errorIntegration.networkQualityStream,
                initialData: _errorIntegration.networkQuality,
                builder: (context, qualitySnapshot) {
                  final quality = qualitySnapshot.data ?? NetworkQuality.unknown;
                  return Text(
                    'Quality: ${quality.toString().split('.').last}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperationButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Test Operations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: () => _testSendMessage(),
              child: const Text('Send Message'),
            ),
            ElevatedButton(
              onPressed: () => _testLoadMessages(),
              child: const Text('Load Messages'),
            ),
            ElevatedButton(
              onPressed: () => _testUploadFile(),
              child: const Text('Upload File'),
            ),
            ElevatedButton(
              onPressed: () => _testSearchUsers(),
              child: const Text('Search Users'),
            ),
            ElevatedButton(
              onPressed: () => _testVoiceCall(),
              child: const Text('Voice Call'),
            ),
            ElevatedButton(
              onPressed: () => _testFailingOperation(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Test Error'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingStates() {
    if (_loadingStates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Loading States',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._loadingStates.entries.map((entry) {
          final operationId = entry.key;
          final loadingState = entry.value;
          
          if (loadingState == null || !loadingState.isLoading) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  operationId,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    MessagingLoadingIndicator(
                      type: loadingState.type == LoadingType.determinate 
                          ? LoadingType.linear 
                          : LoadingType.circular,
                      progress: loadingState.progress,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loadingState.message ?? 'Loading...',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty && _errors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Results',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._results.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${entry.key}: ${entry.value}'),
                ),
              ],
            ),
          );
        }),
        ..._errors.entries.map((entry) {
          if (entry.value == null) return const SizedBox.shrink();
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: InlineErrorWidget(
              message: '${entry.key}: ${entry.value}',
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSystemStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Status',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error Statistics: ${_errorIntegration.getErrorStatistics()}'),
              const SizedBox(height: 4),
              Text('Loading Statistics: ${_errorIntegration.getLoadingStatistics()}'),
              const SizedBox(height: 4),
              Text('Retry Statistics: ${_errorIntegration.getRetryStatistics()}'),
            ],
          ),
        ),
      ],
    );
  }

  // Test operations

  Future<void> _testSendMessage() async {
    const operationId = 'send_message_demo';
    _startListeningToOperation(operationId);

    try {
      final result = await MessagingOperations.sendMessage(
        conversationId: 'demo_conversation',
        content: 'Hello, this is a test message!',
        recipientName: 'Demo User',
      );
      
      setState(() {
        _results[operationId] = result;
        _errors[operationId] = null;
      });
    } catch (e) {
      setState(() {
        _errors[operationId] = e.toString();
      });
    }
  }

  Future<void> _testLoadMessages() async {
    const operationId = 'load_messages_demo';
    _startListeningToOperation(operationId);

    try {
      final result = await MessagingOperations.loadMessages(
        conversationId: 'demo_conversation',
        limit: 20,
      );
      
      setState(() {
        _results[operationId] = '${result.length} messages loaded';
        _errors[operationId] = null;
      });
    } catch (e) {
      setState(() {
        _errors[operationId] = e.toString();
      });
    }
  }

  Future<void> _testUploadFile() async {
    const operationId = 'upload_file_demo.jpg';
    _startListeningToOperation(operationId);

    try {
      final result = await MessagingOperations.uploadFile(
        fileName: 'demo.jpg',
        fileSize: 1024000,
      );
      
      setState(() {
        _results[operationId] = result;
        _errors[operationId] = null;
      });
    } catch (e) {
      setState(() {
        _errors[operationId] = e.toString();
      });
    }
  }

  Future<void> _testSearchUsers() async {
    const operationId = 'search_users_demo';
    _startListeningToOperation(operationId);

    try {
      final result = await MessagingOperations.searchUsers(
        query: 'demo',
      );
      
      setState(() {
        _results[operationId] = '${result.length} users found';
        _errors[operationId] = null;
      });
    } catch (e) {
      setState(() {
        _errors[operationId] = e.toString();
      });
    }
  }

  Future<void> _testVoiceCall() async {
    const operationId = 'voice_call_demo_user';
    _startListeningToOperation(operationId);

    try {
      final result = await MessagingOperations.initiateVoiceCall(
        recipientId: 'demo_user',
        recipientName: 'Demo User',
      );
      
      setState(() {
        _results[operationId] = result;
        _errors[operationId] = null;
      });
    } catch (e) {
      setState(() {
        _errors[operationId] = e.toString();
      });
    }
  }

  Future<void> _testFailingOperation() async {
    const operationId = 'failing_operation';
    _startListeningToOperation(operationId);

    try {
      await _errorIntegration.executeOperation(
        operationId,
        () async {
          await Future.delayed(const Duration(seconds: 1));
          throw Exception('This operation is designed to fail');
        },
        loadingMessage: 'Testing error handling...',
        errorMessage: 'Operation failed as expected',
        maxRetries: 2,
      );
    } catch (e) {
      setState(() {
        _errors[operationId] = e.toString();
      });
    }
  }

  void _startListeningToOperation(String operationId) {
    _errorIntegration.getLoadingStateStream(operationId).listen((loadingState) {
      setState(() {
        _loadingStates[operationId] = loadingState;
      });
    });
  }

  @override
  void dispose() {
    _errorIntegration.dispose();
    super.dispose();
  }
}