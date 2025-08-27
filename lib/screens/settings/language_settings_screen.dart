// Enhanced Language Settings Screen for TALOWA
// Comprehensive multi-language support with translation and RTL features

import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../services/rtl_support_service.dart';
import '../../services/messaging/message_translation_service.dart';
import '../../services/messaging/voice_transcription_service.dart';
import '../../core/theme/app_theme.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selectedLanguage = 'en';
  bool _autoTranslateEnabled = true;
  bool _voiceTranscriptionEnabled = true;
  bool _showOriginalText = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await RTLSupportService.initialize();
    await MessageTranslationService.initialize();
    await VoiceTranscriptionService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: RTLSupportService.currentTextDirection,
      child: Scaffold(
        appBar: RTLSupportService.createDirectionalAppBar(
          title: 'Language Settings',
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: RTLSupportService.crossAxisAlignment,
                  children: [
                    _buildLanguageSelection(),
                    const SizedBox(height: 24),
                    _buildTranslationSettings(),
                    const SizedBox(height: 24),
                    _buildVoiceSettings(),
                    const SizedBox(height: 24),
                    _buildRTLSettings(),
                    const SizedBox(height: 24),
                    _buildPreviewSection(),
                    const SizedBox(height: 30),
                    _buildApplyButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLanguageSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: RTLSupportService.crossAxisAlignment,
          children: [
            const Row(
              children: [
                Icon(Icons.language, color: AppTheme.talowaGreen),
                SizedBox(width: 8),
                Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...{'en': 'English', 'hi': 'Hindi', 'te': 'Telugu'}.entries.map((entry) {
              const isRTL = false;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<String>(
                  title: RTLSupportService.createDirectionalText(
                    entry.value,
                    languageCode: entry.key,
                    style: const TextStyle(fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: RTLSupportService.crossAxisAlignment,
                    children: [
                      Text(
                        'Code: ${entry.key.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isRTL)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'RTL Support',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
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
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: RTLSupportService.crossAxisAlignment,
          children: [
            const Row(
              children: [
                Icon(Icons.translate, color: AppTheme.talowaGreen),
                SizedBox(width: 8),
                Text(
                  'Translation Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto-translate messages'),
              subtitle: const Text('Automatically translate incoming messages'),
              value: _autoTranslateEnabled,
              activeColor: AppTheme.talowaGreen,
              onChanged: (bool value) {
                setState(() {
                  _autoTranslateEnabled = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Show original text'),
              subtitle: const Text('Display original text alongside translation'),
              value: _showOriginalText,
              activeColor: AppTheme.talowaGreen,
              onChanged: _autoTranslateEnabled
                  ? (bool value) {
                      setState(() {
                        _showOriginalText = value;
                      });
                    }
                  : null,
            ),
            if (_autoTranslateEnabled) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.info_outline, color: Colors.blue.shade600),
                title: const Text('Supported Translations'),
                subtitle: Text(
                  _getSupportedTranslationsText(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: RTLSupportService.crossAxisAlignment,
          children: [
            const Row(
              children: [
                Icon(Icons.mic, color: AppTheme.talowaGreen),
                SizedBox(width: 8),
                Text(
                  'Voice Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Voice transcription'),
              subtitle: const Text('Convert voice messages to text'),
              value: _voiceTranscriptionEnabled,
              activeColor: AppTheme.talowaGreen,
              onChanged: (bool value) {
                setState(() {
                  _voiceTranscriptionEnabled = value;
                });
              },
            ),
            if (_voiceTranscriptionEnabled) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.language, color: Colors.green.shade600),
                title: const Text('Transcription Accuracy'),
                subtitle: Column(
                  crossAxisAlignment: RTLSupportService.crossAxisAlignment,
                  children: VoiceTranscriptionService.getLanguageAccuracy()
                      .entries
                      .map((entry) {
                    final languageName = LocalizationService.supportedLanguages[entry.key] ??
                        entry.value;
                    final accuracy = (entry.value * 100).toInt();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(languageName.toString()),
                          Text(
                            '$accuracy%',
                            style: TextStyle(
                              color: accuracy >= 90
                                  ? Colors.green
                                  : accuracy >= 80
                                      ? Colors.orange
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRTLSettings() {
    const isRTLLanguage = false;
    
    if (!isRTLLanguage) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: RTLSupportService.crossAxisAlignment,
          children: [
            const Row(
              children: [
                Icon(Icons.format_textdirection_r_to_l, color: AppTheme.talowaGreen),
                SizedBox(width: 8),
                Text(
                  'RTL Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: RTLSupportService.crossAxisAlignment,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Right-to-Left Support Enabled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This language uses right-to-left text direction. '
                    'The app layout will automatically adjust.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: RTLSupportService.crossAxisAlignment,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Language Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: RTLSupportService.createDirectionalText(
                _getPreviewText(),
                languageCode: _selectedLanguage,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            _buildPreviewStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStats() {
    const isRTL = false;
    final accuracy = VoiceTranscriptionService.getLanguageAccuracy()[_selectedLanguage] ?? 0.0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatChip(
          'Direction',
          isRTL ? 'RTL' : 'LTR',
          isRTL ? Colors.orange : Colors.blue,
        ),
        _buildStatChip(
          'Voice Accuracy',
          '${(accuracy * 100).toInt()}%',
          accuracy >= 0.9 ? Colors.green : Colors.orange,
        ),
        _buildStatChip(
          'Translation',
          MessageTranslationService.isTranslationSupported('en', _selectedLanguage) 
              ? 'Supported' 
              : 'Limited',
          MessageTranslationService.isTranslationSupported('en', _selectedLanguage)
              ? Colors.green
              : Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildApplyButton() {
    final hasChanges = _selectedLanguage != 'en';
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasChanges ? _applyLanguageChange : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.talowaGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Apply Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  String _getPreviewText() {
    final previews = {
      'en': 'Welcome to TALOWA! Your land rights are protected. Report issues, connect with your network, and get legal help.',
      'hi': 'तलावा में आपका स्वागत है! आपके भूमि अधिकार सुरक्षित हैं। समस्याओं की रिपोर्ट करें, अपने नेटवर्क से जुड़ें, और कानूनी मदद लें।',
      'te': 'తలావాకు స్వాగతం! మీ భూమి హక్కులు రక్షించబడ్డాయి. సమస్యలను నివేదించండి, మీ నెట్‌వర్క్‌తో కనెక్ట్ అవ్వండి మరియు న్యాయ సహాయం పొందండి.',
      'ur': 'تلاوا میں خوش آمدید! آپ کے زمینی حقوق محفوظ ہیں۔ مسائل کی اطلاع دیں، اپنے نیٹ ورک سے جڑیں، اور قانونی مدد حاصل کریں۔',
      'ar': 'مرحباً بك في تالاوا! حقوق أرضك محمية. أبلغ عن المشاكل، تواصل مع شبكتك، واحصل على المساعدة القانونية.',
    };
    
    return previews[_selectedLanguage] ?? previews['en']!;
  }

  String _getSupportedTranslationsText() {
    final supported = MessageTranslationService.getSupportedTranslations();
    final currentSupported = supported[_selectedLanguage] ?? [];
    
    if (currentSupported.isEmpty) {
      return 'No translations available for this language';
    }
    
    final languageNames = currentSupported
        .map((code) => {'en': 'English', 'hi': 'Hindi', 'te': 'Telugu'}[code] ?? code)
        .join(', ');
    
    return 'Can translate to/from: $languageNames';
  }

  Future<void> _applyLanguageChange() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Apply language change
      // await LocalizationService.setLanguage(_selectedLanguage);
      
      // Update voice transcription language
      if (_voiceTranscriptionEnabled) {
        await VoiceTranscriptionService.setTranscriptionLanguage(_selectedLanguage);
      }
      
      if (mounted) {
        final languageName = {'en': 'English', 'hi': 'Hindi', 'te': 'Telugu'}[_selectedLanguage];
        const isRTL = false;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Language changed to $languageName${isRTL ? ' (RTL)' : ''}',
              textDirection: RTLSupportService.getTextDirectionForLanguage(_selectedLanguage),
            ),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Small delay to show the success message
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Go back to previous screen
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change language: $e'),
            backgroundColor: AppTheme.emergencyRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}