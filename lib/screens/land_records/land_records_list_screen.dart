import 'package:flutter/material.dart';
import '../../services/land_records_service.dart';
import '../../models/land_record_model.dart';
import '../../core/theme/app_theme.dart';

class LandRecordsListScreen extends StatelessWidget {
  final LandRecordsService? serviceOverride;
  final Stream<List<LandRecordModel>>? recordsStream;
  const LandRecordsListScreen({super.key, this.serviceOverride, this.recordsStream});

  @override
  Widget build(BuildContext context) {
    final service = serviceOverride ?? LandRecordsService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Land Records'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/land/add'),
        backgroundColor: AppTheme.talowaGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<LandRecordModel>>(
        stream: recordsStream ?? service.getUserLandRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.separated(
            itemCount: records.length,
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = records[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.landscape),
                  title: Text('${r.surveyNumber} • ${r.location.village}'),
                  subtitle: Text('${r.area} ${r.unit} • ${r.landType}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/land/detail',
                    arguments: r.id,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.landscape, size: 56, color: AppTheme.talowaGreen),
            const SizedBox(height: 12),
            const Text('No land records yet'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/land/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add Land Record'),
            ),
          ],
        ),
      ),
    );
  }
}

