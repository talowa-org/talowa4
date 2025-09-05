// Conversation Monitoring Screen for TALOWA Admin Dashboard
import 'package:flutter/material.dart';
import '../../services/admin/admin_dashboard_service.dart';

class ConversationMonitoringScreen extends StatefulWidget {
  const ConversationMonitoringScreen({super.key});

  @override
  State<ConversationMonitoringScreen> createState() => _ConversationMonitoringScreenState();
}

class _ConversationMonitoringScreenState extends State<ConversationMonitoringScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation Monitoring'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ConversationMonitorData>>(
        stream: AdminDashboardService.getConversationMonitoring(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading conversations: ${snapshot.error}'),
                ],
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No conversations to monitor'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final data = conversations[index];
              return _buildConversationCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildConversationCard(ConversationMonitorData data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: data.riskLevel.colorCode.isNotEmpty 
              ? Color(int.parse(data.riskLevel.colorCode.substring(1), radix: 16) + 0xFF000000)
              : Colors.grey,
          child: Icon(
            _getConversationIcon(data.conversation.type),
            color: Colors.white,
          ),
        ),
        title: Text(
          data.conversation.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data.conversation.participantCount} participants'),
            Text('${data.recentMessageCount} messages (24h)'),
            if (data.reportCount > 0)
              Text(
                '${data.reportCount} reports',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(
                data.riskLevel.displayName,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Color(
                int.parse(data.riskLevel.colorCode.substring(1), radix: 16) + 0xFF000000,
              ).withOpacity(0.1),
            ),
          ],
        ),
        onTap: () => _showConversationDetails(data),
      ),
    );
  }

  IconData _getConversationIcon(dynamic type) {
    // This would map conversation types to icons
    return Icons.chat;
  }

  void _showConversationDetails(ConversationMonitorData data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data.conversation.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${data.conversation.type}'),
            Text('Participants: ${data.conversation.participantCount}'),
            Text('Recent Messages: ${data.recentMessageCount}'),
            Text('Reports: ${data.reportCount}'),
            Text('Risk Level: ${data.riskLevel.displayName}'),
            const SizedBox(height: 16),
            const Text(
              'Actions available:\n'
              'â€¢ View conversation history\n'
              'â€¢ Monitor message patterns\n'
              'â€¢ Apply conversation restrictions\n'
              'â€¢ Export conversation data',
            ),
          ],
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
}
