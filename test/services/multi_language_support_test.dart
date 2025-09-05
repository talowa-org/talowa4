// Comprehensive Multi-Language Support Test for TALOWA
// Tests all aspects of the multi-language implementation

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/localization_service.dart';
import 'package:talowa/services/rtl_support_service.dart';
import 'package:talowa/services/messaging/message_translation_service.dart';
import 'package:talowa/services/messaging/voice_transcription_service.dart';
import 'package:talowa/services/language_preferences.dart';

void main() {
  group('Multi-Language Support Tests', () {
    setUpAll(() async {
      // Initialize all services
      await LanguagePreferences.initialize();
      await LocalizationService.initialize();
      await RTLSupportService.initialize();
      await MessageTranslationService.initialize();
      await VoiceTranscriptionService.initialize();
    });

    group('LocalizationService Tests', () {
      test('should support all required languages', () {
        final supportedLanguages = LocalizationService.supportedLanguages;
        
        expect(supportedLanguages.containsKey('en'), true);
        expect(supportedLanguages.containsKey('hi'), true);
        expect(supportedLanguages.containsKey('te'), true);
        expect(supportedLanguages.containsKey('ur'), true);
        expect(supportedLanguages.containsKey('ar'), true);
      });

      test('should detect language correctly', () {
        expect(LocalizationService.detectLanguage('Hello world'), 'en');
        expect(LocalizationService.detectLanguage('à¤¨à¤®à¤¸à¥à¤¤à¥‡ à¤¦à¥à¤¨à¤¿à¤¯à¤¾'), 'hi');
        expect(LocalizationService.detectLanguage('à°¹à°²à±‹ à°ªà±à°°à°ªà°‚à°šà°‚'), 'te');
        expect(LocalizationService.detectLanguage('Ø§Ù„Ø³Ù„Ø§Ù… Ø¹Ù„ÛŒÚ©Ù…'), 'ur');
        expect(LocalizationService.detectLanguage('Ù…Ø±Ø­Ø¨Ø§ Ø¨Ø§Ù„Ø¹Ø§Ù„Ù…'), 'ar');
      });

      test('should identify RTL languages correctly', () {
        expect(LocalizationService.rtlLanguages.contains('ur'), true);
        expect(LocalizationService.rtlLanguages.contains('ar'), true);
        expect(LocalizationService.rtlLanguages.contains('en'), false);
        expect(LocalizationService.rtlLanguages.contains('hi'), false);
        expect(LocalizationService.rtlLanguages.contains('te'), false);
      });

      test('should format numbers correctly for different languages', () async {
        // Test Hindi numerals
        await LocalizationService.setLanguage('hi');
        expect(LocalizationService.formatNumber(123), 'à¥§à¥¨à¥©');
        
        // Test Telugu numerals
        await LocalizationService.setLanguage('te');
        expect(LocalizationService.formatNumber(456), 'à±ªà±«à±¬');
        
        // Test Arabic-Indic numerals for Urdu
        await LocalizationService.setLanguage('ur');
        expect(LocalizationService.formatNumber(789), 'Û·Û¸Û¹');
        
        // Test Arabic numerals
        await LocalizationService.setLanguage('ar');
        expect(LocalizationService.formatNumber(101), 'Ù¡Ù Ù¡');
      });

      test('should provide voice commands for all languages', () {
        final voiceCommands = LocalizationService.getVoiceCommands();
        
        expect(voiceCommands.containsKey('en'), true);
        expect(voiceCommands.containsKey('hi'), true);
        expect(voiceCommands.containsKey('te'), true);
        expect(voiceCommands.containsKey('ur'), true);
        expect(voiceCommands.containsKey('ar'), true);
        
        expect(voiceCommands['en']!.isNotEmpty, true);
        expect(voiceCommands['hi']!.isNotEmpty, true);
        expect(voiceCommands['te']!.isNotEmpty, true);
        expect(voiceCommands['ur']!.isNotEmpty, true);
        expect(voiceCommands['ar']!.isNotEmpty, true);
      });
    });

    group('RTLSupportService Tests', () {
      test('should identify RTL languages correctly', () {
        expect(RTLSupportService.getTextDirectionForLanguage('ar').name, 'rtl');
        expect(RTLSupportService.getTextDirectionForLanguage('ur').name, 'rtl');
        expect(RTLSupportService.getTextDirectionForLanguage('en').name, 'ltr');
        expect(RTLSupportService.getTextDirectionForLanguage('hi').name, 'ltr');
        expect(RTLSupportService.getTextDirectionForLanguage('te').name, 'ltr');
      });

      test('should provide correct text alignment for languages', () {
        expect(RTLSupportService.getTextAlignForLanguage('ar').name, 'right');
        expect(RTLSupportService.getTextAlignForLanguage('ur').name, 'right');
        expect(RTLSupportService.getTextAlignForLanguage('en').name, 'left');
        expect(RTLSupportService.getTextAlignForLanguage('hi').name, 'left');
        expect(RTLSupportService.getTextAlignForLanguage('te').name, 'left');
      });

      test('should format RTL text with proper markers', () {
        final arabicText = RTLSupportService.formatRTLText('Ù…Ø±Ø­Ø¨Ø§ 123 Ø¨Ø§Ù„Ø¹Ø§Ù„Ù…', 'ar');
        expect(arabicText.contains('\u200E'), true); // Contains LTR mark
        expect(arabicText.contains('\u200F'), true); // Contains RTL mark
        
        final englishText = RTLSupportService.formatRTLText('Hello 123 World', 'en');
        expect(englishText, 'Hello 123 World'); // No markers for LTR text
      });

      test('should provide appropriate font families for RTL languages', () {
        expect(RTLSupportService.getFontFamily('ar'), 'NotoSansArabic');
        expect(RTLSupportService.getFontFamily('ur'), 'NotoNastaliqUrdu');
        expect(RTLSupportService.getFontFamily('en'), null);
        expect(RTLSupportService.getFontFamily('hi'), null);
        expect(RTLSupportService.getFontFamily('te'), null);
      });
    });

    group('MessageTranslationService Tests', () {
      test('should identify supported translation pairs', () {
        final supportedTranslations = MessageTranslationService.getSupportedTranslations();
        
        expect(supportedTranslations.containsKey('en'), true);
        expect(supportedTranslations.containsKey('hi'), true);
        expect(supportedTranslations.containsKey('te'), true);
        expect(supportedTranslations.containsKey('ur'), true);
        expect(supportedTranslations.containsKey('ar'), true);
      });

      test('should check translation support correctly', () {
        expect(MessageTranslationService.isTranslationSupported('en', 'hi'), true);
        expect(MessageTranslationService.isTranslationSupported('hi', 'en'), true);
        expect(MessageTranslationService.isTranslationSupported('te', 'en'), true);
        expect(MessageTranslationService.isTranslationSupported('ur', 'ar'), true);
      });

      test('should translate common phrases', () async {
        final result = await MessageTranslationService.translateMessage(
          message: 'hello',
          targetLanguage: 'hi',
          sourceLanguage: 'en',
        );
        
        expect(result.isTranslated, true);
        expect(result.sourceLanguage, 'en');
        expect(result.targetLanguage, 'hi');
        expect(result.confidence, greaterThan(0.0));
      });

      test('should handle same language translation', () async {
        final result = await MessageTranslationService.translateMessage(
          message: 'Hello world',
          targetLanguage: 'en',
          sourceLanguage: 'en',
        );
        
        expect(result.isTranslated, false);
        expect(result.originalText, result.translatedText);
        expect(result.confidence, 1.0);
      });

      test('should provide translation confidence scores', () {
        final confidence1 = MessageTranslationService.getTranslationConfidence('hi', 'ur');
        final confidence2 = MessageTranslationService.getTranslationConfidence('en', 'te');
        
        expect(confidence1, greaterThan(0.0));
        expect(confidence1, lessThanOrEqualTo(1.0));
        expect(confidence2, greaterThan(0.0));
        expect(confidence2, lessThanOrEqualTo(1.0));
      });
    });

    group('VoiceTranscriptionService Tests', () {
      test('should support all required languages', () {
        final supportedLanguages = VoiceTranscriptionService.getSupportedLanguages();
        
        expect(supportedLanguages.contains('en'), true);
        expect(supportedLanguages.contains('hi'), true);
        expect(supportedLanguages.contains('te'), true);
        expect(supportedLanguages.contains('ur'), true);
        expect(supportedLanguages.contains('ar'), true);
      });

      test('should validate language support', () {
        expect(VoiceTranscriptionService.isLanguageSupported('en'), true);
        expect(VoiceTranscriptionService.isLanguageSupported('hi'), true);
        expect(VoiceTranscriptionService.isLanguageSupported('te'), true);
        expect(VoiceTranscriptionService.isLanguageSupported('ur'), true);
        expect(VoiceTranscriptionService.isLanguageSupported('ar'), true);
        expect(VoiceTranscriptionService.isLanguageSupported('fr'), false);
      });

      test('should provide accuracy ratings for languages', () {
        final accuracy = VoiceTranscriptionService.getLanguageAccuracy();
        
        expect(accuracy.containsKey('en'), true);
        expect(accuracy.containsKey('hi'), true);
        expect(accuracy.containsKey('te'), true);
        expect(accuracy.containsKey('ur'), true);
        expect(accuracy.containsKey('ar'), true);
        
        expect(accuracy['en']!, greaterThan(0.9)); // High accuracy for English
        expect(accuracy['hi']!, greaterThan(0.8)); // Good accuracy for Hindi
        expect(accuracy['te']!, greaterThan(0.7)); // Good accuracy for Telugu
      });

      test('should handle transcription language changes', () async {
        await VoiceTranscriptionService.setTranscriptionLanguage('hi');
        // Should not throw an exception
        
        await VoiceTranscriptionService.setTranscriptionLanguage('te');
        // Should not throw an exception
        
        expect(() async {
          await VoiceTranscriptionService.setTranscriptionLanguage('invalid');
        }, throwsException);
      });
    });

    group('LanguagePreferences Tests', () {
      test('should validate language codes correctly', () {
        expect(LanguagePreferences.isValidLanguageCode('en'), true);
        expect(LanguagePreferences.isValidLanguageCode('hi'), true);
        expect(LanguagePreferences.isValidLanguageCode('te'), true);
        expect(LanguagePreferences.isValidLanguageCode('ur'), true);
        expect(LanguagePreferences.isValidLanguageCode('ar'), true);
        expect(LanguagePreferences.isValidLanguageCode('fr'), false);
        expect(LanguagePreferences.isValidLanguageCode('invalid'), false);
      });

      test('should save and retrieve language preferences', () async {
        await LanguagePreferences.setLanguage('hi');
        final savedLanguage = await LanguagePreferences.getLanguage();
        expect(savedLanguage, 'hi');
        
        await LanguagePreferences.setLanguage('te');
        final newSavedLanguage = await LanguagePreferences.getLanguage();
        expect(newSavedLanguage, 'te');
      });

      test('should provide language statistics', () async {
        final stats = await LanguagePreferences.getLanguageStats();
        
        expect(stats.containsKey('current_language'), true);
        expect(stats.containsKey('changes_today'), true);
        expect(stats.containsKey('last_change'), true);
        expect(stats.containsKey('first_launch_completed'), true);
      });

      test('should handle preference export and import', () async {
        await LanguagePreferences.setLanguage('ur');
        
        final exported = await LanguagePreferences.exportPreferences();
        expect(exported.containsKey('language'), true);
        expect(exported['language'], 'ur');
        
        await LanguagePreferences.setLanguage('ar');
        await LanguagePreferences.importPreferences(exported);
        
        final importedLanguage = await LanguagePreferences.getLanguage();
        expect(importedLanguage, 'ur');
      });
    });

    group('Integration Tests', () {
      test('should handle complete language change workflow', () async {
        // Start with English
        await LocalizationService.setLanguage('en');
        expect(LocalizationService.currentLanguage, 'en');
        expect(RTLSupportService.isCurrentLanguageRTL, false);
        
        // Change to Arabic (RTL)
        await LocalizationService.setLanguage('ar');
        expect(LocalizationService.currentLanguage, 'ar');
        expect(RTLSupportService.isCurrentLanguageRTL, true);
        
        // Change to Hindi (LTR)
        await LocalizationService.setLanguage('hi');
        expect(LocalizationService.currentLanguage, 'hi');
        expect(RTLSupportService.isCurrentLanguageRTL, false);
      });

      test('should handle message translation workflow', () async {
        await LocalizationService.setLanguage('en');
        
        final translationResult = await MessageTranslationService.translateMessage(
          message: 'Hello, how are you?',
          targetLanguage: 'hi',
        );
        
        expect(translationResult.isTranslated, true);
        expect(translationResult.sourceLanguage, 'en');
        expect(translationResult.targetLanguage, 'hi');
        expect(translationResult.confidence, greaterThan(0.0));
      });

      test('should handle voice transcription workflow', () async {
        // This would test with actual audio files in a real implementation
        const mockAudioPath = 'test_audio.wav';
        
        final transcriptionResult = await VoiceTranscriptionService.transcribeVoiceMessage(
          audioFilePath: mockAudioPath,
          targetLanguage: 'hi',
        );
        
        // In mock implementation, this should return a result
        expect(transcriptionResult.audioFilePath, mockAudioPath);
        expect(transcriptionResult.detectedLanguage, 'hi');
      });

      test('should maintain consistency across services', () async {
        // Set language to Telugu
        await LocalizationService.setLanguage('te');
        
        // Check all services reflect the change
        expect(LocalizationService.currentLanguage, 'te');
        expect(RTLSupportService.isCurrentLanguageRTL, false);
        expect(RTLSupportService.currentTextDirection.name, 'ltr');
        
        // Set language to Urdu (RTL)
        await LocalizationService.setLanguage('ur');
        
        expect(LocalizationService.currentLanguage, 'ur');
        expect(RTLSupportService.isCurrentLanguageRTL, true);
        expect(RTLSupportService.currentTextDirection.name, 'rtl');
      });
    });

    group('Performance Tests', () {
      test('should handle language detection efficiently', () {
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 1000; i++) {
          LocalizationService.detectLanguage('Hello world $i');
          LocalizationService.detectLanguage('à¤¨à¤®à¤¸à¥à¤¤à¥‡ à¤¦à¥à¤¨à¤¿à¤¯à¤¾ $i');
          LocalizationService.detectLanguage('à°¹à°²à±‹ à°ªà±à°°à°ªà°‚à°šà°‚ $i');
        }
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should complete in under 1 second
      });

      test('should handle number formatting efficiently', () async {
        await LocalizationService.setLanguage('hi');
        
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 1000; i++) {
          LocalizationService.formatNumber(i);
        }
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(500)); // Should complete in under 0.5 seconds
      });

      test('should handle translation caching', () async {
        // First translation (should be slower)
        final stopwatch1 = Stopwatch()..start();
        await MessageTranslationService.translateMessage(
          message: 'test message',
          targetLanguage: 'hi',
          sourceLanguage: 'en',
        );
        stopwatch1.stop();
        
        // Second translation (should be faster due to caching)
        final stopwatch2 = Stopwatch()..start();
        await MessageTranslationService.translateMessage(
          message: 'test message',
          targetLanguage: 'hi',
          sourceLanguage: 'en',
        );
        stopwatch2.stop();
        
        expect(stopwatch2.elapsedMilliseconds, lessThanOrEqualTo(stopwatch1.elapsedMilliseconds));
      });
    });

    tearDownAll(() {
      // Clean up
      MessageTranslationService.clearCache();
      VoiceTranscriptionService.clearCache();
    });
  });
}
