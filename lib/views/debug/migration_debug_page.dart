import 'package:flutter/material.dart';
import '../../services/migration/simple_url_migration.dart';

class MigrationDebugPage extends StatefulWidget {
  const MigrationDebugPage({super.key});

  @override
  State<MigrationDebugPage> createState() => _MigrationDebugPageState();
}

class _MigrationDebugPageState extends State<MigrationDebugPage> {
  bool _isRunning = false;
  String _status = 'Ready to run migration';
  
  Future<void> _runMigration() async {
    setState(() {
      _isRunning = true;
      _status = 'Running migration...';
    });
    
    try {
      await SimpleUrlMigration.runMigration();
      setState(() {
        _status = 'Migration completed successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Migration failed: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Migration Debug'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Firebase Storage URL Migration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will fix Firebase Storage URLs in Firestore by replacing '
              'talowa.appspot.com with talowa.firebasestorage.app',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (_isRunning)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _runMigration,
                        child: const Text('Run Migration'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What this migration does:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('â€¢ Updates imageUrls in posts collection'),
                    Text('â€¢ Updates videoUrls in posts collection'),
                    Text('â€¢ Updates documentUrls in posts collection'),
                    Text('â€¢ Updates legacy mediaUrls in posts collection'),
                    Text('â€¢ Updates mediaUrl and thumbnailUrl in stories collection'),
                    Text('â€¢ Updates profileImageUrl and coverImageUrl in users collection'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
