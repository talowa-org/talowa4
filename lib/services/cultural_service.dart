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
        'hindi': 'आपकी मेहनत रंग लाएगी। जय किसान!',
        'english': 'Your hard work will pay off. Jai Kisan!',
        'telugu': 'మీ కష్టం ఫలిస్తుంది. జై కిసాన్!',
      },
      {
        'hindi': 'एकजुट होकर हम अपनी जमीन की रक्षा करेंगे।',
        'english': 'Together we will protect our land.',
        'telugu': 'కలిసి మన భూమిని కాపాడుకుంటాం.',
      },
      {
        'hindi': 'आपका हक, आपकी जमीन, आपका सम्मान।',
        'english': 'Your right, your land, your dignity.',
        'telugu': 'మీ హక్కు, మీ భూమి, మీ గౌరవం.',
      },
    ];

    final stories = [
      {
        'title': 'Rameshwar\'s Victory',
        'content': 'After 15 years, Telangana\'s Rameshwar finally got his land title.',
        'impact': '5 acres of land secured',
      },
      {
        'title': 'सुनीता का संघर्ष',
        'content': 'महिला किसान सुनीता ने भूमि हड़पने वालों से अपनी जमीन वापस दिलाई।',
        'impact': '2 एकड़ जमीन वापस मिली',
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
    if (input.contains('जमीन') || input.contains('land') || input.contains('भूमि')) {
      extractedData['category'] = 'land_issue';
      
      if (input.contains('हड़प') || input.contains('grab') || input.contains('कब्जा')) {
        extractedData['type'] = 'land_grabbing';
      }
      
      if (input.contains('पटवारी') || input.contains('patwari')) {
        extractedData['involved_party'] = 'patwari';
      }
      
      // Extract time references
      if (input.contains('आज') || input.contains('today')) {
        extractedData['when'] = 'today';
      } else if (input.contains('कल') || input.contains('yesterday')) {
        extractedData['when'] = 'yesterday';
      } else if (input.contains('दिन') || input.contains('days')) {
        final match = RegExp(r'(\d+)').firstMatch(input);
        if (match != null) {
          extractedData['days_ago'] = int.parse(match.group(1)!);
        }
      }
    }

    // Extract location information
    final locationKeywords = ['गांव', 'village', 'मंडल', 'mandal', 'जिला', 'district'];
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
        'morning': 'सुप्रभात! आज कैसा दिन है?',
        'afternoon': 'नमस्कार! दोपहर की शुभकामनाएं।',
        'evening': 'शुभ संध्या! आज कैसा रहा?',
        'night': 'शुभ रात्रि! कल मिलते हैं।',
      },
      'telugu': {
        'morning': 'శుభోదయం! ఈ రోజు ఎలా ఉంది?',
        'afternoon': 'నమస్కారం! మధ్యాహ్న శుభాకాంక్షలు।',
        'evening': 'శుభ సాయంత్రం! ఈ రోజు ఎలా గడిచింది?',
        'night': 'శుభ రాత్రి! రేపు కలుద్దాం.',
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
        5: 'गांव का नेता! आपने 5 लोगों को जोड़ा।',
        10: 'समुदाय निर्माता! 10 सदस्य जुड़े।',
        25: 'गांव समन्वयक बनने के लिए तैयार!',
        50: 'महान नेता! 50 लोगों का नेटवर्क।',
      },
      'land_protected': {
        1: 'पहली जीत! 1 एकड़ जमीन सुरक्षित।',
        5: 'बड़ी सफलता! 5 एकड़ जमीन बचाई।',
        10: 'गांव का रक्षक! 10 एकड़ सुरक्षित।',
      },
      'cases_won': {
        1: 'न्याय की जीत! पहला केस जीता।',
        3: 'कानूनी योद्धा! 3 केस जीते।',
        5: 'न्याय के चैंपियन! 5 केस जीते।',
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
      'title': 'बधाई हो, $userName!',
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