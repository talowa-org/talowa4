import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
// import 'package:speech_to_text/speech_to_text.dart';  // Temporarily disabled
import 'package:cloud_firestore/cloud_firestore.dart';

class CulturalService {
  static final FlutterTts _tts = FlutterTts();
  // static final SpeechToText _stt = SpeechToText();  // Temporarily disabled
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize text-to-speech for local languages
  static Future<void> initializeTTS() async {
    await _tts.setLanguage('en-US'); // Default to English
    await _tts.setSpeechRate(0.5); // Slower for better comprehension
    await _tts.setVolume(0.8);
    await _tts.setPitch(1.0);
  }

  /// Voice-based navigation for illiterate users
  static Future<void> speakText(String text, {String? language}) async {
    try {
      if (language != null) {
        await _tts.setLanguage(language);
      }
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  /// Get culturally appropriate icons
  static Map<String, IconData> getCulturalIcons() {
    return {
      // Land & Agriculture
      'land': Icons.landscape,
      'farm': Icons.agriculture,
      'crop': Icons.grass,
      'water': Icons.water_drop,
      'tractor': Icons.agriculture,
      
      // People & Community
      'farmer': Icons.person,
      'village': Icons.home,
      'community': Icons.groups,
      'elder': Icons.elderly,
      'woman': Icons.woman,
      
      // Government & Legal
      'government': Icons.account_balance,
      'legal': Icons.gavel,
      'document': Icons.description,
      'stamp': Icons.verified,
      'signature': Icons.draw,
      
      // Communication
      'announcement': Icons.campaign,
      'meeting': Icons.meeting_room,
      'phone': Icons.phone,
      'message': Icons.message,
      
      // Actions
      'report': Icons.report_problem,
      'help': Icons.help,
      'success': Icons.celebration,
      'warning': Icons.warning,
    };
  }

  /// Get regional color scheme
  static Map<String, Color> getRegionalColors() {
    return {
      'primary': const Color(0xFF2E7D32), // Forest Green (agriculture)
      'secondary': const Color(0xFFFF8F00), // Saffron (cultural)
      'accent': const Color(0xFF1976D2), // Blue (trust)
      'success': const Color(0xFF388E3C), // Green (growth)
      'warning': const Color(0xFFF57C00), // Orange (caution)
      'error': const Color(0xFFD32F2F), // Red (danger)
      'earth': const Color(0xFF8D6E63), // Brown (soil)
      'sky': const Color(0xFF03A9F4), // Light Blue (hope)
    };
  }

  /// Daily motivational messages
  static Future<Map<String, dynamic>> getDailyMotivation() async {
    try {
      final today = DateTime.now();
      final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
      
      // Get cached motivational content
      final motivationDoc = await _firestore
          .collection('content')
          .doc('daily_motivation')
          .get();
      
      if (motivationDoc.exists) {
        final data = motivationDoc.data()!;
        final messages = data['messages'] as List;
        final successStories = data['success_stories'] as List;
        
        // Rotate content based on day of year
        final messageIndex = dayOfYear % messages.length;
        final storyIndex = dayOfYear % successStories.length;
        
        return {
          'message': messages[messageIndex],
          'success_story': successStories[storyIndex],
          'date': today.toIso8601String(),
        };
      }
      
      // Fallback motivational content
      return _getFallbackMotivation(dayOfYear);
    } catch (e) {
      debugPrint('Error getting daily motivation: $e');
      return _getFallbackMotivation(DateTime.now().day);
    }
  }

  static Map<String, dynamic> _getFallbackMotivation(int seed) {
    final messages = [
      {
        'hindi': 'à¤†à¤ªà¤•à¥€ à¤®à¥‡à¤¹à¤¨à¤¤ à¤°à¤‚à¤— à¤²à¤¾à¤à¤—à¥€à¥¤ à¤œà¤¯ à¤•à¤¿à¤¸à¤¾à¤¨!',
        'english': 'Your hard work will pay off. Jai Kisan!',
        'telugu': 'à°®à±€ à°•à°·à±à°Ÿà°‚ à°«à°²à°¿à°¸à±à°¤à±à°‚à°¦à°¿. à°œà±ˆ à°•à°¿à°¸à°¾à°¨à±!',
      },
      {
        'hindi': 'à¤à¤•à¤œà¥à¤Ÿ à¤¹à¥‹à¤•à¤° à¤¹à¤® à¤…à¤ªà¤¨à¥€ à¤œà¤®à¥€à¤¨ à¤•à¥€ à¤°à¤•à¥à¤·à¤¾ à¤•à¤°à¥‡à¤‚à¤—à¥‡à¥¤',
        'english': 'Together we will protect our land.',
        'telugu': 'à°•à°²à°¿à°¸à°¿ à°®à°¨ à°­à±‚à°®à°¿à°¨à°¿ à°•à°¾à°ªà°¾à°¡à±à°•à±à°‚à°Ÿà°¾à°‚.',
      },
      {
        'hindi': 'à¤†à¤ªà¤•à¤¾ à¤¹à¤•, à¤†à¤ªà¤•à¥€ à¤œà¤®à¥€à¤¨, à¤†à¤ªà¤•à¤¾ à¤¸à¤®à¥à¤®à¤¾à¤¨à¥¤',
        'english': 'Your right, your land, your dignity.',
        'telugu': 'à°®à±€ à°¹à°•à±à°•à±, à°®à±€ à°­à±‚à°®à°¿, à°®à±€ à°—à±Œà°°à°µà°‚.',
      },
    ];

    final stories = [
      {
        'title': 'Rameshwar\'s Victory',
        'content': 'After 15 years, Telangana\'s Rameshwar finally got his land title.',
        'impact': '5 acres of land secured',
      },
      {
        'title': 'à¤¸à¥à¤¨à¥€à¤¤à¤¾ à¤•à¤¾ à¤¸à¤‚à¤˜à¤°à¥à¤·',
        'content': 'à¤®à¤¹à¤¿à¤²à¤¾ à¤•à¤¿à¤¸à¤¾à¤¨ à¤¸à¥à¤¨à¥€à¤¤à¤¾ à¤¨à¥‡ à¤­à¥‚à¤®à¤¿ à¤¹à¤¡à¤¼à¤ªà¤¨à¥‡ à¤µà¤¾à¤²à¥‹à¤‚ à¤¸à¥‡ à¤…à¤ªà¤¨à¥€ à¤œà¤®à¥€à¤¨ à¤µà¤¾à¤ªà¤¸ à¤¦à¤¿à¤²à¤¾à¤ˆà¥¤',
        'impact': '2 à¤à¤•à¤¡à¤¼ à¤œà¤®à¥€à¤¨ à¤µà¤¾à¤ªà¤¸ à¤®à¤¿à¤²à¥€',
      },
    ];

    return {
      'message': messages[seed % messages.length],
      'success_story': stories[seed % stories.length],
      'date': DateTime.now().toIso8601String(),
    };
  }

  /// Voice-first form filling
  static Future<Map<String, dynamic>> voiceFormFiller(String voiceInput) async {
    // Simple NLP for common patterns
    final input = voiceInput.toLowerCase();
    Map<String, dynamic> extractedData = {};

    // Extract land grabbing information
    if (input.contains('à¤œà¤®à¥€à¤¨') || input.contains('land') || input.contains('à¤­à¥‚à¤®à¤¿')) {
      extractedData['category'] = 'land_issue';
      
      if (input.contains('à¤¹à¤¡à¤¼à¤ª') || input.contains('grab') || input.contains('à¤•à¤¬à¥à¤œà¤¾')) {
        extractedData['type'] = 'land_grabbing';
      }
      
      if (input.contains('à¤ªà¤Ÿà¤µà¤¾à¤°à¥€') || input.contains('patwari')) {
        extractedData['involved_party'] = 'patwari';
      }
      
      // Extract time references
      if (input.contains('à¤†à¤œ') || input.contains('today')) {
        extractedData['when'] = 'today';
      } else if (input.contains('à¤•à¤²') || input.contains('yesterday')) {
        extractedData['when'] = 'yesterday';
      } else if (input.contains('à¤¦à¤¿à¤¨') || input.contains('days')) {
        final match = RegExp(r'(\d+)').firstMatch(input);
        if (match != null) {
          extractedData['days_ago'] = int.parse(match.group(1)!);
        }
      }
    }

    // Extract location information
    final locationKeywords = ['à¤—à¤¾à¤‚à¤µ', 'village', 'à¤®à¤‚à¤¡à¤²', 'mandal', 'à¤œà¤¿à¤²à¤¾', 'district'];
    for (String keyword in locationKeywords) {
      if (input.contains(keyword)) {
        extractedData['has_location'] = true;
        break;
      }
    }

    return extractedData;
  }

  /// Cultural greeting based on time and region
  static String getCulturalGreeting({String language = 'english'}) {
    final hour = DateTime.now().hour;
    
    Map<String, Map<String, String>> greetings = {
      'hindi': {
        'morning': 'à¤¸à¥à¤ªà¥à¤°à¤­à¤¾à¤¤! à¤†à¤œ à¤•à¥ˆà¤¸à¤¾ à¤¦à¤¿à¤¨ à¤¹à¥ˆ?',
        'afternoon': 'à¤¨à¤®à¤¸à¥à¤•à¤¾à¤°! à¤¦à¥‹à¤ªà¤¹à¤° à¤•à¥€ à¤¶à¥à¤­à¤•à¤¾à¤®à¤¨à¤¾à¤à¤‚à¥¤',
        'evening': 'à¤¶à¥à¤­ à¤¸à¤‚à¤§à¥à¤¯à¤¾! à¤†à¤œ à¤•à¥ˆà¤¸à¤¾ à¤°à¤¹à¤¾?',
        'night': 'à¤¶à¥à¤­ à¤°à¤¾à¤¤à¥à¤°à¤¿! à¤•à¤² à¤®à¤¿à¤²à¤¤à¥‡ à¤¹à¥ˆà¤‚à¥¤',
      },
      'telugu': {
        'morning': 'à°¶à±à°­à±‹à°¦à°¯à°‚! à°ˆ à°°à±‹à°œà± à°Žà°²à°¾ à°‰à°‚à°¦à°¿?',
        'afternoon': 'à°¨à°®à°¸à±à°•à°¾à°°à°‚! à°®à°§à±à°¯à°¾à°¹à±à°¨ à°¶à±à°­à°¾à°•à°¾à°‚à°•à±à°·à°²à±à¥¤',
        'evening': 'à°¶à±à°­ à°¸à°¾à°¯à°‚à°¤à±à°°à°‚! à°ˆ à°°à±‹à°œà± à°Žà°²à°¾ à°—à°¡à°¿à°šà°¿à°‚à°¦à°¿?',
        'night': 'à°¶à±à°­ à°°à°¾à°¤à±à°°à°¿! à°°à±‡à°ªà± à°•à°²à±à°¦à±à°¦à°¾à°‚.',
      },
      'english': {
        'morning': 'Good morning! How is your day?',
        'afternoon': 'Good afternoon! Hope you\'re doing well.',
        'evening': 'Good evening! How was your day?',
        'night': 'Good night! See you tomorrow.',
      },
    };

    String timeOfDay;
    if (hour < 12) {
      timeOfDay = 'morning';
    } else if (hour < 17) {
      timeOfDay = 'afternoon';
    } else if (hour < 21) {
      timeOfDay = 'evening';
    } else {
      timeOfDay = 'night';
    }

    return greetings[language]?[timeOfDay] ?? greetings['english']![timeOfDay]!;
  }

  /// Achievement celebrations
  static Map<String, dynamic> generateAchievement({
    required String type,
    required int count,
    required String userName,
  }) {
    final achievements = {
      'referrals': {
        5: 'à¤—à¤¾à¤‚à¤µ à¤•à¤¾ à¤¨à¥‡à¤¤à¤¾! à¤†à¤ªà¤¨à¥‡ 5 à¤²à¥‹à¤—à¥‹à¤‚ à¤•à¥‹ à¤œà¥‹à¤¡à¤¼à¤¾à¥¤',
        10: 'à¤¸à¤®à¥à¤¦à¤¾à¤¯ à¤¨à¤¿à¤°à¥à¤®à¤¾à¤¤à¤¾! 10 à¤¸à¤¦à¤¸à¥à¤¯ à¤œà¥à¤¡à¤¼à¥‡à¥¤',
        25: 'à¤—à¤¾à¤‚à¤µ à¤¸à¤®à¤¨à¥à¤µà¤¯à¤• à¤¬à¤¨à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤¤à¥ˆà¤¯à¤¾à¤°!',
        50: 'à¤®à¤¹à¤¾à¤¨ à¤¨à¥‡à¤¤à¤¾! 50 à¤²à¥‹à¤—à¥‹à¤‚ à¤•à¤¾ à¤¨à¥‡à¤Ÿà¤µà¤°à¥à¤•à¥¤',
      },
      'land_protected': {
        1: 'à¤ªà¤¹à¤²à¥€ à¤œà¥€à¤¤! 1 à¤à¤•à¤¡à¤¼ à¤œà¤®à¥€à¤¨ à¤¸à¥à¤°à¤•à¥à¤·à¤¿à¤¤à¥¤',
        5: 'à¤¬à¤¡à¤¼à¥€ à¤¸à¤«à¤²à¤¤à¤¾! 5 à¤à¤•à¤¡à¤¼ à¤œà¤®à¥€à¤¨ à¤¬à¤šà¤¾à¤ˆà¥¤',
        10: 'à¤—à¤¾à¤‚à¤µ à¤•à¤¾ à¤°à¤•à¥à¤·à¤•! 10 à¤à¤•à¤¡à¤¼ à¤¸à¥à¤°à¤•à¥à¤·à¤¿à¤¤à¥¤',
      },
      'cases_won': {
        1: 'à¤¨à¥à¤¯à¤¾à¤¯ à¤•à¥€ à¤œà¥€à¤¤! à¤ªà¤¹à¤²à¤¾ à¤•à¥‡à¤¸ à¤œà¥€à¤¤à¤¾à¥¤',
        3: 'à¤•à¤¾à¤¨à¥‚à¤¨à¥€ à¤¯à¥‹à¤¦à¥à¤§à¤¾! 3 à¤•à¥‡à¤¸ à¤œà¥€à¤¤à¥‡à¥¤',
        5: 'à¤¨à¥à¤¯à¤¾à¤¯ à¤•à¥‡ à¤šà¥ˆà¤‚à¤ªà¤¿à¤¯à¤¨! 5 à¤•à¥‡à¤¸ à¤œà¥€à¤¤à¥‡à¥¤',
      },
    };

    final typeAchievements = achievements[type];
    if (typeAchievements == null) return {};

    // Find the highest achievement unlocked
    String? message;
    int highestUnlocked = 0;
    
    for (int threshold in typeAchievements.keys) {
      if (count >= threshold && threshold > highestUnlocked) {
        highestUnlocked = threshold;
        message = typeAchievements[threshold];
      }
    }

    if (message == null) return {};

    return {
      'title': 'à¤¬à¤§à¤¾à¤ˆ à¤¹à¥‹, $userName!',
      'message': message,
      'type': type,
      'count': count,
      'level': highestUnlocked,
      'celebration': true,
    };
  }

  /// Haptic feedback for important actions
  static void provideFeedback(String type) {
    switch (type) {
      case 'success':
        HapticFeedback.lightImpact();
        break;
      case 'warning':
        HapticFeedback.mediumImpact();
        break;
      case 'error':
        HapticFeedback.heavyImpact();
        break;
      case 'selection':
        HapticFeedback.selectionClick();
        break;
    }
  }
}
