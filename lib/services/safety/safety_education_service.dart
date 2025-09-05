// Safety Education Service for TALOWA
// Implements Task 19: Build user safety features - Safety Education

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SafetyEducationService {
  static final SafetyEducationService _instance = SafetyEducationService._internal();
  factory SafetyEducationService() => _instance;
  SafetyEducationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get safety education modules
  Future<List<SafetyModule>> getSafetyModules({String? language}) async {
    try {
      Query query = _firestore
          .collection('safety_modules')
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true);

      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty && language != null) {
        // Fallback to English if no modules in requested language
        return getSafetyModules(language: 'english');
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SafetyModule.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting safety modules: $e');
      return _getDefaultSafetyModules();
    }
  }

  /// Get safety tips for specific scenarios
  Future<List<SafetyTip>> getSafetyTips({
    SafetyScenario? scenario,
    String? language,
  }) async {
    try {
      Query query = _firestore
          .collection('safety_tips')
          .where('isActive', isEqualTo: true);

      if (scenario != null) {
        query = query.where('scenario', isEqualTo: scenario.toString());
      }

      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }

      final snapshot = await query.orderBy('priority', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SafetyTip.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting safety tips: $e');
      return _getDefaultSafetyTips(scenario);
    }
  }

  /// Track user's safety education progress
  Future<void> trackModuleProgress({
    required String userId,
    required String moduleId,
    required double progress,
    bool completed = false,
  }) async {
    try {
      await _firestore
          .collection('user_safety_progress')
          .doc('${userId}_$moduleId')
          .set({
        'userId': userId,
        'moduleId': moduleId,
        'progress': progress,
        'completed': completed,
        'lastUpdated': FieldValue.serverTimestamp(),
        'completedAt': completed ? FieldValue.serverTimestamp() : null,
      }, SetOptions(merge: true));

      // Update user's overall safety education score
      await _updateUserSafetyScore(userId);
    } catch (e) {
      debugPrint('Error tracking module progress: $e');
      rethrow;
    }
  }

  /// Get user's safety education progress
  Future<UserSafetyProgress> getUserSafetyProgress(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_safety_progress')
          .where('userId', isEqualTo: userId)
          .get();

      final moduleProgress = <String, ModuleProgress>{};
      int completedModules = 0;
      double totalProgress = 0.0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final moduleId = data['moduleId'] as String;
        final progress = (data['progress'] as num).toDouble();
        final completed = data['completed'] as bool? ?? false;

        moduleProgress[moduleId] = ModuleProgress(
          moduleId: moduleId,
          progress: progress,
          completed: completed,
          lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
          completedAt: data['completedAt'] != null
              ? (data['completedAt'] as Timestamp).toDate()
              : null,
        );

        if (completed) completedModules++;
        totalProgress += progress;
      }

      final averageProgress = snapshot.docs.isNotEmpty 
          ? totalProgress / snapshot.docs.length 
          : 0.0;

      return UserSafetyProgress(
        userId: userId,
        moduleProgress: moduleProgress,
        completedModules: completedModules,
        totalModules: snapshot.docs.length,
        overallProgress: averageProgress,
        safetyScore: await _getUserSafetyScore(userId),
      );
    } catch (e) {
      debugPrint('Error getting user safety progress: $e');
      return UserSafetyProgress(
        userId: userId,
        moduleProgress: {},
        completedModules: 0,
        totalModules: 0,
        overallProgress: 0.0,
        safetyScore: 0,
      );
    }
  }

  /// Get safety quiz questions
  Future<List<SafetyQuizQuestion>> getQuizQuestions({
    required String moduleId,
    String? language,
  }) async {
    try {
      Query query = _firestore
          .collection('safety_quiz_questions')
          .where('moduleId', isEqualTo: moduleId)
          .where('isActive', isEqualTo: true);

      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SafetyQuizQuestion.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting quiz questions: $e');
      return [];
    }
  }

  /// Submit quiz answers and get results
  Future<QuizResult> submitQuizAnswers({
    required String userId,
    required String moduleId,
    required Map<String, String> answers,
  }) async {
    try {
      final questions = await getQuizQuestions(moduleId: moduleId);
      int correctAnswers = 0;
      final feedback = <String, String>{};

      for (final question in questions) {
        final userAnswer = answers[question.id];
        final isCorrect = userAnswer == question.correctAnswer;
        
        if (isCorrect) {
          correctAnswers++;
        }
        
        feedback[question.id] = isCorrect 
            ? 'Correct!' 
            : 'Incorrect. ${question.explanation}';
      }

      final score = questions.isNotEmpty 
          ? (correctAnswers / questions.length) * 100 
          : 0.0;
      
      final passed = score >= 70.0; // 70% passing score

      // Save quiz result
      await _firestore.collection('quiz_results').add({
        'userId': userId,
        'moduleId': moduleId,
        'score': score,
        'correctAnswers': correctAnswers,
        'totalQuestions': questions.length,
        'passed': passed,
        'answers': answers,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update module progress if passed
      if (passed) {
        await trackModuleProgress(
          userId: userId,
          moduleId: moduleId,
          progress: 100.0,
          completed: true,
        );
      }

      return QuizResult(
        score: score,
        correctAnswers: correctAnswers,
        totalQuestions: questions.length,
        passed: passed,
        feedback: feedback,
      );
    } catch (e) {
      debugPrint('Error submitting quiz answers: $e');
      rethrow;
    }
  }

  /// Get safety alerts for user
  Future<List<SafetyAlert>> getSafetyAlerts({
    required String userId,
    bool unreadOnly = false,
  }) async {
    try {
      Query query = _firestore
          .collection('safety_alerts')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      if (unreadOnly) {
        // Get user's read alerts
        final readAlertsSnapshot = await _firestore
            .collection('user_read_alerts')
            .where('userId', isEqualTo: userId)
            .get();
        
        final readAlertIds = readAlertsSnapshot.docs
            .map((doc) => doc.data()['alertId'] as String)
            .toList();

        if (readAlertIds.isNotEmpty) {
          query = query.where(FieldPath.documentId, whereNotIn: readAlertIds);
        }
      }

      final snapshot = await query.limit(50).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SafetyAlert.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      debugPrint('Error getting safety alerts: $e');
      return [];
    }
  }

  /// Mark safety alert as read
  Future<void> markAlertAsRead({
    required String userId,
    required String alertId,
  }) async {
    try {
      await _firestore
          .collection('user_read_alerts')
          .doc('${userId}_$alertId')
          .set({
        'userId': userId,
        'alertId': alertId,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking alert as read: $e');
      rethrow;
    }
  }

  /// Get safety education statistics
  Future<SafetyEducationStats> getSafetyEducationStats() async {
    try {
      // Get total users with safety progress
      final progressSnapshot = await _firestore
          .collection('user_safety_progress')
          .get();

      final userIds = progressSnapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toSet();

      // Get completed modules count
      final completedSnapshot = await _firestore
          .collection('user_safety_progress')
          .where('completed', isEqualTo: true)
          .get();

      // Get quiz attempts
      final quizSnapshot = await _firestore
          .collection('quiz_results')
          .get();

      // Get active alerts
      final alertsSnapshot = await _firestore
          .collection('safety_alerts')
          .where('isActive', isEqualTo: true)
          .get();

      return SafetyEducationStats(
        totalUsers: userIds.length,
        completedModules: completedSnapshot.docs.length,
        quizAttempts: quizSnapshot.docs.length,
        activeAlerts: alertsSnapshot.docs.length,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting safety education stats: $e');
      return SafetyEducationStats(
        totalUsers: 0,
        completedModules: 0,
        quizAttempts: 0,
        activeAlerts: 0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  // Private helper methods

  List<SafetyModule> _getDefaultSafetyModules() {
    return [
      SafetyModule(
        id: 'online_safety_basics',
        title: 'Online Safety Basics',
        description: 'Learn fundamental online safety principles',
        category: SafetyCategory.digitalSafety,
        priority: 10,
        estimatedDuration: 15,
        language: 'english',
        content: [
          SafetyContent(
            type: ContentType.text,
            title: 'Protecting Your Personal Information',
            content: 'Never share personal information like phone numbers, addresses, or financial details with strangers online.',
          ),
          SafetyContent(
            type: ContentType.text,
            title: 'Recognizing Scams',
            content: 'Be wary of offers that seem too good to be true, requests for money, or urgent messages asking for personal information.',
          ),
        ],
      ),
      SafetyModule(
        id: 'harassment_prevention',
        title: 'Harassment Prevention',
        description: 'Learn how to identify and prevent harassment',
        category: SafetyCategory.harassment,
        priority: 9,
        estimatedDuration: 20,
        language: 'english',
        content: [
          SafetyContent(
            type: ContentType.text,
            title: 'What is Harassment?',
            content: 'Harassment includes repeated unwanted contact, threats, bullying, or any behavior that makes you feel unsafe.',
          ),
          SafetyContent(
            type: ContentType.text,
            title: 'How to Respond',
            content: 'Block the user, report the behavior, save evidence, and seek support from trusted friends or authorities.',
          ),
        ],
      ),
    ];
  }

  List<SafetyTip> _getDefaultSafetyTips(SafetyScenario? scenario) {
    final tips = <SafetyTip>[
      SafetyTip(
        id: 'strong_passwords',
        title: 'Use Strong Passwords',
        content: 'Create unique passwords with a mix of letters, numbers, and symbols. Never reuse passwords across different accounts.',
        scenario: SafetyScenario.accountSecurity,
        priority: 10,
        language: 'english',
      ),
      SafetyTip(
        id: 'verify_links',
        title: 'Verify Links Before Clicking',
        content: 'Hover over links to see the actual URL before clicking. Be suspicious of shortened URLs or links from unknown sources.',
        scenario: SafetyScenario.phishing,
        priority: 9,
        language: 'english',
      ),
      SafetyTip(
        id: 'report_harassment',
        title: 'Report Harassment Immediately',
        content: 'Don\'t ignore harassment. Use the report feature and block users who make you uncomfortable.',
        scenario: SafetyScenario.harassment,
        priority: 10,
        language: 'english',
      ),
    ];

    if (scenario != null) {
      return tips.where((tip) => tip.scenario == scenario).toList();
    }
    return tips;
  }

  Future<void> _updateUserSafetyScore(String userId) async {
    try {
      final progress = await getUserSafetyProgress(userId);
      final score = _calculateSafetyScore(progress);

      await _firestore.collection('user_safety_scores').doc(userId).set({
        'userId': userId,
        'score': score,
        'completedModules': progress.completedModules,
        'overallProgress': progress.overallProgress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user safety score: $e');
    }
  }

  Future<int> _getUserSafetyScore(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_safety_scores')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data()!['score'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting user safety score: $e');
      return 0;
    }
  }

  int _calculateSafetyScore(UserSafetyProgress progress) {
    // Base score from completed modules (0-70 points)
    final moduleScore = progress.totalModules > 0
        ? (progress.completedModules / progress.totalModules * 70).round()
        : 0;

    // Bonus points for overall progress (0-30 points)
    final progressBonus = (progress.overallProgress * 0.3).round();

    return (moduleScore + progressBonus).clamp(0, 100);
  }
}

// Data models for safety education

enum SafetyCategory {
  digitalSafety,
  harassment,
  privacy,
  scamPrevention,
  emergencyResponse,
}

enum SafetyScenario {
  accountSecurity,
  phishing,
  harassment,
  dataPrivacy,
  emergencyContact,
}

enum ContentType {
  text,
  video,
  interactive,
  quiz,
}

enum AlertSeverity {
  info,
  warning,
  critical,
}

class SafetyModule {
  final String id;
  final String title;
  final String description;
  final SafetyCategory category;
  final int priority;
  final int estimatedDuration; // in minutes
  final String language;
  final List<SafetyContent> content;

  SafetyModule({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.estimatedDuration,
    required this.language,
    required this.content,
  });

  factory SafetyModule.fromMap(Map<String, dynamic> map) {
    return SafetyModule(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: SafetyCategory.values.firstWhere(
        (e) => e.toString() == 'SafetyCategory.${map['category']}',
        orElse: () => SafetyCategory.digitalSafety,
      ),
      priority: map['priority'] ?? 0,
      estimatedDuration: map['estimatedDuration'] ?? 0,
      language: map['language'] ?? 'english',
      content: (map['content'] as List<dynamic>?)
              ?.map((item) => SafetyContent.fromMap(item))
              .toList() ??
          [],
    );
  }
}

class SafetyContent {
  final ContentType type;
  final String title;
  final String content;
  final String? mediaUrl;

  SafetyContent({
    required this.type,
    required this.title,
    required this.content,
    this.mediaUrl,
  });

  factory SafetyContent.fromMap(Map<String, dynamic> map) {
    return SafetyContent(
      type: ContentType.values.firstWhere(
        (e) => e.toString() == 'ContentType.${map['type']}',
        orElse: () => ContentType.text,
      ),
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      mediaUrl: map['mediaUrl'],
    );
  }
}

class SafetyTip {
  final String id;
  final String title;
  final String content;
  final SafetyScenario scenario;
  final int priority;
  final String language;

  SafetyTip({
    required this.id,
    required this.title,
    required this.content,
    required this.scenario,
    required this.priority,
    required this.language,
  });

  factory SafetyTip.fromMap(Map<String, dynamic> map) {
    return SafetyTip(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      scenario: SafetyScenario.values.firstWhere(
        (e) => e.toString() == 'SafetyScenario.${map['scenario']}',
        orElse: () => SafetyScenario.digitalSafety,
      ),
      priority: map['priority'] ?? 0,
      language: map['language'] ?? 'english',
    );
  }
}

class UserSafetyProgress {
  final String userId;
  final Map<String, ModuleProgress> moduleProgress;
  final int completedModules;
  final int totalModules;
  final double overallProgress;
  final int safetyScore;

  UserSafetyProgress({
    required this.userId,
    required this.moduleProgress,
    required this.completedModules,
    required this.totalModules,
    required this.overallProgress,
    required this.safetyScore,
  });
}

class ModuleProgress {
  final String moduleId;
  final double progress;
  final bool completed;
  final DateTime lastUpdated;
  final DateTime? completedAt;

  ModuleProgress({
    required this.moduleId,
    required this.progress,
    required this.completed,
    required this.lastUpdated,
    this.completedAt,
  });
}

class SafetyQuizQuestion {
  final String id;
  final String moduleId;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String language;

  SafetyQuizQuestion({
    required this.id,
    required this.moduleId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.language,
  });

  factory SafetyQuizQuestion.fromMap(Map<String, dynamic> map) {
    return SafetyQuizQuestion(
      id: map['id'] ?? '',
      moduleId: map['moduleId'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswer: map['correctAnswer'] ?? '',
      explanation: map['explanation'] ?? '',
      language: map['language'] ?? 'english',
    );
  }
}

class QuizResult {
  final double score;
  final int correctAnswers;
  final int totalQuestions;
  final bool passed;
  final Map<String, String> feedback;

  QuizResult({
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.passed,
    required this.feedback,
  });
}

class SafetyAlert {
  final String id;
  final String title;
  final String content;
  final AlertSeverity severity;
  final DateTime createdAt;
  final String? actionUrl;

  SafetyAlert({
    required this.id,
    required this.title,
    required this.content,
    required this.severity,
    required this.createdAt,
    this.actionUrl,
  });

  factory SafetyAlert.fromMap(Map<String, dynamic> map) {
    return SafetyAlert(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      severity: AlertSeverity.values.firstWhere(
        (e) => e.toString() == 'AlertSeverity.${map['severity']}',
        orElse: () => AlertSeverity.info,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      actionUrl: map['actionUrl'],
    );
  }
}

class SafetyEducationStats {
  final int totalUsers;
  final int completedModules;
  final int quizAttempts;
  final int activeAlerts;
  final DateTime lastUpdated;

  SafetyEducationStats({
    required this.totalUsers,
    required this.completedModules,
    required this.quizAttempts,
    required this.activeAlerts,
    required this.lastUpdated,
  });
}
