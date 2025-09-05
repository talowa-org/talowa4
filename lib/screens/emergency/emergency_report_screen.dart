import 'package:flutter/material.dart';
import '../../services/emergency_service.dart';
import '../../core/theme/app_theme.dart';

class EmergencyReportScreen extends StatefulWidget {
  const EmergencyReportScreen({super.key});

  @override
  State<EmergencyReportScreen> createState() => _EmergencyReportScreenState();
}

class _EmergencyReportScreenState extends State<EmergencyReportScreen> {
  final _formKey = GlobalKey<FormState>();
  EmergencyType type = EmergencyType.landGrabbing;
  final descCtrl = TextEditingController();
  bool anonymous = false;
  bool loading = false;

  final service = EmergencyService();

  @override
  void dispose() { descCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(()=> loading = true);
    try {
      final id = await service.reportIncident(
        type: type,
        description: descCtrl.text.trim(),
        isAnonymous: anonymous,
        priority: EmergencyPriority.high,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(id != null ? 'Incident reported' : 'Report failed')),
        );
        if (id != null) Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(()=> loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Emergency'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<EmergencyType>(
              value: type,
              items: EmergencyType.values.map((e)=> DropdownMenuItem(value: e, child: Text(e.toString().split('.').last))).toList(),
              onChanged: (v){ if (v!=null) setState(()=> type=v); },
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 4,
              validator: (v)=> v==null||v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: anonymous,
              onChanged: (v)=> setState(()=> anonymous = v),
              title: const Text('Report anonymously'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: loading ? null : _submit,
              icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.report),
              label: Text(loading ? 'Submitting...' : 'Submit'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.talowaGreen, foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}


