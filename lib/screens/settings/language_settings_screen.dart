// Language Settings Screen for TALOWA
// Allows users to change the app language

import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../core/theme/app_theme.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selectedLanguage = LocalizationService.currentLanguage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Settings'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select your preferred language:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...LocalizationService.supportedLanguages.entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<String>(
                  title: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 16),
                  ),
                  subtitle: Text(
                    'Language code: ${entry.key}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  value: entry.key,
                  groupValue: _selectedLanguage,
                  activeColor: AppTheme.talowaGreen,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        _selectedLanguage = value;
                      });
                    }
                  },
                ),
              );
            }).toList(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedLanguage != LocalizationService.currentLanguage
                    ? _applyLanguageChange
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.talowaGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Apply Changes',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Language Preview',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPreviewText(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPreviewText() {
    final previews = {
      'en': 'Welcome to TALOWA! Your land rights are protected.',
      'hi': 'तलावा में आपका स्वागत है! आपके भूमि अधिकार सुरक्षित हैं।',
      'te': 'తలావాకు స్వాగతం! మీ భూమి హక్కులు రక్షించబడ్డాయి.',
    };
    
    return previews[_selectedLanguage] ?? previews['en']!;
  }

  Future<void> _applyLanguageChange() async {
    try {
      await LocalizationService.setLanguage(_selectedLanguage);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language changed to ${LocalizationService.supportedLanguages[_selectedLanguage]}'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        
        // Go back to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change language: $e'),
            backgroundColor: AppTheme.emergencyRed,
          ),
        );
      }
    }
  }
}