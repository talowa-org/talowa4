// Core Multi-Language Support Test for TALOWA
// Tests core functionality without Flutter bindings

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/localization_service.dart';
import 'package:talowa/services/rtl_support_service.dart';
import 'package:talowa/services/messaging/message_translation_service.dart';
import 'package:talowa/services/messaging/voice_transcription_service.dart';

void main() {
  group('Core Multi-Language Support Tests', () {
    group('LocalizationService Core Tests', () {
      test('should support all required languages', () {
        final supportedLanguages = LocalizationService.supportedLanguages;
        
        expect(supportedLanguages.containsKey('en'), true);
        expect(supportedLanguages.containsKey('hi'), true);
        expect(supportedLanguages.containsKey('te'), true);
        expect(supportedLanguages.containsKey('ur'), true);
        expect(supportedLanguages.containsKey('ar'), true);
        
        expect(supportedLanguages['en'], 'English');
        expect(supportedLanguages['hi'], 'à¤¹à¤¿à¤‚à¤¦à¥€');
        expect(supportedLanguages['te'], 'à°¤à±†à°²à±à°—à±');
        expect(supportedLanguages['ur'], 'Ø§Ø±Ø¯Ùˆ');
        expect(supportedLanguages['ar'], 'Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©');
      });

      test('should detect language correctly', () {
        expect(LocalizationService.detectLanguage('Hello world'), 'en');
        expect(LocalizationService.detectLanguage('à¤¨à¤®à¤¸à¥à¤¤à¥‡ à¤¦à¥à¤¨à¤¿à¤¯à¤¾'), 'hi');
        expect(LocalizationService.detectLanguage('à°¹à°²à±‹ à°ªà±à°°à°ªà°‚à°šà°‚'), 'te');
        expect(LocalizationService.detectLanguage('Ù…Ø±Ø­Ø¨Ø§ Ø¨Ø§Ù„Ø¹Ø§Ù„Ù…'), 'ar');
        expect(LocalizationService.detectLanguage(''), 'en'); // Default for empty
      });

      test('should identify RTL languages correctly', () {
        expect(LocalizationService.rtlLanguages.contains('ur'), true);
        expect(LocalizationService.rtlLanguages.contains('ar'), true);
        expect(LocalizationService.rtlLanguages.contains('en'), false);
        expect(LocalizationService.rtlLanguages.contains('hi'), false);
        expect(LocalizationService.rtlLanguages.contains('te'), false);
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

      test('should provide messaging translations', () {
        final messagingTranslations = LocalizationService.getMessagingTranslations();
        
        expect(messagingTranslations.containsKey('typing'), true);
        expect(messagingTranslations.containsKey('online'), true);
        expect(messagingTranslations.containsKey('offline'), true);
        expect(messagingTranslations.containsKey('delivered'), true);
        expect(messagingTranslations.containsKey('read'), true);
        
        expect(messagingTranslations['typing']!.isNotEmpty, true);
        expect(messagingTranslations['online']!.isNotEmpty, true);
      });
    });

    group('RTLSupportService Core Tests', () {
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

    group('MessageTranslationService Core Tests', () {
      test('should identify supported translation pairs', () {
        final supportedTranslations = MessageTranslationService.getSupportedTranslations();
        
        expect(supportedTranslations.containsKey('en'), true);
        expect(supportedTranslations.containsKey('hi'), true);
        expect(supportedTranslations.containsKey('te'), true);
        expect(supportedTranslations.containsKey('ur'), true);
        expect(supportedTranslations.containsKey('ar'), true);
        
        expect(supportedTranslations['en']!.isNotEmpty, true);
        expect(supportedTranslations['hi']!.isNotEmpty, true);
      });

      test('should check translation support correctly', () {
        expect(MessageTranslationService.isTranslationSupported('en', 'hi'), true);
        expect(MessageTranslationService.isTranslationSupported('hi', 'en'), true);
        expect(MessageTranslationService.isTranslationSupported('te', 'en'), true);
        expect(MessageTranslationService.isTranslationSupported('ur', 'ar'), true);
        expect(MessageTranslationService.isTranslationSupported('en', 'fr'), false);
      });

      test('should provide translation confidence scores', () {
        final confidence1 = MessageTranslationService.getTranslationConfidence('hi', 'ur');
        final confidence2 = MessageTranslationService.getTranslationConfidence('en', 'te');
        
        expect(confidence1, greaterThan(0.0));
        expect(confidence1, lessThanOrEqualTo(1.0));
        expect(confidence2, greaterThan(0.0));
        expect(confidence2, lessThanOrEqualTo(1.0));
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

      test('should translate common phrases', () async {
        final result = await MessageTranslationService.translateMessage(
          message: 'hello',
          targetLanguage: 'hi',
          sourceLanguage: 'en',
        );
        
        expect(result.sourceLanguage, 'en');
        expect(result.targetLanguage, 'hi');
        expect(result.confidence, greaterThan(0.0));
      });
    });

    group('VoiceTranscriptionService Core Tests', () {
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
        expect(VoiceTranscriptionService.isLanguageSupported('invalid'), false);
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
        expect(accuracy['ur']!, greaterThan(0.7)); // Good accuracy for Urdu
        expect(accuracy['ar']!, greaterThan(0.6)); // Medium accuracy for Arabic
      });

      test('should handle transcription results', () async {
        const mockAudioPath = 'test_audio.wav';
        
        final transcriptionResult = await VoiceTranscriptionService.transcribeVoiceMessage(
          audioFilePath: mockAudioPath,
          targetLanguage: 'hi',
        );
        
        expect(transcriptionResult.audioFilePath, mockAudioPath);
        expect(transcriptionResult.detectedLanguage, 'hi');
        expect(transcriptionResult.confidence, greaterThan(0.0));
      });
    });

    group('Integration Tests', () {
      test('should handle language family relationships', () {
        final families = LocalizationService.languageFamilies;
        
        expect(families.containsKey('indo_european'), true);
        expect(families.containsKey('dravidian'), true);
        expect(families.containsKey('semitic'), true);
        
        expect(families['indo_european']!.contains('en'), true);
        expect(families['indo_european']!.contains('hi'), true);
        expect(families['indo_european']!.contains('ur'), true);
        
        expect(families['dravidian']!.contains('te'), true);
        expect(families['semitic']!.contains('ar'), true);
      });

      test('should provide consistent language support across services', () {
        final localizationLanguages = LocalizationService.supportedLanguages.keys.toSet();
        final transcriptionLanguages = VoiceTranscriptionService.getSupportedLanguages().toSet();
        final translationLanguages = MessageTranslationService.getSupportedTranslations().keys.toSet();
        
        // All services should support the core languages
        final coreLanguages = {'en', 'hi', 'te', 'ur', 'ar'};
        
        expect(localizationLanguages.containsAll(coreLanguages), true);
        expect(transcriptionLanguages.containsAll(coreLanguages), true);
        expect(translationLanguages.containsAll(coreLanguages), true);
      });

      test('should handle RTL detection consistently', () {
        final rtlLanguages = LocalizationService.rtlLanguages;
        
        for (final language in rtlLanguages) {
          expect(RTLSupportService.getTextDirectionForLanguage(language).name, 'rtl');
          expect(RTLSupportService.getTextAlignForLanguage(language).name, 'right');
        }
        
        final ltrLanguages = LocalizationService.supportedLanguages.keys
            .where((lang) => !rtlLanguages.contains(lang));
        
        for (final language in ltrLanguages) {
          expect(RTLSupportService.getTextDirectionForLanguage(language).name, 'ltr');
          expect(RTLSupportService.getTextAlignForLanguage(language).name, 'left');
        }
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

      test('should handle translation caching', () async {
        // Clear cache first
        MessageTranslationService.clearCache();
        
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

    group('Error Handling Tests', () {
      test('should handle invalid language codes gracefully', () {
        expect(LocalizationService.detectLanguage(''), 'en'); // Default for empty
        expect(RTLSupportService.getTextDirectionForLanguage('invalid').name, 'ltr'); // Default to LTR
        expect(VoiceTranscriptionService.isLanguageSupported('invalid'), false);
      });

      test('should handle translation errors gracefully', () async {
        final result = await MessageTranslationService.translateMessage(
          message: '',
          targetLanguage: 'invalid',
          sourceLanguage: 'en',
        );
        
        expect(result.isTranslated, false);
        expect(result.confidence, 0.0);
        expect(result.error, isNotNull);
      });

      test('should handle transcription errors gracefully', () async {
        final result = await VoiceTranscriptionService.transcribeVoiceMessage(
          audioFilePath: 'nonexistent.wav',
          targetLanguage: 'en',
        );
        
        expect(result.isSuccessful, false);
        expect(result.confidence, 0.0);
        expect(result.error, isNotNull);
      });
    });

    tearDownAll(() {
      // Clean up
      MessageTranslationService.clearCache();
      VoiceTranscriptionService.clearCache();
    });
  });
}
