import 'package:flutter/material.dart';
import '../../services/land_records_service.dart';
import '../../models/land_record_model.dart';
import '../../core/theme/app_theme.dart';

class LandRecordDetailScreen extends StatefulWidget {
  final String recordId;
  const LandRecordDetailScreen({super.key, required this.recordId});

  @override
  State<LandRecordDetailScreen> createState() => _LandRecordDetailScreenState();
}

class _LandRecordDetailScreenState extends State<LandRecordDetailScreen> {
  final service = LandRecordsService();
  LandRecordModel? record;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await service.getLandRecord(widget.recordId);
    if (mounted) setState(() { record = r; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Land Record'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: record == null ? null : () {
              Navigator.pushNamed(context, '/land/edit', arguments: record);
            },
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: record == null ? null : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete record?'),
                  content: const Text('This will mark the record as inactive.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              ) ?? false;
              if (confirm) {
                await service.deleteLandRecord(widget.recordId);
                if (mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : record == null
              ? const Center(child: Text('Record not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _tile('Survey Number', record!.surveyNumber),
                    _tile('Area', '${record!.area} ${record!.unit}'),
                    _tile('Type', record!.landType),
                    _tile('Legal Status', record!.legalStatus),
                    _tile('Village', record!.location.village),
                    _tile('Mandal', record!.location.mandal),
                    _tile('District', record!.location.district),
                    if (record!.issues.description != null && record!.issues.description!.isNotEmpty)
                      _tile('Issues', record!.issues.description!),
                  ],
                ),
    );
  }

  Widget _tile(String label, String value) => ListTile(
        title: Text(label),
        subtitle: Text(value),
      );
}

