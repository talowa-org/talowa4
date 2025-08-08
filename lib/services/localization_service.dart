// Centralized Localization Service for TALOWA
// This service ensures 100% language consistency throughout the app

import 'package:flutter/foundation.dart';
import 'language_preferences.dart';

class LocalizationService {
  static const String defaultLanguage = 'en';
  
  // Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'हिंदी',
    'te': 'తెలుగు',
  };
  
  // Current language (singleton pattern)
  static String _currentLanguage = defaultLanguage;
  static String get currentLanguage => _currentLanguage;
  
  // Language change listeners
  static final List<VoidCallback> _listeners = [];
  
  /// Initialize the localization service
  static Future<void> initialize() async {
    try {
      // Initialize language preferences first
      await LanguagePreferences.initialize();
      
      // Get the saved language
      _currentLanguage = await LanguagePreferences.getLanguage();
      
      debugPrint('LocalizationService initialized with language: $_currentLanguage');
    } catch (e) {
      debugPrint('Error initializing LocalizationService: $e');
      _currentLanguage = defaultLanguage;
    }
  }
  
  /// Change the app language
  static Future<void> setLanguage(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      debugPrint('Unsupported language: $languageCode');
      return;
    }
    
    try {
      // Save using LanguagePreferences
      final success = await LanguagePreferences.setLanguage(languageCode);
      
      if (success) {
        _currentLanguage = languageCode;
        debugPrint('Language changed to: $languageCode');
        
        // Notify all listeners
        for (final listener in _listeners) {
          listener();
        }
      } else {
        debugPrint('Failed to save language preference');
      }
    } catch (e) {
      debugPrint('Error changing language: $e');
    }
  }
  
  /// Add a language change listener
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }
  
  /// Remove a language change listener
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  /// Get localized text based on current language
  static String getText(Map<String, String> translations) {
    return translations[_currentLanguage] ?? 
           translations[defaultLanguage] ?? 
           translations.values.first;
  }
  
  /// Get localized greeting
  static String getGreeting() {
    final hour = DateTime.now().hour;
    
    final greetings = {
      'en': {
        'morning': 'Good morning! How is your day?',
        'afternoon': 'Good afternoon! Hope you\'re having a great day.',
        'evening': 'Good evening! How was your day?',
      },
      'hi': {
        'morning': 'सुप्रभात! आज कैसा दिन है?',
        'afternoon': 'नमस्कार! दोपहर की शुभकामनाएं।',
        'evening': 'शुभ संध्या! आपका दिन कैसा रहा?',
      },
      'te': {
        'morning': 'శుభోదయం! మీ రోజు ఎలా ఉంది?',
        'afternoon': 'శుభ మధ్యాహ్నం! మీ రోజు బాగా గడుస్తుందని ఆశిస్తున్నాను.',
        'evening': 'శుభ సాయంత్రం! మీ రోజు ఎలా గడిచింది?',
      },
    };
    
    String timeKey;
    if (hour < 12) {
      timeKey = 'morning';
    } else if (hour < 17) {
      timeKey = 'afternoon';
    } else {
      timeKey = 'evening';
    }
    
    return greetings[_currentLanguage]?[timeKey] ?? 
           greetings[defaultLanguage]![timeKey]!;
  }
  
  /// Get localized inspiration messages
  static String getInspirationMessage() {
    final messages = [
      {
        'en': 'Your hard work will pay off. Together we stand strong!',
        'hi': 'आपकी मेहनत रंग लाएगी। जय किसान!',
        'te': 'మీ కష్టం ఫలిస్తుంది. జై కిసాన్!',
      },
      {
        'en': 'Together we will protect our land.',
        'hi': 'एकजुट होकर हम अपनी जमीन की रक्षा करेंगे।',
        'te': 'కలిసి మన భూమిని కాపాడుకుంటాం.',
      },
      {
        'en': 'Your right, your land, your dignity.',
        'hi': 'आपका हक, आपकी जमीन, आपका सम्मान।',
        'te': 'మీ హక్కు, మీ భూమి, మీ గౌరవం.',
      },
    ];
    
    final randomMessage = messages[DateTime.now().day % messages.length];
    return getText(randomMessage);
  }
  
  /// Get localized success stories
  static Map<String, String> getSuccessStory() {
    final stories = [
      {
        'title': {
          'en': 'Rameshwar\'s Victory',
          'hi': 'रामेश्वर की जीत',
          'te': 'రామేశ్వర్ విజయం',
        },
        'content': {
          'en': 'After 15 years, Telangana\'s Rameshwar finally got his land title.',
          'hi': 'तेलंगाना के रामेश्वर ने 15 साल बाद अपनी जमीन का पट्टा पाया।',
          'te': '15 సంవత్సరాల తర్వాత, తెలంగాణకు చెందిన రామేశ్వర్ తన భూమి పట్టా పొందాడు.',
        },
      },
      {
        'title': {
          'en': 'Sunita\'s Land Rights',
          'hi': 'सुनीता के भूमि अधिकार',
          'te': 'సునీత భూమి హక్కులు',
        },
        'content': {
          'en': 'Sunita from Karnataka successfully defended her 3-acre farm from illegal occupation.',
          'hi': 'कर्नाटक की सुनीता ने अपनी 3 एकड़ जमीन को अवैध कब्जे से बचाया।',
          'te': 'కర్ణాటకకు చెందిన సునీత తన 3 ఎకరాల పొలాన్ని అక్రమ ఆక్రమణ నుండి రక్షించుకుంది.',
        },
      },
    ];
    
    final randomStory = stories[DateTime.now().day % stories.length];
    return {
      'title': getText(randomStory['title'] as Map<String, String>),
      'content': getText(randomStory['content'] as Map<String, String>),
    };
  }
  
  /// Get localized voice assistant responses
  static String getVoiceResponse(String responseType, {Map<String, String>? customResponses}) {
    if (customResponses != null) {
      return getText(customResponses);
    }
    
    final responses = {
      'land_issue_registered': {
        'en': 'I understand. Your land issue is being registered. Would you like to share your location?',
        'hi': 'मैं समझ गया। आपकी जमीन की समस्या दर्ज की जा रही है। क्या आप अपना स्थान बताना चाहेंगे?',
        'te': 'నేను అర్థం చేసుకున్నాను. మీ భూమి సమస్య నమోదు చేయబడుతోంది. మీ స్థానాన్ని పంచుకోవాలనుకుంటున్నారా?',
      },
      'land_help': {
        'en': 'I will help you with your land issue. Please provide more information.',
        'hi': 'आपकी जमीन की समस्या के लिए मैं मदद करूंगा। कृपया और जानकारी दें।',
        'te': 'మీ భూమి సమస్యతో నేను మీకు సహాయం చేస్తాను. దయచేసి మరింత సమాచారం అందించండి.',
      },
      'coordinator_search': {
        'en': 'Searching for your area coordinator.',
        'hi': 'आपके क्षेत्र का समन्वयक खोजा जा रहा है।',
        'te': 'మీ ప్రాంత సమన్వయకుడి కోసం వెతుకుతున్నాము.',
      },
      'general_help': {
        'en': 'I am here to help you. You can report land issues, view your network, or get legal assistance.',
        'hi': 'मैं आपकी मदद के लिए यहां हूं। आप जमीन की समस्या रिपोर्ट कर सकते हैं, अपना नेटवर्क देख सकते हैं, या कानूनी सहायता ले सकते हैं।',
        'te': 'నేను మీకు సహాయం చేయడానికి ఇక్కడ ఉన్నాను. మీరు భూమి సమస్యలను నివేదించవచ్చు, మీ నెట్‌వర్క్‌ను చూడవచ్చు లేదా న్యాయ సహాయం పొందవచ్చు.',
      },
      'listening': {
        'en': 'Please speak, I am listening',
        'hi': 'कहिए, मैं सुन रहा हूं',
        'te': 'చెప్పండి, నేను వింటున్నాను',
      },
      'error': {
        'en': 'Sorry, I could not understand',
        'hi': 'माफ करें, मैं समझ नहीं पाया',
        'te': 'క్షమించండి, నేను అర్థం చేసుకోలేకపోయాను',
      },
    };
    
    return getText(responses[responseType] ?? responses['error']!);
  }
  
  /// Get localized quick action labels
  static List<Map<String, String>> getQuickActions() {
    return [
      {
        'label': getText({
          'en': 'Land Issues',
          'hi': 'जमीन की समस्या',
          'te': 'భూమి సమస్యలు',
        }),
        'query': getText({
          'en': 'I need to report a land issue',
          'hi': 'जमीन की समस्या रिपोर्ट करना है',
          'te': 'భూమి సమస్యను నివేదించాలి',
        }),
      },
      {
        'label': getText({
          'en': 'My Network',
          'hi': 'मेरा नेटवर्क',
          'te': 'నా నెట్‌వర్క్',
        }),
        'query': getText({
          'en': 'Show my network',
          'hi': 'मेरा नेटवर्क दिखाओ',
          'te': 'నా నెట్‌వర్క్ చూపించు',
        }),
      },
      {
        'label': getText({
          'en': 'Legal Help',
          'hi': 'कानूनी मदद',
          'te': 'న్యాయ సహాయం',
        }),
        'query': getText({
          'en': 'I need legal help',
          'hi': 'कानूनी मदद चाहिए',
          'te': 'న్యాయ సహాయం కావాలి',
        }),
      },
      {
        'label': getText({
          'en': 'Support',
          'hi': 'समन्वयक',
          'te': 'మద్దతు',
        }),
        'query': getText({
          'en': 'Who is my area coordinator',
          'hi': 'मेरे क्षेत्र का समन्वयक कौन है',
          'te': 'నా ప్రాంత సమన్వయకుడు ఎవరు',
        }),
      },
    ];
  }
}