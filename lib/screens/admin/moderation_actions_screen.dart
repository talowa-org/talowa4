// Moderation Actions Screen for TALOWA Admin Dashboard
import 'package:flutter/material.dart';

class ModerationActionsScreen extends StatefulWidget {
  const ModerationActionsScreen({super.key});

  @override
  State<ModerationActionsScreen> createState() => _ModerationActionsScreenState();
}

class _ModerationActionsScreenState extends State<ModerationActionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Actions'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Moderation Actions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'View and manage active moderation actions',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              'This screen will show:\n'
              '• Active user restrictions\n'
              '• Temporary bans and their expiration\n'
              '• Permanent bans\n'
              '• Message removals\n'
              '• Action history and logs',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}