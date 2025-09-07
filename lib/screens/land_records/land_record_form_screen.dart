import 'package:flutter/material.dart';
import '../../services/land_records_service.dart';
import '../../models/land_record_model.dart';
import '../../core/theme/app_theme.dart';

class LandRecordFormScreen extends StatefulWidget {
  final LandRecordModel? initial;
  const LandRecordFormScreen({super.key, this.initial});

  @override
  State<LandRecordFormScreen> createState() => _LandRecordFormScreenState();
}

class _LandRecordFormScreenState extends State<LandRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final service = LandRecordsService();

  final surveyCtrl = TextEditingController();
  final villageCtrl = TextEditingController();
  final mandalCtrl = TextEditingController();
  final districtCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  String areaUnit = 'acres';
  LandType landType = LandType.agricultural;
  PattaStatus patta = PattaStatus.pending;
  final descCtrl = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      surveyCtrl.text = i.surveyNumber;
      villageCtrl.text = i.location.village;
      mandalCtrl.text = i.location.mandal;
      districtCtrl.text = i.location.district;
      areaCtrl.text = i.area.toString();
      areaUnit = i.unit;
      landType = _landTypeFromString(i.landType);
      patta = _pattaFromString(i.legalStatus);
      descCtrl.text = i.issues.description ?? '';
    }
  }

  LandType _landTypeFromString(String v) {
    return LandType.values.firstWhere((e) => e.toString().split('.').last == v, orElse: () => LandType.agricultural);
  }
  PattaStatus _pattaFromString(String v) {
    return PattaStatus.values.firstWhere((e) => e.toString().split('.').last == v, orElse: () => PattaStatus.pending);
  }

  @override
  void dispose() {
    surveyCtrl.dispose(); villageCtrl.dispose(); mandalCtrl.dispose(); districtCtrl.dispose(); areaCtrl.dispose(); descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { loading = true; });

    try {
      if (widget.initial == null) {
        Map<String, double>? pos;
        try { pos = await service.getCurrentLocation(); } catch (_) {}
        final id = await service.createLandRecord(
          surveyNumber: surveyCtrl.text.trim(),
          village: villageCtrl.text.trim(),
          mandal: mandalCtrl.text.trim(),
          district: districtCtrl.text.trim(),
          area: double.tryParse(areaCtrl.text.trim()) ?? 0,
          areaUnit: areaUnit,
          landType: landType,
          pattaStatus: patta,
          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          coordinates: pos,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(id != null ? 'Record created' : 'Create failed')),
          );
          if (id != null) Navigator.pop(context);
        }
      } else {
        final ok = await service.updateLandRecord(
          recordId: widget.initial!.id,
          surveyNumber: surveyCtrl.text.trim(),
          village: villageCtrl.text.trim(),
          mandal: mandalCtrl.text.trim(),
          district: districtCtrl.text.trim(),
          area: double.tryParse(areaCtrl.text.trim()),
          areaUnit: areaUnit,
          landType: landType,
          pattaStatus: patta,
          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ok ? 'Record updated' : 'Update failed')),
          );
          if (ok) Navigator.pop(context);
        }
      }
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Add Land Record' : 'Edit Land Record'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: surveyCtrl,
              decoration: const InputDecoration(labelText: 'Survey Number', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: villageCtrl, decoration: const InputDecoration(labelText: 'Village', border: OutlineInputBorder()), validator: (v)=> v==null||v.trim().isEmpty?'Required':null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: mandalCtrl, decoration: const InputDecoration(labelText: 'Mandal', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: areaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Area', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: areaUnit,
                items: const [DropdownMenuItem(value: 'acres', child: Text('Acres')), DropdownMenuItem(value: 'guntas', child: Text('Guntas')), DropdownMenuItem(value: 'hectares', child: Text('Hectares'))],
                onChanged: (v){ if (v!=null) setState(()=> areaUnit=v); },
                decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
              )),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<LandType>(
              initialValue: landType,
              items: LandType.values.map((e)=> DropdownMenuItem(value: e, child: Text(e.toString().split('.').last))).toList(),
              onChanged: (v){ if (v!=null) setState(()=> landType=v); },
              decoration: const InputDecoration(labelText: 'Land Type', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PattaStatus>(
              initialValue: patta,
              items: PattaStatus.values.map((e)=> DropdownMenuItem(value: e, child: Text(e.toString().split('.').last))).toList(),
              onChanged: (v){ if (v!=null) setState(()=> patta=v); },
              decoration: const InputDecoration(labelText: 'Patta Status', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: loading ? null : _save,
              icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: Text(loading ? 'Saving...' : 'Save'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.talowaGreen, foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}


