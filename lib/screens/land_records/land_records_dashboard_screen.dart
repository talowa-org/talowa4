// Land Records Dashboard Screen for TALOWA
// Comprehensive land record management interface

import 'package:flutter/material.dart';
import '../../services/land_records_service.dart';
import '../../core/theme/app_theme.dart';

class LandRecordsDashboardScreen extends StatefulWidget {
  const LandRecordsDashboardScreen({super.key});

  @override
  State<LandRecordsDashboardScreen> createState() => _LandRecordsDashboardScreenState();
}

class _LandRecordsDashboardScreenState extends State<LandRecordsDashboardScreen> {
  final LandRecordsService _landService = LandRecordsService();
  LandRecordStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _landService.getLandRecordStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Land Records'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddLandRecordDialog,
            tooltip: 'Add Land Record',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
 
