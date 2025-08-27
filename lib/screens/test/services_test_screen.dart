// Services Test Screen for TALOWA
// Test screen to demonstrate new services functionality

import 'package:flutter/material.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/land_records_service.dart';
import '../../services/emergency_service.dart';
import '../../services/legal_case_service.dart';
import '../../core/theme/app_theme.dart';

class ServicesTestScreen extends StatefulWidget {
  const ServicesTestScreen({super.key});

  @override
  State<ServicesTestScreen> createState() => _ServicesTestScreenState();
}

class _ServicesTestScreenState extends State<ServicesTestScreen> {
  final AIAssistantService _aiService = AIAssistantService();
  final LandRecordsService _landService = LandRecordsService();
  final EmergencyService _emergencyService = EmergencyService();
  final LegalCaseService _legalService = LegalCaseService();

  String _testResults = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services Test'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TALOWA Services Test',
              style: AppTheme.heading1Style,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Test the newly implemented services:',
              style: AppTheme.bodyStyle,
            ),
            const SizedBox(height: 24),

            // Test Buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildTestButton(
                  'Test AI Assistant',
                  Icons.smart_toy,
                  Colors.blue,
                  _testAIAssistant,
                ),
                _buildTestButton(
                  'Test Land Records',
                  Icons.landscape,
                  Colors.green,
                  _testLandRecords,
                ),
                _buildTestButton(
                  'Test Emergency',
                  Icons.emergency,
                  Colors.red,
                  _testEmergency,
                ),
                _buildTestButton(
                  'Test Legal Cases',
                  Icons.gavel,
                  Colors.purple,
                  _testLegalCases,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),

            // Results
            if (_testResults.isNotEmpty) ...[
              const Text(
                'Test Results:',
                style: AppTheme.heading3Style,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _testResults,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _testAIAssistant() async {
    setState(() {
      _isLoading = true;
      _testResults = 'Testing AI Assistant Service...\n\n';
    });

    try {
      // Test initialization
      _appendResult('1. Initializing AI Assistant...');
      final initialized = await _aiService.initialize();
      _appendResult('   Result: ${initialized ? 'SUCCESS' : 'FAILED'}\n');

      // Test query processing
      _appendResult('2. Testing query processing...');
      final response = await _aiService.processQuery('Show my land records');
      _appendResult('   Query: "Show my land records"');
      _appendResult('   Response: ${response.text}');
      _appendResult('   Confidence: ${response.confidence}');
      _appendResult('   Actions: ${response.actions.length}\n');

      // Test contextual suggestions
      _appendResult('3. Getting contextual suggestions...');
      final suggestions = await _aiService.getContextualSuggestions();
      _appendResult('   Suggestions count: ${suggestions.length}');
      for (int i = 0; i < suggestions.length && i < 3; i++) {
        _appendResult('   - ${suggestions[i]}');
      }

      _appendResult('\n✅ AI Assistant Service Test COMPLETED');
    } catch (e) {
      _appendResult('❌ AI Assistant Test FAILED: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLandRecords() async {
    setState(() {
      _isLoading = true;
      _testResults = 'Testing Land Records Service...\n\n';
    });

    try {
      // Test getting user land records
      _appendResult('1. Getting user land records...');
      final recordsStream = _landService.getUserLandRecords();
      final records = await recordsStream.first;
      _appendResult('   Current records count: ${records.length}\n');

      // Test getting statistics
      _appendResult('2. Getting land record statistics...');
      final stats = await _landService.getLandRecordStats();
      _appendResult('   Total records: ${stats.totalRecords}');
      _appendResult('   Total area: ${stats.totalArea} acres');
      _appendResult('   Patta received: ${stats.pattaReceivedCount}');
      _appendResult('   Patta pending: ${stats.pattaPendingCount}\n');

      // Test location services
      _appendResult('3. Testing GPS location...');
      final location = await _landService.getCurrentLocation();
      if (location != null) {
        _appendResult('   GPS: ${location.latitude}, ${location.longitude}');
      } else {
        _appendResult('   GPS: Not available (permissions needed)');
      }

      _appendResult('\n✅ Land Records Service Test COMPLETED');
    } catch (e) {
      _appendResult('❌ Land Records Test FAILED: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testEmergency() async {
    setState(() {
      _isLoading = true;
      _testResults = 'Testing Emergency Service...\n\n';
    });

    try {
      // Test getting emergency contacts
      _appendResult('1. Getting emergency contacts...');
      final contacts = await _emergencyService.getEmergencyContacts();
      _appendResult('   Emergency contacts count: ${contacts.length}');
      for (int i = 0; i < contacts.length && i < 3; i++) {
        _appendResult('   - ${contacts[i].name}: ${contacts[i].phoneNumber}');
      }
      _appendResult('');

      // Test getting user incidents
      _appendResult('2. Getting user incidents...');
      final incidentsStream = _emergencyService.getUserIncidents();
      final incidents = await incidentsStream.first;
      _appendResult('   User incidents count: ${incidents.length}\n');

      // Test emergency contact numbers
      _appendResult('3. Available emergency numbers:');
      EmergencyService.emergencyContacts.forEach((key, value) {
        _appendResult('   $key: $value');
      });

      _appendResult('\n✅ Emergency Service Test COMPLETED');
    } catch (e) {
      _appendResult('❌ Emergency Test FAILED: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLegalCases() async {
    setState(() {
      _isLoading = true;
      _testResults = 'Testing Legal Case Service...\n\n';
    });

    try {
      // Test getting user legal cases
      _appendResult('1. Getting user legal cases...');
      final casesStream = _legalService.getUserLegalCases();
      final cases = await casesStream.first;
      _appendResult('   Current cases count: ${cases.length}\n');

      // Test getting case statistics
      _appendResult('2. Getting case statistics...');
      final stats = await _legalService.getCaseStatistics();
      _appendResult('   Total cases: ${stats.totalCases}');
      _appendResult('   Active cases: ${stats.activeCases}');
      _appendResult('   Resolved cases: ${stats.resolvedCases}\n');

      // Test getting upcoming hearings
      _appendResult('3. Getting upcoming hearings...');
      final hearings = await _legalService.getUpcomingHearings();
      _appendResult('   Upcoming hearings: ${hearings.length}\n');

      // Test getting available lawyers
      _appendResult('4. Getting available lawyers...');
      final lawyers = await _legalService.getAvailableLawyers();
      _appendResult('   Available lawyers: ${lawyers.length}');

      _appendResult('\n✅ Legal Case Service Test COMPLETED');
    } catch (e) {
      _appendResult('❌ Legal Case Test FAILED: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _appendResult(String result) {
    setState(() {
      _testResults += '$result\n';
    });
  }
}